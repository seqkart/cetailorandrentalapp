import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_date_format.dart';
import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/stitch_loader.dart';
import '../transactions/transaction_voucher_details.dart';
import 'rental_repository.dart';

class RentalWorkflowScreen extends StatefulWidget {
  const RentalWorkflowScreen({
    required this.session,
    required this.repository,
    this.initialTab = 0,
    this.showAppBar = true,
    this.onOpenAssistant,
    this.onOpenMenu,
    super.key,
  });

  final AuthSession session;
  final RentalRepository repository;
  final int initialTab;
  final bool showAppBar;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onOpenMenu;

  @override
  State<RentalWorkflowScreen> createState() => _RentalWorkflowScreenState();
}

class _RentalWorkflowScreenState extends State<RentalWorkflowScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _fromDate = DateUtils.dateOnly(DateTime.now());
  DateTime _toDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  DateTime _returnDate = DateUtils.dateOnly(DateTime.now());
  Future<List<Map<String, dynamic>>>? _catalogFuture;
  Future<List<Map<String, dynamic>>>? _bookingsFuture;
  final List<Map<String, dynamic>> _cart = [];
  DateTime? _cartFromDate;
  DateTime? _cartToDate;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _series = [];
  List<Map<String, dynamic>> _measurements = [];
  List<Map<String, dynamic>> _tailors = [];
  List<Map<String, dynamic>> _sizes = [];
  List<Map<String, dynamic>> _colors = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _itemGroups = [];
  List<Map<String, dynamic>> _itemUnits = [];
  final _searchController = TextEditingController();
  final _mobileController = TextEditingController();
  final _remarksController = TextEditingController();
  final _depositController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _eventDateController = TextEditingController();
  final _returnRemarksController = TextEditingController();
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedRent;
  List<Map<String, dynamic>> _openRents = [];
  bool _alterationRequired = false;
  bool _depositPaid = false;
  bool _busy = false;
  String _paymentMode = 'Cash';
  String _depositPaymentMode = 'Cash';
  String _returnPaymentMode = 'Cash';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      vsync: this,
    );
    _loadSupportingData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _mobileController.dispose();
    _remarksController.dispose();
    _depositController.dispose();
    _paidController.dispose();
    _eventDateController.dispose();
    _returnRemarksController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportingData() async {
    await Future.wait([
      _loadSupportingPart(
        'customers',
        widget.repository.loadCustomers,
        (data) => _customers = data,
      ),
      _loadSupportingPart(
        'rental voucher series',
        widget.repository.loadVoucherSeries,
        (data) => _series = data,
      ),
      _loadSupportingPart(
        'alteration measurements',
        widget.repository.loadMeasurements,
        (data) => _measurements = data,
      ),
      _loadSupportingPart(
        'tailors',
        widget.repository.loadTailors,
        (data) => _tailors = data,
      ),
      _loadSupportingPart(
        'catalogue sizes',
        widget.repository.loadSizes,
        (data) => _sizes = data,
      ),
      _loadSupportingPart(
        'catalogue colours',
        widget.repository.loadColors,
        (data) => _colors = data,
      ),
      _loadSupportingPart(
        'Item Master items',
        widget.repository.loadItems,
        (data) => _items = data,
      ),
      _loadSupportingPart(
        'Item Master groups',
        widget.repository.loadItemGroups,
        (data) => _itemGroups = data,
      ),
      _loadSupportingPart(
        'Item Master units',
        widget.repository.loadItemUnits,
        (data) => _itemUnits = data,
      ),
    ]);
  }

  Future<void> _loadSupportingPart<T>(
    String label,
    Future<T> Function(AuthSession) load,
    void Function(T) update,
  ) async {
    try {
      final data = await load(widget.session);
      if (mounted) setState(() => update(data));
    } catch (error) {
      if (mounted) {
        _message(
          '${localizedUiText(context, 'Could not load')} ${localizedUiText(context, label)}: $error',
          localize: false,
        );
      }
    }
  }

  Future<void> _loadCatalog() async {
    if (_toDate.isBefore(_fromDate)) {
      _message('The return date must be on or after the rental start date.');
      return;
    }
    final cartRangeChanged =
        _cart.isNotEmpty &&
        (!DateUtils.isSameDay(_cartFromDate, _fromDate) ||
            !DateUtils.isSameDay(_cartToDate, _toDate));
    if (cartRangeChanged) {
      setState(() {
        _cart.clear();
        _depositController.text = '0';
        _cartFromDate = null;
        _cartToDate = null;
      });
      _message(
        'Cart cleared because rental dates changed. Select items again.',
      );
    }
    setState(() {
      _catalogFuture = widget.repository.loadCatalog(
        widget.session,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    });
  }

  Future<void> _createCatalogItem() async {
    final form = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _NewRentCatalogDialog(
        items: _items,
        groups: _itemGroups,
        units: _itemUnits,
        sizes: _sizes,
        colors: _colors,
        onCreateItem: _createItemMasterEntry,
        onCreateGroup: _createItemGroupEntry,
        onCreateSize: _createSizeMasterEntry,
        onCreateColor: _createColorMasterEntry,
      ),
    );
    if (form == null || !mounted) return;

    await _runRequest(() async {
      final item = form['item']! as Map<String, dynamic>;
      final itemId = _int(item['itemId'] ?? item['itemID']);
      final itemName = item['itemName']?.toString() ?? 'Rental item';
      if (itemId <= 0) {
        throw FormatException(
          localizedUiText(
            context,
            'Select or add an item in Item Master before creating the catalogue record.',
          ),
        );
      }

      final variants = (form['variants'] as List)
          .whereType<Map<String, Object?>>()
          .map(
            (variant) => <String, Object?>{
              'variantID': 0,
              'sizeID': variant['sizeID'],
              'colorID': variant['colorID'],
              'totalQty': variant['totalQty'],
              'rentRate': variant['rentRate'],
              'isActive': true,
              'photos': variant['photos'] as List<Object?>? ?? <Object?>[],
            },
          )
          .toList();
      await widget.repository.saveCatalog(widget.session, {
        'catalogID': 0,
        'itemId': itemId,
        'description': form['description'],
        'baseRentRate': 0,
        'securityDeposit': 0,
        'isActive': true,
        'variants': variants,
      });
      if (!mounted) return;
      setState(() {
        _catalogFuture = widget.repository.loadCatalog(
          widget.session,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      });
      _message(
        '$itemName ${localizedUiText(context, 'added to rental catalogue.')}',
        localize: false,
      );
    });
  }

  Future<Map<String, dynamic>?> _createItemMasterEntry(
    Map<String, Object?> payload,
  ) async {
    try {
      final response = await widget.repository.saveItem(
        widget.session,
        payload,
      );
      final name = payload['itemName']?.toString().trim() ?? '';
      final loadedItems = await widget.repository.loadItems(widget.session);
      final responseData = response['data'];
      final savedId = _int(
        response['itemId'] ??
            response['itemID'] ??
            (responseData is Map
                ? responseData['itemId'] ?? responseData['itemID']
                : null),
      );
      final item = loadedItems.cast<Map<String, dynamic>?>().firstWhere(
        (candidate) =>
            candidate?['itemName']?.toString().trim().toLowerCase() ==
            name.toLowerCase(),
        orElse: () => null,
      );
      final result =
          item ??
          (savedId > 0
              ? <String, dynamic>{'itemId': savedId, 'itemName': name}
              : null);
      if (result == null) {
        if (!mounted) return null;
        throw FormatException(
          localizedUiText(
            context,
            'Item was saved, but it could not be found in Item Master. Refresh the list and try again.',
          ),
        );
      }
      if (mounted) {
        setState(() {
          _items = List.of(loadedItems)
            ..removeWhere(
              (entry) =>
                  _int(entry['itemId'] ?? entry['itemID']) ==
                  _int(result['itemId'] ?? result['itemID']),
            )
            ..add(result);
        });
      }
      return result;
    } catch (error) {
      if (mounted) {
        _message(
          '${localizedUiText(context, 'Could not add item to Item Master')}: $error',
          localize: false,
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _createItemGroupEntry(String name) async {
    try {
      final response = await widget.repository.saveItemGroup(
        widget.session,
        name,
      );
      final loadedGroups = await widget.repository.loadItemGroups(
        widget.session,
      );
      final responseData = response['data'];
      final savedId = _int(
        response['groupID'] ??
            response['groupId'] ??
            (responseData is Map
                ? responseData['groupID'] ?? responseData['groupId']
                : null),
      );
      final group = loadedGroups.cast<Map<String, dynamic>?>().firstWhere(
        (candidate) =>
            candidate?['groupName']?.toString().trim().toLowerCase() ==
            name.toLowerCase(),
        orElse: () => null,
      );
      final result =
          group ??
          (savedId > 0
              ? <String, dynamic>{
                  'groupID': savedId,
                  'groupName': name,
                  'isActive': true,
                }
              : null);
      if (result == null) {
        if (!mounted) return null;
        throw FormatException(
          localizedUiText(
            context,
            'Group was saved, but it could not be found in Item Master groups. Refresh the list and try again.',
          ),
        );
      }
      if (mounted) {
        setState(() {
          _itemGroups = List.of(loadedGroups)
            ..removeWhere(
              (entry) =>
                  _int(entry['groupID'] ?? entry['groupId']) ==
                  _int(result['groupID'] ?? result['groupId']),
            )
            ..add(result);
        });
      }
      return result;
    } catch (error) {
      if (mounted) {
        _message(
          '${localizedUiText(context, 'Could not add Item Master group')}: $error',
          localize: false,
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _createSizeMasterEntry(String name) async {
    try {
      var loadedSizes = await widget.repository.loadSizes(widget.session);
      var size = _findNamedMaster(loadedSizes, 'sizeName', name);
      if (size != null) {
        if (mounted) setState(() => _sizes = loadedSizes);
        return size;
      }

      try {
        await widget.repository.saveSize(widget.session, name);
      } catch (_) {
        loadedSizes = await widget.repository.loadSizes(widget.session);
        size = _findNamedMaster(loadedSizes, 'sizeName', name);
        if (size == null) rethrow;
        if (mounted) setState(() => _sizes = loadedSizes);
        return size;
      }

      loadedSizes = await widget.repository.loadSizes(widget.session);
      size = _findNamedMaster(loadedSizes, 'sizeName', name);
      if (size == null) {
        if (!mounted) return null;
        throw FormatException(
          localizedUiText(
            context,
            'Size was saved, but it was not returned from the size master. Refresh and try again.',
          ),
        );
      }
      if (mounted) setState(() => _sizes = loadedSizes);
      return size;
    } catch (error) {
      if (mounted) {
        _message(
          '${localizedUiText(context, 'Could not add size')}: $error',
          localize: false,
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _createColorMasterEntry(String name) async {
    try {
      var loadedColors = await widget.repository.loadColors(widget.session);
      var color = _findNamedMaster(loadedColors, 'colorName', name);
      if (color != null) {
        if (mounted) setState(() => _colors = loadedColors);
        return color;
      }

      try {
        await widget.repository.saveColor(widget.session, name);
      } catch (_) {
        loadedColors = await widget.repository.loadColors(widget.session);
        color = _findNamedMaster(loadedColors, 'colorName', name);
        if (color == null) rethrow;
        if (mounted) setState(() => _colors = loadedColors);
        return color;
      }

      loadedColors = await widget.repository.loadColors(widget.session);
      color = _findNamedMaster(loadedColors, 'colorName', name);
      if (color == null) {
        if (!mounted) return null;
        throw FormatException(
          localizedUiText(
            context,
            'Colour was saved, but it was not returned from the colour master. Refresh and try again.',
          ),
        );
      }
      if (mounted) setState(() => _colors = loadedColors);
      return color;
    } catch (error) {
      if (mounted) {
        _message(
          '${localizedUiText(context, 'Could not add colour')}: $error',
          localize: false,
        );
      }
      return null;
    }
  }

  Map<String, dynamic>? _findNamedMaster(
    List<Map<String, dynamic>> values,
    String nameKey,
    String name,
  ) {
    final normalizedName = name.trim().toLowerCase();
    for (final value in values) {
      if (value[nameKey]?.toString().trim().toLowerCase() == normalizedName) {
        return value;
      }
    }
    return null;
  }

  Future<void> _loadBookings() async {
    setState(() {
      _bookingsFuture = widget.repository.loadBookings(widget.session);
    });
  }

  Future<void> _pickRentalDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _fromDate : _toDate,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _addVariant(
    Map<String, dynamic> item,
    Map<String, dynamic> variant,
  ) async {
    final available = _int(variant['availableQty']);
    if (available <= 0) {
      _message('This size and colour are not available for those dates.');
      return;
    }
    final catalogId = _int(item['catalogID']);
    final variantId = _int(variant['variantID']);
    final existingIndex = _cart.indexWhere(
      (row) =>
          _int(row['catalogID']) == catalogId &&
          _int(row['variantID']) == variantId,
    );
    final photos = item['photos'] is List
        ? (item['photos'] as List).whereType<Map>().toList()
        : const <Map>[];
    final photoPath = photos.isEmpty
        ? ''
        : photos.first['photoPath']?.toString() ?? '';
    setState(() {
      if (_cart.isEmpty) {
        _cartFromDate = _fromDate;
        _cartToDate = _toDate;
      }
      if (existingIndex >= 0) {
        final row = _cart[existingIndex];
        if (_int(row['qty']) < available) {
          row['qty'] = _int(row['qty']) + 1;
        }
      } else {
        _cart.add({
          'catalogID': catalogId,
          'variantID': variantId,
          'itemId': _int(item['itemId']),
          'itemCode': item['itemCode']?.toString() ?? '',
          'itemName': item['itemName']?.toString() ?? 'Rental item',
          'groupName': item['groupName']?.toString() ?? '',
          'photoPath': photoPath,
          'sizeID': _int(variant['sizeID']),
          'sizeName': variant['sizeName']?.toString() ?? '',
          'colorID': _int(variant['colorID']),
          'colorName': variant['colorName']?.toString() ?? '',
          'rentRate': _num(variant['rentRate'] ?? item['baseRentRate']),
          'qty': 1,
          'maxQty': available,
          'securityDeposit': _num(item['securityDeposit']),
          'measurements': <Map<String, Object?>>[],
          'assignedToTailorId': null,
          'tailorName': '',
        });
      }
      _depositController.text = _cartSecurityDeposit.toStringAsFixed(2);
    });
  }

  Map<String, dynamic>? _cartItemFor(
    Map<String, dynamic> item,
    Map<String, dynamic> variant,
  ) {
    final catalogId = _int(item['catalogID']);
    final variantId = _int(variant['variantID']);
    for (final row in _cart) {
      if (_int(row['catalogID']) == catalogId &&
          _int(row['variantID']) == variantId) {
        return row;
      }
    }
    return null;
  }

  void _changeCartQuantity(Map<String, dynamic> row, int change) {
    setState(() {
      final nextQty = _int(row['qty']) + change;
      if (nextQty <= 0) {
        _cart.remove(row);
        if (_cart.isEmpty) {
          _cartFromDate = null;
          _cartToDate = null;
        }
      } else if (nextQty <= _int(row['maxQty'])) {
        row['qty'] = nextQty;
      }
      _depositController.text = _cartSecurityDeposit.toStringAsFixed(2);
    });
  }

  Future<void> _chooseCustomer() async {
    var query = '';
    final customer = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          final normalizedQuery = query.trim().toLowerCase();
          final filteredCustomers = _customers.where((customer) {
            final name =
                (customer['fullName'] ?? customer['customerName'] ?? '')
                    .toString()
                    .toLowerCase();
            final mobile = (customer['mobileNo'] ?? '').toString();
            return normalizedQuery.isEmpty ||
                name.contains(normalizedQuery) ||
                mobile.contains(normalizedQuery);
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedUiText(context, 'Choose customer'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      selectAllOnFocus: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: localizedUiText(
                          context,
                          'Search by name or mobile',
                        ),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        updateSheet(() => query = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (RegExp(r'^\d{10}$').hasMatch(query.trim()) &&
                        !filteredCustomers.any(
                          (entry) =>
                              entry['mobileNo']?.toString() == query.trim(),
                        ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final created = await _createCustomer(
                                query.trim(),
                              );
                              if (created != null && sheetContext.mounted) {
                                Navigator.pop(sheetContext, created);
                              }
                            },
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text(
                              '${localizedUiText(context, 'Add customer •')} ${query.trim()}',
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? Center(
                              child: Text(
                                localizedUiText(
                                  context,
                                  'No matching customers found.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final entry = filteredCustomers[index];
                                final name =
                                    (entry['fullName'] ??
                                            entry['customerName'] ??
                                            'Customer')
                                        .toString();
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      name.characters.first.toUpperCase(),
                                    ),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(
                                    entry['mobileNo']?.toString() ?? '',
                                  ),
                                  onTap: () =>
                                      Navigator.pop(sheetContext, entry),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (customer != null && mounted) {
      setState(() => _selectedCustomer = customer);
    }
  }

  Future<Map<String, dynamic>?> _createCustomer(String mobile) async {
    var fullName = '';
    var email = '';
    var address = '';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizedUiText(dialogContext, 'Add new customer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                selectAllOnFocus: true,
                initialValue: mobile,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: localizedUiText(dialogContext, 'Mobile number'),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                selectAllOnFocus: true,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: localizedUiText(dialogContext, 'Full name *'),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (value) => fullName = value,
              ),
              const SizedBox(height: 10),
              TextField(
                selectAllOnFocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: localizedUiText(dialogContext, 'Email'),
                ),
                onChanged: (value) => email = value,
              ),
              const SizedBox(height: 10),
              TextField(
                selectAllOnFocus: true,
                decoration: InputDecoration(
                  labelText: localizedUiText(dialogContext, 'Address'),
                ),
                onChanged: (value) => address = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localizedUiText(dialogContext, 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final name = fullName.trim();
              if (name.isEmpty) {
                _message('Enter the customer name to continue.');
                return;
              }
              Navigator.pop(dialogContext, {
                'fullName': name,
                'email': email.trim(),
                'address1': address.trim(),
              });
            },
            child: Text(localizedUiText(dialogContext, 'Save customer')),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return null;

    Map<String, dynamic>? savedCustomer;
    await _runRequest(() async {
      final response = await widget.repository.saveCustomer(widget.session, {
        'customerID': 0,
        'fullName': result['fullName'],
        'mobileNo': mobile,
        'email': result['email'] ?? '',
        'stateId': 28,
        'address1': result['address1'] ?? '',
        'address2': '',
        'cityID': 2,
        'isActive': true,
      });
      final customers = await widget.repository.loadCustomers(widget.session);
      if (!mounted) return;
      setState(() => _customers = customers);
      final responseData = response['data'];
      final savedId =
          response['customerID'] ??
          (responseData is Map ? responseData['customerID'] : null);
      savedCustomer = customers.cast<Map<String, dynamic>?>().firstWhere(
        (customer) =>
            customer?['mobileNo']?.toString() == mobile &&
            (savedId == null || _int(customer?['customerID']) == _int(savedId)),
        orElse: () => null,
      );
      if (savedCustomer == null) {
        _message(
          'Customer saved, but the customer list did not return the new record. Refresh the list and select it before booking.',
        );
        return;
      }
      final responseMessage =
          response['message']?.toString() ?? response['errorDesc']?.toString();
      _message(
        responseMessage ?? 'Customer saved.',
        localize: responseMessage == null,
      );
    });
    return savedCustomer;
  }

  Future<void> _editItemAlteration(Map<String, dynamic> item) async {
    var query = '';
    final picked = (item['measurements'] as List? ?? const [])
        .whereType<Map>()
        .map(_stringMap)
        .toList();
    Map<String, dynamic>? selectedTailor = _tailors
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (tailor) =>
              _int(tailor?['employeeID']) == _int(item['assignedToTailorId']),
          orElse: () => null,
        );

    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          final matches = _measurements
              .where((measurement) {
                final name = (measurement['measurementName'] ?? '')
                    .toString()
                    .toLowerCase();
                final code = (measurement['measurementCode'] ?? '')
                    .toString()
                    .toLowerCase();
                return query.trim().isNotEmpty &&
                    (name.contains(query.trim().toLowerCase()) ||
                        code.contains(query.trim().toLowerCase())) &&
                    !picked.any(
                      (entry) =>
                          _int(entry['measurementMapId']) ==
                          _int(measurement['measurementID']),
                    );
              })
              .take(8)
              .toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${localizedUiText(context, 'Alteration')} • ${item['itemName']}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: selectedTailor,
                      decoration: InputDecoration(
                        labelText: localizedUiText(context, 'Assign tailor *'),
                        prefixIcon: Icon(Icons.content_cut),
                      ),
                      items: [
                        for (final tailor in _tailors)
                          DropdownMenuItem(
                            value: tailor,
                            child: Text(
                              tailor['fullName']?.toString() ??
                                  tailor['employeeName']?.toString() ??
                                  localizedUiText(context, 'Tailor'),
                            ),
                          ),
                      ],
                      onChanged: (tailor) {
                        updateSheet(() => selectedTailor = tailor);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      selectAllOnFocus: true,
                      decoration: InputDecoration(
                        labelText: localizedUiText(
                          context,
                          'Search measurements',
                        ),
                        hintText: localizedUiText(
                          context,
                          'e.g. Chest, Waist, Length',
                        ),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        updateSheet(() => query = value);
                      },
                    ),
                    if (query.trim().isNotEmpty && matches.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final name = _titleCase(query);
                            final response = await _runValueRequest(
                              () => widget.repository.saveMeasurement(
                                widget.session,
                                name,
                              ),
                            );
                            if (response == null || !sheetContext.mounted) {
                              return;
                            }
                            final refreshed = await widget.repository
                                .loadMeasurements(widget.session);
                            if (!mounted || !sheetContext.mounted) return;
                            final created = refreshed
                                .cast<Map<String, dynamic>?>()
                                .firstWhere(
                                  (entry) =>
                                      entry?['measurementName']
                                          ?.toString()
                                          .toLowerCase() ==
                                      name.toLowerCase(),
                                  orElse: () => null,
                                );
                            setState(() => _measurements = refreshed);
                            if (created != null) {
                              updateSheet(() {
                                picked.add({
                                  'measurementMapId': _int(
                                    created['measurementID'],
                                  ),
                                  'measurementName': created['measurementName'],
                                  'measurementValue': 0.0,
                                });
                                query = '';
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            '${localizedUiText(context, 'Create')} "$query" ${localizedUiText(context, 'measurement')}',
                          ),
                        ),
                      ),
                    if (matches.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView(
                          children: [
                            for (final measurement in matches)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.straighten),
                                title: Text(
                                  measurement['measurementName']?.toString() ??
                                      'Measurement',
                                ),
                                onTap: () {
                                  updateSheet(() {
                                    picked.add({
                                      'measurementMapId': _int(
                                        measurement['measurementID'],
                                      ),
                                      'measurementName':
                                          measurement['measurementName'],
                                      'measurementValue': 0.0,
                                    });
                                    query = '';
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      '${localizedUiText(context, 'Measurements')} (${picked.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: picked.isEmpty
                          ? Center(
                              child: Text(
                                localizedUiText(
                                  context,
                                  'Search and add item measurements.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: picked.length,
                              itemBuilder: (context, index) {
                                final measurement = picked[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        measurement['measurementName']
                                                ?.toString() ??
                                            'Measurement',
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        selectAllOnFocus: true,
                                        key: ValueKey(
                                          'measure-$index-${measurement['measurementMapId']}',
                                        ),
                                        initialValue:
                                            measurement['measurementValue']
                                                .toString(),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: localizedUiText(
                                            context,
                                            'Value',
                                          ),
                                        ),
                                        onChanged: (value) {
                                          measurement['measurementValue'] =
                                              double.tryParse(value) ?? 0;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: localizedUiText(
                                        context,
                                        'Remove measurement',
                                      ),
                                      onPressed: () => updateSheet(
                                        () => picked.removeAt(index),
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectedTailor == null || picked.isEmpty
                            ? null
                            : () => Navigator.pop(sheetContext, {
                                'measurements': picked,
                                'assignedToTailorId': _int(
                                  selectedTailor!['employeeID'],
                                ),
                                'tailorName':
                                    selectedTailor!['fullName'] ??
                                    selectedTailor!['employeeName'] ??
                                    '',
                              }),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          localizedUiText(context, 'Save item alteration'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      item['measurements'] = result['measurements'];
      item['assignedToTailorId'] = result['assignedToTailorId'];
      item['tailorName'] = result['tailorName'];
    });
  }

  Future<Map<String, dynamic>?> _runValueRequest(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (mounted) setState(() => _busy = true);
    try {
      return await request();
    } catch (error) {
      if (mounted) _message(error.toString(), localize: false);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _titleCase(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');

  double get _cartTotal => _cart.fold(
    0,
    (sum, row) => sum + _num(row['rentRate']) * _int(row['qty']),
  );

  double get _cartSecurityDeposit => _cart.fold(
    0,
    (sum, row) => sum + _num(row['securityDeposit']) * _int(row['qty']),
  );

  Future<void> _submitBooking() async {
    if (_cart.isEmpty || _selectedCustomer == null) {
      _message('Select a customer and add at least one available item.');
      return;
    }
    if (_alterationRequired) {
      final incomplete = _cart.where((row) {
        final measurements = row['measurements'];
        return measurements is! List ||
            measurements.isEmpty ||
            _int(row['assignedToTailorId']) <= 0;
      });
      if (incomplete.isNotEmpty) {
        final itemName = incomplete.first['itemName']?.toString() ?? 'item';
        _message(
          '${localizedUiText(context, 'Add measurements and assign a tailor for')} $itemName.',
          localize: false,
        );
        return;
      }
    }
    if (_series.isEmpty) {
      _message('No rental voucher series is available for this account.');
      return;
    }
    final paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0;
    if (paid < 0 || paid > _cartTotal || deposit < 0) {
      _message('Check the booking payment and security deposit amounts.');
      return;
    }
    final currentSeries = _series.firstWhere(
      (row) => row['isCurrent'] == true,
      orElse: () => _series.first,
    );
    final payment = paid > 0
        ? [_paymentPayload(paid, _paymentMode)]
        : <Map<String, Object?>>[];
    final bookingDetails = _cart.map((row) {
      return <String, Object?>{
        'bookingDetailID': 0,
        'catalogID': _int(row['catalogID']),
        'variantID': _int(row['variantID']),
        'itemId': _int(row['itemId']),
        'sizeID': _int(row['sizeID']),
        'colorID': _int(row['colorID']),
        'qty': _int(row['qty']),
        'rate': _num(row['rentRate']),
        'remarks': '',
        'measurements': (row['measurements'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (measurement) => <String, Object?>{
                'measurementMapId': _int(measurement['measurementMapId']),
                'measurementName':
                    measurement['measurementName']?.toString() ?? '',
                'measurementValue': _num(measurement['measurementValue']),
              },
            )
            .toList(),
        'assignedToTailorId': _int(row['assignedToTailorId']) > 0
            ? _int(row['assignedToTailorId'])
            : null,
      };
    }).toList();
    final payload = <String, Object?>{
      'bookingID': 0,
      'customerID': _int(_selectedCustomer!['customerID']),
      'bookingDate': _iso(DateTime.now()),
      'voucherSeriesId': _int(
        currentSeries['voucherSeriesID'] ?? currentSeries['voucherSeriesId'],
      ),
      'eventDate': _eventDateController.text.isEmpty
          ? ''
          : _apiDate(parseDateValue(_eventDateController.text)!),
      'fromDate': _apiDate(_fromDate),
      'toDate': _apiDate(_toDate),
      'totalAmount': _cartTotal,
      'bookingAmount': paid,
      'securityDeposit': deposit,
      'securityDepositMode': _depositPaid ? _depositPaymentMode : '',
      'securityDepositStatus': _depositPaid ? 'Paid' : 'Unpaid',
      'status': 'Booked',
      'remarks': _remarksController.text.trim(),
      'finYearID': widget.session.financialYearId,
      'isAlterationRequired': _alterationRequired,
      'assignedToTailorId': 0,
      'bookingDetails': bookingDetails,
      'bookingPayments': payment,
    };
    await _runRequest(() async {
      final result = await widget.repository.saveBooking(
        widget.session,
        payload,
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _cartFromDate = null;
        _cartToDate = null;
        _paidController.text = '0';
        _depositController.text = '0';
        _remarksController.clear();
        _selectedCustomer = null;
        _mobileController.clear();
        _bookingsFuture = widget.repository.loadBookings(widget.session);
      });
      final responseMessage =
          result['message']?.toString() ?? result['errorDesc']?.toString();
      _message(
        responseMessage ?? 'Rental booking saved.',
        localize: responseMessage == null,
      );
      _tabs.animateTo(1);
    });
  }

  Future<void> _deliverBooking(Map<String, dynamic> booking) async {
    final depositController = TextEditingController(
      text: _num(booking['securityDeposit']).toStringAsFixed(2),
    );
    final paymentController = TextEditingController(text: '0');
    var deliveryPaymentMode = 'Cash';
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(
            '${localizedUiText(context, 'Deliver')} ${booking['bookingNo'] ?? localizedUiText(context, 'booking')}?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedUiText(
                  context,
                  'This converts the booking into an issued rental. Confirm the security deposit and any additional payment collected.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                selectAllOnFocus: true,
                controller: depositController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Security deposit'),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                selectAllOnFocus: true,
                controller: paymentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localizedUiText(
                    context,
                    'Additional payment collected',
                  ),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: deliveryPaymentMode,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Payment method'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Cash',
                    child: Text(localizedUiText(context, 'Cash')),
                  ),
                  DropdownMenuItem(
                    value: 'UPI',
                    child: Text(localizedUiText(context, 'UPI')),
                  ),
                  DropdownMenuItem(
                    value: 'Card',
                    child: Text(localizedUiText(context, 'Card')),
                  ),
                  DropdownMenuItem(
                    value: 'Online',
                    child: Text(localizedUiText(context, 'Online transfer')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    updateDialog(() => deliveryPaymentMode = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizedUiText(dialogContext, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'deposit': double.tryParse(depositController.text) ?? 0,
                'payment': double.tryParse(paymentController.text) ?? 0,
                'paymentMode': deliveryPaymentMode,
              }),
              child: Text(localizedUiText(dialogContext, 'Confirm delivery')),
            ),
          ],
        ),
      ),
    );
    depositController.dispose();
    paymentController.dispose();
    if (result == null) {
      return;
    }
    final deposit = result['deposit'] as double;
    final additionalPayment = result['payment'] as double;
    if (deposit < 0 || additionalPayment < 0) {
      _message('Deposit and payment amounts cannot be negative.');
      return;
    }
    final currentSeries = _series.isEmpty
        ? null
        : _series.firstWhere(
            (row) => row['isCurrent'] == true,
            orElse: () => _series.first,
          );
    if (currentSeries == null) {
      _message('No rental voucher series is available for delivery.');
      return;
    }
    await _runRequest(() async {
      await widget.repository.deliverBooking(widget.session, {
        'bookingID': _int(booking['bookingID']),
        'rentDate': _iso(DateTime.now()),
        'voucherSeriesID': _int(
          currentSeries['voucherSeriesID'] ?? currentSeries['voucherSeriesId'],
        ),
        'securityDeposit': deposit,
        'additionalPayments': additionalPayment > 0
            ? [
                _paymentPayload(
                  additionalPayment,
                  result['paymentMode'] as String,
                ),
              ]
            : <Object?>[],
      });
      if (!mounted) return;
      _message('Rental delivered.');
      await _loadBookings();
    });
  }

  Future<void> _findRents() async {
    final mobile = _mobileController.text.replaceAll(RegExp(r'\D'), '');
    if (mobile.length != 10) {
      _message('Enter a valid 10-digit customer mobile number.');
      return;
    }
    setState(() {
      _selectedRent = null;
      _busy = true;
    });
    try {
      final rents = await widget.repository.findOpenRents(
        widget.session,
        mobile,
      );
      if (!mounted) return;
      final availableRents = rents.map(_prepareReturnRent).toList();
      setState(() {
        _openRents = availableRents;
        _selectedRent = availableRents.isEmpty ? null : availableRents.first;
        _busy = false;
      });
      if (rents.isEmpty) _message('No open rentals found for this number.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        '${localizedUiText(context, 'Could not find open rentals')}: $error',
      );
    }
  }

  Future<void> _submitReturn(Map<String, dynamic> rent) async {
    final details = rent['rentDetails'];
    if (details is! List || details.isEmpty) {
      _message('This rental has no returnable item details.');
      return;
    }
    final activeRows = details.whereType<Map>().where(
      (row) =>
          row['status']?.toString().toLowerCase() != 'returned' &&
          (_int(row['returnQty']) > 0 ||
              row['returnStatus']?.toString() == 'Lost'),
    );
    final netSettlement = _netSettlement(rent, activeRows);
    final settlement = netSettlement.abs();
    final payload = <String, Object?>{
      'returnDate': _iso(_returnDate),
      'returnRemarks': _returnRemarksController.text.trim(),
      'refundAmount': netSettlement < 0 ? settlement : 0,
      'voucherSeriesId': _currentSeriesId,
      'rentReturnDetails': [
        for (final row in activeRows)
          {
            'menuId': 0,
            'detailID': _int(row['detailID']),
            'itemId': _int(row['itemId']),
            'returnQty': _int(row['returnQty']),
            'status': row['returnStatus']?.toString() ?? 'Returned',
            'damageAmount': _num(row['damageAmount']),
            'lateAmount': _num(row['lateAmount']),
            'otherCharges': _num(row['otherCharges']),
            'remarks': row['returnRemarks']?.toString() ?? '',
            'rentItemPhotos': <Object?>[],
          },
      ],
      'rentReturnPayments': netSettlement > 0
          ? [_paymentPayload(settlement, _returnPaymentMode)]
          : <Object?>[],
      'rentPhotos': <Object?>[],
      'rentRefundPayments': netSettlement < 0
          ? [_paymentPayload(settlement, _returnPaymentMode)]
          : <Object?>[],
    };
    if (payload['rentReturnDetails'] is List &&
        (payload['rentReturnDetails'] as List).isEmpty) {
      _message('There are no remaining items to return.');
      return;
    }
    await _runRequest(() async {
      await widget.repository.saveReturn(widget.session, payload);
      if (!mounted) return;
      setState(() {
        _openRents.remove(rent);
        _selectedRent = _openRents.isEmpty ? null : _openRents.first;
        _returnRemarksController.clear();
      });
      _message('Rental return saved.');
    });
  }

  Map<String, dynamic> _prepareReturnRent(Map<String, dynamic> rent) {
    final details = rent['rentDetails'];
    if (details is! List) return rent;
    return {
      ...rent,
      'rentDetails': details.whereType<Map>().map((raw) {
        final row = _stringMap(raw);
        final qty = _int(row['qty']);
        return {
          ...row,
          'returnDate': row['returnDate'] ?? rent['returnDate'],
          'returnQty': qty,
          'returnStatus': 'Returned',
          'damageAmount': 0.0,
          'otherCharges': 0.0,
          'returnRemarks': '',
          'lateAmount': _lateFee(row, qty),
          'rentItemPhotos': <Object?>[],
        };
      }).toList(),
    };
  }

  double _netSettlement(Map<String, dynamic> rent, Iterable<Map> rows) {
    final charges = rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          _num(row['damageAmount']) +
          _num(row['lateAmount']) +
          _num(row['otherCharges']),
    );
    return _num(rent['pendingAmount']) +
        charges -
        _num(rent['securityDeposit']);
  }

  double _lateFee(Map row, int returnQty) {
    final dueDate = parseDateValue(row['returnDate']);
    if (dueDate == null || returnQty <= 0) return 0;
    final dueDay = DateUtils.dateOnly(dueDate);
    final today = DateUtils.dateOnly(_returnDate);
    final daysLate = today.difference(dueDay).inDays;
    return daysLate <= 0 ? 0 : daysLate * _num(row['rate']) * returnQty * 0.1;
  }

  void _changeReturnStatus(Map row, String status) {
    final qty = _int(row['qty']);
    setState(() {
      row['returnStatus'] = status;
      row['returnQty'] = status == 'Lost' ? 0 : qty;
      if (status == 'Lost') {
        row['damageAmount'] = _num(row['rate']) * qty;
      } else if (status == 'Damaged' && _num(row['damageAmount']) == 0) {
        row['damageAmount'] = _num(row['rate']) * qty * 0.5;
      } else if (status == 'Returned') {
        row['damageAmount'] = 0.0;
      }
      row['lateAmount'] = _lateFee(row, _int(row['returnQty']));
    });
  }

  void _changeReturnQty(Map row, int? qty) {
    if (qty == null) return;
    setState(() {
      row['returnQty'] = qty;
      row['lateAmount'] = _lateFee(row, qty);
    });
  }

  Future<void> _pickReturnDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _returnDate = selected;
      final details = _selectedRent?['rentDetails'];
      if (details is List) {
        for (final row in details.whereType<Map>()) {
          row['lateAmount'] = _lateFee(row, _int(row['returnQty']));
        }
      }
    });
  }

  int? get _currentSeriesId {
    if (_series.isEmpty) return null;
    final current = _series.firstWhere(
      (row) => row['isCurrent'] == true,
      orElse: () => _series.first,
    );
    return _int(current['voucherSeriesID'] ?? current['voucherSeriesId']);
  }

  Map<String, Object?> _paymentPayload(double amount, String mode) => {
    'menuId': RentalRepository.rentalMenuId,
    'paymentDate': _iso(DateTime.now()),
    'paymentMode': mode,
    'totalAmount': amount,
    'cardType': '',
    'cardDigits': '',
    'cardNumber': '',
    'nameOnCard': '',
    'cardAmount': mode.toLowerCase() == 'card' ? amount : 0,
    'cardSlipNo': '',
    'pgType': '',
    'upiid': '',
    'upiMobileNo': '',
    'nameOnUPI': '',
    'onlineAmount': mode.toLowerCase() == 'upi' ? amount : 0,
    'transactionNo': '',
    'remarks': '',
    'receiptNo': '',
  };

  Future<void> _runRequest(Future<void> Function() request) async {
    setState(() => _busy = true);
    try {
      await request();
    } catch (error) {
      if (mounted) _message(error.toString(), localize: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message, {bool localize = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(localize ? localizedUiText(context, message) : message),
        ),
      );
  }

  Future<void> _pickEventDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(DateTime.now()),
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) {
      _eventDateController.text = formatDisplayDate(selected);
    }
  }

  String _apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _iso(DateTime value) => value.toIso8601String();

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  double _num(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(Object? value) => '₹${_num(value).toStringAsFixed(2)}';

  String _prettyDate(DateTime value) => formatDisplayDate(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              title: Text(localizedUiText(context, 'Rental workspace')),
              actions: [
                if (widget.onOpenAssistant != null)
                  IconButton(
                    tooltip: localizedUiText(context, 'Ask assistant'),
                    onPressed: widget.onOpenAssistant,
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
              ],
              bottom: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.checkroom_outlined),
                    text: localizedUiText(context, 'Catalogue'),
                  ),
                  Tab(
                    icon: const Icon(Icons.event_note_outlined),
                    text: localizedUiText(context, 'Bookings'),
                  ),
                  Tab(
                    icon: Icon(Icons.assignment_return_outlined),
                    text: localizedUiText(context, 'Returns'),
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [_catalogTab(), _bookingsTab(), _returnsTab()],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: StitchLoader(size: 72, showMonogram: false),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _tabs,
        builder: (context, child) {
          if (_tabs.index != 0 || _cart.isEmpty) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Material(
              elevation: 12,
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedUiText(
                              context,
                              '${_cart.fold<int>(0, (sum, row) => sum + _int(row['qty']))} item(s) in cart',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF68768C),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _money(_cartTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _tabs.animateTo(1),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(localizedUiText(context, 'View cart')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _catalogTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizedUiText(context, 'Check availability'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createCatalogItem,
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(localizedUiText(context, 'Create item')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              localizedUiText(
                context,
                'Choose rental dates to see available sizes and colours.',
              ),
              style: TextStyle(color: Color(0xFF68768C)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    localizedUiText(context, 'From'),
                    _fromDate,
                    () => _pickRentalDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateButton(
                    localizedUiText(context, 'Return by'),
                    _toDate,
                    () => _pickRentalDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _loadCatalog,
                icon: const Icon(Icons.search),
                label: Text(localizedUiText(context, 'Find available items')),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_catalogFuture != null)
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _errorCard(snapshot.error.toString());
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: StitchLoader(size: 64, showMonogram: false),
                ),
              );
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return _emptyCard(
                localizedUiText(
                  context,
                  'No catalogue items are available for those dates.',
                ),
              );
            }
            final query = _searchController.text.trim().toLowerCase();
            final filtered = items.where((item) {
              if (query.isEmpty) return true;
              final searchable =
                  '${item['itemName']} ${item['itemCode']} ${item['groupName']}'
                      .toLowerCase();
              return searchable.contains(query);
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  selectAllOnFocus: true,
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: localizedUiText(context, 'Search catalogue'),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                for (final item in filtered) _catalogCard(item),
              ],
            );
          },
        ),
    ],
  );

  Widget _catalogCard(Map<String, dynamic> item) {
    final variants = item['variants'] is List
        ? (item['variants'] as List).whereType<Map>().toList()
        : const <Map>[];
    final photos = item['photos'] is List
        ? (item['photos'] as List).whereType<Map>().toList()
        : const <Map>[];
    final photoPath = photos.isEmpty
        ? null
        : photos.first['photoPath']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoPath != null && photoPath.startsWith('http'))
            Image.network(
              photoPath,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['itemName']?.toString() ??
                      localizedUiText(context, 'Rental item'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${item['itemCode'] ?? ''}  •  ${item['groupName'] ?? localizedUiText(context, 'Occasionwear')}',
                  style: const TextStyle(color: Color(0xFF68768C)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localizedUiText(context, 'Security deposit')}: ${_money(item['securityDeposit'])}',
                  style: const TextStyle(color: Color(0xFF68768C)),
                ),
                const Divider(height: 22),
                for (final variant in variants)
                  _variantRow(item, _stringMap(variant)),
                if (variants.isEmpty)
                  Text(
                    localizedUiText(
                      context,
                      'No size or colour variants are listed.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _stringMap(Map value) => {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };

  Widget _variantRow(Map<String, dynamic> item, Map<String, dynamic> variant) {
    final available = _int(variant['availableQty']);
    final isAvailable = available > 0;
    final cartRow = _cartItemFor(item, variant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${variant['sizeName'] ?? localizedUiText(context, 'Size')} • ${variant['colorName'] ?? localizedUiText(context, 'Colour')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFFE7F5F0)
                      : const Color(0xFFFFECEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAvailable
                      ? '$available ${localizedUiText(context, 'available')}'
                      : localizedUiText(context, 'Unavailable'),
                  style: TextStyle(
                    color: isAvailable
                        ? const Color(0xFF16816D)
                        : const Color(0xFF9B2838),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_money(variant['rentRate'])} ${localizedUiText(context, 'rental')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF34435A),
                  ),
                ),
              ),
              if (cartRow == null)
                FilledButton.tonalIcon(
                  key: ValueKey(
                    'add-${item['catalogID']}-${variant['variantID']}',
                  ),
                  onPressed: isAvailable
                      ? () => _addVariant(item, variant)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(localizedUiText(context, 'Add to cart')),
                )
              else
                _quantitySelector(cartRow),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _quantitySelector(Map<String, dynamic> row) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFDCE3ED)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: localizedUiText(context, 'Decrease quantity'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeCartQuantity(row, -1),
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text(
          '${row['qty']}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: localizedUiText(context, 'Increase quantity'),
          visualDensity: VisualDensity.compact,
          onPressed: _int(row['qty']) < _int(row['maxQty'])
              ? () => _changeCartQuantity(row, 1)
              : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    ),
  );

  Widget _cartPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                localizedUiText(context, 'Your cart'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_cart.fold<int>(0, (sum, row) => sum + _int(row['qty']))} ${localizedUiText(context, 'item(s)')}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in _cart)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          (row['photoPath']?.toString().startsWith('http') ??
                              false)
                          ? Image.network(
                              row['photoPath'].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.checkroom_outlined),
                            )
                          : const Icon(Icons.checkroom_outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['itemName']?.toString() ??
                                localizedUiText(context, 'Item'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['sizeName']} • ${row['colorName']}',
                            style: const TextStyle(
                              color: Color(0xFF68768C),
                              fontSize: 12,
                            ),
                          ),
                          Text(_money(row['rentRate'])),
                          if (_alterationRequired &&
                              _int(row['assignedToTailorId']) > 0)
                            Text(
                              '${localizedUiText(context, 'Tailor')}: ${row['tailorName']} • ${(row['measurements'] as List? ?? const []).length} ${localizedUiText(context, 'measurements')}',
                              style: const TextStyle(
                                color: Color(0xFF16816D),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _quantitySelector(row),
                  ],
                ),
                if (_alterationRequired)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editItemAlteration(row),
                      icon: const Icon(Icons.straighten, size: 18),
                      label: Text(
                        _int(row['assignedToTailorId']) > 0
                            ? localizedUiText(context, 'Edit alteration')
                            : localizedUiText(
                                context,
                                'Add measurements & assign tailor',
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(),
        if (_cartFromDate != null && _cartToDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Color(0xFF68768C),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_prettyDate(_cartFromDate!)} – ${_prettyDate(_cartToDate!)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        _summaryLine(
          localizedUiText(context, 'Rental subtotal'),
          _money(_cartTotal),
          emphasized: true,
        ),
        _summaryLine(
          localizedUiText(context, 'Refundable security deposit'),
          _money(_cartSecurityDeposit),
        ),
      ],
    ),
  );

  Widget _bookingsTab() {
    _bookingsFuture ??= widget.repository.loadBookings(widget.session);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bookingForm(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                localizedUiText(context, 'Existing bookings'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _errorCard(snapshot.error.toString());
            if (!snapshot.hasData) {
              return const Center(
                child: StitchLoader(size: 64, showMonogram: false),
              );
            }
            final bookings = snapshot.data!;
            if (bookings.isEmpty) {
              return _emptyCard(
                localizedUiText(
                  context,
                  'Bookings will appear here after saving.',
                ),
              );
            }
            return Column(
              children: [for (final booking in bookings) _bookingCard(booking)],
            );
          },
        ),
      ],
    );
  }

  Widget _bookingForm() =>
      _cart.isEmpty ? _emptyBookingForm() : _checkoutForm();

  Widget _emptyBookingForm() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizedUiText(context, 'Your cart is empty'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          localizedUiText(
            context,
            'Choose an available outfit to start a rental booking.',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _tabs.animateTo(0),
          icon: const Icon(Icons.storefront_outlined),
          label: Text(localizedUiText(context, 'Browse catalogue')),
        ),
      ],
    ),
  );

  Widget _checkoutForm() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizedUiText(context, 'Complete your booking'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${_cart.length} ${localizedUiText(context, 'style(s)')} • ${_money(_cartTotal)} ${localizedUiText(context, 'rental')}',
          style: const TextStyle(color: Color(0xFF68768C)),
        ),
        const SizedBox(height: 16),
        _cartPanel(),
        const SizedBox(height: 16),
        _sectionHeading(localizedUiText(context, '1. Customer details')),
        const SizedBox(height: 8),
        InkWell(
          onTap: _chooseCustomer,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Customer'),
              prefixIcon: Icon(Icons.person_outline),
              suffixIcon: Icon(Icons.search),
            ),
            child: Text(
              _selectedCustomer == null
                  ? localizedUiText(
                      context,
                      'Search by customer name or mobile',
                    )
                  : '${_selectedCustomer!['fullName'] ?? _selectedCustomer!['customerName'] ?? localizedUiText(context, 'Customer')} • ${_selectedCustomer!['mobileNo'] ?? ''}',
              style: TextStyle(
                color: _selectedCustomer == null
                    ? const Color(0xFF68768C)
                    : const Color(0xFF202B3C),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickEventDate,
          icon: const Icon(Icons.celebration_outlined),
          label: Text(
            _eventDateController.text.isEmpty
                ? localizedUiText(context, 'Add event date (optional)')
                : '${localizedUiText(context, 'Event date')}: ${_eventDateController.text}',
          ),
        ),
        const SizedBox(height: 10),
        _sectionHeading(localizedUiText(context, '2. Rental preferences')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(localizedUiText(context, 'Alteration required')),
          subtitle: Text(
            localizedUiText(
              context,
              'Flag this rental for alteration before delivery.',
            ),
          ),
          value: _alterationRequired,
          onChanged: (value) => setState(() => _alterationRequired = value),
        ),
        const SizedBox(height: 6),
        _sectionHeading(localizedUiText(context, '3. Payment')),
        const SizedBox(height: 8),
        _summaryLine(
          localizedUiText(context, 'Rental amount'),
          _money(_cartTotal),
        ),
        TextField(
          selectAllOnFocus: true,
          controller: _depositController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: localizedUiText(context, 'Refundable security deposit'),
            prefixText: '₹ ',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(localizedUiText(context, 'Security deposit collected')),
          subtitle: Text(
            localizedUiText(context, 'Mark received only after collecting it.'),
          ),
          value: _depositPaid,
          onChanged: (value) => setState(() => _depositPaid = value),
        ),
        if (_depositPaid) ...[
          const SizedBox(height: 4),
          _paymentModeDropdown(
            _depositPaymentMode,
            (value) => setState(() => _depositPaymentMode = value),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          selectAllOnFocus: true,
          controller: _paidController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: localizedUiText(context, 'Advance payment collected'),
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 10),
        _paymentModeDropdown(
          _paymentMode,
          (value) => setState(() => _paymentMode = value),
        ),
        const SizedBox(height: 10),
        TextField(
          selectAllOnFocus: true,
          controller: _remarksController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: localizedUiText(context, 'Booking remarks'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _submitBooking,
            icon: const Icon(Icons.event_available),
            label: Text(localizedUiText(context, 'Confirm rental booking')),
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeading(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: Color(0xFF34435A),
    ),
  );

  Widget _bookingCard(Map<String, dynamic> booking) {
    final converted = _int(booking['rentID']) > 0;
    final status = booking['status']?.toString() ?? 'Booked';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking['bookingNo']?.toString() ??
                        '${localizedUiText(context, 'Booking')} ${booking['bookingID'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(
                  label: Text(
                    localizedUiText(context, converted ? 'Delivered' : status),
                  ),
                ),
              ],
            ),
            Text(
              '${booking['customerName'] ?? ''} • ${booking['customerMobile'] ?? ''}',
            ),
            const SizedBox(height: 4),
            Text(
              '${_prettyDate(_parseDate(booking['fromDate']))} – ${_prettyDate(_parseDate(booking['toDate']))}  •  ${_money(booking['totalAmount'])}',
              style: const TextStyle(color: Color(0xFF68768C)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showTransactionVoucherDetails(
                  context,
                  title:
                      '${localizedUiText(context, 'Booking')} ${booking['bookingNo'] ?? booking['bookingID'] ?? ''} ${localizedUiText(context, 'details')}',
                  voucher: Map<String, dynamic>.from(booking),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  localizedUiText(context, 'View all voucher details'),
                ),
              ),
            ),
            if (!converted && status.toLowerCase() != 'cancelled') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _deliverBooking(booking),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(localizedUiText(context, 'Deliver')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _returnsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizedUiText(context, 'Process rental return'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              localizedUiText(
                context,
                'Find active rentals using the customer mobile number.',
              ),
              style: TextStyle(color: Color(0xFF68768C)),
            ),
            const SizedBox(height: 12),
            TextField(
              selectAllOnFocus: true,
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: localizedUiText(context, 'Customer mobile number'),
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _findRents,
                icon: const Icon(Icons.search),
                label: Text(localizedUiText(context, 'Find active rentals')),
              ),
            ),
          ],
        ),
      ),
      if (_selectedRent != null) ...[
        const SizedBox(height: 14),
        if (_openRents.length > 1)
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedRent,
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Select active rental'),
            ),
            items: [
              for (final rent in _openRents)
                DropdownMenuItem(
                  value: rent,
                  child: Text(
                    rent['rentNo']?.toString() ??
                        localizedUiText(context, 'Rental'),
                  ),
                ),
            ],
            onChanged: (rent) => setState(() => _selectedRent = rent),
          ),
        if (_openRents.length > 1) const SizedBox(height: 12),
        _returnCard(_selectedRent!),
      ],
    ],
  );

  Widget _returnCard(Map<String, dynamic> rent) {
    final details = rent['rentDetails'] is List
        ? (rent['rentDetails'] as List).whereType<Map>().toList()
        : const <Map>[];
    final active = details
        .where((row) => row['status']?.toString().toLowerCase() != 'returned')
        .toList();
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rent['rentNo']?.toString() ??
                localizedUiText(context, 'Active rental'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            '${rent['customerName'] ?? ''} • ${localizedUiText(context, 'Due')} ${_prettyDate(_parseDate(rent['returnDate']))}',
            style: const TextStyle(color: Color(0xFF68768C)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showTransactionVoucherDetails(
                context,
                title: localizedUiText(
                  context,
                  'Rental ${rent['rentNo'] ?? ''} details',
                ),
                voucher: Map<String, dynamic>.from(rent),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(
                localizedUiText(context, 'View rental voucher details'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _dateButton(
            localizedUiText(context, 'Return date'),
            _returnDate,
            _pickReturnDate,
          ),
          const Divider(height: 22),
          for (final row in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['itemName']?.toString() ??
                        localizedUiText(context, 'Rental item'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${row['sizeName'] ?? ''} ${row['colorName'] ?? ''} • ${localizedUiText(context, 'Rented qty')} ${row['qty'] ?? 0}',
                    style: const TextStyle(color: Color(0xFF68768C)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              row['returnStatus']?.toString() ?? 'Returned',
                          decoration: InputDecoration(
                            labelText: localizedUiText(context, 'Condition'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Returned',
                              child: Text(localizedUiText(context, 'Returned')),
                            ),
                            DropdownMenuItem(
                              value: 'Partial',
                              child: Text(localizedUiText(context, 'Partial')),
                            ),
                            DropdownMenuItem(
                              value: 'Damaged',
                              child: Text(localizedUiText(context, 'Damaged')),
                            ),
                            DropdownMenuItem(
                              value: 'Lost',
                              child: Text(localizedUiText(context, 'Lost')),
                            ),
                          ],
                          onChanged: (status) {
                            if (status != null) {
                              _changeReturnStatus(row, status);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _int(row['returnQty']),
                          decoration: InputDecoration(
                            labelText: localizedUiText(context, 'Return qty'),
                          ),
                          items: [
                            for (var qty = 0; qty <= _int(row['qty']); qty++)
                              DropdownMenuItem(value: qty, child: Text('$qty')),
                          ],
                          onChanged: (qty) => _changeReturnQty(row, qty),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          selectAllOnFocus: true,
                          initialValue: _num(row['damageAmount']).toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: localizedUiText(
                              context,
                              'Damage/loss charge',
                            ),
                            prefixText: '₹ ',
                          ),
                          onChanged: (value) => setState(() {
                            row['damageAmount'] = double.tryParse(value) ?? 0;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          selectAllOnFocus: true,
                          initialValue: _num(row['otherCharges']).toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: localizedUiText(
                              context,
                              'Other charges',
                            ),
                            prefixText: '₹ ',
                          ),
                          onChanged: (value) => setState(() {
                            row['otherCharges'] = double.tryParse(value) ?? 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${localizedUiText(context, 'Late fee')}: ${_money(row['lateAmount'])}',
                    style: const TextStyle(
                      color: Color(0xFFB16B35),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(height: 18),
                ],
              ),
            ),
          Builder(
            builder: (context) {
              final net = _netSettlement(rent, active);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryLine(
                    localizedUiText(context, 'Pending rent'),
                    _money(rent['pendingAmount']),
                  ),
                  _summaryLine(
                    localizedUiText(context, 'Security deposit held'),
                    _money(rent['securityDeposit']),
                  ),
                  _summaryLine(
                    localizedUiText(
                      context,
                      net < 0 ? 'Refund due' : 'Amount to collect',
                    ),
                    _money(net.abs()),
                    emphasized: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          _paymentModeDropdown(
            _returnPaymentMode,
            (value) => setState(() => _returnPaymentMode = value),
          ),
          const SizedBox(height: 10),
          TextField(
            selectAllOnFocus: true,
            controller: _returnRemarksController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Return remarks'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _submitReturn(rent),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: Text(localizedUiText(context, 'Save return')),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(Object? value) {
    if (value == null || value.toString().isEmpty) return DateTime.now();
    return parseDateValue(value) ?? DateTime.now();
  }

  Widget _paymentModeDropdown(String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: localizedUiText(context, 'Payment method'),
        ),
        items: [
          DropdownMenuItem(
            value: 'Cash',
            child: Text(localizedUiText(context, 'Cash')),
          ),
          DropdownMenuItem(
            value: 'UPI',
            child: Text(localizedUiText(context, 'UPI')),
          ),
          DropdownMenuItem(
            value: 'Card',
            child: Text(localizedUiText(context, 'Card')),
          ),
          DropdownMenuItem(
            value: 'Online',
            child: Text(localizedUiText(context, 'Online transfer')),
          ),
        ],
        onChanged: (mode) {
          if (mode != null) onChanged(mode);
        },
      );

  Widget _dateButton(String label, DateTime value, VoidCallback onPressed) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10)),
                  Text(
                    _prettyDate(value),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _panel({required Widget child}) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: child,
    ),
  );

  Widget _summaryLine(String label, String value, {bool emphasized = false}) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ],
      );

  Widget _emptyCard(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _errorCard(String message) => Card(
    color: const Color(0xFFFFECEE),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: Color(0xFF9B2838))),
    ),
  );
}

class _NewRentCatalogDialog extends StatefulWidget {
  const _NewRentCatalogDialog({
    required this.items,
    required this.groups,
    required this.units,
    required this.sizes,
    required this.colors,
    required this.onCreateItem,
    required this.onCreateGroup,
    required this.onCreateSize,
    required this.onCreateColor,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> sizes;
  final List<Map<String, dynamic>> colors;
  final Future<Map<String, dynamic>?> Function(Map<String, Object?>)
  onCreateItem;
  final Future<Map<String, dynamic>?> Function(String) onCreateGroup;
  final Future<Map<String, dynamic>?> Function(String) onCreateSize;
  final Future<Map<String, dynamic>?> Function(String) onCreateColor;

  @override
  State<_NewRentCatalogDialog> createState() => _NewRentCatalogDialogState();
}

class _NewRentCatalogDialogState extends State<_NewRentCatalogDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();
  final List<_CatalogVariantDraft> _variants = [_CatalogVariantDraft()];
  late final List<Map<String, dynamic>> _items = List.of(widget.items);
  late final List<Map<String, dynamic>> _groups = List.of(widget.groups);
  late final List<Map<String, dynamic>> _sizes = List.of(widget.sizes);
  late final List<Map<String, dynamic>> _colors = List.of(widget.colors);
  Map<String, dynamic>? _selectedItem;

  @override
  void dispose() {
    _descriptionController.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _addVariant() => setState(() => _variants.add(_CatalogVariantDraft()));

  void _removeVariant(int index) {
    final removed = _variants.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _addItemMasterEntry() async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _NewItemMasterDialog(
        groups: _groups,
        units: widget.units,
        onCreateGroup: widget.onCreateGroup,
      ),
    );
    if (payload == null) return;
    final existing = _items.cast<Map<String, dynamic>?>().firstWhere(
      (item) =>
          item?['itemName']?.toString().trim().toLowerCase() ==
          payload['itemName']?.toString().trim().toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      setState(() => _selectedItem = existing);
      return;
    }
    final item = await widget.onCreateItem(payload);
    if (item != null && mounted) {
      setState(() {
        _items.add(item);
        _selectedItem = item;
      });
    }
  }

  Future<void> _addSize(int index) async {
    final name = await _askForName('Add size', 'Size name');
    if (name == null) return;
    final existing = _sizes.cast<Map<String, dynamic>?>().firstWhere(
      (size) =>
          size?['sizeName']?.toString().trim().toLowerCase() ==
          name.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      setState(() => _variants[index].sizeId = _int(existing['sizeID']));
      return;
    }
    final size = await widget.onCreateSize(name);
    if (size == null || !mounted) return;
    setState(() {
      _sizes.add(size);
      _variants[index].sizeId = _int(size['sizeID']);
    });
  }

  Future<void> _addColor(int index) async {
    final name = await _askForName('Add colour', 'Colour name');
    if (name == null) return;
    final existing = _colors.cast<Map<String, dynamic>?>().firstWhere(
      (color) =>
          color?['colorName']?.toString().trim().toLowerCase() ==
          name.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      setState(() => _variants[index].colorId = _int(existing['colorID']));
      return;
    }
    final color = await widget.onCreateColor(name);
    if (color == null || !mounted) return;
    setState(() {
      _colors.add(color);
      _variants[index].colorId = _int(color['colorID']);
    });
  }

  Future<String?> _askForName(String title, String label) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _MasterNameDialog(title: title, label: label),
    );
  }

  Future<void> _addPhotos(
    _CatalogVariantDraft variant, {
    required bool fromCamera,
  }) async {
    try {
      if (fromCamera) {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1800,
          maxHeight: 1800,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        _appendPhoto(
          variant,
          bytes,
          image.mimeType ?? _mimeType(image.name),
          image.name,
        );
        return;
      }

      final selection = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (selection == null) return;
      for (final file in selection.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          if (!mounted) return;
          _showMessage(
            '${localizedUiText(context, 'Could not read')} ${file.name}. ${localizedUiText(context, 'Select the image again.')}',
            localize: false,
          );
          continue;
        }
        _appendPhoto(variant, bytes, _mimeType(file.name), file.name);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${localizedUiText(context, 'Could not attach image')}: $error',
        localize: false,
      );
    }
  }

  void _appendPhoto(
    _CatalogVariantDraft variant,
    Uint8List bytes,
    String photoType,
    String fileName,
  ) {
    if (variant.photos.length >= 5) {
      _showMessage(
        localizedUiText(
          context,
          'You can attach up to 5 images to each variant.',
        ),
      );
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage(
        '$fileName ${localizedUiText(context, 'is over 5 MB. Choose a smaller image.')}',
      );
      return;
    }
    setState(() {
      variant.photos.add(
        _CatalogPhotoDraft(
          bytes: bytes,
          photoType: photoType,
          fileName: fileName,
        ),
      );
    });
  }

  String _mimeType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  void _showMessage(String text, {bool localize = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(localize ? localizedUiText(context, text) : text),
        ),
      );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null ||
        _variants.any(
          (variant) =>
              variant.sizeId == null ||
              variant.colorId == null ||
              variant.quantity <= 0 ||
              variant.rate < 0,
        )) {
      return;
    }
    Navigator.pop(context, <String, Object?>{
      'item': _selectedItem!,
      'description': _descriptionController.text.trim(),
      'variants': [
        for (final variant in _variants)
          <String, Object?>{
            'sizeID': variant.sizeId,
            'colorID': variant.colorId,
            'totalQty': variant.quantity,
            'rentRate': variant.rate,
            'photos': [
              for (final photo in variant.photos)
                <String, Object?>{
                  'photoType': photo.photoType,
                  'photoBase64': base64Encode(photo.bytes),
                  'photoPath': '',
                  'remarks': photo.remarksController.text.trim(),
                },
            ],
          },
      ],
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Create rental catalogue item')),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey<int?>(
                  _selectedItem == null
                      ? null
                      : _int(
                          _selectedItem!['itemId'] ?? _selectedItem!['itemID'],
                        ),
                ),
                initialValue: _selectedItem == null
                    ? null
                    : _int(
                        _selectedItem!['itemId'] ?? _selectedItem!['itemID'],
                      ),
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Item Master item *'),
                  prefixIcon: Icon(Icons.checkroom_outlined),
                ),
                items: [
                  for (final item in _items)
                    if (_int(item['itemId'] ?? item['itemID']) > 0)
                      DropdownMenuItem(
                        value: _int(item['itemId'] ?? item['itemID']),
                        child: Text(item['itemName']?.toString() ?? ''),
                      ),
                ],
                onChanged: (itemId) => setState(() {
                  _selectedItem = _items
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                        (item) =>
                            _int(item?['itemId'] ?? item?['itemID']) == itemId,
                        orElse: () => null,
                      );
                }),
                validator: (value) => value == null || value <= 0
                    ? localizedUiText(context, 'Select an Item Master item')
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addItemMasterEntry,
                  icon: const Icon(Icons.add),
                  label: Text(
                    localizedUiText(context, 'Add item to Item Master'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                selectAllOnFocus: true,
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Description'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizedUiText(context, 'Size, colour & stock'),
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addVariant,
                    icon: const Icon(Icons.add),
                    label: Text(localizedUiText(context, 'Add variant')),
                  ),
                ],
              ),
              for (var index = 0; index < _variants.length; index++)
                _variantFields(index),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(localizedUiText(context, 'Create catalogue item')),
      ),
    ],
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextFormField(
        selectAllOnFocus: true,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: localizedUiText(context, label),
          prefixText: '₹ ',
        ),
        validator: (value) {
          final amount = double.tryParse(value ?? '');
          return amount == null || amount < 0 ? 'Enter valid amount' : null;
        },
      );

  Widget _variantFields(int index) {
    final variant = _variants[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey<int?>(variant.sizeId),
                      initialValue: variant.sizeId,
                      decoration: InputDecoration(
                        labelText: localizedUiText(context, 'Size *'),
                      ),
                      items: [
                        for (final size in _sizes)
                          DropdownMenuItem(
                            value: _int(size['sizeID']),
                            child: Text(size['sizeName']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => variant.sizeId = value),
                      validator: (value) => value == null || value <= 0
                          ? localizedUiText(context, 'Select size')
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: () => _addSize(index),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(localizedUiText(context, 'Add size')),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey<int?>(variant.colorId),
                      initialValue: variant.colorId,
                      decoration: InputDecoration(
                        labelText: localizedUiText(context, 'Colour *'),
                      ),
                      items: [
                        for (final color in _colors)
                          DropdownMenuItem(
                            value: _int(color['colorID']),
                            child: Text(color['colorName']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => variant.colorId = value),
                      validator: (value) => value == null || value <= 0
                          ? localizedUiText(context, 'Select colour')
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: () => _addColor(index),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(localizedUiText(context, 'Add colour')),
                    ),
                  ],
                ),
              ),
              if (_variants.length > 1)
                IconButton(
                  tooltip: localizedUiText(context, 'Remove variant'),
                  onPressed: () => _removeVariant(index),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  selectAllOnFocus: true,
                  controller: variant.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: localizedUiText(context, 'Total qty *'),
                  ),
                  validator: (value) {
                    final qty = int.tryParse(value ?? '');
                    return qty == null || qty <= 0
                        ? localizedUiText(context, 'Enter quantity')
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  variant.rateController,
                  localizedUiText(context, 'Rent rate *'),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${localizedUiText(context, 'Photos')} (${variant.photos.length}/5)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addPhotos(variant, fromCamera: false),
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(localizedUiText(context, 'From files')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addPhotos(variant, fromCamera: true),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(localizedUiText(context, 'Camera')),
                  ),
                ],
              ),
            ],
          ),
          if (variant.photos.isNotEmpty)
            for (
              var photoIndex = 0;
              photoIndex < variant.photos.length;
              photoIndex++
            )
              _photoAttachment(variant, photoIndex),
        ],
      ),
    );
  }

  Widget _photoAttachment(_CatalogVariantDraft variant, int photoIndex) {
    final photo = variant.photos[photoIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              photo.bytes,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              selectAllOnFocus: true,
              controller: photo.remarksController,
              decoration: InputDecoration(
                labelText: localizedUiText(context, 'Image remarks'),
                hintText: photo.fileName,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: localizedUiText(context, 'Remove image'),
            onPressed: () => setState(() {
              variant.photos.removeAt(photoIndex).dispose();
            }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}

class _MasterNameDialog extends StatefulWidget {
  const _MasterNameDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_MasterNameDialog> createState() => _MasterNameDialogState();
}

class _NewItemMasterDialog extends StatefulWidget {
  const _NewItemMasterDialog({
    required this.groups,
    required this.units,
    required this.onCreateGroup,
  });

  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> units;
  final Future<Map<String, dynamic>?> Function(String) onCreateGroup;

  @override
  State<_NewItemMasterDialog> createState() => _NewItemMasterDialogState();
}

class _NewItemMasterDialogState extends State<_NewItemMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemRateController = TextEditingController(text: '0');
  late final List<Map<String, dynamic>> _groups = List.of(widget.groups);
  int? _groupId;
  int? _unitId;
  bool _isActive = true;

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemRateController.dispose();
    super.dispose();
  }

  Future<void> _addGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _MasterNameDialog(
        title: 'Add Item Master group',
        label: 'Group name',
      ),
    );
    if (name == null) return;
    final existing = _groups.cast<Map<String, dynamic>?>().firstWhere(
      (group) =>
          group?['groupName']?.toString().trim().toLowerCase() ==
          name.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      setState(
        () => _groupId = _int(existing['groupID'] ?? existing['groupId']),
      );
      return;
    }
    final group = await widget.onCreateGroup(name);
    if (group != null && mounted) {
      setState(() {
        _groups.add(group);
        _groupId = _int(group['groupID'] ?? group['groupId']);
      });
    }
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final group = _groups.cast<Map<String, dynamic>?>().firstWhere(
      (entry) => _int(entry?['groupID'] ?? entry?['groupId']) == _groupId,
      orElse: () => null,
    );
    Navigator.pop(context, <String, Object?>{
      'itemId': 0,
      'itemCode': '',
      'itemName': _itemNameController.text.trim(),
      'itemRate': double.parse(_itemRateController.text),
      'unitId': _unitId,
      'groupId': _groupId,
      'groupName': group?['groupName']?.toString() ?? '',
      'isActive': _isActive,
      'companyId': 0,
      'createdDate': DateTime.now().toIso8601String(),
      'createdBy': 0,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Add Item Master item')),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                selectAllOnFocus: true,
                controller: _itemNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Item name *'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? localizedUiText(context, 'Enter an item name')
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<int?>(_groupId),
                      initialValue: _groupId,
                      decoration: InputDecoration(
                        labelText: localizedUiText(context, 'Group *'),
                      ),
                      items: [
                        for (final group in _groups)
                          if (_int(group['groupID'] ?? group['groupId']) > 0)
                            DropdownMenuItem(
                              value: _int(group['groupID'] ?? group['groupId']),
                              child: Text(group['groupName']?.toString() ?? ''),
                            ),
                      ],
                      onChanged: (value) => setState(() => _groupId = value),
                      validator: (value) => value == null || value <= 0
                          ? localizedUiText(context, 'Select or add a group')
                          : null,
                    ),
                  ),
                  IconButton(
                    tooltip: localizedUiText(context, 'Add group'),
                    onPressed: _addGroup,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: ValueKey<int?>(_unitId),
                initialValue: _unitId,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Unit *'),
                ),
                items: [
                  for (final unit in widget.units)
                    if (_int(unit['unitID'] ?? unit['unitId']) > 0)
                      DropdownMenuItem(
                        value: _int(unit['unitID'] ?? unit['unitId']),
                        child: Text(unit['unitName']?.toString() ?? ''),
                      ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
                validator: (value) => value == null || value <= 0
                    ? localizedUiText(context, 'Select a unit')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                selectAllOnFocus: true,
                controller: _itemRateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Item rate *'),
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final rate = double.tryParse(value ?? '');
                  return rate == null || rate < 0
                      ? localizedUiText(context, 'Enter a valid rate')
                      : null;
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localizedUiText(context, 'Active')),
                value: _isActive,
                onChanged: (value) =>
                    setState(() => _isActive = value ?? false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(localizedUiText(context, 'Save item')),
      ),
    ],
  );
}

class _MasterNameDialogState extends State<_MasterNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, widget.title)),
    content: TextField(
      selectAllOnFocus: true,
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: localizedUiText(context, widget.label),
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(localizedUiText(context, 'Save')),
      ),
    ],
  );
}

class _CatalogVariantDraft {
  int? sizeId;
  int? colorId;
  final quantityController = TextEditingController(text: '1');
  final rateController = TextEditingController(text: '0');

  int get quantity => int.tryParse(quantityController.text) ?? 0;
  double get rate => double.tryParse(rateController.text) ?? -1;

  void dispose() {
    quantityController.dispose();
    rateController.dispose();
    for (final photo in photos) {
      photo.dispose();
    }
  }

  final List<_CatalogPhotoDraft> photos = [];
}

class _CatalogPhotoDraft {
  _CatalogPhotoDraft({
    required this.bytes,
    required this.photoType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String photoType;
  final String fileName;
  final remarksController = TextEditingController();

  void dispose() => remarksController.dispose();
}
