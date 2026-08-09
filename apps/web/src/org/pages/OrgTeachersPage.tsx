import { useMemo, useState, type FormEvent } from 'react';

import { formatCalendarDate, initials, pluralize } from '@warq/core';
import type { InviteResult, OrgTeacher } from '@warq/data';

import {
  Button,
  Card,
  DataTable,
  Drawer,
  Field,
  Modal,
  SearchField,
  useToast,
  type Column,
} from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { TeacherStatePill } from '../components/TeacherStatePill.tsx';
import {
  useInvitations,
  useInviteTeacher,
  useOrgTeachers,
  useRemoveTeacher,
  useRevokeInvitation,
} from '../queries.ts';

export function OrgTeachersPage() {
  const teachers = useOrgTeachers();
  const invitations = useInvitations();
  const [search, setSearch] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);

  const rows = useMemo(() => teachers.data ?? [], [teachers.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return rows;

    return rows.filter((row) =>
      [row.full_name, row.email]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    );
  }, [rows, search]);

  const pendingInvites = (invitations.data ?? []).filter((invite) => invite.status === 'sent');
  const selected = rows.find((row) => row.id === openId) ?? null;

  const columns: Column<OrgTeacher>[] = [
    {
      key: 'name',
      header: 'Teacher',
      width: '1.8fr',
      render: (row) => (
        <div className="flex min-w-0 items-center gap-2.5">
          <span className="flex size-8 shrink-0 items-center justify-center rounded-sm bg-[color-mix(in_srgb,var(--warq-brand-accent)_8%,transparent)] font-display text-[11.5px] font-bold text-accent">
            {initials(row.full_name ?? '?')}
          </span>
          <span className="truncate text-[13.5px] font-bold">{row.full_name}</span>
        </div>
      ),
    },
    {
      key: 'email',
      header: 'Email',
      width: '2fr',
      render: (row) => (
        <p className="truncate text-[12.5px] font-semibold text-ink-base">{row.email}</p>
      ),
    },
    {
      key: 'classes',
      header: 'Classes',
      width: '0.8fr',
      render: (row) => (
        <p className="text-[12.5px] font-bold tabular-nums">{row.class_count ?? 0}</p>
      ),
    },
    {
      key: 'students',
      header: 'Students',
      width: '0.9fr',
      render: (row) => (
        <p className="text-[12.5px] font-bold tabular-nums">{row.student_count ?? 0}</p>
      ),
    },
    {
      key: 'last',
      header: 'Last register',
      width: '1.3fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.last_attendance_date ? formatCalendarDate(row.last_attendance_date) : 'Never'}
        </p>
      ),
    },
    {
      key: 'state',
      header: 'Status',
      width: '1fr',
      render: (row) => <TeacherStatePill state={row.activity_state} />,
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Teachers"
        subtitle={`${pluralize(rows.length, 'teacher')} in your organization`}
        action={
          <div className="flex flex-wrap items-center gap-2.5">
            <SearchField
              value={search}
              onChange={setSearch}
              placeholder="Search teachers"
              label="Search teachers by name or email"
            />
            <Button onClick={() => setInviteOpen(true)}>+ Invite</Button>
          </div>
        }
      />

      {pendingInvites.length > 0 && (
        <Card title={`${pluralize(pendingInvites.length, 'invitation')} not yet accepted`}>
          <ul className="flex flex-col gap-2">
            {pendingInvites.map((invite) => (
              <li
                key={invite.id}
                className="flex flex-wrap items-center gap-3 rounded-tile border border-line-subtle px-3.5 py-2.5"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-bold">{invite.full_name}</p>
                  <p className="truncate text-[11.5px] text-ink-muted">
                    {invite.email} · expires {formatCalendarDate(invite.expires_at.slice(0, 10))}
                  </p>
                </div>
                <InviteLinkActions token={invite.token} name={invite.full_name} />
                <RevokeButton invitationId={invite.id} name={invite.full_name} />
              </li>
            ))}
          </ul>
        </Card>
      )}

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        onRowClick={(row) => setOpenId(row.id)}
        loading={teachers.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No teachers yet',
                body: 'Invite a teacher and they appear here once they accept. Their classes, registers and marks stay with your organization even if they later leave.',
              }
            : { title: 'Nothing matches that', body: 'Try a different search.' }
        }
      />

      <TeacherDrawer teacher={selected} open={openId !== null} onClose={() => setOpenId(null)} />
      <InviteModal open={inviteOpen} onClose={() => setInviteOpen(false)} />
    </div>
  );
}

// ── Invitation ──────────────────────────────────────────────

function InviteModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const invite = useInviteTeacher();
  const toast = useToast();

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [result, setResult] = useState<InviteResult | null>(null);

  function reset() {
    setFullName('');
    setEmail('');
    setResult(null);
    onClose();
  }

  function submit(event: FormEvent, sendVia: 'email' | 'whatsapp') {
    event.preventDefault();

    invite.mutate(
      { email, fullName, sendVia },
      {
        onSuccess: (created) => setResult(created),
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  return (
    <Modal
      open={open}
      onClose={reset}
      title={result ? 'Invitation created' : 'Invite a teacher'}
      description={
        result
          ? undefined
          : 'They will get a link that adds them to your organization when they sign up.'
      }
    >
      {result ? (
        <div className="flex flex-col gap-3">
          {/*
            Automatic delivery is the worker's job in M7. Rather than claim an
            email was sent when nothing was, the link is handed over to send by
            whatever means is at hand.
          */}
          <p className="text-[13px] leading-relaxed text-ink-base">
            Send this link to <strong>{result.invitation.full_name}</strong>. It works once, and
            only for {result.invitation.email}.
          </p>

          <code className="block overflow-x-auto rounded-control border border-line-subtle bg-sunken px-3 py-2.5 font-mono text-[11.5px] text-ink-base">
            {result.link}
          </code>

          <div className="flex flex-wrap gap-2">
            <Button
              variant="secondary"
              onClick={() => {
                void navigator.clipboard.writeText(result.link);
                toast('Link copied');
              }}
            >
              Copy link
            </Button>
            <a
              href={`https://wa.me/?text=${encodeURIComponent(
                `You have been invited to join ${result.invitation.full_name ? '' : ''}Warq. Open this link to join: ${result.link}`,
              )}`}
              target="_blank"
              rel="noreferrer"
              className="rounded-control border border-transparent bg-active px-4 py-2.5 text-[13px] font-bold text-white transition-opacity hover:opacity-92"
            >
              Send on WhatsApp
            </a>
            <a
              href={`mailto:${result.invitation.email}?subject=${encodeURIComponent('Join us on Warq')}&body=${encodeURIComponent(`Open this link to join: ${result.link}`)}`}
              className="rounded-control border border-line-input bg-raised px-4 py-2.5 text-[13px] font-bold text-ink-base"
            >
              Send by email
            </a>
          </div>

          <Button variant="ghost" onClick={reset} className="mt-1 self-start">
            Done
          </Button>

          <p className="text-[12px] text-ink-muted">
            Automatic sending arrives with the notifications worker in M7. Until then the link is
            yours to pass on.
          </p>
        </div>
      ) : (
        <form
          onSubmit={(event) => submit(event, 'email')}
          className="flex flex-col gap-3"
          noValidate
        >
          <Field
            label="Teacher name"
            required
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
          />
          <Field
            label="Teacher email"
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            hint="The invitation only works for this address."
          />

          <div className="mt-1 flex gap-2.5">
            <Button type="submit" disabled={invite.isPending} className="flex-1">
              {invite.isPending ? 'Creating…' : 'Create invitation'}
            </Button>
            <Button variant="ghost" onClick={reset}>
              Cancel
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}

function InviteLinkActions({ token, name }: { token: string; name: string }) {
  const toast = useToast();
  const link = `${window.location.origin}/join/${token}`;

  return (
    <Button
      variant="secondary"
      size="sm"
      onClick={() => {
        void navigator.clipboard.writeText(link);
        toast(`Invitation link for ${name} copied`);
      }}
    >
      Copy link
    </Button>
  );
}

function RevokeButton({ invitationId, name }: { invitationId: string; name: string }) {
  const revoke = useRevokeInvitation();
  const toast = useToast();

  return (
    <Button
      variant="danger"
      size="sm"
      disabled={revoke.isPending}
      onClick={() =>
        revoke.mutate(invitationId, {
          onSuccess: () => toast(`Invitation to ${name} revoked`),
          onError: (cause) => toast(cause.message, 'danger'),
        })
      }
    >
      Revoke
    </Button>
  );
}

// ── Teacher detail ──────────────────────────────────────────

function TeacherDrawer({
  teacher,
  open,
  onClose,
}: {
  teacher: OrgTeacher | null;
  open: boolean;
  onClose: () => void;
}) {
  const remove = useRemoveTeacher();
  const toast = useToast();
  const [confirming, setConfirming] = useState(false);

  if (!teacher) return null;

  const name = teacher.full_name ?? 'This teacher';

  const stats: [string, string][] = [
    ['Classes', String(teacher.class_count ?? 0)],
    ['Students', String(teacher.student_count ?? 0)],
    ['Registers taken', String(teacher.session_count ?? 0)],
    ['Assessments', String(teacher.assessment_count ?? 0)],
  ];

  return (
    <>
      <Drawer open={open} onClose={onClose} title={teacher.full_name ?? 'Teacher'}>
        <div className="flex items-center gap-3">
          <span className="flex size-12 shrink-0 items-center justify-center rounded-tile bg-[color-mix(in_srgb,var(--warq-brand-accent)_8%,transparent)] font-display text-[16px] font-bold text-accent">
            {initials(teacher.full_name ?? '?')}
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="font-display text-[18px] font-bold">{teacher.full_name}</h2>
            <p className="truncate text-[12px] text-ink-muted">{teacher.email}</p>
          </div>
          <TeacherStatePill state={teacher.activity_state} />
        </div>

        <div className="mt-4 grid grid-cols-2 gap-2.5">
          {stats.map(([label, value]) => (
            <div key={label} className="rounded-tile border border-line-subtle px-3.5 py-3">
              <p className="font-display text-[19px] font-bold tabular-nums">{value}</p>
              <p className="mt-0.5 text-[11px] font-semibold text-ink-muted">{label}</p>
            </div>
          ))}
        </div>

        <dl className="mt-4 flex flex-col gap-2 rounded-tile border border-line-subtle px-4 py-3.5 text-[12.5px]">
          <div className="flex justify-between gap-4">
            <dt className="font-semibold text-ink-muted">Last register</dt>
            <dd className="font-bold text-ink-base">
              {teacher.last_attendance_date
                ? formatCalendarDate(teacher.last_attendance_date)
                : 'Never'}
            </dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="font-semibold text-ink-muted">Last assessment</dt>
            <dd className="font-bold text-ink-base">
              {teacher.last_assessment_date
                ? formatCalendarDate(teacher.last_assessment_date)
                : 'None'}
            </dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="font-semibold text-ink-muted">Joined</dt>
            <dd className="font-bold text-ink-base">
              {formatCalendarDate(teacher.joined_at?.slice(0, 10) ?? null)}
            </dd>
          </div>
        </dl>

        <Button variant="danger" onClick={() => setConfirming(true)} className="mt-5 w-full py-3">
          Remove from organization
        </Button>
      </Drawer>

      <Modal
        open={confirming}
        onClose={() => setConfirming(false)}
        title={`Remove ${name}?`}
        width="sm"
      >
        <p className="text-[12.5px] leading-relaxed text-ink-base">
          They lose access immediately. Their classes, registers and marks stay with your
          organization — nothing they recorded is deleted.
        </p>

        <div className="mt-4 flex gap-2.5">
          <Button variant="secondary" onClick={() => setConfirming(false)} className="flex-1">
            Cancel
          </Button>
          <Button
            variant="danger"
            disabled={remove.isPending}
            className="flex-1 border-transparent bg-expired text-white"
            onClick={() =>
              remove.mutate(teacher.id ?? '', {
                onSuccess: () => {
                  setConfirming(false);
                  onClose();
                  toast(`${name} removed · records kept`);
                },
                onError: (cause) => toast(cause.message, 'danger'),
              })
            }
          >
            {remove.isPending ? 'Removing…' : 'Remove'}
          </Button>
        </div>
      </Modal>
    </>
  );
}
