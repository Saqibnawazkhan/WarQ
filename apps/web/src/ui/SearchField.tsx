import { useId } from 'react';

interface SearchFieldProps {
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly placeholder: string;
  readonly label?: string | undefined;
}

/** The search box that sits above every table in the mockups. */
export function SearchField({ value, onChange, placeholder, label }: SearchFieldProps) {
  const id = useId();

  return (
    <div className="flex h-10 w-full items-center gap-2 rounded-control border border-line bg-raised px-3 sm:w-64">
      <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden="true">
        <circle
          cx="7"
          cy="7"
          r="5"
          stroke="currentColor"
          strokeWidth="1.6"
          className="text-ink-muted"
        />
        <path
          d="M11 11l3.5 3.5"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          className="text-ink-muted"
        />
      </svg>

      <label htmlFor={id} className="sr-only">
        {label ?? placeholder}
      </label>

      <input
        id={id}
        type="search"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        className="min-w-0 flex-1 bg-transparent text-[13px] text-ink placeholder:text-ink-muted"
      />
    </div>
  );
}
