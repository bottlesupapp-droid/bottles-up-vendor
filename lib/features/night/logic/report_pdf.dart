import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'night_rules.dart';

/// The standard PDF fonts only hold Latin-1, so a few common typographic characters are swapped for plain ones and anything else outside
/// it becomes "?". (A name in another alphabet prints as question marks in the PDF; it is complete on the screen.)
String pdfSafe(String s) {
  const swaps = {'·': '-', '–': '-', '—': '-', '‘': "'", '’': "'", '“': '"', '”': '"', '…': '...', '•': '-'};
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (swaps.containsKey(ch)) {
      out.write(swaps[ch]);
    } else if (rune < 256) {
      out.write(ch);
    } else {
      out.write('?');
    }
  }
  return out.toString();
}

/// The report as a PDF: the title, who and when, whether it is final, then each section as a two-column table. [compress] is switched off
/// in tests so the words can be found in the bytes.
Future<Uint8List> buildReportPdf(ReportDocument doc, {bool compress = true}) async {
  final pdf = pw.Document(title: pdfSafe(doc.title), author: 'BottlesUp', compress: compress);
  final base = pw.TextStyle(fontSize: 10);
  final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(pdfSafe('BottlesUp  -  page ${context.pageNumber} of ${context.pagesCount}'), style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ),
      build: (context) => [
        pw.Text(pdfSafe(doc.title), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(pdfSafe(doc.subtitle), style: pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(pdfSafe(doc.statusLine), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        pw.SizedBox(height: 14),
        for (final s in doc.sections) ...[
          pw.Text(pdfSafe(s.title), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Table(
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            children: [
              for (final row in s.rows)
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(pdfSafe(row.label), style: row.strong ? bold : base)),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(pdfSafe(row.value), style: row.strong ? bold : base, textAlign: pw.TextAlign.right)),
                ]),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      ],
    ),
  );
  return pdf.save();
}
