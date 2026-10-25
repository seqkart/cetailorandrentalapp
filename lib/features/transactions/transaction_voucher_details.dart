import 'package:flutter/material.dart';

import '../../core/app_date_format.dart';
import '../../l10n/app_strings.dart';

const _ink = Color(0xFF172B4D);
const _muted = Color(0xFF718198);
const _line = Color(0xFFE4EAF2);
const _canvas = Color(0xFFF4F7FB);
const _blue = Color(0xFF2864C5);

Future<void> showTransactionVoucherDetails(
  BuildContext context, {
  required String title,
  required Map<String, dynamic> voucher,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _VoucherDetailsSheet(title: title, voucher: voucher),
  );
}

class _VoucherDetailsSheet extends StatelessWidget {
  const _VoucherDetailsSheet({required this.title, required this.voucher});

  final String title;
  final Map<String, dynamic> voucher;

  @override
  Widget build(BuildContext context) {
    final entries = voucher.entries.toList(growable: false);
    final number = _findValue({
      'orderno',
      'invoiceno',
      'bookingno',
      'rentno',
      'returnno',
      'voucherno',
      'transactionno',
      'deliveryno',
    });
    final status = _findValue({'status', 'orderstatus', 'paymentstatus'});
    final customer = _findValue({
      'customername',
      'customerfullname',
      'fullname',
      'name',
    });
    final mobile = _findValue({
      'customermobile',
      'mobileno',
      'mobile',
      'phonenumber',
    });
    final dateEntries = entries
        .where((entry) {
          final key = _normalize(entry.key);
          return _isDateKey(key) && _hasValue(entry.value);
        })
        .toList(growable: false);
    final itemEntry = _findItemList();
    final items = itemEntry == null
        ? const <Map>[]
        : _mapItems(itemEntry.value);
    final moneyEntries = entries
        .where((entry) {
          final key = _normalize(entry.key);
          return _moneyKeys.contains(key) && _hasValue(entry.value);
        })
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: _blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      localizedUiText(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: _ink, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: localizedUiText(context, 'Close voucher details'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _VoucherHeader(
                    number: number,
                    status: status,
                    dates: dateEntries,
                  ),
                  if (_hasValue(customer) || _hasValue(mobile)) ...[
                    const _SectionTitle(
                      title: 'CUSTOMER',
                      icon: Icons.person_outline_rounded,
                    ),
                    _CustomerCard(name: customer, mobile: mobile),
                  ],
                  if (items.isNotEmpty) ...[
                    _SectionTitle(
                      title: 'ITEMS',
                      icon: Icons.inventory_2_outlined,
                      trailing: '${items.length}',
                    ),
                    _ItemList(items: items),
                  ],
                  if (moneyEntries.isNotEmpty) ...[
                    const _SectionTitle(
                      title: 'PAYMENT SUMMARY',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _PaymentSummary(entries: moneyEntries),
                  ],
                  if (items.isEmpty && moneyEntries.isEmpty)
                    const _EmptyVoucher(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Object? _findValue(Set<String> keys) {
    for (final entry in voucher.entries) {
      if (keys.contains(_normalize(entry.key)) && _hasValue(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  MapEntry<String, dynamic>? _findItemList() {
    for (final entry in voucher.entries) {
      final key = _normalize(entry.key);
      if (entry.value is Iterable &&
          entry.value is! String &&
          (key.contains('detail') ||
              key.contains('item') ||
              key == 'products')) {
        return entry;
      }
    }
    return null;
  }
}

class _VoucherHeader extends StatelessWidget {
  const _VoucherHeader({
    required this.number,
    required this.status,
    required this.dates,
  });

  final Object? number;
  final Object? status;
  final List<MapEntry<String, dynamic>> dates;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF244D87), Color(0xFF347CC2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A244D87),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                localizedUiText(context, 'VOUCHER'),
                style: const TextStyle(
                  color: Color(0xFFD8E9FF),
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_hasValue(status))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                ),
                child: Text(
                  _display(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _hasValue(number)
              ? _display(number)
              : localizedUiText(context, 'Transaction details'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (dates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final entry in dates.take(2))
                _HeaderDate(
                  label: localizedUiText(context, _humanize(entry.key)),
                  value: formatDateValue(entry.value) ?? _display(entry.value),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _HeaderDate extends StatelessWidget {
  const _HeaderDate({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.event_outlined, size: 15, color: Color(0xFFD8E9FF)),
      const SizedBox(width: 5),
      Text(
        '$label  $value',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon, this.trailing});

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 9),
    child: Row(
      children: [
        Icon(icon, size: 17, color: _blue),
        const SizedBox(width: 7),
        Text(
          localizedUiText(context, title),
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.name, required this.mobile});

  final Object? name;
  final Object? mobile;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFEAF1FB),
          child: Text(
            _hasValue(name) ? _display(name)[0].toUpperCase() : 'C',
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasValue(name)
                    ? _display(name)
                    : localizedUiText(context, 'Customer'),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (_hasValue(mobile)) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: _muted),
                    const SizedBox(width: 5),
                    Text(
                      _display(mobile),
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<Map> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [for (final item in items) _VoucherItemCard(item: item)],
  );
}

class _VoucherItemCard extends StatelessWidget {
  const _VoucherItemCard({required this.item});

  final Map item;

  @override
  Widget build(BuildContext context) {
    final name = _valueFor(item, {
      'itemname',
      'productname',
      'description',
      'name',
    });
    final amount = _valueFor(item, {
      'netamount',
      'totalamount',
      'rentamount',
      'amount',
      'rate',
    });
    final subtitleParts = [
      _valueFor(item, {'sizename', 'size'}),
      _valueFor(item, {'colorname', 'colourname', 'color'}),
      _valueFor(item, {'processname', 'process'}),
      _valueFor(item, {'quantity', 'qty'}),
    ].where(_hasValue).map(_display).toList(growable: false);
    final measurements = _findList(item, {'ordermeasurements', 'measurements'});
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FB),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.checkroom_outlined,
                    size: 19,
                    color: _blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasValue(name)
                            ? _display(name)
                            : localizedUiText(context, 'Item'),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitleParts.join('  •  '),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_hasValue(amount))
                  Text(
                    _money(amount),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          if (measurements != null && _mapItems(measurements.value).isNotEmpty)
            _MeasurementDetails(rows: _mapItems(measurements.value)),
        ],
      ),
    );
  }
}

class _MeasurementDetails extends StatelessWidget {
  const _MeasurementDetails({required this.rows});

  final List<Map> rows;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      visualDensity: VisualDensity.compact,
      title: Text(
        localizedUiText(context, 'Measurements (${rows.length})'),
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _display(
                      _valueFor(row, {'measurementname', 'name'}) ??
                          'Measurement',
                    ),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
                Text(
                  _display(
                    _valueFor(row, {'measurementvalue', 'value'}) ?? '—',
                  ),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.entries});

  final List<MapEntry<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final total = _selectMoney(entries, {
      'grandtotal',
      'totalamount',
      'netamount',
      'nettotal',
      'invoiceamount',
      'total',
      'amount',
    });
    final remaining = entries
        .where((entry) => _isBalanceKey(_normalize(entry.key)))
        .toList(growable: false);
    final primary = [
      ?total,
      ...entries.where(
        (entry) =>
            _isPaymentKey(_normalize(entry.key)) &&
            (total == null || entry.key != total.key),
      ),
      ...remaining,
    ];
    final shown = <String>{};

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 7),
      child: Column(
        children: [
          for (final entry in primary)
            if (shown.add(_normalize(entry.key)))
              _MoneyLine(
                label: localizedUiText(context, _humanize(entry.key)),
                value: _money(entry.value),
                emphasis:
                    _isBalanceKey(_normalize(entry.key)) ||
                    _normalize(entry.key) == _normalize(total?.key ?? ''),
              ),
        ],
      ),
    );
  }

  MapEntry<String, dynamic>? _selectMoney(
    List<MapEntry<String, dynamic>> values,
    Set<String> preferred,
  ) {
    for (final entry in values) {
      if (preferred.contains(_normalize(entry.key))) return entry;
    }
    return null;
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasis ? _ink : _muted,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w500,
              fontSize: emphasis ? 14 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasis ? _blue : _ink,
            fontWeight: FontWeight.w800,
            fontSize: emphasis ? 15 : 13,
          ),
        ),
      ],
    ),
  );
}

class _EmptyVoucher extends StatelessWidget {
  const _EmptyVoucher();

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          localizedUiText(context, 'No additional voucher details available.'),
          style: const TextStyle(color: _muted),
        ),
      ),
    ),
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080E2A50),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

const _moneyKeys = {
  'amount',
  'advance',
  'advancepaid',
  'balance',
  'balanceamount',
  'balancedue',
  'discount',
  'discountamount',
  'grandtotal',
  'invoiceamount',
  'netamount',
  'nettotal',
  'paidamount',
  'paymentamount',
  'receivedamount',
  'rentamount',
  'total',
  'totalamount',
};

String _normalize(Object? value) =>
    value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';

bool _hasValue(Object? value) =>
    value != null && value.toString().trim().isNotEmpty;

bool _isDateKey(String key) =>
    key.contains('date') || key.endsWith('on') || key.endsWith('at');

bool _isBalanceKey(String key) =>
    key.contains('balance') || key.contains('due');

bool _isPaymentKey(String key) =>
    key.contains('advance') ||
    key.contains('paid') ||
    key.contains('payment') ||
    key.contains('received') ||
    key.contains('discount');

String _humanize(Object? value) {
  final text = value?.toString() ?? '';
  final spaced = text
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return 'Detail';
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _display(Object? value) {
  if (value == null) return '—';
  final text = value.toString().trim();
  if (text.isEmpty) return '—';
  if (text.length > 256 &&
      (text.startsWith('data:') || text.startsWith('/9j/'))) {
    return 'Attachment available';
  }
  return text;
}

String _money(Object? value) {
  final raw = value?.toString().replaceAll(',', '').trim() ?? '';
  final amount = num.tryParse(raw);
  if (amount == null) return '₹$raw';
  return '₹${amount.toStringAsFixed(2)}';
}

Object? _valueFor(Map map, Set<String> keys) {
  for (final entry in map.entries) {
    if (keys.contains(_normalize(entry.key)) && _hasValue(entry.value)) {
      return entry.value;
    }
  }
  return null;
}

MapEntry<dynamic, dynamic>? _findList(Map map, Set<String> keys) {
  for (final entry in map.entries) {
    if (keys.contains(_normalize(entry.key)) && entry.value is Iterable) {
      return MapEntry(entry.key, entry.value);
    }
  }
  return null;
}

List<Map> _mapItems(Object? values) {
  if (values is! Iterable || values is String) return const [];
  return values.whereType<Map>().toList(growable: false);
}
