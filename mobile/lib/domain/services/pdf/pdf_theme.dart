import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared look and reusable building blocks for every generated report.
///
/// Only the fonts bundled with the `pdf` package are used, so report
/// generation works completely offline.
class PdfTheme {
  const PdfTheme._();

  static const PdfColor brand = PdfColor.fromInt(0xFF2E5BFF);
  static const PdfColor brandSoft = PdfColor.fromInt(0xFFEAEFFF);
  static const PdfColor ink = PdfColor.fromInt(0xFF0F1729);
  static const PdfColor muted = PdfColor.fromInt(0xFF667085);
  static const PdfColor border = PdfColor.fromInt(0xFFE4E7EC);
  static const PdfColor surface = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor success = PdfColor.fromInt(0xFF1EA97C);
  static const PdfColor successSoft = PdfColor.fromInt(0xFFE3F6EF);
  static const PdfColor warning = PdfColor.fromInt(0xFFF2A93B);
  static const PdfColor warningSoft = PdfColor.fromInt(0xFFFDF2E0);
  static const PdfColor danger = PdfColor.fromInt(0xFFE5484D);
  static const PdfColor dangerSoft = PdfColor.fromInt(0xFFFDECEC);

  static pw.ThemeData theme() {
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    ).copyWith(
      defaultTextStyle: pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 9.5,
        color: ink,
        lineSpacing: 1.4,
      ),
    );
  }

  static pw.PageTheme pageTheme({
    PdfPageFormat format = PdfPageFormat.a4,
    bool landscape = false,
  }) {
    final PdfPageFormat resolved = landscape ? format.landscape : format;
    return pw.PageTheme(
      pageFormat: resolved.copyWith(
        marginLeft: 32,
        marginRight: 32,
        marginTop: 34,
        marginBottom: 40,
      ),
      theme: theme(),
    );
  }

  // ---------------------------------------------------------------------------
  // Text styles
  // ---------------------------------------------------------------------------

  static pw.TextStyle get title => pw.TextStyle(
        fontSize: 19,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      );

  static pw.TextStyle get subtitle => const pw.TextStyle(
        fontSize: 10.5,
        color: muted,
      );

  static pw.TextStyle get sectionTitle => pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      );

  static pw.TextStyle get label => const pw.TextStyle(
        fontSize: 8,
        color: muted,
        letterSpacing: 0.4,
      );

  static pw.TextStyle get value => pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      );

  static pw.TextStyle get tableHeader => pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: muted,
      );

  static const pw.TextStyle tableCell = pw.TextStyle(fontSize: 9, color: ink);

  static pw.TextStyle get metricValue => pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      );

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Folds typographic characters to ASCII.
  ///
  /// The report uses the fonts bundled with the `pdf` package (Helvetica),
  /// which only cover Latin-1. Characters such as the em dash the UI uses for
  /// "no value" would otherwise be dropped silently, leaving blanks in the
  /// printed report. Folding them here keeps generation fully offline — no
  /// downloaded font, no network at report time.
  static String ascii(String value) => value
      .replaceAll('—', '-') // em dash
      .replaceAll('–', '-') // en dash
      .replaceAll('…', '...') // ellipsis
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('•', '-'); // bullet

  /// A `pw.Text` with [ascii] applied. Every string in a report goes through
  /// this so no call site has to remember the encoding limitation.
  static pw.Widget pdfText(
    String value, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    int? maxLines,
  }) {
    return pw.Text(
      ascii(value),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  /// Report header with the app mark, a title and a right-aligned meta block.
  static pw.Widget header({
    required String title,
    required String subtitle,
    required List<String> meta,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Row(
                    children: <pw.Widget>[
                      pw.Container(
                        width: 22,
                        height: 22,
                        decoration: const pw.BoxDecoration(
                          color: brand,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(5)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'E',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'EDU Manager',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: brand,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pdfText(title, style: PdfTheme.title),
                  pw.SizedBox(height: 3),
                  pdfText(subtitle, style: PdfTheme.subtitle),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                for (final String line in meta)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pdfText(line, style: PdfTheme.subtitle),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: brand),
      ],
    );
  }

  static pw.Widget footer(pw.Context context, String generatedAt) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pdfText('Generated $generatedAt', style: PdfTheme.label),
          pdfText(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: PdfTheme.label,
          ),
        ],
      ),
    );
  }

  static pw.Widget sectionHeading(String text, {String? trailing}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: <pw.Widget>[
          pdfText(text, style: sectionTitle),
          if (trailing != null) pdfText(trailing, style: subtitle),
        ],
      ),
    );
  }

  /// A bordered card used to group a section's content.
  static pw.Widget card({
    required pw.Widget child,
    PdfColor background = PdfColors.white,
    PdfColor borderColor = border,
    double padding = 12,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(padding),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: child,
    );
  }

  /// Label/value pair used inside information cards.
  static pw.Widget field(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pdfText(label.toUpperCase(), style: PdfTheme.label),
        pw.SizedBox(height: 2),
        pdfText(value, style: PdfTheme.value),
      ],
    );
  }

  /// Grid of label/value pairs that wraps across the page width.
  static pw.Widget fieldGrid(
    List<({String label, String value})> fields, {
    int columns = 3,
  }) {
    final List<pw.Widget> rows = <pw.Widget>[];
    for (int i = 0; i < fields.length; i += columns) {
      final List<({String label, String value})> chunk =
          fields.sublist(i, (i + columns).clamp(0, fields.length));
      rows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: i + columns < fields.length ? 10 : 0),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              for (int c = 0; c < columns; c++)
                pw.Expanded(
                  child: c < chunk.length
                      ? field(chunk[c].label, chunk[c].value)
                      : pw.SizedBox(),
                ),
            ],
          ),
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// Highlighted statistic tile.
  static pw.Widget metric(
    String label,
    String value, {
    PdfColor background = surface,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pdfText(label.toUpperCase(), style: PdfTheme.label),
          pw.SizedBox(height: 3),
          pdfText(
            value,
            style: valueColor == null
                ? metricValue
                : metricValue.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget metricRow(List<pw.Widget> metrics) {
    // Deliberately not `stretch`: a stretched row inside the unbounded height
    // of a MultiPage resolves to an infinite height and fails to lay out.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        for (int i = 0; i < metrics.length; i++) ...<pw.Widget>[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: metrics[i]),
        ],
      ],
    );
  }

  /// Small coloured pill, used for grades and statuses.
  static pw.Widget badge(
    String text, {
    PdfColor background = brandSoft,
    PdfColor color = brand,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pdfText(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// Horizontal progress bar used for percentages and distributions.
  ///
  /// Built from two flexible children rather than a fractional box so it only
  /// relies on layout primitives the `pdf` package is guaranteed to provide.
  static pw.Widget bar(double fraction, {PdfColor? color, double height = 6}) {
    final double clamped =
        fraction.isNaN || fraction.isInfinite ? 0 : fraction.clamp(0, 1);
    final int filled = (clamped * 1000).round();
    final int remaining = 1000 - filled;

    return pw.Container(
      height: height,
      decoration: const pw.BoxDecoration(
        color: border,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          if (filled > 0)
            pw.Expanded(
              flex: filled,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: color ?? brand,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
            ),
          if (remaining > 0) pw.Expanded(flex: remaining, child: pw.SizedBox()),
        ],
      ),
    );
  }

  /// Table with a tinted header row and zebra striping.
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
    List<pw.Alignment>? alignments,
  }) {
    pw.Alignment alignmentFor(int index) {
      if (alignments == null || index >= alignments.length) {
        return pw.Alignment.centerLeft;
      }
      return alignments[index];
    }

    return pw.Table(
      columnWidths: columnWidths,
      border: pw.TableBorder.all(color: border, width: 0.5),
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surface),
          children: <pw.Widget>[
            for (int i = 0; i < headers.length; i++)
              pw.Container(
                alignment: alignmentFor(i),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: pdfText(headers[i].toUpperCase(), style: tableHeader),
              ),
          ],
        ),
        for (int r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? surface : PdfColors.white,
            ),
            children: <pw.Widget>[
              for (int c = 0; c < headers.length; c++)
                pw.Container(
                  alignment: alignmentFor(c),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  child: pdfText(
                    c < rows[r].length ? rows[r][c] : '',
                    style: tableCell,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Picks a colour for a percentage: green good, amber borderline, red poor.
  static PdfColor colorForPercent(double? percent) {
    if (percent == null) return muted;
    if (percent >= 75) return success;
    if (percent >= 50) return warning;
    return danger;
  }

  static PdfColor softColorForPercent(double? percent) {
    if (percent == null) return surface;
    if (percent >= 75) return successSoft;
    if (percent >= 50) return warningSoft;
    return dangerSoft;
  }
}
