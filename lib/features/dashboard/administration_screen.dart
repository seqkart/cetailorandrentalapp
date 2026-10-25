import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import 'administration_repository.dart';

enum AdministrationKind { customers, users, permissions, company }

extension AdministrationKindLabel on AdministrationKind {
  String get title => switch (this) {
    AdministrationKind.customers => 'Customers',
    AdministrationKind.users => 'Users & roles',
    AdministrationKind.permissions => 'Permissions',
    AdministrationKind.company => 'Company settings',
  };

  IconData get icon => switch (this) {
    AdministrationKind.customers => Icons.people_outline,
    AdministrationKind.users => Icons.manage_accounts_outlined,
    AdministrationKind.permissions => Icons.lock_outline,
    AdministrationKind.company => Icons.business_outlined,
  };
}

class AdministrationScreen extends StatefulWidget {
  const AdministrationScreen({
    required this.session,
    required this.repository,
    required this.kind,
    super.key,
  });

  final AuthSession session;
  final AdministrationRepository repository;
  final AdministrationKind kind;

  @override
  State<AdministrationScreen> createState() => _AdministrationScreenState();
}

class _AdministrationScreenState extends State<AdministrationScreen> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _menus = [];
  Map<String, dynamic> _company = {};
  Map<int, Map<String, dynamic>> _permissions = {};
  Map<String, dynamic>? _selectedUser;
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _ui(String source) => localizedUiText(context, source);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.kind) {
        case AdministrationKind.customers:
          _entries = await widget.repository.loadCustomers(widget.session);
          break;
        case AdministrationKind.users:
          final results = await Future.wait([
            widget.repository.loadUsers(widget.session),
            widget.repository.loadRoles(widget.session),
          ]);
          _entries = results[0];
          _roles = results[1];
          break;
        case AdministrationKind.permissions:
          final results = await Future.wait([
            widget.repository.loadUsers(widget.session),
            widget.repository.loadMenus(widget.session),
          ]);
          _entries = results[0];
          _menus = _flattenMenus(results[1]);
          _selectedUser ??= _entries.firstOrNull;
          if (_selectedUser != null) await _loadPermissions();
          break;
        case AdministrationKind.company:
          _company = await widget.repository.loadCompany(widget.session);
          break;
      }
    } on Object catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPermissions() async {
    final user = _selectedUser;
    if (user == null) return;
    final id = _int(user['userID'] ?? user['userId'] ?? user['id']);
    if (id == null) {
      throw FormatException(_ui('The selected user has no valid user ID.'));
    }
    final loaded = await widget.repository.loadUserPermissions(
      widget.session,
      id,
    );
    _permissions = {};
    for (final permission in loaded) {
      final menuId = _int(permission['menuId'] ?? permission['menuID']);
      if (menuId != null) _permissions[menuId] = permission;
    }
  }

  List<Map<String, dynamic>> _flattenMenus(List<Map<String, dynamic>> entries) {
    final flattened = <Map<String, dynamic>>[];
    void add(Map<String, dynamic> entry) {
      flattened.add(entry);
      final children = entry['children'] ?? entry['subMenus'] ?? entry['menus'];
      if (children is List) {
        for (final child in children.whereType<Map>()) {
          add({for (final e in child.entries) e.key.toString(): e.value});
        }
      }
    }

    for (final entry in entries) {
      add(entry);
    }
    return flattened;
  }

  Future<void> _selectUser(Map<String, dynamic>? user) async {
    setState(() {
      _selectedUser = user;
      _permissions = {};
      _loading = true;
      _error = null;
    });
    try {
      await _loadPermissions();
    } on Object catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCustomer([Map<String, dynamic>? entry]) async {
    final result = await _showForm(
      context,
      title: _ui(entry == null ? 'Add customer' : 'Edit customer'),
      values: entry ?? {'customerID': 0, 'isActive': true},
      fields: const [
        _AdminField('fullName', 'Full name', required: true, maxLength: 200),
        _AdminField(
          'mobileNo',
          'Mobile number',
          keyboardType: TextInputType.phone,
          required: true,
          maxLength: 15,
        ),
        _AdminField('email', 'Email', keyboardType: TextInputType.emailAddress),
        _AdminField('address1', 'Address line 1', maxLength: 300),
        _AdminField('address2', 'Address line 2', maxLength: 300),
        _AdminField(
          'cityID',
          'City ID',
          keyboardType: TextInputType.number,
          numeric: true,
        ),
      ],
      switches: const [_AdminSwitch('isActive', 'Active')],
    );
    if (result == null) return;
    await _save(() => widget.repository.saveCustomer(widget.session, result));
  }

  Future<void> _editUser(Map<String, dynamic> entry) async {
    final roleOptions = _roles
        .map((role) {
          final code = (role['roleCode'] ?? role['code'] ?? '').toString();
          final name = (role['roleName'] ?? role['name'] ?? code).toString();
          return MapEntry(code, name);
        })
        .where((entry) => entry.key.isNotEmpty)
        .toList(growable: false);
    final result = await _showForm(
      context,
      title: _ui('Edit user'),
      values: entry,
      fields: [
        const _AdminField('userName', 'User name', required: true),
        const _AdminField(
          'mobileNo',
          'Mobile number',
          keyboardType: TextInputType.phone,
        ),
        const _AdminField(
          'email',
          'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        _AdminField('roleCode', 'Role', options: roleOptions, required: true),
      ],
      switches: const [_AdminSwitch('isActive', 'Active')],
    );
    if (result == null) return;
    final userId = _int(entry['userID'] ?? entry['userId'] ?? entry['id']);
    if (userId == null) {
      _message(_ui('This user has no valid user ID.'));
      return;
    }
    await _save(
      () => widget.repository.saveUser(widget.session, {
        ...entry,
        ...result,
        'menuId': 0,
        'userID': userId,
      }),
    );
  }

  Future<void> _editCompany() async {
    final result = await _showForm(
      context,
      title: _ui('Company settings'),
      values: {'companyID': _int(_company['companyID']) ?? 0, ..._company},
      fields: const [
        _AdminField('companyName', 'Company name', required: true),
        _AdminField('legalName', 'Legal name'),
        _AdminField('companyCode', 'Company code'),
        _AdminField(
          'companyType',
          'Company type ID',
          keyboardType: TextInputType.number,
          numeric: true,
        ),
        _AdminField('panNumber', 'PAN'),
        _AdminField('gstin', 'GSTIN'),
        _AdminField('tanNumber', 'TAN'),
        _AdminField('cinNumber', 'CIN'),
        _AdminField('addressLine1', 'Address line 1'),
        _AdminField('addressLine2', 'Address line 2'),
        _AdminField(
          'cityID',
          'City ID',
          keyboardType: TextInputType.number,
          numeric: true,
        ),
        _AdminField('pincode', 'PIN code'),
        _AdminField('contactPersonName', 'Contact person'),
        _AdminField(
          'contactPersonMobile',
          'Contact mobile',
          keyboardType: TextInputType.phone,
        ),
        _AdminField('phone', 'Phone', keyboardType: TextInputType.phone),
        _AdminField('email', 'Email', keyboardType: TextInputType.emailAddress),
        _AdminField('website', 'Website', keyboardType: TextInputType.url),
        _AdminField(
          'wapLink',
          'WhatsApp link',
          keyboardType: TextInputType.url,
        ),
        _AdminField(
          'companyLogo',
          'Company logo URL',
          keyboardType: TextInputType.url,
        ),
      ],
      switches: const [
        _AdminSwitch('isActive', 'Active'),
        _AdminSwitch('isGST', 'GST registered'),
        _AdminSwitch('isCompositionScheme', 'Composition scheme'),
      ],
    );
    if (result == null) return;
    await _save(
      () => widget.repository.saveCompany(widget.session, {
        ..._company,
        ...result,
        'appId': widget.session.appId,
        'companyID': _int(_company['companyID']) ?? 0,
      }),
    );
  }

  Future<void> _savePermissions() async {
    final user = _selectedUser;
    if (user == null) return;
    final userId = _int(user['userID'] ?? user['userId'] ?? user['id']);
    if (userId == null) {
      _message(_ui('The selected user has no valid user ID.'));
      return;
    }
    final rows = <Map<String, Object?>>[];
    for (final menu in _menus) {
      final id = _int(menu['menuID'] ?? menu['menuId'] ?? menu['id']);
      if (id == null) continue;
      final permission = _permissions[id] ?? const <String, dynamic>{};
      rows.add({
        'menuId': id,
        for (final action in _permissionActions)
          action.key: permission[action.key] == true,
      });
    }
    await _save(
      () => widget.repository.savePermissions(widget.session, userId, rows),
    );
  }

  Future<void> _save(Future<void> Function() save) async {
    setState(() => _saving = true);
    try {
      await save();
      if (widget.kind == AdministrationKind.permissions) {
        await _selectUser(_selectedUser);
      } else {
        await _load();
      }
      if (mounted) {
        final error = _error;
        _message(
          error == null
              ? _ui('Saved successfully.')
              : '${_ui('Changes were saved, but refresh failed:')} $error',
        );
      }
    } on Object catch (error) {
      if (mounted) _message('${_ui('Could not save:')} $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final isCustomer = widget.kind == AdministrationKind.customers;
    final id = _int(
      isCustomer
          ? entry['customerID'] ?? entry['customerId'] ?? entry['id']
          : entry['userID'] ?? entry['userId'] ?? entry['id'],
    );
    if (id == null) {
      _message(_ui('This record has no valid ID.'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${_ui('Delete')} ${_ui(isCustomer ? 'Customer' : 'User').toLowerCase()}?',
        ),
        content: Text(_ui('This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_ui('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_ui('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _save(
      () => isCustomer
          ? widget.repository.deleteCustomer(widget.session, id)
          : widget.repository.deleteUser(widget.session, id),
    );
  }

  void _setPermission(int menuId, String action, bool value) {
    setState(() {
      _permissions[menuId] = {
        ...?_permissions[menuId],
        'menuId': menuId,
        action: value,
      };
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ui(widget.kind.title)),
        actions: [
          if (widget.kind == AdministrationKind.customers)
            IconButton(
              tooltip: _ui('Add customer'),
              onPressed: _loading || _saving ? null : _editCustomer,
              icon: const Icon(Icons.add),
            ),
          if (widget.kind == AdministrationKind.users)
            IconButton(
              tooltip: _ui(
                'New user creation unavailable until password format is confirmed',
              ),
              onPressed: null,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          if (widget.kind == AdministrationKind.company)
            IconButton(
              tooltip: _ui('Edit company'),
              onPressed: _loading || _saving ? null : _editCompany,
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: _ui('Refresh'),
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : _content(),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_ui('Try again')),
          ),
        ],
      ),
    ),
  );

  Widget _content() => switch (widget.kind) {
    AdministrationKind.customers => _customerList(),
    AdministrationKind.users => _userList(),
    AdministrationKind.permissions => _permissionsView(),
    AdministrationKind.company => _companyView(),
  };

  Widget _customerList() {
    final query = _query.trim().toLowerCase();
    final entries = _entries.where((entry) {
      return entry.values.any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
    return Column(
      children: [
        _searchBox('Search customers'),
        Expanded(
          child: entries.isEmpty
              ? _empty('No customers found.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final customer = entries[index];
                    return _recordCard(
                      title:
                          customer['fullName']?.toString() ??
                          customer['customerName']?.toString() ??
                          _ui('Customer'),
                      subtitle: [
                        customer['mobileNo'],
                        customer['email'],
                      ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                      onEdit: () => _editCustomer(customer),
                      onDelete: () => _delete(customer),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _userList() => Column(
    children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF966300)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _ui(
                  'Adding users is paused until the API password-hash format is confirmed. Existing users can still be managed.',
                ),
              ),
            ),
          ],
        ),
      ),
      _searchBox('Search users'),
      Expanded(
        child: _filteredEntries().isEmpty
            ? _empty('No users found.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _filteredEntries().length,
                itemBuilder: (context, index) {
                  final user = _filteredEntries()[index];
                  return _recordCard(
                    title: user['userName']?.toString() ?? _ui('User'),
                    subtitle: [
                      user['roleName'] ?? user['roleCode'],
                      user['mobileNo'],
                      user['email'],
                    ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                    onEdit: () => _editUser(user),
                    onDelete: () => _delete(user),
                  );
                },
              ),
      ),
    ],
  );

  Widget _permissionsView() {
    final menus = _menus
        .where(
          (menu) =>
              _int(menu['menuID'] ?? menu['menuId'] ?? menu['id']) != null,
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedUser,
            decoration: InputDecoration(
              labelText: _ui('Select user'),
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: _entries
                .map(
                  (user) => DropdownMenuItem(
                    value: user,
                    child: Text(
                      user['userName']?.toString() ?? _ui('User'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving ? null : _selectUser,
          ),
        ),
        Expanded(
          child: _selectedUser == null
              ? _empty('No users are available.')
              : menus.isEmpty
              ? _empty('No menu permissions were returned by the API.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  children: [for (final menu in menus) _permissionTile(menu)],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _selectedUser == null
                    ? null
                    : _savePermissions,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_ui('Save permissions')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _permissionTile(Map<String, dynamic> menu) {
    final menuId = _int(menu['menuID'] ?? menu['menuId'] ?? menu['id'])!;
    final permission = _permissions[menuId] ?? const <String, dynamic>{};
    final name =
        menu['menuName'] ??
        menu['menuTitle'] ??
        menu['name'] ??
        '${_ui('Menu')} $menuId';
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(name.toString()),
        subtitle: Text(
          _ui(
            permission['access'] == true ? 'Access enabled' : 'Access disabled',
          ),
        ),
        children: [
          for (final action in _permissionActions)
            SwitchListTile.adaptive(
              title: Text(_ui(action.label)),
              value: permission[action.key] == true,
              onChanged: _saving
                  ? null
                  : (value) => _setPermission(menuId, action.key, value),
            ),
        ],
      ),
    );
  }

  Widget _companyView() {
    final fields = [
      ('Company', _company['companyName']),
      ('Legal name', _company['legalName']),
      ('Company code', _company['companyCode']),
      ('Contact', _company['contactPersonName']),
      ('Phone', _company['phone'] ?? _company['contactPersonMobile']),
      ('Email', _company['email']),
      ('Address', _company['addressLine1']),
      ('GSTIN', _company['gstin']),
    ].where((field) => field.$2 != null && '${field.$2}'.isNotEmpty).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.business_outlined,
                  color: Color(0xFF1688E8),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  _company['companyName']?.toString() ?? _ui('Company profile'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (fields.isEmpty)
                  Text(_ui('No company profile is configured yet.'))
                else
                  for (final field in fields)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_ui(field.$1)),
                      subtitle: Text(field.$2.toString()),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _editCompany,
          icon: const Icon(Icons.edit_outlined),
          label: Text(_ui(fields.isEmpty ? 'Set up company' : 'Edit company')),
        ),
      ],
    );
  }

  Widget _searchBox(String hint) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: _ui(hint),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: _ui('Clear search'),
                onPressed: () => setState(() => _query = ''),
                icon: const Icon(Icons.close),
              ),
      ),
    ),
  );

  List<Map<String, dynamic>> _filteredEntries() {
    final query = _query.trim().toLowerCase();
    return _entries.where((entry) {
      return entry.values.any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Widget _recordCard({
    required String title,
    required String subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase()),
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        tooltip: _ui('Record actions'),
        onSelected: (action) {
          if (action == 'edit') onEdit();
          if (action == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(_ui('Edit'))),
          PopupMenuItem(value: 'delete', child: Text(_ui('Delete'))),
        ],
      ),
    ),
  );

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(_ui(text), textAlign: TextAlign.center),
    ),
  );

  Future<Map<String, Object?>?> _showForm(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> values,
    required List<_AdminField> fields,
    List<_AdminSwitch> switches = const [],
  }) => showDialog<Map<String, Object?>>(
    context: context,
    builder: (context) => _AdministrationFormDialog(
      title: title,
      values: values,
      fields: fields,
      switches: switches,
    ),
  );
}

class _AdminField {
  const _AdminField(
    this.key,
    this.label, {
    this.required = false,
    this.maxLength,
    this.keyboardType,
    this.numeric = false,
    this.options = const [],
  });

  final String key;
  final String label;
  final bool required;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool numeric;
  final List<MapEntry<String, String>> options;
}

class _AdminSwitch {
  const _AdminSwitch(this.key, this.label);

  final String key;
  final String label;
}

class _AdministrationFormDialog extends StatefulWidget {
  const _AdministrationFormDialog({
    required this.title,
    required this.values,
    required this.fields,
    required this.switches,
  });

  final String title;
  final Map<String, dynamic> values;
  final List<_AdminField> fields;
  final List<_AdminSwitch> switches;

  @override
  State<_AdministrationFormDialog> createState() =>
      _AdministrationFormDialogState();
}

class _AdministrationFormDialogState extends State<_AdministrationFormDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(
        text: widget.values[field.key]?.toString() ?? '',
      ),
  };
  late final Map<String, bool> _switchValues = {
    for (final field in widget.switches)
      field.key: widget.values[field.key] == true,
  };
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final values = <String, Object?>{};
    for (final field in widget.fields) {
      final text = _controllers[field.key]!.text.trim();
      if (field.options.isNotEmpty) {
        values[field.key] = text;
      } else if (field.numeric) {
        values[field.key] = text.isEmpty ? null : int.tryParse(text);
      } else {
        values[field.key] = text.isEmpty ? null : text;
      }
    }
    values.addAll(_switchValues);
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(localizedUiText(context, widget.title)),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields) ...[
                if (field.options.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue:
                        field.options.any(
                          (option) =>
                              option.key == _controllers[field.key]!.text,
                        )
                        ? _controllers[field.key]!.text
                        : null,
                    decoration: InputDecoration(
                      labelText: localizedUiText(context, field.label),
                    ),
                    items: field.options
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.key,
                            child: Text(option.value),
                          ),
                        )
                        .toList(),
                    validator: field.required
                        ? (value) => value == null
                              ? localizedUiText(context, 'Required')
                              : null
                        : null,
                    onChanged: (value) =>
                        _controllers[field.key]!.text = value ?? '',
                  )
                else
                  TextFormField(
                    controller: _controllers[field.key],
                    keyboardType:
                        field.keyboardType ??
                        (field.numeric ? TextInputType.number : null),
                    maxLength: field.maxLength,
                    selectAllOnFocus: true,
                    decoration: InputDecoration(
                      labelText: localizedUiText(context, field.label),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (field.required &&
                          (value == null || value.trim().isEmpty)) {
                        return localizedUiText(context, 'Required');
                      }
                      if (field.key == 'mobileNo' &&
                          value != null &&
                          value.isNotEmpty &&
                          !RegExp(r'^\d{10,15}$').hasMatch(value.trim())) {
                        return localizedUiText(context, 'Enter 10–15 digits');
                      }
                      if (field.numeric &&
                          value != null &&
                          value.isNotEmpty &&
                          int.tryParse(value.trim()) == null) {
                        return localizedUiText(context, 'Enter a whole number');
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 10),
              ],
              for (final field in widget.switches)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizedUiText(context, field.label)),
                  value: _switchValues[field.key] ?? false,
                  onChanged: (value) =>
                      setState(() => _switchValues[field.key] = value),
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
        onPressed: _submit,
        child: Text(localizedUiText(context, 'Save')),
      ),
    ],
  );
}

class _PermissionAction {
  const _PermissionAction(this.key, this.label);

  final String key;
  final String label;
}

const _permissionActions = [
  _PermissionAction('access', 'Access'),
  _PermissionAction('add', 'Add'),
  _PermissionAction('edit', 'Edit'),
  _PermissionAction('delete', 'Delete'),
  _PermissionAction('print', 'Print'),
  _PermissionAction('export', 'Export'),
];

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
