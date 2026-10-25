import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_date_format.dart';
import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import '../transactions/transaction_voucher_details.dart';
import '../../widgets/stitch_loader.dart';
import 'reports_repository.dart';

const _reportShareChannel = MethodChannel(
  'com.creativeease.ce_tailor_rentals/report_share',
);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    required this.session,
    required this.repository,
    this.showAppBar = true,
    this.onOpenMenu,
    this.onOpenAssistant,
    super.key,
  });

  final AuthSession session;
  final ReportsRepository repository;
  final bool showAppBar;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenAssistant;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: showAppBar
        ? AppBar(
            leading: onOpenMenu == null
                ? null
                : IconButton(
                    tooltip: localizedUiText(
                      context,
                      'Masters and administration',
                    ),
                    onPressed: onOpenMenu,
                    icon: const Icon(Icons.menu),
                  ),
            title: Text(localizedUiText(context, 'Reports')),
            actions: [
              if (onOpenAssistant != null)
                IconButton(
                  tooltip: localizedUiText(context, 'Ask assistant'),
                  onPressed: onOpenAssistant,
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
            ],
          )
        : null,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9F5FF), Color(0xFFDDEEFF)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD3E8FB)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF1688E8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedUiText(context, 'Business reports'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF142C4B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedUiText(
                        context,
                        'Rental activity, tailoring orders, balances and cash flow.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF657B94)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final report in _reports)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAF5FF),
                child: Icon(report.icon, color: const Color(0xFF1688E8)),
              ),
              title: Text(
                localizedUiText(context, report.title),
                style: const TextStyle(
                  color: Color(0xFF203956),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(localizedUiText(context, report.description)),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF1688E8),
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _ReportDetailScreen(
                    session: session,
                    repository: repository,
                    report: report,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ReportDefinition {
  const _ReportDefinition({
    required this.title,
    required this.description,
    required this.endpoint,
    required this.icon,
    required this.columns,
    this.customerFilter = false,
    this.itemFilter = false,
    this.mobileFilter = false,
    this.statusFilter = false,
    this.requiredCustomer = false,
  });

  final String title;
  final String description;
  final String endpoint;
  final IconData icon;
  final List<_ReportColumn> columns;
  final bool customerFilter;
  final bool itemFilter;
  final bool mobileFilter;
  final bool statusFilter;
  final bool requiredCustomer;

  bool get usesDates => true;
}

class _ReportColumn {
  const _ReportColumn(
    this.key,
    this.label, {
    this.numeric = false,
    this.sum = false,
  });

  final String key;
  final String label;
  final bool numeric;
  final bool sum;
}

const _reports = <_ReportDefinition>[
  _ReportDefinition(
    title: 'Active Rentals',
    description: 'Current rental items, payments and due dates.',
    endpoint: 'GetActiveRentals',
    icon: Icons.checkroom_outlined,
    customerFilter: true,
    itemFilter: true,
    mobileFilter: true,
    columns: [
      _ReportColumn('rentNo', 'Rent No'),
      _ReportColumn('rentDate', 'Rent Date'),
      _ReportColumn('customerName', 'Customer'),
      _ReportColumn('customerPhone', 'Mobile'),
      _ReportColumn('itemName', 'Item'),
      _ReportColumn('variantSize', 'Size'),
      _ReportColumn('variantColor', 'Color'),
      _ReportColumn('rentalRate', 'Rate', numeric: true),
      _ReportColumn('rentalVariantAmount', 'Amount', numeric: true, sum: true),
      _ReportColumn('advanceReceived', 'Advance', numeric: true, sum: true),
      _ReportColumn('securityDeposit', 'Security', numeric: true, sum: true),
      _ReportColumn('pendingAmount', 'Pending', numeric: true, sum: true),
      _ReportColumn('rentalReturnDueDate', 'Return Due'),
      _ReportColumn('lateDays', 'Late Days', numeric: true),
    ],
  ),
  _ReportDefinition(
    title: 'Bookings In Hand',
    description: 'Upcoming rental bookings and outstanding amounts.',
    endpoint: 'GetBookingsInHand',
    icon: Icons.event_available_outlined,
    customerFilter: true,
    itemFilter: true,
    mobileFilter: true,
    columns: [
      _ReportColumn('bookingNo', 'Booking No'),
      _ReportColumn('bookingDate', 'Booking Date'),
      _ReportColumn('eventDate', 'Event Date'),
      _ReportColumn('rentalFromDate', 'Rental From'),
      _ReportColumn('rentalToDate', 'Rental To'),
      _ReportColumn('status', 'Status'),
      _ReportColumn('customerName', 'Customer'),
      _ReportColumn('customerPhone', 'Mobile'),
      _ReportColumn('itemName', 'Item'),
      _ReportColumn('variantSize', 'Size'),
      _ReportColumn('variantColor', 'Color'),
      _ReportColumn('qty', 'Qty', numeric: true, sum: true),
      _ReportColumn('rentalRate', 'Rate', numeric: true),
      _ReportColumn('itemAmount', 'Item Amount', numeric: true, sum: true),
      _ReportColumn(
        'totalBookingAmount',
        'Total Amount',
        numeric: true,
        sum: true,
      ),
      _ReportColumn(
        'totalReceivedAmount',
        'Received',
        numeric: true,
        sum: true,
      ),
      _ReportColumn('pendingAmount', 'Pending', numeric: true, sum: true),
      _ReportColumn(
        'cancellationCharges',
        'Cancel Charges',
        numeric: true,
        sum: true,
      ),
      _ReportColumn('daysUntilRentalStart', 'Days To Start', numeric: true),
    ],
  ),
  _ReportDefinition(
    title: 'Tailoring Orders',
    description: 'Order, stitching, tailor assignment and payment status.',
    endpoint: 'GetTailoringOrders',
    icon: Icons.content_cut_outlined,
    customerFilter: true,
    itemFilter: true,
    mobileFilter: true,
    statusFilter: true,
    columns: [
      _ReportColumn('orderNo', 'Order No'),
      _ReportColumn('orderDate', 'Order Date'),
      _ReportColumn('orderStatus', 'Status'),
      _ReportColumn('trialDate', 'Trial Date'),
      _ReportColumn('deliveryDate', 'Delivery Date'),
      _ReportColumn('customerName', 'Customer'),
      _ReportColumn('customerPhone', 'Mobile'),
      _ReportColumn('itemName', 'Item'),
      _ReportColumn('sizeName', 'Size'),
      _ReportColumn('colorName', 'Color'),
      _ReportColumn('processName', 'Process'),
      _ReportColumn('qty', 'Qty', numeric: true, sum: true),
      _ReportColumn('rate', 'Rate', numeric: true),
      _ReportColumn('netAmount', 'Net Amount', numeric: true, sum: true),
      _ReportColumn('tailorName', 'Tailor'),
      _ReportColumn('tailorIssueDate', 'Issue Date'),
      _ReportColumn('tailorExpectedDate', 'Expected Date'),
      _ReportColumn('tailorReceivedDate', 'Received Date'),
      _ReportColumn('jobStatus', 'Job Status'),
      _ReportColumn('totalAmount', 'Total Amount', numeric: true, sum: true),
      _ReportColumn('advancePaid', 'Advance', numeric: true, sum: true),
      _ReportColumn(
        'totalReceivedAmount',
        'Received',
        numeric: true,
        sum: true,
      ),
      _ReportColumn('pendingAmount', 'Pending', numeric: true, sum: true),
    ],
  ),
  _ReportDefinition(
    title: 'Alteration Issue Pending',
    description: 'Rental bookings with alteration work awaiting assignment.',
    endpoint: 'GetRentBookingsPendingTailorAssignment',
    icon: Icons.pending_actions_outlined,
    customerFilter: true,
    columns: [
      _ReportColumn('bookingNo', 'Booking No'),
      _ReportColumn('bookingDate', 'Booking Date'),
      _ReportColumn('eventDate', 'Event Date'),
      _ReportColumn('fromDate', 'From Date'),
      _ReportColumn('toDate', 'To Date'),
      _ReportColumn('customerName', 'Customer'),
      _ReportColumn('customerMobile', 'Mobile'),
      _ReportColumn('itemName', 'Item'),
      _ReportColumn('sizeName', 'Size'),
      _ReportColumn('colorName', 'Color'),
      _ReportColumn('qty', 'Qty', numeric: true),
      _ReportColumn('rate', 'Rate', numeric: true),
      _ReportColumn('amount', 'Amount', numeric: true, sum: true),
      _ReportColumn('bookingStatus', 'Status'),
      _ReportColumn('itemAlterationStatus', 'Alteration Status'),
      _ReportColumn('remarks', 'Remarks'),
    ],
  ),
  _ReportDefinition(
    title: 'Returned Rentals',
    description: 'Returned items, condition, damage charges and balances.',
    endpoint: 'GetReturnedRentals',
    icon: Icons.assignment_return_outlined,
    customerFilter: true,
    itemFilter: true,
    mobileFilter: true,
    columns: [
      _ReportColumn('returnNo', 'Return No'),
      _ReportColumn('returnDate', 'Return Date'),
      _ReportColumn('rentNo', 'Rent No'),
      _ReportColumn('rentDate', 'Rent Date'),
      _ReportColumn('customerName', 'Customer'),
      _ReportColumn('customerPhone', 'Mobile'),
      _ReportColumn('itemName', 'Item'),
      _ReportColumn('variantSize', 'Size'),
      _ReportColumn('variantColor', 'Color'),
      _ReportColumn('returnQty', 'Qty', numeric: true),
      _ReportColumn('conditionStatus', 'Condition'),
      _ReportColumn('damageAmount', 'Damage', numeric: true, sum: true),
      _ReportColumn('rentalRate', 'Rate', numeric: true),
      _ReportColumn('rentalVariantAmount', 'Amount', numeric: true, sum: true),
      _ReportColumn('advanceReceived', 'Advance', numeric: true, sum: true),
      _ReportColumn('securityDeposit', 'Security', numeric: true, sum: true),
      _ReportColumn('pendingAmount', 'Pending', numeric: true, sum: true),
      _ReportColumn('rentalReturnDueDate', 'Return Due'),
      _ReportColumn('lateDays', 'Late Days', numeric: true),
    ],
  ),
  _ReportDefinition(
    title: 'Customer Ledger',
    description: 'Customer debit, credit and running balance.',
    endpoint: 'GetCustomerLedger',
    icon: Icons.account_balance_wallet_outlined,
    customerFilter: true,
    requiredCustomer: true,
    columns: [
      _ReportColumn('entryDate', 'Date'),
      _ReportColumn('voucherType', 'Voucher Type'),
      _ReportColumn('voucherNumber', 'Voucher No'),
      _ReportColumn('narration', 'Narration'),
      _ReportColumn('debitAmount', 'Debit', numeric: true, sum: true),
      _ReportColumn('creditAmount', 'Credit', numeric: true, sum: true),
      _ReportColumn('runningBalanceText', 'Balance'),
    ],
  ),
  _ReportDefinition(
    title: 'Cash Flow Summary',
    description: 'Daily receipts, payments and net cash flow.',
    endpoint: 'GetCashFlowSummary',
    icon: Icons.trending_up_outlined,
    columns: [
      _ReportColumn('entryDate', 'Date'),
      _ReportColumn('dailyReceipts', 'Receipts', numeric: true, sum: true),
      _ReportColumn('dailyPayments', 'Payments', numeric: true, sum: true),
      _ReportColumn('netFlow', 'Net Flow', numeric: true, sum: true),
    ],
  ),
];

class _ReportDetailScreen extends StatefulWidget {
  const _ReportDetailScreen({
    required this.session,
    required this.repository,
    required this.report,
  });

  final AuthSession session;
  final ReportsRepository repository;
  final _ReportDefinition report;

  @override
  State<_ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<_ReportDetailScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _customerId;
  int? _itemId;
  final _mobile = TextEditingController();
  final _status = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _items = [];
  ReportResult? _result;
  Object? _error;
  Object? _masterError;
  bool _loading = false;
  bool _loadingMasters = false;
  bool _exporting = false;
  bool _hasRun = false;

  @override
  void initState() {
    super.initState();
    _loadMasters();
    if (!widget.report.requiredCustomer) _loadReport();
  }

  @override
  void dispose() {
    _mobile.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    if (!widget.report.customerFilter && !widget.report.itemFilter) return;
    setState(() {
      _loadingMasters = true;
      _masterError = null;
    });
    try {
      final results = await Future.wait([
        if (widget.report.customerFilter)
          widget.repository.loadCustomers(widget.session),
        if (widget.report.itemFilter)
          widget.repository.loadItems(widget.session),
      ]);
      var index = 0;
      if (widget.report.customerFilter) _customers = results[index++];
      if (widget.report.itemFilter) _items = results[index];
    } catch (error) {
      _masterError = error;
    } finally {
      if (mounted) setState(() => _loadingMasters = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range == null || !mounted) return;
    setState(() {
      _fromDate = range.start;
      _toDate = range.end;
    });
  }

  String _date(DateTime value) => formatDisplayDate(value);

  String _apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Map<String, Object?> _filters() {
    final filters = <String, Object?>{};
    if (_fromDate != null) filters['fromDate'] = _apiDate(_fromDate!);
    if (_toDate != null) filters['toDate'] = _apiDate(_toDate!);
    if (_customerId != null) {
      filters[widget.report.endpoint == 'GetRentBookingsPendingTailorAssignment'
              ? 'customerID'
              : widget.report.endpoint == 'GetCustomerLedger'
              ? 'customerID'
              : 'customerId'] =
          _customerId;
    }
    if (_itemId != null) filters['itemId'] = _itemId;
    if (_mobile.text.trim().isNotEmpty) {
      filters['customerMobileNo'] = _mobile.text.trim();
    }
    if (_status.text.trim().isNotEmpty) filters['status'] = _status.text.trim();
    return filters;
  }

  Future<void> _loadReport() async {
    if (widget.report.requiredCustomer && _customerId == null) {
      setState(() {
        _error = 'Select a customer to view their ledger.';
        _hasRun = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _hasRun = true;
    });
    try {
      final result = await widget.repository.load(
        widget.session,
        report: widget.report.endpoint,
        filters: _filters(),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _customerId = null;
      _itemId = null;
      _mobile.clear();
      _status.clear();
      _result = null;
      _error = null;
      _hasRun = false;
    });
    if (!widget.report.requiredCustomer) _loadReport();
  }

  Future<void> _exportReport({required bool share}) async {
    final result = _result;
    if (result == null || result.rows.isEmpty || _exporting) return;
    setState(() => _exporting = true);

    try {
      final document = pw.Document();
      final localizedReportTitle = localizedUiText(
        context,
        widget.report.title,
      );
      final data = [
        [
          for (final column in widget.report.columns)
            localizedUiText(context, column.label),
        ],
        for (final row in result.rows)
          [
            for (final column in widget.report.columns)
              _pdfDisplay(column.key, row[column.key]),
          ],
        if (widget.report.columns.any((column) => column.sum))
          [
            for (final column in widget.report.columns)
              column.sum
                  ? _money(_sum(result.rows, column.key))
                  : column == widget.report.columns.first
                  ? localizedUiText(context, 'Total')
                  : '',
          ],
      ];
      final filterSummary = _exportFilterSummary();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              widget.session.companyName,
              style: pw.TextStyle(
                color: PdfColors.blueGrey700,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                color: PdfColors.blueGrey600,
                fontSize: 8,
              ),
            ),
          ),
          build: (context) => [
            pw.Text(
              localizedReportTitle,
              style: pw.TextStyle(
                color: PdfColors.blueGrey900,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '${result.rows.length} records - Generated ${_date(DateTime.now())}',
              style: const pw.TextStyle(
                color: PdfColors.blueGrey600,
                fontSize: 9,
              ),
            ),
            if (filterSummary.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                filterSummary,
                style: const pw.TextStyle(
                  color: PdfColors.blueGrey700,
                  fontSize: 9,
                ),
              ),
            ],
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              data: data,
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF244D87),
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFD7E0EA),
                width: .4,
              ),
            ),
          ],
        ),
      );
      final bytes = await document.save();
      final filename =
          '${widget.report.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.pdf';
      if (share) {
        final shareText =
            '${widget.report.title} - ${result.rows.length} records';
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _reportShareChannel.invokeMethod<void>('sharePdf', {
            'bytes': bytes,
            'filename': filename,
            'title': widget.report.title,
            'text': shareText,
          });
        } else {
          final shared = await Printing.sharePdf(
            bytes: bytes,
            filename: filename,
            subject: widget.report.title,
            body: shareText,
          );
          if (!shared && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizedUiText(
                    context,
                    'No compatible app is available to share this PDF.',
                  ),
                ),
              ),
            );
          }
        }
      } else {
        final info = await Printing.info();
        if (!info.canPrint) {
          throw StateError(
            'Printing is unavailable on this device. Use Share PDF to send the report to a printer app.',
          );
        }
        final printed = await Printing.layoutPdf(
          name: widget.report.title,
          format: PdfPageFormat.a3.landscape,
          dynamicLayout: false,
          onLayout: (_) async => bytes,
        );
        if (!printed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizedUiText(context, 'Printing was canceled.')),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not ${share ? 'share' : 'print'} report: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _exportFilterSummary() {
    final applied = <String>[];
    if (_fromDate != null) applied.add('From: ${_date(_fromDate!)}');
    if (_toDate != null) applied.add('To: ${_date(_toDate!)}');
    if (_customerId != null) {
      final customer = _customers.where(
        (item) => _integer(item['customerID']) == _customerId,
      );
      if (customer.isNotEmpty) {
        applied.add(
          'Customer: ${customer.first['fullName'] ?? customer.first['customerName'] ?? 'Customer'}',
        );
      }
    }
    if (_itemId != null) {
      final item = _items.where(
        (value) => _integer(value['itemId']) == _itemId,
      );
      if (item.isNotEmpty) {
        applied.add('Item: ${item.first['itemName'] ?? 'Item'}');
      }
    }
    if (_mobile.text.trim().isNotEmpty) {
      applied.add('Mobile: ${_mobile.text.trim()}');
    }
    if (_status.text.trim().isNotEmpty) {
      applied.add('Status: ${_status.text.trim()}');
    }
    return applied.join('  |  ');
  }

  int get _activeFilterCount =>
      (_fromDate != null || _toDate != null ? 1 : 0) +
      (_customerId != null ? 1 : 0) +
      (_itemId != null ? 1 : 0) +
      (_mobile.text.trim().isNotEmpty ? 1 : 0) +
      (_status.text.trim().isNotEmpty ? 1 : 0);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(localizedUiText(context, widget.report.title))),
    bottomNavigationBar: _result != null && _result!.rows.isNotEmpty
        ? SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE1E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A172B4D),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportReport(share: false),
                      icon: const Icon(Icons.print_outlined),
                      label: Text(localizedUiText(context, 'Print')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFF244D87),
                        side: const BorderSide(color: Color(0xFFD5E0ED)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportReport(share: true),
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share_outlined),
                      label: Text(localizedUiText(context, 'Share PDF')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF2864C5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null,
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              if (_masterError != null)
                _ErrorCard(
                  message: localizedUiText(
                    context,
                    'Could not load report filters: $_masterError',
                  ),
                  onRetry: _loadMasters,
                ),
              if (_error != null)
                _ErrorCard(
                  message: localizedUiText(context, _error.toString()),
                  onRetry: _loadReport,
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: StitchLoader(size: 64, showMonogram: false),
                  ),
                )
              else if (_result != null)
                _buildResult(context, _result!)
              else if (!_hasRun && !_loadingMasters)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      localizedUiText(context, 'Choose filters and tap Show.'),
                    ),
                  ),
                ),
              if (_loadingMasters)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildFilters(BuildContext context) {
    final fields = <Widget>[
      if (widget.report.usesDates) _dateRangeField(),
      if (widget.report.customerFilter)
        DropdownButtonFormField<int>(
          initialValue: _customerId,
          isExpanded: true,
          decoration: _filterDecoration(
            localizedUiText(
              context,
              widget.report.requiredCustomer ? 'Customer *' : 'Customer',
            ),
          ),
          items: [
            if (!widget.report.requiredCustomer)
              DropdownMenuItem<int>(
                child: Text(localizedUiText(context, 'All customers')),
              ),
            for (final customer in _customers)
              DropdownMenuItem(
                value: _integer(customer['customerID']),
                child: Text(
                  '${customer['fullName'] ?? customer['customerName'] ?? 'Customer'}'
                  '${customer['mobileNo'] == null ? '' : ' (${customer['mobileNo']})'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _customerId = value),
        ),
      if (widget.report.mobileFilter)
        TextField(
          selectAllOnFocus: true,
          controller: _mobile,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration:
              _filterDecoration(localizedUiText(context, 'Mobile number'))
                  .copyWith(
                    counterText: '',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
        ),
      if (widget.report.itemFilter)
        DropdownButtonFormField<int>(
          initialValue: _itemId,
          isExpanded: true,
          decoration: _filterDecoration(localizedUiText(context, 'Item')),
          items: [
            DropdownMenuItem<int>(
              child: Text(localizedUiText(context, 'All items')),
            ),
            for (final item in _items)
              DropdownMenuItem(
                value: _integer(item['itemId']),
                child: Text(
                  item['itemName']?.toString() ?? 'Item',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _itemId = value),
        ),
      if (widget.report.statusFilter)
        TextField(
          selectAllOnFocus: true,
          controller: _status,
          onChanged: (_) => setState(() {}),
          decoration: _filterDecoration(localizedUiText(context, 'Status')),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080E2A50),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Color(0xFF2864C5),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedUiText(context, 'Report filters'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF172B4D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizedUiText(
                        context,
                        'Choose criteria to refine ${widget.report.title.toLowerCase()}.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF718198)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  localizedUiText(context, '$_activeFilterCount active'),
                  style: const TextStyle(
                    color: Color(0xFF2864C5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final field in fields)
                      SizedBox(width: width, child: field),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _clear,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: Text(localizedUiText(context, 'Reset')),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _loadReport,
                icon: const Icon(Icons.filter_alt_rounded, size: 17),
                label: Text(localizedUiText(context, 'Apply filters')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2864C5), width: 1.4),
    ),
  );

  Widget _dateRangeField() {
    final label = _fromDate == null && _toDate == null
        ? 'Any date'
        : '${_fromDate == null ? '—' : _date(_fromDate!)}  –  ${_toDate == null ? '—' : _date(_toDate!)}';
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E7EF)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.date_range_outlined,
                size: 19,
                color: Color(0xFF2864C5),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedUiText(context, 'Date range'),
                      style: const TextStyle(
                        color: Color(0xFF718198),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF34435A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_fromDate != null || _toDate != null)
                IconButton(
                  tooltip: localizedUiText(context, 'Clear date range'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _fromDate = null;
                    _toDate = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              else
                const Icon(Icons.expand_more_rounded, color: Color(0xFF718198)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, ReportResult result) {
    final summary = result.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null) _summaryCard(summary),
        for (final account in result.accounts) _cashAccountCard(account),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE1E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080E2A50),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_chart_outlined,
                      color: Color(0xFF2864C5),
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedUiText(context, 'Report data'),
                            style: const TextStyle(
                              color: Color(0xFF172B4D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${result.rows.length} ${result.rows.length == 1 ? 'record' : 'records'}',
                            style: const TextStyle(
                              color: Color(0xFF718198),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${result.rows.length} rows',
                      style: const TextStyle(
                        color: Color(0xFF2864C5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7ECF2)),
              if (result.rows.isEmpty)
                Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 32,
                        color: Color(0xFF9AA9BB),
                      ),
                      SizedBox(height: 8),
                      Text(
                        localizedUiText(context, 'No report rows found'),
                        style: const TextStyle(
                          color: Color(0xFF52657D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        localizedUiText(
                          context,
                          'Try changing the filters and run the report again.',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF718198),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dataTableTheme: const DataTableThemeData(
                          headingRowColor: WidgetStatePropertyAll(
                            Color(0xFFF2F6FB),
                          ),
                          headingTextStyle: TextStyle(
                            color: Color(0xFF34435A),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          dataTextStyle: TextStyle(
                            color: Color(0xFF34435A),
                            fontSize: 12,
                          ),
                          dividerThickness: .7,
                          horizontalMargin: 16,
                          columnSpacing: 24,
                          headingRowHeight: 48,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 60,
                        ),
                      ),
                      child: DataTable(
                        columns: [
                          for (final column in widget.report.columns)
                            DataColumn(
                              label: Text(
                                localizedUiText(context, column.label),
                              ),
                              numeric: column.numeric,
                            ),
                          DataColumn(
                            label: Text(localizedUiText(context, 'Details')),
                          ),
                        ],
                        rows: [
                          for (
                            var index = 0;
                            index < result.rows.length;
                            index++
                          )
                            DataRow(
                              color: WidgetStatePropertyAll(
                                index.isEven
                                    ? Colors.white
                                    : const Color(0xFFFAFBFD),
                              ),
                              cells: [
                                for (final column in widget.report.columns)
                                  DataCell(
                                    Text(
                                      _display(
                                        result.rows[index][column.key],
                                        key: column.key,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                DataCell(
                                  IconButton(
                                    tooltip: localizedUiText(
                                      context,
                                      'View voucher details',
                                    ),
                                    onPressed: () =>
                                        showTransactionVoucherDetails(
                                          context,
                                          title: localizedUiText(
                                            context,
                                            '${widget.report.title} details',
                                          ),
                                          voucher: result.rows[index],
                                        ),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (widget.report.columns.any((column) => column.sum))
                            DataRow(
                              color: const WidgetStatePropertyAll(
                                Color(0xFFEAF1FB),
                              ),
                              cells: [
                                for (final column in widget.report.columns)
                                  DataCell(
                                    Text(
                                      column.sum
                                          ? _money(
                                              _sum(result.rows, column.key),
                                            )
                                          : column ==
                                                widget.report.columns.first
                                          ? localizedUiText(context, 'TOTAL')
                                          : '',
                                      style: const TextStyle(
                                        color: Color(0xFF172B4D),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                const DataCell(Text('')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(Map<String, dynamic> summary) {
    final opening = _number(summary['openingBalance']);
    final closing = _number(summary['closingBalance']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _summaryValue('Customer', summary['customerName']),
            _summaryValue('Mobile', summary['mobileNo']),
            _summaryValue(localizedUiText(context, 'Opening'), _drCr(opening)),
            _summaryValue(
              localizedUiText(context, 'Total debit'),
              _money(summary['totalDebit']),
            ),
            _summaryValue(
              localizedUiText(context, 'Total credit'),
              _money(summary['totalCredit']),
            ),
            _summaryValue(localizedUiText(context, 'Closing'), _drCr(closing)),
          ],
        ),
      ),
    );
  }

  Widget _cashAccountCard(Map<String, dynamic> account) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizedUiText(
              context,
              account['accountType']?.toString() ?? 'Account',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _summaryValue(
            localizedUiText(context, 'Receipts'),
            _money(account['totalReceipts']),
          ),
          _summaryValue(
            localizedUiText(context, 'Payments'),
            _money(account['totalPayments']),
          ),
          _summaryValue(
            localizedUiText(context, 'Net cash flow'),
            _money(account['netCashFlow']),
          ),
        ],
      ),
    ),
  );

  Widget _summaryValue(String label, Object? value) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizedUiText(context, label),
          style: const TextStyle(color: Colors.black54),
        ),
        Text(value?.toString() ?? '—'),
      ],
    ),
  );

  String _drCr(Object? value) {
    final number = _number(value);
    final formatted = _money(number.abs());
    return number < 0
        ? '$formatted Cr'
        : number > 0
        ? '$formatted Dr'
        : formatted;
  }

  String _display(Object? value, {String? key}) {
    if (value == null) return '—';
    if (key != null && isDateField(key)) {
      return formatDateValue(value) ?? value.toString();
    }
    if (value is double) return value.toStringAsFixed(2);
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }

  String _pdfDisplay(String key, Object? value) => _display(value, key: key)
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('•', '/')
      .replaceAll('₹', 'INR ');

  String _money(Object? value) => _number(value).toStringAsFixed(2);

  double _sum(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0, (sum, row) => sum + _number(row[key]));

  double _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  int? _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizedUiText(context, message)),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: Text(localizedUiText(context, 'Retry')),
              ),
            ),
        ],
      ),
    ),
  );
}
