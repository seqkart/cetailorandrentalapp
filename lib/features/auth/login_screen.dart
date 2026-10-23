import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.repository,
    required this.onSignedIn,
    super.key,
  });

  final AuthRepository repository;
  final ValueChanged<AuthSession> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  List<FinancialYear> _financialYears = const [];
  FinancialYear? _selectedYear;
  bool _loadingYears = false;
  bool _signingIn = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _appIdController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadFinancialYears() async {
    final appId = _appIdController.text.trim();
    if (appId.isEmpty) {
      setState(() => _error = 'Enter your App ID to load financial years.');
      return;
    }

    setState(() {
      _loadingYears = true;
      _error = null;
      _financialYears = const [];
      _selectedYear = null;
    });

    try {
      final years = await widget.repository.loadFinancialYears(appId);
      if (!mounted) return;
      setState(() {
        _financialYears = years;
        _selectedYear =
            years.where((year) => year.isCurrent).firstOrNull ??
            (years.isEmpty ? null : years.first);
        if (years.isEmpty) {
          _error = 'No financial years are available for this App ID.';
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingYears = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedYear == null) {
      setState(() => _error = 'Load and select a financial year first.');
      return;
    }

    setState(() {
      _signingIn = true;
      _error = null;
    });

    try {
      final session = await widget.repository.signIn(
        appId: _appIdController.text,
        userName: _userNameController.text,
        password: _passwordController.text,
        financialYear: _selectedYear!,
      );
      if (mounted) widget.onSignedIn(session);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111B33), Color(0xFF24457F), Color(0xFF0C7777)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.content_cut_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'CREATIVE EASE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Made to fit.\nReady to wear.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tailoring & occasionwear rentals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      color: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Team sign in',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sign in to manage your tailoring and rentals.',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _appIdController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'App ID',
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                validator: _required,
                                onFieldSubmitted: (_) => _loadFinancialYears(),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _loadingYears
                                      ? null
                                      : _loadFinancialYears,
                                  icon: _loadingYears
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: const Text('Load financial years'),
                                ),
                              ),
                              DropdownButtonFormField<FinancialYear>(
                                initialValue: _selectedYear,
                                decoration: const InputDecoration(
                                  labelText: 'Financial year',
                                  prefixIcon: Icon(Icons.calendar_month),
                                ),
                                items: _financialYears
                                    .map(
                                      (year) => DropdownMenuItem(
                                        value: year,
                                        child: Text(
                                          '${year.name}${year.isCurrent ? ' (Current)' : ''}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _signingIn
                                    ? null
                                    : (year) =>
                                          setState(() => _selectedYear = year),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _userNameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'User name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: _required,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: _required,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  style: TextStyle(color: colors.error),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _signingIn ? null : _signIn,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _signingIn
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'SIGN IN',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'A considered fit. A simpler rental.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
