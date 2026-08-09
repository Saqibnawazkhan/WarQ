import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';

import { ToastContext, type ToastTone } from './toast-context.ts';

interface ActiveToast {
  readonly id: number;
  readonly message: string;
  readonly tone: ToastTone;
}

const TONE: Readonly<Record<ToastTone, string>> = {
  neutral: 'bg-inverse text-white',
  success: 'bg-active text-white',
  danger: 'bg-expired text-white',
};

/**
 * The dark pill that confirms an action, exactly as the mockups draw it.
 *
 * A control says what it will do; the toast says it in the past tense — Approve,
 * then "Approved". Announced politely so a screen reader hears it without having
 * focus yanked away.
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<ActiveToast | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const nextId = useRef(0);

  const show = useCallback((message: string, tone: ToastTone = 'neutral') => {
    if (timer.current) clearTimeout(timer.current);

    nextId.current += 1;
    setToast({ id: nextId.current, message, tone });
    timer.current = setTimeout(() => setToast(null), 3200);
  }, []);

  useEffect(() => () => (timer.current ? clearTimeout(timer.current) : undefined), []);

  return (
    <ToastContext value={show}>
      {children}

      <div
        aria-live="polite"
        aria-atomic="true"
        className="pointer-events-none fixed inset-x-0 bottom-7 z-50 flex justify-center px-4"
      >
        {toast && (
          <p
            key={toast.id}
            className={`animate-[toastIn_0.22s_ease] max-w-full truncate rounded-pill px-5 py-3 text-[13px] font-semibold shadow-toast ${TONE[toast.tone]}`}
          >
            {toast.message}
          </p>
        )}
      </div>
    </ToastContext>
  );
}
