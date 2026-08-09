import type { ButtonHTMLAttributes, ReactNode } from 'react';

import { cx } from '../lib/cx.ts';

export type ButtonVariant = 'primary' | 'secondary' | 'approve' | 'danger' | 'ghost';
export type ButtonSize = 'sm' | 'md';

const VARIANT: Readonly<Record<ButtonVariant, string>> = {
  primary: 'bg-accent text-on-accent border-transparent hover:opacity-93',
  secondary: 'bg-raised text-ink-base border-line-input hover:border-line-hover',
  approve: 'bg-active text-white border-transparent hover:opacity-92',
  danger: 'bg-raised text-expired border-[#F3C4C4] hover:bg-[#DC26260A]',
  ghost: 'bg-transparent text-ink-muted border-transparent hover:bg-hover',
};

const SIZE: Readonly<Record<ButtonSize, string>> = {
  sm: 'rounded-sm px-3 py-1.5 text-xs',
  md: 'rounded-control px-4 py-2.5 text-[13px]',
};

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'> {
  readonly children: ReactNode;
  readonly variant?: ButtonVariant | undefined;
  readonly size?: ButtonSize | undefined;
  readonly className?: string | undefined;
}

/** Label a button with what it does — the toast afterwards says it in the past tense. */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  className,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      className={cx(
        'cursor-pointer border font-bold whitespace-nowrap transition-opacity',
        'disabled:cursor-not-allowed disabled:opacity-50',
        VARIANT[variant],
        SIZE[size],
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  );
}
