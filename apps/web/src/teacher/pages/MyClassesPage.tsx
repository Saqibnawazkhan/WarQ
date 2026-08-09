import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import { formatCalendarDate, pluralize } from '@warq/core';
import { color } from '@warq/tokens';

import { Button, Card, EmptyState, Field, Modal, useToast } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useCreateClass, useMyClasses } from '../queries.ts';

export function MyClassesPage() {
  const classes = useMyClasses();
  const [creating, setCreating] = useState(false);
  const rows = classes.data ?? [];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Classes"
        subtitle={`${pluralize(rows.length, 'class', 'classes')} this session`}
        action={<Button onClick={() => setCreating(true)}>+ New class</Button>}
      />

      {classes.isLoading ? (
        <Card>
          <p className="py-6 text-center text-[13px] text-ink-muted">Loading…</p>
        </Card>
      ) : rows.length === 0 ? (
        <Card padded={false}>
          <EmptyState
            title="No classes yet"
            body="A class holds your students, their registers and their marks. Create one to begin."
            action={<Button onClick={() => setCreating(true)}>Create a class</Button>}
          />
        </Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {rows.map((row) => (
            <Link
              key={row.id}
              to={`/teacher/classes/${row.id ?? ''}`}
              className="flex gap-3 rounded-card border border-line bg-raised p-4 transition-colors hover:border-line-hover"
            >
              <span
                aria-hidden="true"
                className="w-2 shrink-0 rounded-pill"
                style={{ backgroundColor: color.series[(row.color_index ?? 0) % 6] }}
              />

              <div className="min-w-0 flex-1">
                <h2 className="truncate font-display text-[15.5px] font-bold">{row.name}</h2>
                <p className="mt-0.5 text-[12px] text-ink-muted">
                  Section {row.section} · Session {row.session}
                </p>

                <dl className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-[12px] font-semibold text-ink-base">
                  <div className="flex gap-1">
                    <dt className="text-ink-muted">Students</dt>
                    <dd className="tabular-nums">{row.student_count ?? 0}</dd>
                  </div>
                  <div className="flex gap-1">
                    <dt className="text-ink-muted">Attendance</dt>
                    <dd className="tabular-nums">
                      {(row.session_count ?? 0) === 0 ? '—' : `${row.attendance_percent ?? 0}%`}
                    </dd>
                  </div>
                  <div className="flex gap-1">
                    <dt className="text-ink-muted">Assessments</dt>
                    <dd className="tabular-nums">{row.assessment_count ?? 0}</dd>
                  </div>
                </dl>

                <p className="mt-2 text-[11.5px] text-ink-faint">
                  {row.last_session_date
                    ? `Last register ${formatCalendarDate(row.last_session_date)}`
                    : 'No register taken yet'}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}

      <CreateClassModal open={creating} onClose={() => setCreating(false)} />
    </div>
  );
}

function CreateClassModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const create = useCreateClass();
  const toast = useToast();
  const navigate = useNavigate();

  const [name, setName] = useState('');
  const [section, setSection] = useState('');
  // Most classes belong to the current academic year, so it is filled in rather
  // than asked for.
  const [session, setSession] = useState(String(new Date().getUTCFullYear()));

  function reset() {
    setName('');
    setSection('');
    onClose();
  }

  function submit(event: FormEvent) {
    event.preventDefault();

    create.mutate(
      { name, section, session },
      {
        onSuccess: (created) => {
          toast(`${name} created`, 'success');
          reset();
          if (created?.id) void navigate(`/teacher/classes/${created.id}`);
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  return (
    <Modal
      open={open}
      onClose={reset}
      title="New class"
      description="You can add students straight afterwards."
    >
      <form onSubmit={submit} className="flex flex-col gap-3" noValidate>
        <Field
          label="Class name"
          required
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Software Engineering"
        />
        <Field
          label="Section"
          required
          value={section}
          onChange={(event) => setSection(event.target.value)}
          placeholder="A"
        />
        <Field
          label="Session"
          required
          value={session}
          onChange={(event) => setSession(event.target.value)}
          hint="The academic year this class belongs to."
        />

        <div className="mt-1 flex gap-2.5">
          <Button type="submit" disabled={create.isPending} className="flex-1">
            {create.isPending ? 'Creating…' : 'Create class'}
          </Button>
          <Button variant="ghost" onClick={reset}>
            Cancel
          </Button>
        </div>
      </form>
    </Modal>
  );
}
