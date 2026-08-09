import { Card, EmptyState } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';

const PLANNED: readonly { name: string; body: string }[] = [
  {
    name: 'Platform report',
    body: 'Organizations, teachers, students and subscription mix across the whole platform, for a chosen period.',
  },
  {
    name: 'Organization report',
    body: 'One institution: its teachers, classes, attendance and assessment coverage.',
  },
  {
    name: 'Class report',
    body: 'A register and mark sheet for one class, ready to print or file.',
  },
  {
    name: 'Student report',
    body: 'Attendance, assessment performance and overall grade for one student.',
  },
];

export function ReportsPage() {
  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Reports" subtitle="Generated PDFs, stored and shared by signed link" />

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
          Reports name real students and list their marks, so each file is served through a signed,
          expiring link rather than a public URL — the same rule that keeps a Main Admin out of
          student records in the first place.
        </p>
      </Card>
    </div>
  );
}
