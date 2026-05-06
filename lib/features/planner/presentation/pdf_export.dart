import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../shared/models/monthly_plan.dart';
import '../../../shared/models/planner_slot.dart';

/// Generates and shares a landscape A4 PDF of the given monthly plan.
///
/// Cross-platform: iOS, Android, macOS, Windows, web — `printing` handles
/// the share/print sheet for each.
class PlannerPdfExport {
  PlannerPdfExport._();

  static Future<void> exportAndShare(MonthlyPlan plan) async {
    final doc = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interSemiBold();
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => _buildLayout(plan),
      ),
    );

    final bytes = await doc.save();
    final filename =
        'BRsimo-${plan.year}-${plan.month.toString().padLeft(2, '0')}-plan.pdf';

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ---------- Layout ----------

  static pw.Widget _buildLayout(MonthlyPlan plan) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(plan),
        pw.SizedBox(height: 10),
        _calendar(plan),
        pw.SizedBox(height: 8),
        _legend(plan),
      ],
    );
  }

  static pw.Widget _header(MonthlyPlan plan) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BR Simo Agency — Content Plan',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              plan.displayMonthYear,
              style: const pw.TextStyle(fontSize: 22),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              plan.isConfirmed ? 'CONFIRMED' : 'DRAFT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: plan.isConfirmed
                    ? PdfColor.fromInt(0xFF10B981)
                    : PdfColor.fromInt(0xFFF59E0B),
              ),
            ),
            pw.Text(
              '${plan.totalCommitments} commitments · ${plan.totalPlacedSlots} placed',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _calendar(MonthlyPlan plan) {
    final daysInMonth = DateTime(plan.year, plan.month + 1, 0).day;
    final firstOfMonth = DateTime(plan.year, plan.month, 1);
    final firstColIdx = _saturdayFirstIndex(firstOfMonth.weekday);

    final slotsByDate = <int, List<PlannerSlot>>{};
    for (final s in plan.slots) {
      slotsByDate.putIfAbsent(s.slotDate.day, () => []).add(s);
    }

    final rows = <pw.TableRow>[];
    rows.add(_headerRow());

    var day = 1;
    var weekIdx = 0;
    while (day <= daysInMonth) {
      final cells = <pw.Widget>[];
      for (var col = 0; col < 7; col++) {
        if (weekIdx == 0 && col < firstColIdx) {
          cells.add(_blankCell());
          continue;
        }
        if (day > daysInMonth) {
          cells.add(_blankCell());
          continue;
        }
        final date = DateTime(plan.year, plan.month, day);
        final isFri = date.weekday == DateTime.friday;
        cells.add(_dayCell(date, isFri, slotsByDate[day] ?? const []));
        day++;
      }
      rows.add(pw.TableRow(children: cells));
      weekIdx++;
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE2E8F0),
        width: 0.5,
      ),
      defaultColumnWidth: const pw.FlexColumnWidth(),
      children: rows,
    );
  }

  static pw.TableRow _headerRow() {
    const labels = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: labels
          .map((l) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  l,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: l == 'Fri'
                        ? PdfColor.fromInt(0xFFCBD5E1)
                        : PdfColor.fromInt(0xFF334155),
                  ),
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _blankCell() {
    return pw.Container(
      height: 65,
      color: PdfColor.fromInt(0xFFF8FAFC),
    );
  }

  static pw.Widget _dayCell(
    DateTime date,
    bool isFri,
    List<PlannerSlot> slots,
  ) {
    return pw.Container(
      height: 65,
      color: isFri ? PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            DateFormat('d').format(date),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isFri
                  ? PdfColor.fromInt(0xFFCBD5E1)
                  : PdfColor.fromInt(0xFF334155),
            ),
          ),
          if (isFri)
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  'OFF',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFCBD5E1),
                  ),
                ),
              ),
            )
          else if (slots.isNotEmpty)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: slots
                    .take(4)
                    .map((s) => _slotChipPdf(s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _slotChipPdf(PlannerSlot s) {
    final typeColor = s.isPost
        ? PdfColor.fromInt(0xFF0EA5E9)
        : PdfColor.fromInt(0xFFF59E0B);
    final initials = _initials(s.assignedUserName);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 1),
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFFFFF),
        border: pw.Border.all(
          color: typeColor,
          width: 0.4,
        ),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 7,
            height: 7,
            color: typeColor,
            margin: const pw.EdgeInsets.only(right: 2),
            alignment: pw.Alignment.center,
            child: pw.Text(
              s.isPost ? 'P' : 'V',
              style: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              s.clientName ?? 'Client',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.SizedBox(width: 2),
          pw.Text(
            initials,
            style: pw.TextStyle(
              fontSize: 5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _legend(MonthlyPlan plan) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          _legendItem('P', 'Post', PdfColor.fromInt(0xFF0EA5E9)),
          pw.SizedBox(width: 16),
          _legendItem('V', 'Video', PdfColor.fromInt(0xFFF59E0B)),
          pw.SizedBox(width: 16),
          pw.Text(
            'Friday is the agency day off.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Spacer(),
          pw.Text(
            'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    );
  }

  static pw.Widget _legendItem(String letter, String label, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 12,
          height: 12,
          color: color,
          alignment: pw.Alignment.center,
          child: pw.Text(
            letter,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  // ---------- Helpers ----------

  static int _saturdayFirstIndex(int dartWd) {
    switch (dartWd) {
      case DateTime.saturday:
        return 0;
      case DateTime.sunday:
        return 1;
      case DateTime.monday:
        return 2;
      case DateTime.tuesday:
        return 3;
      case DateTime.wednesday:
        return 4;
      case DateTime.thursday:
        return 5;
      case DateTime.friday:
        return 6;
    }
    return 0;
  }

  static String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
