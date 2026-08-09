import { useState } from 'react';

import { EXPIRY_REMINDER_DAYS, pluralize } from '@warq/core';

import { Button, Card, Chip, EmptyState, useToast } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { useReminderLog, useReminderSchedule, useSaveReminderSchedule } from '../queries.ts';

/**
 * The reminder schedule and the log of what has gone out.
 *
 * Offsets are toggles rather than free text: a schedule of arbitrary numbers is
 * harder to reason about and easy to make absurd, and the five in the mockups
 * cover every case anyone asked for.
 */
export function NotificationsPage() {
  const schedule = useReminderSchedule();
  const save = useSaveReminderSchedule();
  const log = useReminderLog();
  const toast = useToast();

  /**
   * Null until the administrator touches a chip, at which point it holds their
   * unsaved edit.
   *
   * Derived rather than copied out of the query with an effect: an effect that
   * mirrors server state into local state has to decide what to do when the
   * server changes underneath an unsaved edit, and every answer is wrong. This
   * way the saved schedule shows through until there is an edit, and the edit
   * wins until it is saved or discarded.
   */
  const [edit, setEdit] = useState<number[] | null>(null);

  const saved = schedule.data ?? [];
  const selected = edit ?? saved;
  const dirty = edit !== null;

  function toggle(day: number) {
    setEdit((current) => {
      const base = current ?? saved;
      return base.includes(day) ? base.filter((value) => value !== day) : [...base, day];
    });
  }

  function handleSave() {
    if (selected.length === 0) {
      toast('Keep at least one reminder, or nobody is warned before expiry.', 'danger');
      return;
    }

    save.mutate(selected, {
      onSuccess: () => {
        // Drop the local edit so the freshly refetched schedule shows through.
        setEdit(null);
        toast(`Schedule saved · ${pluralize(selected.length, 'reminder')}`, 'success');
      },
      onError: (cause) => toast(cause.message, 'danger'),
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Notifications"
        subtitle="When subscribers are reminded that their subscription is ending"
      />

      <Card title="Reminder schedule">
        <p className="text-[12.5px] text-ink-muted">
          A notice goes out this many days before the end date. One notice per step — a retried job
          cannot send the same reminder twice.
        </p>

        <div className="mt-3.5 flex flex-wrap gap-2">
          {EXPIRY_REMINDER_DAYS.map((day) => (
            <Chip
              key={day}
              label={day === 1 ? '1 day before' : `${day} days before`}
              selected={selected.includes(day)}
              onSelect={() => toggle(day)}
            />
          ))}
        </div>

        <div className="mt-4 flex items-center gap-3">
          <Button onClick={handleSave} disabled={!dirty || save.isPending}>
            {save.isPending ? 'Saving…' : 'Save schedule'}
          </Button>
          {dirty && (
            <button
              type="button"
              onClick={() => setEdit(null)}
              className="cursor-pointer text-[12px] font-bold text-ink-muted hover:text-ink-base"
            >
              Discard changes
            </button>
          )}
        </div>

        <p className="mt-3 text-[12px] text-ink-muted">
          Sending is handled by the worker, which lands in M7. Until then the schedule is stored but
          no email leaves the building.
        </p>
      </Card>

      <Card title="Sent log" padded={(log.data?.length ?? 0) > 0}>
        {log.isLoading ? (
          <p className="py-6 text-center text-[13px] text-ink-muted">Loading…</p>
        ) : (log.data?.length ?? 0) === 0 ? (
          <EmptyState
            title="Nothing sent yet"
            body="Every expiry reminder is recorded here — who it went to, which step it was, and through which channel."
          />
        ) : (
          <ul className="flex flex-col gap-2.5">
            {log.data?.map((entry) => (
              <li key={entry.id} className="flex items-start gap-2.5">
                <span
                  aria-hidden="true"
                  className="mt-[5px] size-[7px] shrink-0 rounded-pill bg-expiring"
                />
                <p className="flex-1 text-[12.5px] leading-relaxed text-ink-base">
                  {entry.message}
                </p>
                <span className="shrink-0 text-[11px] text-ink-faint tabular-nums">
                  {entry.days_before}d · {entry.channel}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
