import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/stitch_loader.dart';
import '../rentals/rental_repository.dart';
import '../tailoring/tailoring_repository.dart';

enum MasterKind {
  items,
  groups,
  sizes,
  colors,
  measurements,
  processes,
  units,
  tailors,
  voucherSeries,
}

extension MasterKindLabel on MasterKind {
  String get title => switch (this) {
    MasterKind.items => 'Item Master',
    MasterKind.groups => 'Groups',
    MasterKind.sizes => 'Sizes',
    MasterKind.colors => 'Colors',
    MasterKind.measurements => 'Measurements',
    MasterKind.processes => 'Processes',
    MasterKind.units => 'Units',
    MasterKind.tailors => 'Tailors',
    MasterKind.voucherSeries => 'Voucher series',
  };

  String get singular => switch (this) {
    MasterKind.items => 'item',
    MasterKind.groups => 'group',
    MasterKind.sizes => 'size',
    MasterKind.colors => 'color',
    MasterKind.measurements => 'measurement',
    MasterKind.processes => 'process',
    MasterKind.units => 'unit',
    MasterKind.tailors => 'tailor',
    MasterKind.voucherSeries => 'voucher series',
  };

  IconData get icon => switch (this) {
    MasterKind.items => Icons.inventory_2_outlined,
    MasterKind.groups => Icons.category_outlined,
    MasterKind.sizes => Icons.straighten_outlined,
    MasterKind.colors => Icons.palette_outlined,
    MasterKind.measurements => Icons.square_foot_outlined,
    MasterKind.processes => Icons.work_outline,
    MasterKind.units => Icons.scale_outlined,
    MasterKind.tailors => Icons.content_cut_outlined,
    MasterKind.voucherSeries => Icons.confirmation_number_outlined,
  };

  bool get canCreate => switch (this) {
    MasterKind.items ||
    MasterKind.groups ||
    MasterKind.sizes ||
    MasterKind.colors ||
    MasterKind.measurements ||
    MasterKind.processes => true,
    MasterKind.units || MasterKind.tailors || MasterKind.voucherSeries => false,
  };
}

class MasterManagementScreen extends StatefulWidget {
  const MasterManagementScreen({
    required this.session,
    required this.rentalRepository,
    required this.tailoringRepository,
    required this.kind,
    required this.onOpenMenu,
    this.openCreateOnStart = false,
    this.onOpenAssistant,
    super.key,
  });

  final AuthSession session;
  final RentalRepository rentalRepository;
  final TailoringRepository tailoringRepository;
  final MasterKind kind;
  final VoidCallback? onOpenMenu;
  final bool openCreateOnStart;
  final VoidCallback? onOpenAssistant;

  @override
  State<MasterManagementScreen> createState() => _MasterManagementScreenState();
}

class _MasterManagementScreenState extends State<MasterManagementScreen> {
  late Future<List<Map<String, dynamic>>> _entries;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _units = [];
  String _query = '';
  bool _saving = false;

  String _ui(String source) => localizedUiText(context, source);

  @override
  void initState() {
    super.initState();
    _entries = _load();
    if (widget.kind == MasterKind.items) {
      _loadItemOptions().then((_) {
        if (mounted && widget.openCreateOnStart) _createEntry();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MasterManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != oldWidget.kind) {
      _query = '';
      _entries = _load();
      if (widget.kind == MasterKind.items) _loadItemOptions();
    }
  }

  Future<List<Map<String, dynamic>>> _load() => switch (widget.kind) {
    MasterKind.items => widget.rentalRepository.loadItems(widget.session),
    MasterKind.groups => widget.rentalRepository.loadItemGroups(widget.session),
    MasterKind.sizes => widget.rentalRepository.loadSizes(widget.session),
    MasterKind.colors => widget.rentalRepository.loadColors(widget.session),
    MasterKind.measurements => widget.rentalRepository.loadMeasurements(
      widget.session,
    ),
    MasterKind.processes => widget.tailoringRepository.loadProcesses(
      widget.session,
    ),
    MasterKind.units => widget.rentalRepository.loadItemUnits(widget.session),
    MasterKind.tailors => widget.rentalRepository.loadTailors(widget.session),
    MasterKind.voucherSeries => widget.rentalRepository.loadVoucherSeries(
      widget.session,
    ),
  };

  Future<void> _loadItemOptions() async {
    try {
      final results = await Future.wait([
        widget.rentalRepository.loadItemGroups(widget.session),
        widget.rentalRepository.loadItemUnits(widget.session),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0];
        _units = results[1];
      });
    } catch (error) {
      if (mounted) {
        _message('${_ui('Could not load item form options:')} $error');
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _entries = _load();
    });
    await _entries;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> entries) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries
        .where((entry) {
          return entry.values.any(
            (value) => value?.toString().toLowerCase().contains(query) ?? false,
          );
        })
        .toList(growable: false);
  }

  String _entryTitle(Map<String, dynamic> entry) {
    final keys = switch (widget.kind) {
      MasterKind.items => ['itemName', 'name'],
      MasterKind.groups => ['groupName'],
      MasterKind.sizes => ['sizeName'],
      MasterKind.colors => ['colorName'],
      MasterKind.measurements => ['measurementName'],
      MasterKind.processes => ['processName'],
      MasterKind.units => ['unitTypeName', 'unitName', 'name'],
      MasterKind.tailors => ['fullName', 'employeeName', 'tailorName'],
      MasterKind.voucherSeries => ['voucherSeriesName', 'seriesName'],
    };
    for (final key in keys) {
      final value = entry[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '${_ui('Unnamed')} ${_ui(widget.kind.singular)}';
  }

  String _entrySubtitle(Map<String, dynamic> entry) {
    final parts = switch (widget.kind) {
      MasterKind.items => [
        entry['itemCode'],
        entry['groupName'],
        entry['unitName'],
        entry['itemRate'] == null
            ? null
            : '${_ui('Rate')} ${entry['itemRate']}',
      ],
      MasterKind.groups => [entry['description']],
      MasterKind.sizes => [entry['description']],
      MasterKind.colors => [entry['description']],
      MasterKind.measurements => [entry['description']],
      MasterKind.processes => [entry['processDescription']],
      MasterKind.units => [entry['unitCode']],
      MasterKind.tailors => [entry['mobileNo'] ?? entry['mobileNumber']],
      MasterKind.voucherSeries => [
        entry['menuName'],
        entry['prefix'],
        entry['startingNo'],
      ],
    };
    return parts
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' · ');
  }

  Future<void> _createEntry() async {
    if (widget.kind == MasterKind.items) {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => _ItemMasterDialog(groups: _groups, units: _units),
      );
      if (result == null) return;
      await _save(
        () => widget.rentalRepository.saveItem(widget.session, result),
      );
      return;
    }
    if (widget.kind == MasterKind.processes) {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _ProcessMasterDialog(),
      );
      if (result == null) return;
      await _save(
        () => widget.tailoringRepository.saveProcess(widget.session, result),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _MasterNameDialog(kind: widget.kind),
    );
    if (result == null) return;
    await _save(() async {
      switch (widget.kind) {
        case MasterKind.groups:
          return widget.rentalRepository.saveItemGroup(widget.session, result);
        case MasterKind.sizes:
          return widget.rentalRepository.saveSize(widget.session, result);
        case MasterKind.colors:
          return widget.rentalRepository.saveColor(widget.session, result);
        case MasterKind.measurements:
          return widget.rentalRepository.saveMeasurement(
            widget.session,
            result,
          );
        default:
          throw StateError(
            _ui('Creation is not supported for ${widget.kind.title}.'),
          );
      }
    });
  }

  Future<void> _save(Future<Object?> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      await _refresh();
      _message('${_ui(widget.kind.title)} ${_ui('saved.')}');
    } catch (error) {
      if (mounted) {
        _message('${_ui('Could not save')} ${_ui(widget.kind.title)}: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      leading: widget.onOpenMenu == null
          ? null
          : IconButton(
              tooltip: _ui('Masters and administration'),
              onPressed: widget.onOpenMenu,
              icon: const Icon(Icons.menu),
            ),
      title: Text(_ui(widget.kind.title)),
      actions: [
        if (widget.onOpenAssistant != null)
          IconButton(
            tooltip: _ui('Ask assistant'),
            onPressed: widget.onOpenAssistant,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        IconButton(
          tooltip: _ui('Refresh'),
          onPressed: _saving ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: widget.kind.canCreate
        ? FloatingActionButton.extended(
            onPressed: _saving ? null : _createEntry,
            icon: const Icon(Icons.add),
            label: Text('${_ui('Add')} ${_ui(widget.kind.singular)}'),
            shape: const StadiumBorder(),
          )
        : null,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            selectAllOnFocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '${_ui('Search')} ${_ui(widget.kind.title)}',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MasterLoadError(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: StitchLoader(size: 64, showMonogram: false),
                );
              }
              final entries = _filtered(snapshot.requireData);
              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.kind.icon,
                          size: 42,
                          color: const Color(0xFF8AA5C0),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? '${_ui('No')} ${_ui(widget.kind.title)} ${_ui('yet')}'
                              : _ui('No matches found'),
                          style: const TextStyle(
                            color: Color(0xFF405875),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.kind.canCreate) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${_ui('Use')} ${_ui('Add')} '
                            '${_ui('to create the first')} '
                            '${_ui(widget.kind.singular)}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF778BA2)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final subtitle = _entrySubtitle(entry);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEAF5FF),
                        child: Icon(
                          widget.kind.icon,
                          color: const Color(0xFF1688E8),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _entryTitle(entry),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _MasterNameDialog extends StatefulWidget {
  const _MasterNameDialog({required this.kind});

  final MasterKind kind;

  @override
  State<_MasterNameDialog> createState() => _MasterNameDialogState();
}

class _MasterNameDialogState extends State<_MasterNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Add ${widget.kind.singular}')),
    content: Form(
      key: _formKey,
      child: TextFormField(
        selectAllOnFocus: true,
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: switch (widget.kind) {
            MasterKind.groups => localizedUiText(context, 'Group name'),
            MasterKind.sizes => localizedUiText(context, 'Size name'),
            MasterKind.colors => localizedUiText(context, 'Color name'),
            MasterKind.measurements => localizedUiText(
              context,
              'Measurement name',
            ),
            _ => localizedUiText(context, 'Name'),
          },
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? localizedUiText(context, 'Enter a name')
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(localizedUiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _name.text.trim());
        },
        child: Text(localizedUiText(context, 'Save')),
      ),
    ],
  );
}

class _ProcessMasterDialog extends StatefulWidget {
  const _ProcessMasterDialog();

  @override
  State<_ProcessMasterDialog> createState() => _ProcessMasterDialogState();
}

class _ProcessMasterDialogState extends State<_ProcessMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Add process')),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            selectAllOnFocus: true,
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Process name'),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? localizedUiText(context, 'Enter a process name')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            selectAllOnFocus: true,
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: localizedUiText(context, 'Process description'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(localizedUiText(context, 'Active')),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'processID': 0,
            'processName': _name.text.trim(),
            'processDescription': _description.text.trim(),
            'isActive': _isActive,
          });
        },
        child: Text(localizedUiText(context, 'Save')),
      ),
    ],
  );
}

class _ItemMasterDialog extends StatefulWidget {
  const _ItemMasterDialog({required this.groups, required this.units});

  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> units;

  @override
  State<_ItemMasterDialog> createState() => _ItemMasterDialogState();
}

class _ItemMasterDialogState extends State<_ItemMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rate = TextEditingController(text: '0');
  int? _groupId;
  int? _unitId;
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, 'Add Item Master item')),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                selectAllOnFocus: true,
                key: const Key('master-item-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Item name *'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? localizedUiText(context, 'Enter an item name')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('master-item-group'),
                initialValue: _groupId,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Group *'),
                ),
                items: [
                  for (final group in widget.groups)
                    if (_int(group['groupID'] ?? group['groupId']) > 0)
                      DropdownMenuItem(
                        value: _int(group['groupID'] ?? group['groupId']),
                        child: Text(group['groupName']?.toString() ?? ''),
                      ),
                ],
                onChanged: (value) => setState(() => _groupId = value),
                validator: (value) => value == null
                    ? localizedUiText(context, 'Select a group')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('master-item-unit'),
                initialValue: _unitId,
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Unit *'),
                ),
                items: [
                  for (final unit in widget.units)
                    if (_int(unit['unitID'] ?? unit['unitId']) > 0)
                      DropdownMenuItem(
                        value: _int(unit['unitID'] ?? unit['unitId']),
                        child: Text(
                          unit['unitName']?.toString() ??
                              unit['unitTypeName']?.toString() ??
                              '',
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
                validator: (value) => value == null
                    ? localizedUiText(context, 'Select a unit')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                selectAllOnFocus: true,
                key: const Key('master-item-rate'),
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localizedUiText(context, 'Item rate'),
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount < 0) {
                    return localizedUiText(
                      context,
                      'Enter a valid non-negative rate',
                    );
                  }
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localizedUiText(context, 'Active')),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final selectedGroup = widget.groups.firstWhere(
            (group) => _int(group['groupID'] ?? group['groupId']) == _groupId,
          );
          Navigator.pop(context, <String, Object?>{
            'itemId': 0,
            'itemCode': '',
            'itemName': _name.text.trim(),
            'itemRate': double.parse(_rate.text.trim()),
            'unitId': _unitId,
            'groupId': _groupId,
            'groupName': selectedGroup['groupName']?.toString() ?? '',
            'isActive': _isActive,
            'companyId': 0,
            'createdDate': DateTime.now().toIso8601String(),
            'createdBy': 0,
          });
        },
        child: Text(localizedUiText(context, 'Save item')),
      ),
    ],
  );
}

class _MasterLoadError extends StatelessWidget {
  const _MasterLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFB54150)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(localizedUiText(context, 'Retry')),
          ),
        ],
      ),
    ),
  );
}
