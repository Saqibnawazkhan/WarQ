import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4 px-6 py-24 text-center">
      <p className="font-mono text-[11px] font-bold tracking-[0.12em] text-ink-muted uppercase">
        404
      </p>
      <h1 className="font-display text-3xl font-extrabold tracking-tight">That page isn’t here</h1>
      <p className="text-ink-base">
        The address may be mistyped, or the page may not be built yet. Everything that exists today
        is linked from the home page.
      </p>
      <Link
        to="/"
        className="mx-auto mt-2 inline-flex rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent transition-opacity hover:opacity-93"
      >
        Back to Warq
      </Link>
    </div>
  );
}
