import { useEffect, useRef, type ReactNode } from 'react';

interface ModalProps {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly title: string;
  readonly description?: string | undefined;
  readonly children: ReactNode;
  readonly width?: 'sm' | 'md' | undefined;
}

/**
 * A centred dialog. Same keyboard contract as the drawer: Escape closes, focus
 * moves in on open and returns to the trigger on close, the page behind is
 * locked.
 */
export function Modal({ open, onClose, title, description, children, width = 'md' }: ModalProps) {
  const panel = useRef<HTMLDivElement>(null);
  const returnFocusTo = useRef<Element | null>(null);

  useEffect(() => {
    if (!open) return;

    returnFocusTo.current = document.activeElement;
    panel.current?.focus();

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') onClose();
    }

    document.addEventListener('keydown', onKeyDown);

    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = previousOverflow;
      (returnFocusTo.current as HTMLElement | null)?.focus?.();
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <button
        type="button"
        aria-label="Close"
        onClick={onClose}
        className="absolute inset-0 animate-[fadeIn_0.18s_ease] cursor-default bg-[rgba(23,23,58,0.4)]"
      />

      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={`relative w-full animate-[drawerIn_0.2s_ease] rounded-sheet bg-raised p-6 outline-none ${
          width === 'sm' ? 'max-w-sm' : 'max-w-md'
        }`}
      >
        <h2 className="font-display text-[17px] font-bold">{title}</h2>
        {description && <p className="mt-1 text-[12.5px] text-ink-muted">{description}</p>}
        <div className="mt-4">{children}</div>
      </div>
    </div>
  );
}
