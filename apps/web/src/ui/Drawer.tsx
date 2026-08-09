import { useEffect, useRef, type ReactNode } from 'react';

interface DrawerProps {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly title: string;
  readonly children: ReactNode;
}

/**
 * The right-hand detail panel from the mockups.
 *
 * Closes on Escape and on a click outside, moves focus in on open and back to
 * the trigger on close, and locks the page behind it — a drawer you cannot
 * escape from with a keyboard is a trap, not a panel.
 */
export function Drawer({ open, onClose, title, children }: DrawerProps) {
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
    <div className="fixed inset-0 z-40">
      <button
        type="button"
        aria-label="Close"
        onClick={onClose}
        className="absolute inset-0 animate-[fadeIn_0.18s_ease] cursor-default bg-[rgba(23,23,58,0.35)]"
      />

      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className="absolute inset-y-0 right-0 w-full max-w-[430px] animate-[drawerIn_0.22s_ease] overflow-y-auto bg-raised p-6 shadow-drawer outline-none"
      >
        {children}
      </div>
    </div>
  );
}
