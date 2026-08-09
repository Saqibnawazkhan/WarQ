import { createContext, use } from 'react';

export type ToastTone = 'neutral' | 'success' | 'danger';

export type ShowToast = (message: string, tone?: ToastTone) => void;

export const ToastContext = createContext<ShowToast | null>(null);

export function useToast(): ShowToast {
  const show = use(ToastContext);

  if (!show) {
    throw new Error('useToast must be called inside <ToastProvider>.');
  }

  return show;
}
