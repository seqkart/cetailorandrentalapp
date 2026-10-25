import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_date_format.dart';
import '../../core/session_store.dart';
import '../../widgets/stitch_loader.dart';
import '../../l10n/app_strings.dart';
import '../transactions/transaction_voucher_details.dart';
import 'tailoring_repository.dart';

class TailoringWorkflowScreen extends StatefulWidget {
  const TailoringWorkflowScreen({
    required this.session,
    required this.repository,
    this.initialTab = 0,
    this.onOpenAssistant,
    this.showAppBar = true,
    this.onOpenMenu,
    super.key,
  });

  final AuthSession session;
  final TailoringRepository repository;
  final int initialTab;
  final VoidCallback? onOpenAssistant;
  final bool showAppBar;
  final VoidCallback? onOpenMenu;

  @override
  State<TailoringWorkflowScreen> createState() =>
      _TailoringWorkflowScreenState();
}

class _TailoringWorkflowScreenState extends State<TailoringWorkflowScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _orders;
  late Future<List<Map<String, dynamic>>> _unassigned;
  late Future<List<Map<String, dynamic>>> _assigned;
  late Future<List<Map<String, dynamic>>> _prefit;
  late Future<List<Map<String, dynamic>>> _invoices;
  Future<List<Map<String, dynamic>>>? _allOrders;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _sizes = [];
  List<Map<String, dynamic>> _colors = [];
  List<Map<String, dynamic>> _processes = [];
  List<Map<String, dynamic>> _tailors = [];
  List<Map<String, dynamic>> _series = [];
  final Set<int> _selectedOrderDetails = {};
  final Set<int> _selectedJobDetails = {};
  int? _selectedTailorId;
  String _allOrderStatus = '';
  String _invoiceBarcode = '';
  bool _showInvoiceForm = false;
  bool _busy = false;
  DateTime _orderFromDate = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 7)),
  );
  DateTime _orderToDate = DateUtils.dateOnly(DateTime.now());

  static const _tabTitles = [
    'Orders',
    'New order',
    'Tailor issue',
    'Tailor receipt',
    'Pre-fit',
    'All orders',
    'Invoice list',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _tabTitles.length,
      initialIndex: widget.initialTab.clamp(0, _tabTitles.length - 1),
      vsync: this,
    );
    _orders = _loadOrders();
    _unassigned = _loadUnassigned();
    _assigned = _loadAssigned();
    _prefit = _loadPrefit();
    _invoices = _loadInvoices();
    _loadMasters();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() =>
      widget.repository.loadOrders(
        widget.session,
        fromDate: _date(_orderFromDate),
        toDate: _date(_orderToDate),
      );

  Future<List<Map<String, dynamic>>> _loadUnassigned() =>
      widget.repository.loadUnassignedOrders(widget.session);

  Future<List<Map<String, dynamic>>> _loadAssigned() => widget.repository
      .loadAssignedOrders(widget.session, employeeId: _selectedTailorId);

  Future<List<Map<String, dynamic>>> _loadPrefit() =>
      widget.repository.loadPrefitOrders(widget.session);

  Future<List<Map<String, dynamic>>> _loadInvoices() =>
      widget.repository.loadInvoices(widget.session);

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait([
        widget.repository.loadItems(widget.session),
        widget.repository.loadCustomers(widget.session),
        widget.repository.loadSizes(widget.session),
        widget.repository.loadColors(widget.session),
        widget.repository.loadProcesses(widget.session),
        widget.repository.loadTailors(widget.session),
        widget.repository.loadVoucherSeries(widget.session),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _customers = results[1];
        _sizes = results[2];
        _colors = results[3];
        _processes = results[4];
        _tailors = results[5]
            .where((entry) => entry['isActive'] != false)
            .toList();
        _series = results[6];
      });
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _reload() async {
    setState(() {
      _orders = _loadOrders();
      _unassigned = _loadUnassigned();
      _assigned = _loadAssigned();
      _prefit = _loadPrefit();
      _invoices = _loadInvoices();
      if (_allOrders != null) _allOrders = _loadAllOrders();
    });
  }

  Future<List<Map<String, dynamic>>> _loadAllOrders() =>
      widget.repository.loadOrdersByType(
        widget.session,
        status: _allOrderStatus,
        fromDate: _date(DateTime.now()),
        toDate: _date(DateTime.now()),
      );

  Future<void> _saveOrder(Map<String, Object?> payload) async {
    await _perform(() async {
      await widget.repository.saveOrder(widget.session, payload);
      if (!mounted) return;
      _tabs.animateTo(0);
      await _reload();
      _message('Tailoring order saved.');
    });
  }

  Future<void> _assignOrders() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _TailorPickerDialog(tailors: _tailors),
    );
    if (selected == null || _selectedOrderDetails.isEmpty) return;
    await _perform(() async {
      await widget.repository.assignOrders(
        widget.session,
        employeeId: selected,
        orderDetailIds: _selectedOrderDetails.toList(),
      );
      _selectedOrderDetails.clear();
      await _reload();
      _message('Selected order items assigned to tailor.');
    });
  }

  Future<void> _receiveJobs() async {
    if (_selectedJobDetails.isEmpty) return;
    await _perform(() async {
      await widget.repository.receiveTailorJobs(
        widget.session,
        _selectedJobDetails.toList(),
      );
      _selectedJobDetails.clear();
      await _reload();
      _message('Selected tailor jobs received.');
    });
  }

  Future<void> _setPrefitStatus(Map<String, dynamic> item, String status) =>
      _perform(() => _submitPrefitStatus(item, status, const []));

  Future<void> _alterMeasurements(Map<String, dynamic> item) =>
      _perform(() async {
        final measurements = await widget.repository.loadOrderMeasurements(
          widget.session,
          _int(item['detailID']),
        );
        if (!mounted) return;
        final updated = await showDialog<List<Map<String, Object?>>>(
          context: context,
          builder: (context) =>
              _MeasurementAlterationDialog(measurements: measurements),
        );
        if (updated == null) return;
        await _submitPrefitStatus(item, 'Alteration', updated);
      });

  Future<void> _submitPrefitStatus(
    Map<String, dynamic> item,
    String status,
    List<Map<String, Object?>> measurements,
  ) async {
    await widget.repository.updatePrefitStatus(widget.session, {
      'jobDetailId': _int(item['jobDetailId']),
      'updateDate': _date(DateTime.now()),
      'remarks': '',
      'updateStatus': status,
      'employeeId': 0,
      'measurements': measurements,
    });
    await _reload();
    _message(
      status == 'Approved' ? 'Item ready for dispatch.' : 'Alteration saved.',
    );
  }

  Future<void> _findInvoiceOrder(String barcode) async {
    final search = barcode.trim();
    if (search.isEmpty) return;
    await _perform(() async {
      final order = await widget.repository.findOrderByBarcode(
        widget.session,
        search,
      );
      if (!mounted) return;
      if (order == null) {
        _message(
          '${localizedUiText(context, 'No order found for barcode')} $search.',
        );
        return;
      }
      final details = order['orderDetails'];
      if (details is! List || details.isEmpty) {
        _message('This order has no invoiceable items.');
        return;
      }
      final pending = details
          .whereType<Map>()
          .where((item) => item['status'] != 'Delivered')
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (pending.isEmpty) {
        _message('No pending items in this order.');
        return;
      }
      if (!mounted) return;
      await _createInvoice(order, pending);
    });
  }

  Future<void> _createInvoice(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    final invoice = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _InvoiceDialog(
        order: order,
        items: items,
        financialYearId: widget.session.financialYearId,
      ),
    );
    if (invoice == null) return;
    await widget.repository.generateInvoice(widget.session, invoice);
    if (!mounted) return;
    setState(() {
      _invoices = _loadInvoices();
      _invoiceBarcode = '';
      _showInvoiceForm = false;
    });
    _message('Invoice generated.');
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(localizedUiText(context, value))));
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-${value.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.showAppBar
        ? AppBar(
            leading: widget.onOpenMenu == null
                ? null
                : IconButton(
                    tooltip: localizedUiText(
                      context,
                      'Masters and administration',
                    ),
                    onPressed: widget.onOpenMenu,
                    icon: const Icon(Icons.menu),
                  ),
            title: Text(localizedUiText(context, 'Tailoring transactions')),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                for (final title in _tabTitles)
                  Tab(text: localizedUiText(context, title)),
              ],
            ),
            actions: [
              if (widget.onOpenAssistant != null)
                IconButton(
                  tooltip: localizedUiText(context, 'Ask assistant'),
                  onPressed: widget.onOpenAssistant,
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
              IconButton(
                tooltip: localizedUiText(context, 'Refresh'),
                onPressed: _busy ? null : _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          )
        : null,
    body: Stack(
      children: [
        TabBarView(
          controller: _tabs,
          children: [
            _OrdersBoard(
              future: _orders,
              fromDate: _orderFromDate,
              toDate: _orderToDate,
              onDateRangeChanged: (range) => setState(() {
                _orderFromDate = range.start;
                _orderToDate = range.end;
                _orders = _loadOrders();
              }),
            ),
            _TailorOrderEntry(
              customers: _customers,
              items: _items,
              sizes: _sizes,
              colors: _colors,
              processes: _processes,
              series: _series,
              session: widget.session,
              repository: widget.repository,
              onSave: _saveOrder,
            ),
            _UnassignedBoard(
              future: _unassigned,
              selectedIds: _selectedOrderDetails,
              onSelectionChanged: (id, selected) => setState(() {
                selected
                    ? _selectedOrderDetails.add(id)
                    : _selectedOrderDetails.remove(id);
              }),
              onAssign: _assignOrders,
            ),
            _AssignedBoard(
              future: _assigned,
              tailors: _tailors,
              selectedTailorId: _selectedTailorId,
              selectedIds: _selectedJobDetails,
              onTailorChanged: (id) => setState(() {
                _selectedTailorId = id;
                _assigned = _loadAssigned();
              }),
              onSelectionChanged: (id, selected) => setState(() {
                selected
                    ? _selectedJobDetails.add(id)
                    : _selectedJobDetails.remove(id);
              }),
              onReceive: _receiveJobs,
            ),
            _PrefitBoard(
              future: _prefit,
              onApproved: (item) => _setPrefitStatus(item, 'Approved'),
              onAlteration: _alterMeasurements,
            ),
            _OrdersBoard(
              future: _allOrders ??= _loadAllOrders(),
              status: _allOrderStatus,
              title: 'All tailoring orders',
              showStatusFilter: true,
              onStatusChanged: (status) => setState(() {
                _allOrderStatus = status;
                _allOrders = _loadAllOrders();
              }),
            ),
            _showInvoiceForm
                ? _InvoiceBoard(
                    value: _invoiceBarcode,
                    busy: _busy,
                    onChanged: (value) => _invoiceBarcode = value,
                    onSearch: _findInvoiceOrder,
                    onBack: () => setState(() => _showInvoiceForm = false),
                  )
                : _InvoiceListBoard(
                    future: _invoices,
                    onCreate: () => setState(() => _showInvoiceForm = true),
                  ),
          ],
        ),
        if (_busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  );
}

class _OrdersBoard extends StatelessWidget {
  const _OrdersBoard({
    required this.future,
    this.title = 'Tailoring orders',
    this.status = '',
    this.showStatusFilter = false,
    this.onStatusChanged,
    this.fromDate,
    this.toDate,
    this.onDateRangeChanged,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String status;
  final String title;
  final bool showStatusFilter;
  final ValueChanged<String>? onStatusChanged;
  final DateTime? fromDate;
  final DateTime? toDate;
  final ValueChanged<DateTimeRange>? onDateRangeChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizedUiText(context, title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: showStatusFilter
                  ? DropdownButton<String>(
                      value: status,
                      hint: Text(localizedUiText(context, 'Status')),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(localizedUiText(context, 'All')),
                        ),
                        DropdownMenuItem(
                          value: 'Today',
                          child: Text(localizedUiText(context, 'Today')),
                        ),
                        DropdownMenuItem(
                          value: 'Booked',
                          child: Text(localizedUiText(context, 'Booked')),
                        ),
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text(localizedUiText(context, 'In progress')),
                        ),
                        DropdownMenuItem(
                          value: 'Delivered',
                          child: Text(localizedUiText(context, 'Delivered')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onStatusChanged?.call(value);
                      },
                    )
                  : TextButton.icon(
                      onPressed: fromDate == null || toDate == null
                          ? null
                          : () async {
                              final today = DateUtils.dateOnly(DateTime.now());
                              final selected = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: today.add(const Duration(days: 730)),
                                initialDateRange: DateTimeRange(
                                  start: fromDate!,
                                  end: toDate!,
                                ),
                              );
                              if (selected != null) {
                                onDateRangeChanged?.call(selected);
                              }
                            },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        '${_formatDate(fromDate!)} – ${_formatDate(toDate!)}',
                      ),
                    ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _FutureList(
          future: future,
          empty: localizedUiText(context, 'No tailoring orders found.'),
          itemBuilder: (context, order) => _OrderCard(order: order),
        ),
      ),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final details = order['orderDetails'] is List
        ? (order['orderDetails'] as List).whereType<Map>().toList()
        : const <Map>[];
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: ExpansionTile(
        title: Text(
          order['orderNo']?.toString() ?? localizedUiText(context, 'Order'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${order['customerName'] ?? localizedUiText(context, 'Customer')} • '
          '${order['status'] ?? order['orderStatus'] ?? '—'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _InfoLine(
            label: localizedUiText(context, 'Mobile'),
            value: order['customerMobile']?.toString() ?? '—',
          ),
          _InfoLine(
            label: localizedUiText(context, 'Trial'),
            value:
                formatDateValue(order['trialDate']) ??
                order['trialDate']?.toString() ??
                '—',
          ),
          _InfoLine(
            label: localizedUiText(context, 'Delivery'),
            value:
                formatDateValue(order['deliveryDate']) ??
                order['deliveryDate']?.toString() ??
                '—',
          ),
          _InfoLine(
            label: localizedUiText(context, 'Priority'),
            value: order['priority']?.toString() ?? '—',
          ),
          for (final detail in details)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                detail['itemName']?.toString() ??
                    localizedUiText(context, 'Item'),
              ),
              subtitle: Text(
                '${detail['sizeName'] ?? ''} · ${detail['colorName'] ?? ''} · ${detail['processName'] ?? ''}',
              ),
              trailing: Text(
                '₹${detail['netAmount'] ?? detail['amount'] ?? detail['rate'] ?? 0}',
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showTransactionVoucherDetails(
                context,
                title:
                    '${localizedUiText(context, 'Order')} '
                    '${order['orderNo'] ?? ''} '
                    '${localizedUiText(context, 'details')}',
                voucher: Map<String, dynamic>.from(order),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(localizedUiText(context, 'View all voucher details')),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnassignedBoard extends StatelessWidget {
  const _UnassignedBoard({
    required this.future,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onAssign,
  });

  final Future<List<Map<String, dynamic>>> future;
  final Set<int> selectedIds;
  final void Function(int id, bool selected) onSelectionChanged;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                localizedUiText(context, 'Assign orders to tailor'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: selectedIds.isEmpty ? null : onAssign,
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(
                '${localizedUiText(context, 'Assign')} (${selectedIds.length})',
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _FutureList(
          future: future,
          empty: localizedUiText(context, 'No unassigned tailoring items.'),
          itemBuilder: (context, order) {
            final items = order['unassignedItems_List'] is List
                ? (order['unassignedItems_List'] as List)
                      .whereType<Map>()
                      .toList()
                : const <Map>[];
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  order['orderNo']?.toString() ??
                      localizedUiText(context, 'Order'),
                ),
                subtitle: Text(
                  '${order['customerName'] ?? localizedUiText(context, 'Customer')} · '
                  '${items.length} ${localizedUiText(context, 'items')}',
                ),
                children: [
                  for (final item in items)
                    CheckboxListTile(
                      value: selectedIds.contains(_int(item['detailID'])),
                      onChanged: (value) => onSelectionChanged(
                        _int(item['detailID']),
                        value ?? false,
                      ),
                      title: Text(
                        item['itemName']?.toString() ??
                            localizedUiText(context, 'Item'),
                      ),
                      subtitle: Text(
                        '${item['sizeName'] ?? ''} · ${item['colorName'] ?? ''} · ${item['processName'] ?? ''} · ₹${item['rate'] ?? 0}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _AssignedBoard extends StatelessWidget {
  const _AssignedBoard({
    required this.future,
    required this.tailors,
    required this.selectedTailorId,
    required this.selectedIds,
    required this.onTailorChanged,
    required this.onSelectionChanged,
    required this.onReceive,
  });

  final Future<List<Map<String, dynamic>>> future;
  final List<Map<String, dynamic>> tailors;
  final int? selectedTailorId;
  final Set<int> selectedIds;
  final ValueChanged<int?> onTailorChanged;
  final void Function(int id, bool selected) onSelectionChanged;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey<int?>(selectedTailorId),
              initialValue: selectedTailorId,
              decoration: InputDecoration(
                labelText: localizedUiText(context, 'Tailor'),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(localizedUiText(context, 'All tailors')),
                ),
                for (final tailor in tailors)
                  DropdownMenuItem(
                    value: _int(tailor['employeeID']),
                    child: Text(
                      _tailorName(tailor) ?? localizedUiText(context, 'Tailor'),
                    ),
                  ),
              ],
              onChanged: onTailorChanged,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: selectedIds.isEmpty ? null : onReceive,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: Text(
                  '${localizedUiText(context, 'Received')} (${selectedIds.length})',
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _FutureList(
          future: future,
          empty: localizedUiText(context, 'No pending tailor jobs.'),
          itemBuilder: (context, order) {
            final items = order['pendingItems_List'] is List
                ? (order['pendingItems_List'] as List).whereType<Map>().toList()
                : const <Map>[];
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  order['orderNo']?.toString() ??
                      localizedUiText(context, 'Order'),
                ),
                subtitle: Text(
                  '${order['customerName'] ?? localizedUiText(context, 'Customer')} · '
                  '${items.length} ${localizedUiText(context, 'items')}',
                ),
                children: [
                  for (final item in items)
                    CheckboxListTile(
                      value: selectedIds.contains(_int(item['jobDetailId'])),
                      onChanged: (value) => onSelectionChanged(
                        _int(item['jobDetailId']),
                        value ?? false,
                      ),
                      title: Text(
                        item['itemName']?.toString() ??
                            localizedUiText(context, 'Item'),
                      ),
                      subtitle: Text(
                        '${item['sizeName'] ?? ''} · ${item['colorName'] ?? ''} · ₹${item['rate'] ?? 0}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _PrefitBoard extends StatelessWidget {
  const _PrefitBoard({
    required this.future,
    required this.onApproved,
    required this.onAlteration,
  });

  final Future<List<Map<String, dynamic>>> future;
  final ValueChanged<Map<String, dynamic>> onApproved;
  final ValueChanged<Map<String, dynamic>> onAlteration;

  @override
  Widget build(BuildContext context) => _FutureList(
    future: future,
    empty: localizedUiText(context, 'No orders ready for pre-fit.'),
    itemBuilder: (context, order) {
      final items = order['completedItems_List'] is List
          ? (order['completedItems_List'] as List).whereType<Map>().toList()
          : const <Map>[];
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            order['orderNo']?.toString() ?? localizedUiText(context, 'Order'),
          ),
          subtitle: Text(
            '${order['customerName'] ?? localizedUiText(context, 'Customer')} · '
            '${order['orderStatus'] ?? ''}',
          ),
          children: [
            for (final row in items)
              ListTile(
                title: Text(
                  row['itemName']?.toString() ??
                      localizedUiText(context, 'Item'),
                ),
                subtitle: Text(
                  '${row['sizeName'] ?? ''} · ${row['colorName'] ?? ''} · ${row['processName'] ?? ''}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: localizedUiText(context, 'Alteration'),
                      onPressed: () =>
                          onAlteration(Map<String, dynamic>.from(row)),
                      icon: const Icon(Icons.straighten),
                    ),
                    IconButton(
                      tooltip: localizedUiText(context, 'Ready for dispatch'),
                      onPressed: () =>
                          onApproved(Map<String, dynamic>.from(row)),
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _InvoiceListBoard extends StatelessWidget {
  const _InvoiceListBoard({required this.future, required this.onCreate});

  final Future<List<Map<String, dynamic>>> future;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                localizedUiText(context, 'Invoice list'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(localizedUiText(context, 'Invoice')),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _FutureList(
          future: future,
          empty: localizedUiText(context, 'No invoices found.'),
          itemBuilder: (context, invoice) => Card(
            margin: const EdgeInsets.fromLTRB(12, 5, 12, 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text(
                invoice['invoiceNo']?.toString() ??
                    localizedUiText(context, 'Delivery No'),
              ),
              subtitle: Text(
                '${invoice['customerName'] ?? localizedUiText(context, 'Customer')} · '
                '${formatDateValue(invoice['invoiceDate']) ?? invoice['invoiceDate'] ?? ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${invoice['totalAmount'] ?? 0}'),
                  IconButton(
                    tooltip: localizedUiText(context, 'View invoice details'),
                    onPressed: () => showTransactionVoucherDetails(
                      context,
                      title:
                          '${localizedUiText(context, 'Invoice')} '
                          '${invoice['invoiceNo'] ?? ''} '
                          '${localizedUiText(context, 'details')}',
                      voucher: Map<String, dynamic>.from(invoice),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _InvoiceBoard extends StatefulWidget {
  const _InvoiceBoard({
    required this.value,
    required this.busy,
    required this.onChanged,
    required this.onSearch,
    required this.onBack,
  });

  final String value;
  final bool busy;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;

  @override
  State<_InvoiceBoard> createState() => _InvoiceBoardState();
}

class _InvoiceBoardState extends State<_InvoiceBoard> {
  late final TextEditingController _barcodeController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _InvoiceBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _barcodeController.text != widget.value) {
      _barcodeController.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              tooltip: localizedUiText(context, 'Back to invoice list'),
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              localizedUiText(context, 'Invoice'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          selectAllOnFocus: true,
          controller: _barcodeController,
          decoration: InputDecoration(
            labelText: localizedUiText(
              context,
              'Scan or enter approved item barcode',
            ),
            suffixIcon: IconButton(
              onPressed: widget.busy
                  ? null
                  : () => widget.onSearch(_barcodeController.text),
              icon: const Icon(Icons.search),
            ),
          ),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSearch,
        ),
      ),
    ],
  );
}

class _TailorOrderEntry extends StatelessWidget {
  const _TailorOrderEntry({
    required this.customers,
    required this.items,
    required this.sizes,
    required this.colors,
    required this.processes,
    required this.series,
    required this.session,
    required this.repository,
    required this.onSave,
  });

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> sizes;
  final List<Map<String, dynamic>> colors;
  final List<Map<String, dynamic>> processes;
  final List<Map<String, dynamic>> series;
  final AuthSession session;
  final TailoringRepository repository;
  final ValueChanged<Map<String, Object?>> onSave;

  @override
  Widget build(BuildContext context) => _StitchingOrderForm(
    customers: customers,
    items: items,
    sizes: sizes,
    colors: colors,
    processes: processes,
    series: series,
    session: session,
    repository: repository,
    onSave: onSave,
  );
}

class _NewMeasurementsDialog extends StatefulWidget {
  const _NewMeasurementsDialog({
    required this.groupItems,
    required this.savedMeasurements,
  });

  final List<Map<String, dynamic>> groupItems;
  final List<Map<String, Object?>> savedMeasurements;

  @override
  State<_NewMeasurementsDialog> createState() => _NewMeasurementsDialogState();
}

class _NewMeasurementsDialogState extends State<_NewMeasurementsDialog> {
  final Map<int, List<_OrderMeasurementField>> _fieldsByGroupItem = {};
  int? _selectedGroupItemId;

  @override
  void initState() {
    super.initState();
    final first = widget.groupItems.firstOrNull;
    if (first != null) {
      _selectedGroupItemId = _int(first['groupItemID']);
      _fieldsFor(first);
    }
  }

  @override
  void dispose() {
    for (final fields in _fieldsByGroupItem.values) {
      for (final field in fields) {
        field.value.dispose();
      }
    }
    super.dispose();
  }

  List<_OrderMeasurementField> _fieldsFor(Map<String, dynamic> groupItem) {
    final groupItemId = _int(groupItem['groupItemID']);
    return _fieldsByGroupItem.putIfAbsent(groupItemId, () {
      final mappings = groupItem['mappings'];
      if (mappings is! List) return [];
      return [
        for (final mapping in mappings.whereType<Map>())
          _OrderMeasurementField(
            mapping: _stringMap(mapping),
            groupItemId: groupItemId,
            saved: widget.savedMeasurements
                .cast<Map<String, Object?>>()
                .firstWhere(
                  (saved) =>
                      _int(saved['itemId']) == groupItemId &&
                      _int(saved['measurementMapId']) == _int(mapping['mapId']),
                  orElse: () => const <String, Object?>{},
                ),
          ),
      ];
    });
  }

  void _save() {
    Navigator.pop(context, [
      for (final fields in _fieldsByGroupItem.values)
        for (final field in fields)
          if (field.value.text.trim().isNotEmpty)
            <String, Object?>{
              'itemId': field.groupItemId,
              'measurementMapId': _int(field.mapping['mapId']),
              'measurementName': field.mapping['measurementName'],
              'measurementValue': _number(field.value.text),
              'measurementVariation': null,
              'finalMeasurementValue': null,
            },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.groupItems.firstWhere(
      (item) => _int(item['groupItemID']) == _selectedGroupItemId,
      orElse: () => widget.groupItems.first,
    );
    final fields = _fieldsFor(selectedItem);
    return AlertDialog(
      title: Text(
        '${localizedUiText(context, 'Measurements')} · '
        '${selectedItem['groupItemName'] ?? ''}',
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedGroupItemId,
              decoration: InputDecoration(
                labelText: localizedUiText(context, 'Measurement set'),
              ),
              items: [
                for (final item in widget.groupItems)
                  DropdownMenuItem(
                    value: _int(item['groupItemID']),
                    child: Text(item['groupItemName']?.toString() ?? ''),
                  ),
              ],
              onChanged: (id) => setState(() => _selectedGroupItemId = id),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final field in fields)
                    TextField(
                      selectAllOnFocus: true,
                      controller: field.value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: field.mapping['measurementName']?.toString(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizedUiText(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(localizedUiText(context, 'Save measurements')),
        ),
      ],
    );
  }
}

class _OrderMeasurementField {
  _OrderMeasurementField({
    required this.mapping,
    required this.groupItemId,
    required Map<String, Object?> saved,
  }) : value = TextEditingController(
         text: saved['measurementValue']?.toString() ?? '',
       );

  final Map<String, dynamic> mapping;
  final int groupItemId;
  final TextEditingController value;
}

class _StitchingOrderForm extends StatefulWidget {
  const _StitchingOrderForm({
    required this.customers,
    required this.items,
    required this.sizes,
    required this.colors,
    required this.processes,
    required this.series,
    required this.session,
    required this.repository,
    required this.onSave,
  });

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> sizes;
  final List<Map<String, dynamic>> colors;
  final List<Map<String, dynamic>> processes;
  final List<Map<String, dynamic>> series;
  final AuthSession session;
  final TailoringRepository repository;
  final ValueChanged<Map<String, Object?>> onSave;

  @override
  State<_StitchingOrderForm> createState() => _StitchingOrderFormState();
}

class _StitchingOrderFormState extends State<_StitchingOrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  final _customerName = TextEditingController();
  final _trialDate = TextEditingController();
  final _deliveryDate = TextEditingController();
  final _remarks = TextEditingController();
  final _advance = TextEditingController(text: '0');
  final List<_StitchingRow> _rows = [_StitchingRow()];
  final _imagePicker = ImagePicker();
  int? _customerId;
  int? _seriesId;
  String _priority = 'Low';

  @override
  void initState() {
    super.initState();
    final current = widget.series.where((entry) => entry['isCurrent'] == true);
    final chosen = current.isNotEmpty
        ? current.first
        : widget.series.firstOrNull;
    _seriesId = chosen == null ? null : _int(chosen['voucherSeriesID']);
    _trialDate.text = _formatDate(DateTime.now().add(const Duration(days: 7)));
    _deliveryDate.text = _formatDate(
      DateTime.now().add(const Duration(days: 14)),
    );
  }

  @override
  void dispose() {
    _mobile.dispose();
    _customerName.dispose();
    _trialDate.dispose();
    _deliveryDate.dispose();
    _remarks.dispose();
    _advance.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final initial = parseDateValue(controller.text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date != null) controller.text = _formatDate(date);
  }

  Future<void> _openMeasurements(_StitchingRow row) async {
    final item = widget.items.firstWhere(
      (entry) => _int(entry['itemId'] ?? entry['itemID']) == row.itemId,
      orElse: () => <String, dynamic>{},
    );
    final groupId = _int(item['groupId'] ?? item['groupID']);
    if (groupId == 0) {
      _showDialogMessage('This item has no measurement group configured.');
      return;
    }
    try {
      final mapping = await widget.repository.loadMeasurementMappings(
        widget.session,
        groupId,
      );
      if (!mounted) return;
      final groupItems = mapping?['groupItems'];
      if (groupItems is! List || groupItems.isEmpty) {
        _showDialogMessage(
          'No measurement fields are configured for this item.',
        );
        return;
      }
      final selected = await showDialog<List<Map<String, Object?>>>(
        context: context,
        builder: (context) => _NewMeasurementsDialog(
          groupItems: groupItems.whereType<Map>().map(_stringMap).toList(),
          savedMeasurements: row.measurements,
        ),
      );
      if (selected != null) setState(() => row.measurements = selected);
    } catch (error) {
      _showDialogMessage(error.toString());
    }
  }

  Future<void> _attachCameraPhoto(_StitchingRow row) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      _addPhoto(row, bytes, photo.mimeType ?? 'image/jpeg');
    } catch (error) {
      if (!mounted) return;
      _showDialogMessage(
        '${localizedUiText(context, 'Could not capture image')}: $error',
      );
    }
  }

  Future<void> _attachFiles(_StitchingRow row) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final extension = file.extension?.toLowerCase();
        final mimeType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };
        _addPhoto(row, bytes, mimeType);
      }
    } catch (error) {
      if (!mounted) return;
      _showDialogMessage(
        '${localizedUiText(context, 'Could not attach image')}: $error',
      );
    }
  }

  void _addPhoto(_StitchingRow row, List<int> bytes, String mimeType) {
    setState(() {
      row.photos.add({
        'photoId': 0,
        'photoType': mimeType,
        'photoBase64': base64Encode(bytes),
        'photoPath': null,
        'remarks': '',
        'index': row.photos.length,
        'itemId': row.itemId,
      });
    });
  }

  void _showDialogMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(localizedUiText(context, message))),
      );
  }

  void _selectCustomer(int? id) {
    final customer = widget.customers.cast<Map<String, dynamic>?>().firstWhere(
      (entry) => _int(entry?['customerID']) == id,
      orElse: () => null,
    );
    setState(() {
      _customerId = id;
      if (customer != null) {
        _mobile.text = customer['mobileNo']?.toString() ?? '';
        _customerName.text = customer['fullName']?.toString() ?? '';
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_rows.any(
      (row) =>
          row.itemId == null ||
          row.sizeId == null ||
          row.colorId == null ||
          row.processId == null,
    )) {
      return;
    }
    final details = [
      for (final row in _rows)
        <String, Object?>{
          'detailID': 0,
          'itemId': row.itemId,
          'sizeID': row.sizeId,
          'colorID': row.colorId,
          'processID': row.processId,
          'qty': row.qty,
          'qtyInMeters': row.qtyInMeters,
          'rate': _number(row.rate.text),
          'discountPercent': row.discountPercent,
          'discountAmount': row.discountAmount,
          'amount': row.grossAmount,
          'netAmount': row.amount,
          'barcode': '',
          'remarks': row.remarks.text.trim(),
          'orderItemPhotos': row.photos,
        },
    ];
    final total = _rows.fold<double>(0, (sum, row) => sum + row.amount);
    final advance = double.tryParse(_advance.text) ?? 0;
    widget.onSave({
      'orderID': 0,
      'orderNo': '',
      'orderDate': _formatDate(DateTime.now()),
      'totalAmount': total,
      'advancePaid': advance,
      'status': 'Booked',
      'trialDate': _trialDate.text,
      'deliveryDate': _deliveryDate.text,
      'remarks': _remarks.text.trim(),
      'finYearID': widget.session.financialYearId,
      'mobileNo': _mobile.text.trim(),
      'customerID': _customerId,
      'customerName': _customerName.text.trim(),
      'priority': _priority,
      'voucherSeriesId': _seriesId,
      'orderDetails': details,
      'orderMeasurements': [
        for (final row in _rows)
          for (final measurement in row.measurements)
            <String, Object?>{
              'orderMeasurementId': 0,
              'orderDetailId': 0,
              'itemId': row.itemId,
              'measurementMapId': measurement['measurementMapId'],
              'measurementValue': measurement['measurementValue'],
              'measurementVariation': measurement['measurementVariation'],
              'finalMeasurementValue': measurement['finalMeasurementValue'],
            },
      ],
      'paymentDetails': advance > 0
          ? [
              {
                'paymentDate': DateTime.now().toIso8601String(),
                'paymentMode': 'Cash',
                'amount': advance,
                'remarks': '',
              },
            ]
          : <Object?>[],
      'orderPhotos': [
        for (final row in _rows)
          for (final photo in row.photos)
            <String, Object?>{
              'photoId': photo['photoId'],
              'photoType': photo['photoType'],
              'photoBase64': photo['photoBase64'],
              'photoPath': photo['photoPath'],
              'remarks': photo['remarks'],
            },
      ],
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE7F3F0),
                  foregroundColor: Color(0xFF158878),
                  child: Icon(Icons.content_cut_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedUiText(context, 'Create stitching order'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        localizedUiText(
                          context,
                          'Enter customer, fitting dates and item details',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  localizedUiText(context, 'Required fields *'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _formSection(
                        context,
                        title: localizedUiText(context, 'Order details'),
                        subtitle: localizedUiText(
                          context,
                          'Choose the voucher series and set priority.',
                        ),
                        icon: Icons.receipt_long_outlined,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: _seriesId,
                            decoration: InputDecoration(
                              labelText: localizedUiText(
                                context,
                                'Voucher series',
                              ),
                            ),
                            items: [
                              for (final entry in widget.series)
                                DropdownMenuItem(
                                  value: _int(entry['voucherSeriesID']),
                                  child: Text(
                                    entry['voucherSeriesName']?.toString() ??
                                        localizedUiText(context, 'Series'),
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _seriesId = value),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: InputDecoration(
                              labelText: localizedUiText(context, 'Priority'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'High',
                                child: Text(localizedUiText(context, 'High')),
                              ),
                              DropdownMenuItem(
                                value: 'Medium',
                                child: Text(localizedUiText(context, 'Medium')),
                              ),
                              DropdownMenuItem(
                                value: 'Low',
                                child: Text(localizedUiText(context, 'Low')),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value ?? 'Low'),
                          ),
                        ],
                      ),
                      _formSection(
                        context,
                        title: localizedUiText(context, 'Customer & schedule'),
                        subtitle: localizedUiText(
                          context,
                          'Select a customer and confirm trial and delivery dates.',
                        ),
                        icon: Icons.person_outline_rounded,
                        children: [
                          DropdownButtonFormField<int>(
                            key: ValueKey<int?>(_customerId),
                            initialValue: _customerId,
                            decoration: InputDecoration(
                              labelText: localizedUiText(context, 'Customer *'),
                            ),
                            items: [
                              for (final customer in widget.customers)
                                DropdownMenuItem(
                                  value: _int(customer['customerID']),
                                  child: Text(
                                    '${customer['fullName'] ?? ''} · ${customer['mobileNo'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _selectCustomer,
                            validator: (value) => value == null
                                ? localizedUiText(context, 'Select a customer')
                                : null,
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 620;
                              final fields = [
                                TextFormField(
                                  selectAllOnFocus: true,
                                  controller: _mobile,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  decoration: InputDecoration(
                                    labelText: localizedUiText(
                                      context,
                                      'Mobile number *',
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null ||
                                          !RegExp(r'^\d{10}$').hasMatch(value)
                                      ? localizedUiText(
                                          context,
                                          'Enter 10-digit mobile',
                                        )
                                      : null,
                                ),
                                TextFormField(
                                  selectAllOnFocus: true,
                                  controller: _customerName,
                                  readOnly: _customerId != null,
                                  decoration: InputDecoration(
                                    labelText: localizedUiText(
                                      context,
                                      'Customer name *',
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? localizedUiText(
                                          context,
                                          'Enter customer name',
                                        )
                                      : null,
                                ),
                                _dateField(_trialDate, 'Trial date *'),
                                _dateField(_deliveryDate, 'Delivery date'),
                              ];
                              if (wide) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: fields[0]),
                                        const SizedBox(width: 12),
                                        Expanded(child: fields[1]),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(child: fields[2]),
                                        const SizedBox(width: 12),
                                        Expanded(child: fields[3]),
                                      ],
                                    ),
                                  ],
                                );
                              }
                              return Column(
                                children: [for (final field in fields) field],
                              );
                            },
                          ),
                        ],
                      ),
                      _formSection(
                        context,
                        title: localizedUiText(context, 'Stitching items'),
                        subtitle: localizedUiText(
                          context,
                          'Add each garment, its measurements and work details.',
                        ),
                        icon: Icons.checkroom_outlined,
                        trailing: TextButton.icon(
                          onPressed: () =>
                              setState(() => _rows.add(_StitchingRow())),
                          icon: const Icon(Icons.add),
                          label: Text(localizedUiText(context, 'Add item')),
                        ),
                        children: [
                          for (var index = 0; index < _rows.length; index++)
                            _rowFields(index),
                        ],
                      ),
                      _formSection(
                        context,
                        title: localizedUiText(context, 'Payment & notes'),
                        subtitle: localizedUiText(
                          context,
                          'Record any advance collected and order remarks.',
                        ),
                        icon: Icons.payments_outlined,
                        children: [
                          TextFormField(
                            selectAllOnFocus: true,
                            controller: _advance,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: localizedUiText(
                                context,
                                'Advance paid',
                              ),
                              prefixText: '₹ ',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '');
                              return amount == null || amount < 0
                                  ? localizedUiText(
                                      context,
                                      'Enter valid advance',
                                    )
                                  : null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            selectAllOnFocus: true,
                            controller: _remarks,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: localizedUiText(
                                context,
                                'Order remarks',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${localizedUiText(context, 'Order total')}  ₹${_rows.fold<double>(0, (sum, row) => sum + row.amount).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(localizedUiText(context, 'Save order')),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dateField(TextEditingController controller, String label) =>
      TextFormField(
        selectAllOnFocus: true,
        controller: controller,
        readOnly: true,
        onTap: () => _pickDate(controller),
        decoration: InputDecoration(
          labelText: localizedUiText(context, label),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        validator: (value) => value == null || value.isEmpty
            ? localizedUiText(context, 'Select date')
            : null,
      );

  Widget _rowFields(int index) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<int?>(row.itemId),
                    initialValue: row.itemId,
                    decoration: InputDecoration(
                      labelText: localizedUiText(context, 'Item *'),
                    ),
                    items: [
                      for (final item in widget.items)
                        DropdownMenuItem(
                          value: _int(item['itemId'] ?? item['itemID']),
                          child: Text(item['itemName']?.toString() ?? ''),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      if (row.itemId != id) {
                        row.measurements = [];
                        row.photos.clear();
                      }
                      row.itemId = id;
                      final item = widget.items.firstWhere(
                        (entry) =>
                            _int(entry['itemId'] ?? entry['itemID']) == id,
                        orElse: () => <String, dynamic>{},
                      );
                      row.rate.text = '${item['itemRate'] ?? 0}';
                    }),
                    validator: (value) => value == null
                        ? localizedUiText(context, 'Select item')
                        : null,
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: localizedUiText(context, 'Remove item'),
                    onPressed: () =>
                        setState(() => _rows.removeAt(index).dispose()),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    row.sizeId,
                    'Size *',
                    widget.sizes,
                    'sizeID',
                    'sizeName',
                    (value) => setState(() => row.sizeId = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown(
                    row.colorId,
                    'Color *',
                    widget.colors,
                    'colorID',
                    'colorName',
                    (value) => setState(() => row.colorId = value),
                  ),
                ),
              ],
            ),
            _dropdown(
              row.processId,
              'Process *',
              widget.processes,
              'processID',
              'processName',
              (value) => setState(() => row.processId = value),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: row.itemId == null
                      ? null
                      : () => _openMeasurements(row),
                  icon: const Icon(Icons.straighten),
                  label: Text(
                    row.measurements.isEmpty
                        ? localizedUiText(context, 'Measurements')
                        : '${localizedUiText(context, 'Measurements')} (${row.measurements.length})',
                  ),
                ),
                TextButton.icon(
                  onPressed: row.itemId == null
                      ? null
                      : () => _attachCameraPhoto(row),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(localizedUiText(context, 'Camera')),
                ),
                TextButton.icon(
                  onPressed: row.itemId == null
                      ? null
                      : () => _attachFiles(row),
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    '${localizedUiText(context, 'Files')} (${row.photos.length})',
                  ),
                ),
              ],
            ),
            for (
              var photoIndex = 0;
              photoIndex < row.photos.length;
              photoIndex++
            )
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  '${localizedUiText(context, 'Attached image')} ${photoIndex + 1}',
                ),
                trailing: IconButton(
                  tooltip: localizedUiText(context, 'Remove image'),
                  onPressed: () =>
                      setState(() => row.photos.removeAt(photoIndex)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 24) / 4
                    : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    SizedBox(
                      width: width,
                      child: _numericField(
                        row.quantity,
                        'Qty *',
                        integer: true,
                        validator: (value) {
                          final quantity = int.tryParse(value ?? '');
                          return quantity == null || quantity <= 0
                              ? localizedUiText(
                                  context,
                                  'Quantity must be greater than 0',
                                )
                              : null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _numericField(row.meters, 'Meters'),
                    ),
                    SizedBox(
                      width: width,
                      child: _numericField(
                        row.rate,
                        'Rate *',
                        validator: (_) => row.amount <= 0
                            ? localizedUiText(
                                context,
                                'Amount must be greater than 0',
                              )
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _numericField(
                        row.discount,
                        'Disc %',
                        validator: (value) {
                          final discount = double.tryParse(value ?? '');
                          return discount == null ||
                                  discount < 0 ||
                                  discount >= 100
                              ? localizedUiText(
                                  context,
                                  'Discount must be less than 100%',
                                )
                              : null;
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${localizedUiText(context, 'Amount')}: ₹${row.amount.toStringAsFixed(2)}',
              ),
            ),
            TextFormField(
              selectAllOnFocus: true,
              controller: row.remarks,
              decoration: InputDecoration(
                labelText: localizedUiText(context, 'Item remarks'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    int? value,
    String label,
    List<Map<String, dynamic>> values,
    String idKey,
    String nameKey,
    ValueChanged<int?> changed,
  ) => DropdownButtonFormField<int>(
    key: ValueKey<int?>(value),
    initialValue: value,
    decoration: InputDecoration(labelText: localizedUiText(context, label)),
    items: [
      for (final entry in values)
        DropdownMenuItem(
          value: _int(entry[idKey]),
          child: Text(entry[nameKey]?.toString() ?? ''),
        ),
    ],
    onChanged: changed,
    validator: (selected) =>
        selected == null ? localizedUiText(context, 'Required') : null,
  );

  Widget _numericField(
    TextEditingController controller,
    String label, {
    bool integer = false,
    String? Function(String?)? validator,
  }) => TextFormField(
    selectAllOnFocus: true,
    controller: controller,
    keyboardType: integer
        ? TextInputType.number
        : const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: localizedUiText(context, label)),
    onChanged: (_) => setState(() {}),
    validator:
        validator ??
        (value) {
          final number = double.tryParse(value ?? '');
          return number == null || number < 0
              ? localizedUiText(context, 'Invalid')
              : null;
        },
  );
}

class _TailorPickerDialog extends StatefulWidget {
  const _TailorPickerDialog({required this.tailors});

  final List<Map<String, dynamic>> tailors;

  @override
  State<_TailorPickerDialog> createState() => _TailorPickerDialogState();
}

class _TailorPickerDialogState extends State<_TailorPickerDialog> {
  int? _selected;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Assign selected items')),
    content: DropdownButtonFormField<int>(
      initialValue: _selected,
      decoration: InputDecoration(
        labelText: localizedUiText(context, 'Tailor'),
      ),
      items: [
        for (final tailor in widget.tailors)
          DropdownMenuItem(
            value: _int(tailor['employeeID']),
            child: Text(
              _tailorName(tailor) ?? localizedUiText(context, 'Tailor'),
            ),
          ),
      ],
      onChanged: (value) => setState(() => _selected = value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
        child: Text(localizedUiText(context, 'Assign')),
      ),
    ],
  );
}

class _MeasurementAlterationDialog extends StatefulWidget {
  const _MeasurementAlterationDialog({required this.measurements});

  final List<Map<String, dynamic>> measurements;

  @override
  State<_MeasurementAlterationDialog> createState() =>
      _MeasurementAlterationDialogState();
}

class _MeasurementAlterationDialogState
    extends State<_MeasurementAlterationDialog> {
  late final List<_AlterationRow> _rows = [
    for (final measurement in widget.measurements) _AlterationRow(measurement),
  ];

  @override
  void dispose() {
    for (final row in _rows) {
      row.variation.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, [
      for (final row in _rows)
        <String, Object?>{
          'orderMeasurementId': _int(row.measurement['orderMeasurementId']),
          'orderDetailId': _int(row.measurement['orderDetailId']),
          'measurementMapId': _int(
            row.measurement['measurementMapId'] ?? row.measurement['mapID'],
          ),
          'measurementValue': _number(row.measurement['measurementValue']),
          'measurementVariation': _number(row.variation.text),
          'finalMeasurementValue':
              _number(row.measurement['measurementValue']) +
              _number(row.variation.text),
        },
    ]);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Alteration measurements')),
    content: SizedBox(
      width: 560,
      child: _rows.isEmpty
          ? Text(
              localizedUiText(
                context,
                'No saved measurements are available for this item.',
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final row in _rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.measurement['measurementName']?.toString() ??
                                localizedUiText(context, 'Measurement'),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${localizedUiText(context, 'Base')} '
                            '${row.measurement['measurementValue'] ?? 0}',
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            selectAllOnFocus: true,
                            controller: row.variation,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: localizedUiText(context, 'Alteration'),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (_number(row.measurement['measurementValue']) +
                                  _number(row.variation.text))
                              .toStringAsFixed(1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _rows.isEmpty ? null : _save,
        child: Text(localizedUiText(context, 'Save alteration')),
      ),
    ],
  );
}

class _AlterationRow {
  _AlterationRow(this.measurement)
    : variation = TextEditingController(
        text: '${measurement['measurementVariation'] ?? 0}',
      );

  final Map<String, dynamic> measurement;
  final TextEditingController variation;
}

class _InvoiceDialog extends StatefulWidget {
  const _InvoiceDialog({
    required this.order,
    required this.items,
    required this.financialYearId,
  });

  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;
  final int financialYearId;

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  final _discountAmount = TextEditingController(text: '0');
  final _discountPercent = TextEditingController(text: '0');
  final _advance = TextEditingController(text: '0');
  late final double _subtotal = widget.items.fold<double>(
    0,
    (sum, item) =>
        sum + _number(item['netAmount'] ?? item['amount'] ?? item['rate']),
  );

  @override
  void dispose() {
    _discountAmount.dispose();
    _discountPercent.dispose();
    _advance.dispose();
    super.dispose();
  }

  void _save() {
    final percent = _number(_discountPercent.text).clamp(0, 100);
    final discount = _number(_discountAmount.text).clamp(0, _subtotal);
    final correctedPercent = _subtotal == 0 ? 0 : discount / _subtotal * 100;
    final paymentAmount = _number(_advance.text);
    final paymentDate = DateTime.now().toIso8601String();
    Navigator.pop(context, <String, Object?>{
      'orderDetailIds': [
        for (final item in widget.items) _int(item['detailID']),
      ],
      'invoiceDate': paymentDate,
      'taxPercent': 0,
      'paymentDetails': paymentAmount > 0
          ? [
              {
                'payments': [
                  {
                    'paymentDetailID': 0,
                    'menuId': 0,
                    'paymentDate': paymentDate,
                    'paymentMode': 'CASH',
                    'totalAmount': paymentAmount,
                    'cardType': '',
                    'cardDigits': '',
                    'cardNumber': '',
                    'nameOnCard': '',
                    'cardAmount': 0,
                    'cardSlipNo': '',
                    'pgType': '',
                    'upiid': '',
                    'upiMobileNo': '',
                    'nameOnUPI': '',
                    'onlineAmount': 0,
                    'transactionNo': '',
                    'remarks': '',
                    'receiptNo': '',
                  },
                ],
                'bookingAmount': paymentAmount,
                'securityDeposit': 0,
                'depositPaid': false,
                'depositMode': '',
              },
            ]
          : <Object?>[],
      'finYearID': widget.financialYearId,
      'remarks': '',
      'invoiceDiscountAmount': discount,
      'invoiceDiscountPercent': correctedPercent > 0
          ? correctedPercent
          : percent,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${localizedUiText(context, 'Invoice')} · '
      '${widget.order['orderNo'] ?? ''}',
    ),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${localizedUiText(context, 'Customer')}: '
            '${widget.order['customerName'] ?? ''}',
          ),
          for (final item in widget.items)
            ListTile(
              dense: true,
              title: Text(
                item['itemName']?.toString() ??
                    localizedUiText(context, 'Item'),
              ),
              subtitle: Text(
                '${item['sizeName'] ?? ''} · ${item['colorName'] ?? ''}',
              ),
              trailing: Text(
                '₹${item['netAmount'] ?? item['amount'] ?? item['rate'] ?? 0}',
              ),
            ),
          Text(
            '${localizedUiText(context, 'Subtotal')}: '
            '₹${_subtotal.toStringAsFixed(2)}',
          ),
          TextField(
            selectAllOnFocus: true,
            controller: _discountAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Invoice discount amount'),
            ),
          ),
          TextField(
            selectAllOnFocus: true,
            controller: _discountPercent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Invoice discount %'),
            ),
          ),
          TextField(
            selectAllOnFocus: true,
            controller: _advance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Payment received'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(localizedUiText(context, 'Generate invoice')),
      ),
    ],
  );
}

class _FutureList extends StatelessWidget {
  const _FutureList({
    required this.future,
    required this.empty,
    required this.itemBuilder,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String empty;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${localizedUiText(context, 'Could not load data')}: '
                  '${snapshot.error}',
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: StitchLoader(size: 64, showMonogram: false),
            );
          }
          final entries = snapshot.data ?? const <Map<String, dynamic>>[];
          if (entries.isEmpty) return Center(child: Text(empty));
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) =>
                itemBuilder(context, entries[index]),
          );
        },
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Widget _formSection(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required List<Widget> children,
  Widget? trailing,
}) => Card(
  margin: const EdgeInsets.only(bottom: 14),
  elevation: 0,
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: const BorderSide(color: Color(0xFFE3E8F0)),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1688E8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    ),
  ),
);

class _StitchingRow {
  int? itemId;
  int? sizeId;
  int? colorId;
  int? processId;
  final quantity = TextEditingController(text: '1');
  final meters = TextEditingController(text: '0');
  final rate = TextEditingController(text: '0');
  final discount = TextEditingController(text: '0');
  final remarks = TextEditingController();
  List<Map<String, Object?>> measurements = [];
  final List<Map<String, Object?>> photos = [];

  int get qty => int.tryParse(quantity.text) ?? 0;
  double get qtyInMeters => _number(meters.text);
  double get discountPercent => _number(discount.text);
  double get grossAmount => qty * _number(rate.text);
  double get discountAmount => grossAmount * discountPercent / 100;
  double get amount => grossAmount - discountAmount;

  void dispose() {
    quantity.dispose();
    meters.dispose();
    rate.dispose();
    discount.dispose();
    remarks.dispose();
  }
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _number(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

Map<String, dynamic> _stringMap(Map value) => {
  for (final entry in value.entries) entry.key.toString(): entry.value,
};

String? _tailorName(Map<String, dynamic> tailor) =>
    tailor['fullName']?.toString() ?? tailor['employeeName']?.toString();

String _formatDate(DateTime value) => formatDisplayDate(value);
