import { color, tint } from '@warq/tokens';

interface TeacherStatePillProps {
  /** `active` or `idle`, derived from when a register was last taken. */
  readonly state: string | null;
}

/**
 * Active or Idle, as the mockup draws it.
 *
 * Idle is not a punishment or a stored flag — it means no register has been
 * taken in a week, which is exactly what an Organization Admin opens the page
 * to notice. The tooltip says so, rather than leaving the word to imply
 * something about the person.
 */
export function TeacherStatePill({ state }: TeacherStatePillProps) {
  const idle = state === 'idle';
  const hex = idle ? color.status.idle : color.status.active;

  return (
    <span
      title={idle ? 'No register taken in the last week' : 'Took a register in the last week'}
      className="shrink-0 rounded-xs px-2.5 py-1 text-[11px] font-extrabold"
      style={{ backgroundColor: tint(hex, '1A'), color: hex }}
    >
      {idle ? 'Idle' : 'Active'}
    </span>
  );
}
