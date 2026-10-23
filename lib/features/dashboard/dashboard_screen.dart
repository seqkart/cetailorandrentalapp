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
      backgroundColor: const Color(0xFFF4F6FA),
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
              padding: EdgeInsets.zero,
              children: [
                _DashboardHeader(
                  userName: widget.session.userName,
                  companyName: widget.session.companyName,
                  financialYear: widget.session.financialYearName,
                  onSignOut: () => _signOut(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeading(
                        title: 'Business overview',
                        subtitle: 'Your activity at a glance',
                      ),
                      const SizedBox(height: 14),
                      _OverviewCard(
                        orders: data.totalOrders,
                        customers: data.totalCustomers,
                        ordersToday: data.ordersToday,
                      ),
                      const SizedBox(height: 25),
                      const _SectionHeading(
                        title: 'Quick access',
                        subtitle: 'Common tasks for your team',
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.9,
                        children: [
                          _QuickAction(
                            icon: Icons.people_alt_outlined,
                            title: 'Customers',
                            subtitle: 'Profiles & measurements',
                            color: const Color(0xFF3568B8),
                            onTap: () => _showComingSoon(
                              context,
                              'Customers & measurements',
                            ),
                          ),
                          _QuickAction(
                            icon: Icons.content_cut_rounded,
                            title: 'Tailoring',
                            subtitle: 'Orders & trials',
                            color: const Color(0xFF158878),
                            onTap: () =>
                                _showComingSoon(context, 'Tailoring orders'),
                          ),
                          _QuickAction(
                            icon: Icons.checkroom_outlined,
                            title: 'Bookings',
                            subtitle: 'Occasionwear rentals',
                            color: const Color(0xFF8259B1),
                            onTap: () =>
                                _showComingSoon(context, 'Rental bookings'),
                          ),
                          _QuickAction(
                            icon: Icons.assignment_return_outlined,
                            title: 'Returns',
                            subtitle: 'Settle & check in',
                            color: const Color(0xFFB16B35),
                            onTap: () =>
                                _showComingSoon(context, 'Rental returns'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionHeading(
                              title: 'Needs attention',
                              subtitle: 'Stay ahead of today’s work',
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
                              label: 'Rentals due',
                              value: data.rentalsDueToday,
                              icon: Icons.event_available_outlined,
                              color: const Color(0xFFD7793B),
                              background: const Color(0xFFFFF2E8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AttentionCard(
                              label: 'Overdue returns',
                              value: data.overdueRentals,
                              icon: Icons.assignment_late_outlined,
                              color: const Color(0xFFC74C5C),
                              background: const Color(0xFFFFECEE),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionHeading(
                              title: 'Recent payments',
                              subtitle: 'Latest customer transactions',
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showComingSoon(context, 'Payments'),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (data.recentPayments.isEmpty)
                        const _PaymentEmptyState()
                      else
                        ...data.recentPayments
                            .take(5)
                            .map((payment) => _PaymentTile(payment: payment)),
                    ],
                  ),
                ),
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
    required this.financialYear,
    required this.onSignOut,
  });

  final String userName;
  final String companyName;
  final String financialYear;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
    final firstName = userName.trim().split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172A4B), Color(0xFF234D66), Color(0xFF24766E)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 18, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.content_cut_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CREATIVE EASE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onSignOut,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Good day${firstName.isEmpty ? '' : ', $firstName'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                companyName.isEmpty ? 'Your studio at a glance' : companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white.withValues(alpha: 0.76),
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (financialYear.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'FY $financialYear',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C263B58),
            blurRadius: 18,
            offset: Offset(0, 7),
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
                  'All-time orders',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: Color(0xFF16816D),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'OVERVIEW',
                      style: TextStyle(
                        color: Color(0xFF16816D),
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
                color: Color(0xFF172A4B),
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(height: 1, color: const Color(0xFFEEF1F5)),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  icon: Icons.people_alt_outlined,
                  label: 'Customers',
                  value: customers,
                  color: const Color(0xFF3568B8),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEEF1F5)),
              Expanded(
                child: _OverviewStat(
                  icon: Icons.today_outlined,
                  label: 'Orders today',
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
                    color: Color(0xFF172A4B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF738096),
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09263B58),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE8EDF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09263B58),
                blurRadius: 13,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: color.withValues(alpha: 0.7),
                    size: 17,
                  ),
                ],
              ),
              Column(
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF748198),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentEmptyState extends StatelessWidget {
  const _PaymentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: const Row(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
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
