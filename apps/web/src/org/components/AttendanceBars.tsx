import type { OrgDailyAttendance } from '@warq/data';

const WEEKDAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const;

interface AttendanceBarsProps {
  readonly days: readonly OrgDailyAttendance[];
  readonly loading?: boolean | undefined;
}

/**
 * The attendance bar chart from the mockup.
 *
 * Only days that actually had a register are drawn. A holiday is not a day when
 * nobody attended, and plotting it as a zero would misrepresent the institution
 * to its own administrator — so missing days are missing, not flat.
 *
 * The most recent bar is emphasised; the rest recede. Values are labelled above
 * each bar because a bar chart without numbers makes people estimate.
 */
export function AttendanceBars({ days, loading }: AttendanceBarsProps) {
  if (loading) {
    return <p className="py-6 text-[13px] text-ink-muted">Loading…</p>;
  }

  const recent = days.slice(-7);

  if (recent.length === 0) {
    return (
      <p className="py-4 text-[12.5px] leading-relaxed text-ink-muted">
        No registers taken yet. Once your teachers start marking attendance, the last week appears
        here.
      </p>
    );
  }

  return (
    <div className="flex h-[132px] items-end gap-2.5">
      {recent.map((day, index) => {
        const percent = day.attendance_percent ?? 0;
        const latest = index === recent.length - 1;
        const label = day.date
          ? (WEEKDAY[new Date(`${day.date}T00:00:00Z`).getUTCDay()] ?? '')
          : '';

        return (
          <div
            key={day.date}
            className="flex h-full flex-1 flex-col items-center justify-end gap-1.5"
          >
            <span className="text-[10.5px] font-bold text-ink-base tabular-nums">{percent}%</span>

            <div
              className={`w-full rounded-t-lg rounded-b ${latest ? 'bg-accent' : 'bg-[#DCDCEA]'}`}
              style={{ height: `${Math.max(percent, 2)}%` }}
              // The visible bar carries the same value as the label above it.
              role="img"
              aria-label={`${label}: ${percent}% present`}
            />

            <span className="text-[10.5px] font-semibold text-ink-muted">{label}</span>
          </div>
        );
      })}
    </div>
  );
}
