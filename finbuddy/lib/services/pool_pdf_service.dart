import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/pool_model.dart';
import '../models/shared_expense_model.dart';
import '../utils/debt_simplifier.dart';

class PoolPdfService {
  /// Generates and shares/prints the pool report PDF.
  static Future<void> exportPoolPdf({
    required BuildContext context,
    required PoolModel pool,
    required List<SharedExpenseModel> expenses,
    required Map<String, String> memberNames,
  }) async {
    // ── Load Noto Sans fonts (full Unicode, supports Rs symbol) ──
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();

    // Sort expenses newest first
    final sorted = List<SharedExpenseModel>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate per-person totals
    final Map<String, double> totalPaid     = {};   // How much each person paid
    final Map<String, double> totalConsumed = {};   // How much each person consumed (from splits)
    for (var ex in expenses) {
      if (ex.description == 'Debt Settlement') continue;
      totalPaid[ex.paidBy] = (totalPaid[ex.paidBy] ?? 0) + ex.amount;
      for (final s in ex.splits.entries) {
        totalConsumed[s.key] = (totalConsumed[s.key] ?? 0) + s.value;
      }
    }

    final Map<String, double> balances  = DebtSimplifier.calculateBalances(expenses);
    final settlements                   = DebtSimplifier.calculateSettlements(expenses);

    // Helper: Use "Rs." instead of "₹" to be safe across all PDF viewers,
    // OR keep ₹ since Noto Sans fully supports it.
    String _name(String uid) => memberNames[uid] ?? uid;
    String _fmt(double v)    => 'Rs.${v.toStringAsFixed(2)}';

    // ─── Colour palette ───────────────────────────────────────────────────────
    const headerBg = PdfColor.fromInt(0xFF1565C0);
    const headerFg = PdfColors.white;
    const rowAlt   = PdfColor.fromInt(0xFFEEF4FF);
    const borderC  = PdfColor.fromInt(0xFFBBD6FB);
    const green    = PdfColor.fromInt(0xFF2E7D32);
    const red      = PdfColor.fromInt(0xFFC62828);
    const amber    = PdfColor.fromInt(0xFFE65100);

    // ─── Style helpers ────────────────────────────────────────────────────────
    pw.TextStyle bold(double size, {PdfColor? color}) => pw.TextStyle(
        font: fontBold, fontSize: size, color: color);
    pw.TextStyle reg(double size, {PdfColor? color}) => pw.TextStyle(
        font: fontRegular, fontSize: size, color: color);

    // Table header cell
    pw.Widget thCell(String text) => pw.Container(
      color: headerBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 8, color: headerFg)),
    );

    // Table data cell
    pw.Widget tdCell(String text, {
      bool alt = false,
      PdfColor? color,
      bool rightAlign = false,
    }) =>
        pw.Container(
          color: alt ? rowAlt : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Align(
            alignment: rightAlign ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(text, style: reg(8, color: color)),
          ),
        );

    // ─── Build PDF ────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // ── Header ────────────────────────────────────────────────────────────
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FinBuddy — Pool Report', style: bold(17, color: headerBg)),
                    pw.SizedBox(height: 2),
                    pw.Text(pool.name,
                        style: bold(12, color: const PdfColor.fromInt(0xFF0D47A1))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: reg(7.5, color: PdfColors.grey700)),
                    pw.Text('Total Pool Expenses: ${_fmt(pool.totalExpenses)}',
                        style: bold(10, color: headerBg)),
                    pw.Text('Members: ${pool.members.length}',
                        style: reg(8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: headerBg, thickness: 1.5),
            pw.SizedBox(height: 6),
          ],
        ),
        // ── Footer ────────────────────────────────────────────────────────────
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: reg(7.5, color: PdfColors.grey500),
          ),
        ),
        // ── Body ──────────────────────────────────────────────────────────────
        build: (ctx) => [

          // ══════════════════════════════════════════════════════╗
          //  SECTION 1 – Expense History                          ║
          // ══════════════════════════════════════════════════════╝
          pw.Text('1. Expense History', style: bold(13)),
          pw.SizedBox(height: 6),

          if (sorted.isEmpty)
            pw.Text('No expenses recorded yet.', style: reg(10, color: PdfColors.grey600))
          else
            pw.Table(
              border: pw.TableBorder.all(color: borderC, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.8), // Description
                1: const pw.FlexColumnWidth(1.4), // Date
                2: const pw.FlexColumnWidth(1.8), // Paid By
                3: const pw.FlexColumnWidth(1.3), // Amount
                4: const pw.FlexColumnWidth(4.0), // Beneficiaries
              },
              children: [
                pw.TableRow(children: [
                  thCell('Description'),
                  thCell('Date'),
                  thCell('Paid By'),
                  thCell('Amount'),
                  thCell('Beneficiaries (Individual Share)'),
                ]),
                ...sorted.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final ex  = entry.value;
                  final alt = i.isOdd;
                  final isSettlement = ex.description == 'Debt Settlement';

                  final beneficiaries = ex.splits.entries
                      .map((s) => '${_name(s.key)}: ${_fmt(s.value)}')
                      .join('\n');

                  return pw.TableRow(children: [
                    tdCell(ex.description, alt: alt, color: isSettlement ? green : null),
                    tdCell(DateFormat('dd MMM yy').format(ex.date), alt: alt),
                    tdCell(_name(ex.paidBy), alt: alt),
                    tdCell(_fmt(ex.amount), alt: alt, rightAlign: true,
                        color: isSettlement ? green : amber),
                    tdCell(beneficiaries.isEmpty ? '—' : beneficiaries, alt: alt),
                  ]);
                }),
              ],
            ),

          pw.SizedBox(height: 22),

          // ══════════════════════════════════════════════════════╗
          //  SECTION 2 – Per-Person Summary                       ║
          // ══════════════════════════════════════════════════════╝
          pw.Text('2. Per-Person Summary', style: bold(13)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Total Paid = money the person actually paid upfront. '
            'Total Consumed = their actual share of all expenses. '
            'Net Balance = Paid - Consumed (positive means they are owed money back).',
            style: reg(8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),

          pw.Table(
            border: pw.TableBorder.all(color: borderC, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5), // Member
              1: const pw.FlexColumnWidth(2.0), // Total Paid
              2: const pw.FlexColumnWidth(2.0), // Total Consumed
              3: const pw.FlexColumnWidth(2.0), // Net Balance
              4: const pw.FlexColumnWidth(3.0), // Status
            },
            children: [
              pw.TableRow(children: [
                thCell('Member'),
                thCell('Total Paid'),
                thCell('Total Consumed'),
                thCell('Net Balance'),
                thCell('Status'),
              ]),
              ...pool.members.asMap().entries.map((entry) {
                final i        = entry.key;
                final uid      = entry.value;
                final alt      = i.isOdd;
                final paid     = totalPaid[uid]     ?? 0.0;
                final consumed = totalConsumed[uid] ?? 0.0;
                final balance  = balances[uid]      ?? 0.0;
                final isPos    = balance >  0.01;
                final isNeg    = balance < -0.01;

                return pw.TableRow(children: [
                  tdCell(_name(uid), alt: alt),
                  tdCell(_fmt(paid),     alt: alt, rightAlign: true, color: amber),
                  tdCell(_fmt(consumed), alt: alt, rightAlign: true, color: const PdfColor.fromInt(0xFF1565C0)),
                  tdCell(
                    '${isPos ? '+' : ''}${_fmt(balance)}',
                    alt: alt, rightAlign: true,
                    color: isPos ? green : (isNeg ? red : PdfColors.grey700),
                  ),
                  tdCell(
                    isPos ? 'To receive ${_fmt(balance)}' :
                    isNeg ? 'To pay ${_fmt(balance.abs())}' : 'Settled',
                    alt: alt,
                    color: isPos ? green : (isNeg ? red : PdfColors.grey600),
                  ),
                ]);
              }),
            ],
          ),

          pw.SizedBox(height: 22),

          // ══════════════════════════════════════════════════════╗
          //  SECTION 3 – Pending Settlements (if any)             ║
          // ══════════════════════════════════════════════════════╝
          pw.Text('3. Pending Settlements', style: bold(13)),
          pw.SizedBox(height: 6),

          if (settlements.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE8F5E9),
                border: pw.Border.all(color: green, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'All members are fully settled up!',
                style: bold(11, color: green),
              ),
            )
          else ...[
            pw.Text(
              'Minimum transactions required to clear all debts:',
              style: reg(8.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderC, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  thCell('Payer'),
                  thCell('Receiver'),
                  thCell('Amount'),
                ]),
                ...settlements.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final s   = entry.value;
                  final alt = i.isOdd;
                  return pw.TableRow(children: [
                    tdCell(_name(s.from), alt: alt, color: red),
                    tdCell(_name(s.to),   alt: alt, color: green),
                    tdCell(_fmt(s.amount), alt: alt, rightAlign: true),
                  ]);
                }),
              ],
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(color: borderC),
          pw.Text(
            'This report was auto-generated by FinBuddy. All amounts are in Indian Rupees (Rs.).',
            style: reg(7.5, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${pool.name.replaceAll(' ', '_')}_report.pdf',
    );
  }
}
