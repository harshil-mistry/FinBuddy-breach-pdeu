import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
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
    final pdf = pw.Document();

    // Sort expenses newest first
    final sorted = List<SharedExpenseModel>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate per-person totals paid
    final Map<String, double> totalPaid = {};
    final Map<String, double> balances = DebtSimplifier.calculateBalances(expenses);
    for (var ex in expenses) {
      if (ex.description == 'Debt Settlement') continue;
      totalPaid[ex.paidBy] = (totalPaid[ex.paidBy] ?? 0) + ex.amount;
    }

    // Calculate pending settlements
    final settlements = DebtSimplifier.calculateSettlements(expenses);

    String _name(String uid) => memberNames[uid] ?? uid;
    String _fmt(double v) => '₹${v.toStringAsFixed(2)}';

    // -------- colour palette --------
    const headerBg = PdfColor.fromInt(0xFF1565C0); // primaryBlue
    const headerFg = PdfColors.white;
    const rowAlt   = PdfColor.fromInt(0xFFEEF4FF);
    const borderC  = PdfColor.fromInt(0xFFBBD6FB);
    const green     = PdfColor.fromInt(0xFF2E7D32);
    const red       = PdfColor.fromInt(0xFFC62828);

    pw.TextStyle bold(double size, {PdfColor? color}) =>
        pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: color);
    pw.TextStyle reg(double size, {PdfColor? color}) =>
        pw.TextStyle(fontSize: size, color: color);

    // Helper: Table header cell
    pw.Widget thCell(String text) => pw.Container(
      color: headerBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: headerFg)),
    );

    // Helper: Table data cell
    pw.Widget tdCell(String text, {bool alt = false, PdfColor? color, bool rightAlign = false}) =>
        pw.Container(
          color: alt ? rowAlt : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Align(
            alignment: rightAlign ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(text, style: reg(8.5, color: color)),
          ),
        );

    // -------- PAGE --------
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FinBuddy — Pool Report', style: bold(18, color: headerBg)),
                    pw.SizedBox(height: 2),
                    pw.Text(pool.name, style: bold(13, color: const PdfColor.fromInt(0xFF0D47A1))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: reg(8)),
                    pw.Text('Total Expenses: ${_fmt(pool.totalExpenses)}', style: bold(10, color: headerBg)),
                    pw.Text('Members: ${pool.members.length}', style: reg(8)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: headerBg, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: reg(8, color: PdfColors.grey600)),
        ),
        build: (ctx) => [

          // ===== SECTION 1: Expense History =====
          pw.Text('Expense History', style: bold(14)),
          pw.SizedBox(height: 8),

          if (sorted.isEmpty)
            pw.Text('No expenses recorded.', style: reg(10))
          else
            pw.Table(
              border: pw.TableBorder.all(color: borderC, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5), // Description
                1: const pw.FlexColumnWidth(1.5), // Date
                2: const pw.FlexColumnWidth(1.5), // Paid By
                3: const pw.FlexColumnWidth(1.2), // Amount
                4: const pw.FlexColumnWidth(3.5), // Beneficiaries
              },
              children: [
                // Header row
                pw.TableRow(children: [
                  thCell('Description'),
                  thCell('Date'),
                  thCell('Paid By'),
                  thCell('Amount'),
                  thCell('Beneficiaries (Share)'),
                ]),
                ...sorted.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final ex  = entry.value;
                  final alt = i.isOdd;

                  // Build beneficiaries string
                  final beneficiaries = ex.splits.entries.map((s) {
                    return '${_name(s.key)}: ${_fmt(s.value)}';
                  }).join('\n');

                  final isSettlement = ex.description == 'Debt Settlement';

                  return pw.TableRow(children: [
                    tdCell(ex.description, alt: alt,
                        color: isSettlement ? green : null),
                    tdCell(DateFormat('dd MMM yy').format(ex.date), alt: alt),
                    tdCell(_name(ex.paidBy), alt: alt),
                    tdCell(_fmt(ex.amount), alt: alt, rightAlign: true),
                    tdCell(beneficiaries.isEmpty ? '—' : beneficiaries, alt: alt),
                  ]);
                }),
              ],
            ),

          pw.SizedBox(height: 24),

          // ===== SECTION 2: Per-Person Summary =====
          pw.Text('Per-Person Summary', style: bold(14)),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: borderC, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),   // Member
              1: const pw.FlexColumnWidth(2),   // Total Paid
              2: const pw.FlexColumnWidth(2),   // Net Balance
              3: const pw.FlexColumnWidth(3),   // Status
            },
            children: [
              pw.TableRow(children: [
                thCell('Member'),
                thCell('Total Paid'),
                thCell('Net Balance'),
                thCell('Status'),
              ]),
              ...pool.members.asMap().entries.map((entry) {
                final i   = entry.key;
                final uid = entry.value;
                final alt = i.isOdd;
                final paid    = totalPaid[uid] ?? 0.0;
                final balance = balances[uid] ?? 0.0;
                final isPos   = balance > 0.01;
                final isNeg   = balance < -0.01;

                return pw.TableRow(children: [
                  tdCell(_name(uid), alt: alt),
                  tdCell(_fmt(paid),    alt: alt, rightAlign: true),
                  tdCell('${isPos ? '+' : ''}${_fmt(balance)}',
                      alt: alt, rightAlign: true,
                      color: isPos ? green : (isNeg ? red : null)),
                  tdCell(
                    isPos ? 'To Receive ${_fmt(balance)}' :
                    isNeg ? 'To Pay ${_fmt(balance.abs())}' : 'Settled',
                    alt: alt,
                    color: isPos ? green : (isNeg ? red : PdfColors.grey700),
                  ),
                ]);
              }),
            ],
          ),

          pw.SizedBox(height: 24),

          // ===== SECTION 3: Pending Settlements =====
          if (settlements.isNotEmpty) ...[
            pw.Text('Pending Settlements', style: bold(14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'The following minimum transactions are needed to fully settle all debts:',
              style: reg(9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: borderC, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  thCell('Who Pays'),
                  thCell('Who Receives'),
                  thCell('Amount'),
                ]),
                ...settlements.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final alt = i.isOdd;
                  return pw.TableRow(children: [
                    tdCell(_name(s.from), alt: alt, color: red),
                    tdCell(_name(s.to),   alt: alt, color: green),
                    tdCell(_fmt(s.amount), alt: alt, rightAlign: true),
                  ]);
                }),
              ],
            ),
          ] else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE8F5E9),
                border: pw.Border.all(color: green, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(children: [
                pw.Text('✓  All members are fully settled up!', style: bold(11, color: green)),
              ]),
            ),
          ],

          pw.SizedBox(height: 24),

          // ===== Footer note =====
          pw.Divider(color: borderC),
          pw.Text(
            'This report was auto-generated by FinBuddy. All amounts are in Indian Rupees (₹).',
            style: reg(8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    // Share / print the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${pool.name.replaceAll(' ', '_')}_report.pdf',
    );
  }
}
