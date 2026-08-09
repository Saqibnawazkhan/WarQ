-- Warq · M1 · Dashboard views
--
-- Aggregation belongs in the database, not in three clients that would each
-- drift. An attendance percentage must read the same on the web dashboard, on
-- the phone, and in a generated PDF.
--
-- Every view is created `with (security_invoker = true)`. Without it a view runs
-- with its owner's rights and quietly bypasses row-level security - which would
-- undo every policy in the previous migration.

-- ─────────────────────────────────────────────────────────────
-- v_effective_subscriptions
-- ─────────────────────────────────────────────────────────────

create view public.v_effective_subscriptions
with (security_invoker = true) as
select
  s.id,
  s.organization_id,
  s.profile_id,
  s.plan,
  s.status as stored_status,
  public.fn_effective_subscription_status(s.plan, s.status, s.ends_at) as status,
  s.starts_at,
  s.ends_at,
  case
    when s.plan = 'permanent' or s.ends_at is null then null
    else s.ends_at - current_date
  end as days_remaining,
  public.fn_effective_subscription_status(s.plan, s.status, s.ends_at)
    in ('active', 'expiring_soon') as grants_access,
  s.price_cents,
  s.currency,
  s.created_at
from public.subscriptions s;

comment on view public.v_effective_subscriptions is
  'Subscriptions with the derived status attached. Every badge in the product reads status from here, never from subscriptions.status.';

-- ─────────────────────────────────────────────────────────────
-- v_class_attendance
-- ─────────────────────────────────────────────────────────────

create view public.v_class_attendance
with (security_invoker = true) as
with per_student as (
  select
    c.id as class_id,
    st.id as student_id,
    count(*) filter (where r.mark = 'present') as present,
    count(*) filter (where r.mark = 'absent') as absent,
    count(*) filter (where r.mark = 'late') as late,
    count(r.*) as sessions
  from public.classes c
  join public.students st on st.class_id = c.id
  left join public.attendance_records r on r.student_id = st.id
  group by c.id, st.id
)
select
  c.id as class_id,
  c.organization_id,
  c.teacher_id,
  c.name,
  c.section,
  c.session,
  c.color_index,
  count(distinct ps.student_id) as student_count,
  (select count(*) from public.attendance_sessions s where s.class_id = c.id) as session_count,
  (select count(*) from public.assessments a where a.class_id = c.id) as assessment_count,
  coalesce(sum(ps.present), 0)::bigint as present_total,
  coalesce(sum(ps.absent), 0)::bigint as absent_total,
  coalesce(sum(ps.late), 0)::bigint as late_total,
  -- Averaged per student, not per session: each student counts once, so one
  -- heavily-attending student cannot mask the rest of the class. Matches
  -- averageAttendance() in @warq/core.
  coalesce(
    round(avg(public.fn_percentage(ps.present, nullif(ps.sessions, 0))))::integer,
    0
  ) as attendance_percent,
  (select max(s.date) from public.attendance_sessions s where s.class_id = c.id) as last_session_date
from public.classes c
left join per_student ps on ps.class_id = c.id
where c.archived_at is null
group by c.id;

comment on view public.v_class_attendance is
  'One row per class: roster size, session and assessment counts, and the attendance percentage averaged per student.';

-- ─────────────────────────────────────────────────────────────
-- v_student_performance
-- ─────────────────────────────────────────────────────────────

create view public.v_student_performance
with (security_invoker = true) as
with attendance as (
  select
    st.id as student_id,
    count(*) filter (where r.mark = 'present') as present,
    count(*) filter (where r.mark = 'absent') as absent,
    count(*) filter (where r.mark = 'late') as late,
    count(r.*) as sessions
  from public.students st
  left join public.attendance_records r on r.student_id = st.id
  group by st.id
),
scores as (
  -- Unmarked work is excluded from both sides of the fraction. A student is
  -- never failed for an assessment their teacher has not graded yet.
  select
    st.id as student_id,
    coalesce(sum(m.score) filter (where m.score is not null), 0) as obtained,
    coalesce(sum(a.total_marks) filter (where m.score is not null), 0) as total,
    count(*) filter (where m.score is not null) as marked,
    count(a.*) filter (where m.score is null or m.assessment_id is null) as pending
  from public.students st
  join public.classes c on c.id = st.class_id
  left join public.assessments a on a.class_id = c.id
  left join public.marks m on m.assessment_id = a.id and m.student_id = st.id
  group by st.id
)
select
  st.id as student_id,
  st.class_id,
  c.organization_id,
  c.teacher_id,
  st.full_name,
  st.roll_no,
  att.present,
  att.absent,
  att.late,
  att.sessions,
  public.fn_percentage(att.present, nullif(att.sessions, 0)) as attendance_percent,
  sc.obtained,
  sc.total,
  sc.marked as assessments_marked,
  sc.pending as assessments_pending,
  public.fn_percentage(sc.obtained, nullif(sc.total, 0)) as marks_percent,
  case
    when sc.marked = 0 then null
    else public.fn_grade_for(
      public.fn_percentage(sc.obtained, nullif(sc.total, 0)),
      c.organization_id
    )
  end as grade
from public.students st
join public.classes c on c.id = st.class_id
left join attendance att on att.student_id = st.id
left join scores sc on sc.student_id = st.id;

comment on view public.v_student_performance is
  'One row per student: attendance breakdown, marks total and letter grade. Grade is null when nothing is marked - which is not the same as F.';

-- ─────────────────────────────────────────────────────────────
-- v_org_overview
-- ─────────────────────────────────────────────────────────────

create view public.v_org_overview
with (security_invoker = true) as
select
  o.id as organization_id,
  o.name,
  o.city,
  o.status,
  (select count(*) from public.profiles p
    where p.organization_id = o.id and p.role = 'teacher') as teacher_count,
  (select count(*) from public.classes c
    where c.organization_id = o.id and c.archived_at is null) as class_count,
  (select count(*) from public.students st
    join public.classes c on c.id = st.class_id
    where c.organization_id = o.id and c.archived_at is null) as student_count,
  (select count(*) from public.attendance_sessions s
    join public.classes c on c.id = s.class_id
    where c.organization_id = o.id and s.date = current_date) as classes_marked_today,
  (select coalesce(round(avg(v.attendance_percent))::integer, 0)
    from public.v_class_attendance v
    where v.organization_id = o.id) as attendance_percent
from public.organizations o;

comment on view public.v_org_overview is
  'The figures across the top of the Organization Admin dashboard, and the teacher and student counts the Main Admin sees per organization.';

-- ─────────────────────────────────────────────────────────────
-- v_platform_overview
-- ─────────────────────────────────────────────────────────────

-- The Main Admin dashboard statistics. Under security_invoker this returns
-- platform-wide numbers to a Main Admin and near-empty numbers to anyone else,
-- because the underlying policies decide what they can count.
create view public.v_platform_overview
with (security_invoker = true) as
select
  (select count(*) from public.organizations) as organization_count,
  (select count(*) from public.organizations where status = 'active') as active_organization_count,
  (select count(*) from public.profiles
    where role = 'teacher' and organization_id is null) as individual_teacher_count,
  (select count(*) from public.profiles
    where role = 'teacher' and organization_id is not null) as organization_teacher_count,
  (select count(*) from public.v_effective_subscriptions
    where status in ('active', 'expiring_soon')) as active_subscription_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'expiring_soon') as expiring_soon_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'expired') as expired_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'pending') as pending_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'monthly') as monthly_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'yearly') as yearly_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'permanent') as permanent_count;

comment on view public.v_platform_overview is
  'The Main Admin dashboard figures, including the subscriptions-by-plan bars.';
