import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.session,
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final AuthSession session;
  final DashboardRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSnapshot> _dashboard;
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repository.load(widget.session);
  }

  Future<void> _refresh() async {
    final future = widget.repository.load(widget.session);
    setState(() {
      _dashboard = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Tailoring & Rentals'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackdrop()),
          SafeArea(
            bottom: false,
            child: FutureBuilder<DashboardSnapshot>(
              future: _dashboard,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.requireData;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    children: [
                      _Entrance(
                        child: _WelcomeCard(
                          userName: widget.session.userName,
                          companyName: widget.session.companyName,
                          financialYear: widget.session.financialYearName,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _SectionHeading(
                        title: 'Today at a glance',
                        subtitle: 'A quick look at your business',
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.42,
                        children: [
                          _Entrance(
                            delay: 0,
                            child: _MetricCard(
                              label: 'Customers',
                              value: data.totalCustomers,
                              icon: Icons.people_alt_outlined,
                              color: const Color(0xFF2F80ED),
                            ),
                          ),
                          _Entrance(
                            delay: 70,
                            child: _MetricCard(
                              label: 'Tailor orders',
                              value: data.totalOrders,
                              icon: Icons.receipt_long_outlined,
                              color: const Color(0xFF12A783),
                            ),
                          ),
                          _Entrance(
                            delay: 140,
                            child: _MetricCard(
                              label: 'Orders today',
                              value: data.ordersToday,
                              icon: Icons.today_outlined,
                              color: const Color(0xFFF0A13B),
                            ),
                          ),
                          _Entrance(
                            delay: 210,
                            child: _MetricCard(
                              label: 'Pending orders',
                              value: data.pendingOrders,
                              icon: Icons.pending_actions_outlined,
                              color: const Color(0xFF8C61D8),
                            ),
                          ),
                          _Entrance(
                            delay: 280,
                            child: _MetricCard(
                              label: 'Rentals due',
                              value: data.rentalsDueToday,
                              icon: Icons.event_available_outlined,
                              color: const Color(0xFFDF7562),
                            ),
                          ),
                          _Entrance(
                            delay: 350,
                            child: _MetricCard(
                              label: 'Overdue returns',
                              value: data.overdueRentals,
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFD94B66),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        title: 'Your workspace',
                        subtitle: 'Pick up where your team left off',
                      ),
                      const SizedBox(height: 14),
                      _Entrance(
                        child: _WorkflowTile(
                          icon: Icons.person_search_outlined,
                          title: 'Customers & measurements',
                          subtitle: 'Customer profiles and fit details',
                          onTap: () => _showComingSoon(
                            context,
                            'Customers & measurements',
                          ),
                        ),
                      ),
                      _Entrance(
                        delay: 70,
                        child: _WorkflowTile(
                          icon: Icons.content_cut_rounded,
                          title: 'Tailoring orders',
                          subtitle: 'Orders, trials, tailoring and deliveries',
                          onTap: () =>
                              _showComingSoon(context, 'Tailoring orders'),
                        ),
                      ),
                      _Entrance(
                        delay: 140,
                        child: _WorkflowTile(
                          icon: Icons.checkroom_outlined,
                          title: 'Rental bookings',
                          subtitle: 'Occasionwear bookings and delivery dates',
                          onTap: () =>
                              _showComingSoon(context, 'Rental bookings'),
                        ),
                      ),
                      _Entrance(
                        delay: 210,
                        child: _WorkflowTile(
                          icon: Icons.assignment_return_outlined,
                          title: 'Rental returns',
                          subtitle: 'Returns, charges, deposits and refunds',
                          onTap: () =>
                              _showComingSoon(context, 'Rental returns'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(
                        title: 'Recent payments',
                        subtitle: 'Latest recorded customer payments',
                      ),
                      const SizedBox(height: 12),
                      if (data.recentPayments.isEmpty)
                        const _GlassSurface(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No recent payments.'),
                          ),
                        )
                      else
                        ...data.recentPayments
                            .take(5)
                            .map((payment) => _PaymentTile(payment: payment)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDestination,
        onDestinationSelected: (index) {
          setState(() => _selectedDestination = index);
          if (index != 0) {
            _showComingSoon(
              context,
              const ['Home', 'Tailoring', 'Rentals', 'Customers'][index],
            );
            setState(() => _selectedDestination = 0);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.content_cut_outlined),
            label: 'Tailoring',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            label: 'Rentals',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Customers',
          ),
        ],
      ),
    );
  }

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

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF2F6FC), Color(0xFFEAF1F7), Color(0xFFF8F7F3)],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x557AD9CD),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -110,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: Container(
              width: 270,
              height: 270,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x558BA4E7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.child, this.radius = 18});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF304B6E).withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 480 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.userName,
    required this.companyName,
    required this.financialYear,
  });

  final String userName;
  final String companyName;
  final String financialYear;

  @override
  Widget build(BuildContext context) {
    final title = companyName.isEmpty ? 'Welcome back' : companyName;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const SizedBox(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xEE172C52), Color(0xE91D7778)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(Icons.content_cut_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$userName${financialYear.isEmpty ? '' : ' · $financialYear'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 19, color: color),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value ?? 0).toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, count, _) => Text(
                value == null ? '—' : count.toInt().toString(),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  const _WorkflowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassSurface(
        radius: 18,
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEAF0FB),
              child: Icon(icon, color: const Color(0xFF3157A4)),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
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
      child: _GlassSurface(
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE6F5EE),
              child: Icon(Icons.payments_outlined, color: Color(0xFF188A64)),
            ),
            title: Text(label),
            trailing: Text(amount?.toString() ?? '—'),
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
