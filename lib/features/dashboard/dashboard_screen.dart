import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/app_date_format.dart';
import '../../core/session_store.dart';
import '../assistant/app_assistant_screen.dart';
import 'dashboard_repository.dart';
import 'master_management_screen.dart';
import '../rentals/rental_repository.dart';
import '../rentals/rental_workflow_screen.dart';
import '../reports/reports_repository.dart';
import '../reports/reports_screen.dart';
import '../tailoring/tailoring_repository.dart';
import '../tailoring/tailoring_workflow_screen.dart';
import '../../widgets/stitch_loader.dart';
import '../../widgets/language_picker.dart';
import '../../l10n/app_strings.dart';
import 'administration_repository.dart';
import 'administration_screen.dart';

enum _DashboardSection { home, tailoring, rentals, reports, master, assistant }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.session,
    required this.repository,
    required this.rentalRepository,
    required this.reportsRepository,
    required this.tailoringRepository,
    required this.administrationRepository,
    this.locale,
    this.onLocaleChanged,
    required this.onSignOut,
    super.key,
  });

  final AuthSession session;
  final DashboardRepository repository;
  final RentalRepository rentalRepository;
  final ReportsRepository reportsRepository;
  final TailoringRepository tailoringRepository;
  final AdministrationRepository administrationRepository;
  final Locale? locale;
  final Future<void> Function(Locale locale)? onLocaleChanged;
  final Future<void> Function() onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _wakeSpeech = SpeechToText();
  late Future<DashboardSnapshot> _dashboard;
  _DashboardSection _section = _DashboardSection.home;
  MasterKind _masterKind = MasterKind.items;
  bool _masterOpenCreate = false;
  bool _appInForeground = true;
  bool _wakeInitialized = false;
  bool _wakeAvailable = false;
  bool _wakeListening = false;
  bool _wakeStarting = false;
  String? _wakeError;
  Timer? _wakeRestartTimer;
  int _rentalInitialTab = 0;
  int _tailoringInitialTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboard = widget.repository.load(widget.session);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWakeListening());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeRestartTimer?.cancel();
    _wakeSpeech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      _startWakeListening();
    } else {
      _stopWakeListening();
    }
  }

  bool get _shouldListenForWakeWord =>
      mounted && _appInForeground && _section != _DashboardSection.assistant;

  Future<void> _startWakeListening() async {
    if (!_shouldListenForWakeWord ||
        _wakeStarting ||
        _wakeListening ||
        (_wakeInitialized && !_wakeAvailable)) {
      return;
    }
    _wakeRestartTimer?.cancel();
    _wakeStarting = true;
    try {
      if (!_wakeInitialized) {
        _wakeAvailable = await _wakeSpeech.initialize(
          onStatus: _onWakeStatus,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _wakeListening = false;
              if (error.permanent) _wakeAvailable = false;
              _wakeError = error.errorMsg;
            });
            if (!error.permanent) _scheduleWakeRestart();
          },
        );
        _wakeInitialized = true;
      }
      if (!_wakeAvailable) {
        _wakeError = 'Voice activation unavailable: speech recognition is unavailable on this device.';
        return;
      }
      if (!_shouldListenForWakeWord) return;
      _wakeError = null;
      await _wakeSpeech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (!RegExp(
            r'\bhey[\s,]+ava\b|हे\s*अवा|ਹੇ\s*ਅਵਾ',
            caseSensitive: false,
          ).hasMatch(result.recognizedWords)) {
            return;
          }
          _wakeRestartTimer?.cancel();
          setState(() {
            _wakeListening = false;
            _section = _DashboardSection.assistant;
          });
          _wakeSpeech.stop();
        },
      );
    } catch (error) {
      _wakeInitialized = true;
      _wakeAvailable = false;
      _wakeError = 'Voice activation unavailable: $error';
      _wakeListening = false;
    } finally {
      _wakeStarting = false;
      if (mounted) setState(() {});
    }
  }

  void _onWakeStatus(String status) {
    if (!mounted) return;
    setState(() => _wakeListening = status == 'listening');
    if (status == 'done' || status == 'notListening') {
      _scheduleWakeRestart();
    }
  }

  void _scheduleWakeRestart() {
    _wakeRestartTimer?.cancel();
    if (!_shouldListenForWakeWord) return;
    _wakeRestartTimer = Timer(const Duration(milliseconds: 800), () {
      _startWakeListening();
    });
  }

  void _stopWakeListening() {
    _wakeRestartTimer?.cancel();
    if (_wakeListening || _wakeStarting) {
      _wakeSpeech.stop();
    }
    if (_wakeListening && mounted) {
      setState(() => _wakeListening = false);
    }
  }

  Future<void> _refresh() async {
    final future = widget.repository.load(widget.session);
    setState(() {
      _dashboard = future;
    });
    await future;
  }

  void _selectSection(
    _DashboardSection section, {
    int? rentalTab,
    int? tailoringTab,
  }) {
    setState(() {
      _section = section;
      _masterOpenCreate = false;
      if (section == _DashboardSection.rentals) {
        _rentalInitialTab = rentalTab ?? 0;
      }
      if (section == _DashboardSection.tailoring) {
        _tailoringInitialTab = tailoringTab ?? 0;
      }
    });
    if (section == _DashboardSection.assistant) {
      _stopWakeListening();
    } else {
      _scheduleWakeRestart();
    }
  }

  void _openAdminMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openItemMaster({required bool create}) {
    setState(() {
      _masterKind = MasterKind.items;
      _masterOpenCreate = create;
      _section = _DashboardSection.master;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = appStrings(context);
    final canViewTailoring = widget.session.canViewTailoring;
    final canViewRentals = widget.session.canViewRentals;
    return PopScope<Object?>(
      canPop: _section == _DashboardSection.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _section != _DashboardSection.home) {
          _selectSection(_DashboardSection.home);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF1F6FC),
        drawer: widget.session.isAdmin ? _buildAdminDrawer() : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: switch (_section) {
                _DashboardSection.home => FutureBuilder<DashboardSnapshot>(
                  future: _dashboard,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _LoadError(
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: StitchLoader(size: 64, showMonogram: false),
                      );
                    }
                    final data = snapshot.requireData;
                    final showBothWorkflows =
                        canViewTailoring && canViewRentals;
                    return Stack(
                      children: [
                        const Positioned.fill(child: _DashboardBackdrop()),
                        RefreshIndicator(
                          onRefresh: _refresh,
                          color: const Color(0xFF1688E8),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _DashboardHeader(
                                userName: widget.session.userName,
                                companyName: widget.session.companyName,
                                companyLogo: widget.session.companyLogo,
                                financialYear: widget.session.financialYearName,
                                locale:
                                    widget.locale ??
                                    Localizations.localeOf(context),
                                onLocaleChanged: widget.onLocaleChanged,
                                onSignOut: () => _signOut(context),
                                onOpenMenu: widget.session.isAdmin
                                    ? _openAdminMenu
                                    : null,
                                onOpenAssistant: () =>
                                    _selectSection(_DashboardSection.assistant),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  22,
                                  18,
                                  30,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (canViewTailoring) ...[
                                      _SectionHeading(
                                        title: strings.businessOverview,
                                        subtitle: strings.tailoringActivity,
                                      ),
                                      const SizedBox(height: 14),
                                      _OverviewCard(
                                        orders: data.totalOrders,
                                        customers: data.totalCustomers,
                                        ordersToday: data.ordersToday,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                    if (canViewTailoring || canViewRentals) ...[
                                      _SectionHeading(
                                        title: showBothWorkflows
                                            ? strings.ordersByType
                                            : canViewTailoring
                                            ? strings.tailoringWorkflow
                                            : strings.rentalWorkflow,
                                        subtitle: showBothWorkflows
                                            ? 'Separate stitching work from rental orders'
                                            : canViewTailoring
                                            ? 'Stitching, fittings & tailor deliveries'
                                            : 'Bookings, delivery, alterations & returns',
                                      ),
                                      const SizedBox(height: 14),
                                      if (canViewTailoring)
                                        _OrderStatusCard(
                                          title: localizedUiText(
                                            context,
                                            'Tailoring orders',
                                          ),
                                          subtitle: localizedUiText(
                                            context,
                                            'Stitching, fittings & tailor deliveries',
                                          ),
                                          icon: Icons.content_cut_rounded,
                                          color: const Color(0xFF158878),
                                          statuses: data.tailoringStatuses,
                                          emptyMessage: 'Stitching status counts are not available yet.',
                                        ),
                                      if (showBothWorkflows)
                                        const SizedBox(height: 12),
                                      if (canViewRentals)
                                        _OrderStatusCard(
                                          title: localizedUiText(
                                            context,
                                            'Rental orders',
                                          ),
                                          subtitle: localizedUiText(
                                            context,
                                            'Bookings, delivery, alterations & returns',
                                          ),
                                          icon: Icons.checkroom_outlined,
                                          color: const Color(0xFF8259B1),
                                          statuses: data.rentalStatuses,
                                          emptyMessage: 'Rental status counts are not available.',
                                        ),
                                      const SizedBox(height: 25),
                                    ],
                                    if (canViewRentals) ...[
                                      const SizedBox(height: 26),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _SectionHeading(
                                              title: strings.needsAttention,
                                              subtitle:
                                                  'Stay ahead of today’s work',
                                            ),
                                          ),
                                          _LiveIndicator(
                                            label: data.overdueRentals == null
                                                ? 'UPDATING'
                                                : 'LIVE',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _AttentionCard(
                                              label: localizedUiText(
                                                context,
                                                'Rentals due',
                                              ),
                                              value: data.rentalsDueToday,
                                              icon: Icons
                                                  .event_available_outlined,
                                              color: const Color(0xFFD7793B),
                                              background: const Color(
                                                0xFFFFF2E8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _AttentionCard(
                                              label: localizedUiText(
                                                context,
                                                'Overdue returns',
                                              ),
                                              value: data.overdueRentals,
                                              icon: Icons
                                                  .assignment_late_outlined,
                                              color: const Color(0xFFC74C5C),
                                              background: const Color(
                                                0xFFFFECEE,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 28),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SectionHeading(
                                            title: strings.recentPayments,
                                            subtitle:
                                                'Latest customer transactions',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _showComingSoon(
                                            context,
                                            'Payments',
                                          ),
                                          child: Text(strings.viewAll),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (data.recentPayments.isEmpty)
                                      const _PaymentEmptyState()
                                    else
                                      ...data.recentPayments
                                          .take(5)
                                          .map(
                                            (payment) =>
                                                _PaymentTile(payment: payment),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _DashboardSection.tailoring => TailoringWorkflowScreen(
                  session: widget.session,
                  repository: widget.tailoringRepository,
                  initialTab: _tailoringInitialTab,
                  onOpenAssistant: () =>
                      _selectSection(_DashboardSection.assistant),
                  onOpenMenu: widget.session.isAdmin ? _openAdminMenu : null,
                ),
                _DashboardSection.rentals => RentalWorkflowScreen(
                  session: widget.session,
                  repository: widget.rentalRepository,
                  initialTab: _rentalInitialTab,
                  onOpenAssistant: () =>
                      _selectSection(_DashboardSection.assistant),
                  onOpenMenu: widget.session.isAdmin ? _openAdminMenu : null,
                ),
                _DashboardSection.reports => ReportsScreen(
                  session: widget.session,
                  repository: widget.reportsRepository,
                  onOpenAssistant: () =>
                      _selectSection(_DashboardSection.assistant),
                  onOpenMenu: widget.session.isAdmin ? _openAdminMenu : null,
                ),
                _DashboardSection.master => MasterManagementScreen(
                  key: ValueKey((_masterKind, _masterOpenCreate)),
                  session: widget.session,
                  rentalRepository: widget.rentalRepository,
                  tailoringRepository: widget.tailoringRepository,
                  kind: _masterKind,
                  onOpenMenu: widget.session.isAdmin ? _openAdminMenu : null,
                  openCreateOnStart: _masterOpenCreate,
                  onOpenAssistant: () =>
                      _selectSection(_DashboardSection.assistant),
                ),
                _DashboardSection.assistant => AppAssistantScreen(
                  session: widget.session,
                  rentalRepository: widget.rentalRepository,
                  tailoringRepository: widget.tailoringRepository,
                  onClose: () => _selectSection(_DashboardSection.home),
                  onStartTailoringOrder: () => _selectSection(
                    _DashboardSection.tailoring,
                    tailoringTab: 1,
                  ),
                  onOpenTailoringOrders: () => _selectSection(
                    _DashboardSection.tailoring,
                    tailoringTab: 0,
                  ),
                  onOpenRentals: (tab) =>
                      _selectSection(_DashboardSection.rentals, rentalTab: tab),
                  onCreateItem: () => _openItemMaster(create: true),
                  onLocaleChanged: widget.onLocaleChanged ?? (_) async {},
                ),
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: localizedUiText(context, 'Home'),
          onPressed: () => _selectSection(_DashboardSection.home),
          shape: const CircleBorder(),
          child: const Icon(Icons.home_rounded, size: 24),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: BottomAppBar(
              color: const Color(0xEFFFFFFF),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (canViewTailoring)
                            _BottomDestination(
                              icon: Icons.content_cut_outlined,
                              label: strings.tailor,
                              selected: _section == _DashboardSection.tailoring,
                              onTap: () =>
                                  _selectSection(_DashboardSection.tailoring),
                            ),
                          if (canViewRentals)
                            _BottomDestination(
                              icon: Icons.checkroom_outlined,
                              label: strings.rental,
                              selected: _section == _DashboardSection.rentals,
                              onTap: () =>
                                  _selectSection(_DashboardSection.rentals),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BottomDestination(
                            icon: Icons.assessment_outlined,
                            label: strings.reports,
                            selected: _section == _DashboardSection.reports,
                            onTap: () =>
                                _selectSection(_DashboardSection.reports),
                          ),
                          _BottomDestination(
                            icon: Icons.auto_awesome_rounded,
                            label: strings.ava,
                            tooltip:
                                _wakeError ??
                                (_wakeListening
                                    ? strings.heyAvaListening
                                    : strings.openAva),
                            selected: _section == _DashboardSection.assistant,
                            listening: _wakeListening,
                            warning: _wakeError != null,
                            onTap: () =>
                                _selectSection(_DashboardSection.assistant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    final strings = appStrings(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8F4FF), Color(0xFFD9ECFF)],
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFD1E5F8))),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFF1688E8),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.session.companyName,
                      style: const TextStyle(
                        color: Color(0xFF142C4B),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.session.userName} · Admin',
                      style: const TextStyle(color: Color(0xFF627B98)),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(strings.home),
              onTap: () {
                Navigator.pop(context);
                _selectSection(_DashboardSection.home);
              },
            ),
            ExpansionTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(strings.masters),
              children: [
                _drawerItem(MasterKind.items),
                _drawerItem(MasterKind.groups),
                _drawerItem(MasterKind.sizes),
                _drawerItem(MasterKind.colors),
                _drawerItem(MasterKind.measurements),
                _drawerItem(MasterKind.units),
                _drawerItem(MasterKind.processes),
                _drawerItem(MasterKind.tailors),
                _drawerItem(MasterKind.voucherSeries),
              ],
            ),
            if (widget.session.isAdmin)
              ExpansionTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(strings.administration),
                children: [
                  _adminDrawerItem(AdministrationKind.customers),
                  _adminDrawerItem(AdministrationKind.users),
                  _adminDrawerItem(AdministrationKind.permissions),
                  _adminDrawerItem(AdministrationKind.company),
                ],
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(strings.signOut),
              onTap: () {
                Navigator.pop(context);
                _signOut(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(MasterKind kind) => ListTile(
    leading: Icon(kind.icon, size: 21),
    title: Text(kind == MasterKind.items ? 'Item Master' : kind.title),
    dense: true,
    onTap: () {
      Navigator.pop(context);
      setState(() {
        _masterKind = kind;
        _masterOpenCreate = false;
        _section = _DashboardSection.master;
      });
    },
  );

  Widget _adminDrawerItem(AdministrationKind kind) => ListTile(
    leading: Icon(kind.icon, size: 21),
    title: Text(kind.title),
    dense: true,
    onTap: () {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdministrationScreen(
            session: widget.session,
            repository: widget.administrationRepository,
            kind: kind,
          ),
        ),
      );
    },
  );

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is next in the build.')));
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await widget.onSignOut();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
    }
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
    required this.icon,
    required this.label,
    this.tooltip,
    required this.selected,
    this.listening = false,
    this.warning = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final bool selected;
  final bool listening;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1688E8).withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? const Color(0xFF1688E8)
                          : const Color(0xFF8997AA),
                      size: 21,
                    ),
                    if (listening || warning)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: warning
                                ? const Color(0xFFD75264)
                                : const Color(0xFF1B9A65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF1688E8)
                      : const Color(0xFF8290A3),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF17243D),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF68768C)),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.companyName,
    required this.companyLogo,
    required this.financialYear,
    required this.locale,
    required this.onLocaleChanged,
    required this.onSignOut,
    required this.onOpenMenu,
    required this.onOpenAssistant,
  });

  final String userName;
  final String companyName;
  final String companyLogo;
  final String financialYear;
  final Locale locale;
  final Future<void> Function(Locale locale)? onLocaleChanged;
  final VoidCallback onSignOut;
  final VoidCallback? onOpenMenu;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    final strings = appStrings(context);
    final now = DateTime.now();
    final date = formatDisplayDate(now);
    final firstName = userName.trim().split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF4FF), Color(0xFFDDEEFF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: Color(0xFFD8E8F8))),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -72,
            right: -54,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFF64B5F6).withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (onOpenMenu != null) ...[
                        _HeaderIconButton(
                          tooltip: 'Masters and administration',
                          icon: Icons.menu_rounded,
                          onPressed: onOpenMenu!,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1A5E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Image.asset(
                          'assets/images/logo_mark.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CREATIVE EASE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF142C4B),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              localizedUiText(context, 'TAILORING & RENTALS'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF73849A),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onLocaleChanged != null)
                        LanguagePicker(
                          locale: locale,
                          onChanged: onLocaleChanged!,
                        ),
                      _HeaderIconButton(
                        tooltip: strings.openAva,
                        icon: Icons.auto_awesome_rounded,
                        onPressed: onOpenAssistant,
                      ),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        tooltip: strings.signOut,
                        icon: Icons.logout_rounded,
                        onPressed: onSignOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _PartyLogo(
                                  companyName: companyName,
                                  logo: companyLogo,
                                ),
                                const SizedBox(width: 9),
                                Flexible(
                                  child: Text(
                                    companyName.isEmpty
                                        ? 'YOUR STUDIO'
                                        : companyName.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF7B8DA4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  color: Color(0xFF142C4B),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                                children: [
                                  TextSpan(
                                    text: switch (locale.languageCode) {
                                      'hi' => 'नमस्ते',
                                      'pa' => 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
                                      _ => 'Good day',
                                    },
                                  ),
                                  if (firstName.isNotEmpty) ...[
                                    const TextSpan(text: ',\n'),
                                    TextSpan(
                                      text: firstName,
                                      style: const TextStyle(
                                        color: Color(0xFF1688E8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _GlassPill(
                        icon: Icons.calendar_today_outlined,
                        label: date,
                      ),
                      const Spacer(),
                      if (financialYear.isNotEmpty)
                        _GlassPill(
                          icon: Icons.event_note_outlined,
                          label: 'FY $financialYear',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyLogo extends StatelessWidget {
  const _PartyLogo({required this.companyName, required this.logo});

  final String companyName;
  final String logo;

  @override
  Widget build(BuildContext context) {
    final source = logo.trim();
    final uri = Uri.tryParse(source);
    final imageUri = uri == null
        ? null
        : uri.hasScheme
        ? uri
        : Uri.parse('https://tailorapi.creativeease.app/').resolve(source);

    return Container(
      key: const ValueKey('party-logo'),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD8E8F8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUri == null || source.isEmpty
          ? _fallback()
          : Image.network(
              imageUri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
    );
  }

  Widget _fallback() {
    final initial = companyName.trim().isEmpty
        ? null
        : companyName.trim().characters.first.toUpperCase();
    return Center(
      child: initial == null
          ? const Icon(
              Icons.storefront_outlined,
              size: 19,
              color: Color(0xFF1688E8),
            )
          : Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF1688E8),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      foregroundColor: const Color(0xFF243E5F),
      side: const BorderSide(color: Color(0xFFDDEAF7)),
      fixedSize: const Size(42, 42),
    ),
    icon: Icon(icon, size: 19),
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1688E8), size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF455B75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFF0F6FC), Color(0xFFF8FAFD)],
          ),
        ),
        child: SizedBox.expand(),
      ),
      Positioned(
        top: 280,
        right: -60,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFFB7DDFF).withValues(alpha: 0.24),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ],
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C244D7A),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.statuses,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<DashboardStatusCount> statuses;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1B2A43),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF748198),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (statuses.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(color: Color(0xFF748198), fontSize: 12),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in statuses)
                      SizedBox(
                        width: itemWidth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  status.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                status.count?.toString() ?? '—',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.orders,
    required this.customers,
    required this.ordersToday,
  });

  final int? orders;
  final int? customers;
  final int? ordersToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF167DE2), Color(0xFF32A9EF), Color(0xFF4ABDE9)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261688E8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'All-time tailor orders',
                  style: TextStyle(
                    color: Color(0xD6FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      localizedUiText(context, 'OVERVIEW'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (orders ?? 0).toDouble()),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              orders == null ? '—' : value.toInt().toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.28)),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  icon: Icons.people_alt_outlined,
                  label: localizedUiText(context, 'Customers'),
                  value: customers,
                  color: Colors.white,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.32),
              ),
              Expanded(
                child: _OverviewStat(
                  icon: Icons.today_outlined,
                  label: localizedUiText(context, 'Orders today'),
                  value: ordersToday,
                  color: const Color(0xFF158878),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value?.toString() ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  localizedUiText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isLive = label == 'LIVE';
    final color = isLive ? const Color(0xFF17816D) : const Color(0xFF8A6A27);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFE5F4EF) : const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value?.toString() ?? '—',
            style: TextStyle(
              color: value != null && value! > 0
                  ? color
                  : const Color(0xFF172A4B),
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF68768C),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentEmptyState extends StatelessWidget {
  const _PaymentEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _GlassPanel(
      padding: EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: Color(0xFF8A96A9)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'New payments will appear here.',
              style: TextStyle(color: Color(0xFF69778D), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Object? payment;

  @override
  Widget build(BuildContext context) {
    final data = payment is Map<String, dynamic>
        ? payment! as Map<String, dynamic>
        : null;
    final label =
        data?['customerName']?.toString() ??
        data?['paymentMode']?.toString() ??
        'Payment';
    final amount = data?['amount'] ?? data?['totalAmount'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassPanel(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE6F5EE),
            child: Icon(Icons.payments_outlined, color: Color(0xFF188A64)),
          ),
          title: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1B2A43),
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Text(
            amount?.toString() ?? '—',
            style: const TextStyle(
              color: Color(0xFF172A4B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46),
            const SizedBox(height: 12),
            const Text(
              'Could not load your dashboard',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
