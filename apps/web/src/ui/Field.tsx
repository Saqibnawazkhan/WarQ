import { useId, type InputHTMLAttributes, type ReactNode } from 'react';

import { cx } from '../lib/cx.ts';

interface FieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'id' | 'className'> {
  readonly label: string;
  /** Shown under the field. Replaced by `error` when there is one. */
  readonly hint?: ReactNode | undefined;
  readonly error?: string | undefined;
  readonly className?: string | undefined;
}

/** A labelled text input. The label is always present — never a placeholder standing in for one. */
export function Field({ label, hint, error, className, ...rest }: FieldProps) {
  const id = useId();
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined;

  return (
    <div className={cx('flex flex-col gap-1.5', className)}>
      <label htmlFor={id} className="text-[12.5px] font-bold text-ink-base">
        {label}
      </label>

      <input
        id={id}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        className={cx(
          'h-12 rounded-field border bg-sunken px-3.5 text-[14px] text-ink',
          'placeholder:text-ink-faint',
          error ? 'border-expired' : 'border-line-input',
        )}
        {...rest}
      />

      {error ? (
        <p id={`${id}-error`} className="text-[12px] font-semibold text-expired">
          {error}
        </p>
      ) : hint ? (
        <p id={`${id}-hint`} className="text-[12px] text-ink-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}
