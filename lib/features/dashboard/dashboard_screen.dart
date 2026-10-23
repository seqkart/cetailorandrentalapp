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
    setState(() => _dashboard = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tailoring & Rentals'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<DashboardSnapshot>(
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                _WelcomeCard(
                  userName: widget.session.userName,
                  companyName: widget.session.companyName,
                  financialYear: widget.session.financialYearName,
                ),
                const SizedBox(height: 20),
                Text(
                  'Today at a glance',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.52,
                  children: [
                    _MetricCard(
                      label: 'Customers',
                      value: data.totalCustomers,
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF2F80ED),
                    ),
                    _MetricCard(
                      label: 'Tailor orders',
                      value: data.totalOrders,
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFF12A783),
                    ),
                    _MetricCard(
                      label: 'Orders today',
                      value: data.ordersToday,
                      icon: Icons.today_outlined,
                      color: const Color(0xFFF0A13B),
                    ),
                    _MetricCard(
                      label: 'Pending orders',
                      value: data.pendingOrders,
                      icon: Icons.pending_actions_outlined,
                      color: const Color(0xFF8C61D8),
                    ),
                    _MetricCard(
                      label: 'Rentals due',
                      value: data.rentalsDueToday,
                      icon: Icons.event_available_outlined,
                      color: const Color(0xFFDF7562),
                    ),
                    _MetricCard(
                      label: 'Overdue returns',
                      value: data.overdueRentals,
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFD94B66),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Your workspace',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _WorkflowTile(
                  icon: Icons.person_search_outlined,
                  title: 'Customers & measurements',
                  subtitle: 'Customer profiles and fit details',
                  onTap: () =>
                      _showComingSoon(context, 'Customers & measurements'),
                ),
                _WorkflowTile(
                  icon: Icons.content_cut_rounded,
                  title: 'Tailoring orders',
                  subtitle: 'Orders, trials, tailoring and deliveries',
                  onTap: () => _showComingSoon(context, 'Tailoring orders'),
                ),
                _WorkflowTile(
                  icon: Icons.checkroom_outlined,
                  title: 'Rental bookings',
                  subtitle: 'Occasionwear bookings and delivery dates',
                  onTap: () => _showComingSoon(context, 'Rental bookings'),
                ),
                _WorkflowTile(
                  icon: Icons.assignment_return_outlined,
                  title: 'Rental returns',
                  subtitle: 'Returns, charges, deposits and refunds',
                  onTap: () => _showComingSoon(context, 'Rental returns'),
                ),
                const SizedBox(height: 22),
                Text(
                  'Recent payments',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (data.recentPayments.isEmpty)
                  const Card(
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF203A70), Color(0xFF167B78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9EDF4)),
      ),
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
            Text(
              value?.toString() ?? '—',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EDF4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF0FB),
          child: Icon(icon, color: const Color(0xFF3157A4)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
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
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE6F5EE),
          child: Icon(Icons.payments_outlined, color: Color(0xFF188A64)),
        ),
        title: Text(label),
        trailing: Text(amount?.toString() ?? '—'),
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
