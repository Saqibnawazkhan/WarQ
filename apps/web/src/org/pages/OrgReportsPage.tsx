import { Card, EmptyState } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';

const PLANNED: readonly { name: string; body: string }[] = [
  {
    name: 'Organization report',
    body: 'Teachers, classes, attendance and assessment coverage across the whole institution for a chosen period.',
  },
  {
    name: 'Class report',
    body: 'A register and mark sheet for one class, ready to print or file.',
  },
  {
    name: 'Student report',
    body: 'Attendance, assessment performance and overall grade for one student.',
  },
  {
    name: 'Attendance summary',
    body: 'Daily and monthly attendance per class, for the records an inspection asks for.',
  },
];

export function OrgReportsPage() {
  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Reports" subtitle="Generated PDFs, shared by expiring link" />

      <Card padded={false}>
        <EmptyState
          title="Nothing generated yet"
          body="Rendering runs on the worker, which lands in M8. The four reports below are what it will produce."
        />
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        {PLANNED.map((report) => (
          <Card key={report.name}>
            <h2 className="font-display text-[14px] font-bold">{report.name}</h2>
            <p className="mt-1.5 text-[13px] leading-relaxed text-ink-base">{report.body}</p>
          </Card>
        ))}
      </div>

      <Card>
        <p className="text-[12.5px] leading-relaxed text-ink-muted">
          A report names real students and lists their marks, so each file is served through a
          signed link that expires rather than a public address anyone could forward.
        </p>
      </Card>
    </div>
  );
}
