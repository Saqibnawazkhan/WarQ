import { Card } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';

interface PlaceholderPageProps {
  readonly title: string;
  readonly body: string;
}

/** A nav destination that exists but is still being built. Says so rather than 404ing. */
export function PlaceholderPage({ title, body }: PlaceholderPageProps) {
  return (
    <div className="flex flex-col gap-5">
      <PageHeading title={title} />
      <Card>
        <p className="text-[13.5px] leading-relaxed text-ink-base">{body}</p>
        <p className="mt-2 text-[13px] text-ink-muted">Landing shortly, still in M2.</p>
      </Card>
    </div>
  );
}
