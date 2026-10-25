import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/language_picker.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.repository,
    required this.onSignedIn,
    this.locale,
    this.onLocaleChanged,
    super.key,
  });

  final AuthRepository repository;
  final ValueChanged<AuthSession> onSignedIn;
  final Locale? locale;
  final Future<void> Function(Locale locale)? onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _appIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _backgroundController;
  List<FinancialYear> _financialYears = const [];
  FinancialYear? _selectedYear;
  bool _loadingYears = false;
  bool _signingIn = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
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
    final strings = appStrings(context);
    return Scaffold(
      backgroundColor: const Color(0xFF172844),
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(
            _backgroundController.value,
          );
          return Container(
            key: const ValueKey('login-animated-background'),
            constraints: const BoxConstraints.expand(),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF152544),
                    const Color(0xFF102D4C),
                    progress,
                  )!,
                  Color.lerp(
                    const Color(0xFF253F73),
                    const Color(0xFF1C5569),
                    progress,
                  )!,
                  Color.lerp(
                    const Color(0xFF3D2B69),
                    const Color(0xFF57356B),
                    progress,
                  )!,
                ],
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: LanguagePicker(
                            locale: widget.locale ?? const Locale('en'),
                            onChanged: widget.onLocaleChanged ?? (_) async {},
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Image.asset(
                            'assets/images/login_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'CREATIVE EASE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD8E9FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.madeToFit,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFF6E5),
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          strings.tailoringAndRentals,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD1DDF0),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Card(
                              color: const Color(0xEFFFFFFF),
                              elevation: 1,
                              shadowColor: const Color(0x181688E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: const BorderSide(
                                  color: Color(0xFFD8E9FA),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        strings.teamSignIn,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        strings.signInDescription,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        selectAllOnFocus: true,
                                        controller: _appIdController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: strings.appId,
                                          prefixIcon: const Icon(
                                            Icons.business_outlined,
                                          ),
                                        ),
                                        validator: _required,
                                        onFieldSubmitted: (_) =>
                                            _loadFinancialYears(),
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
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.refresh_rounded,
                                                ),
                                          label: Text(
                                            strings.loadFinancialYears,
                                          ),
                                        ),
                                      ),
                                      DropdownButtonFormField<FinancialYear>(
                                        initialValue: _selectedYear,
                                        decoration: InputDecoration(
                                          labelText: strings.financialYear,
                                          prefixIcon: const Icon(
                                            Icons.calendar_month,
                                          ),
                                        ),
                                        items: _financialYears
                                            .map(
                                              (year) => DropdownMenuItem(
                                                value: year,
                                                child: Text(
                                                  '${year.name}${year.isCurrent ? ' (${strings.current})' : ''}',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _signingIn
                                            ? null
                                            : (year) => setState(
                                                () => _selectedYear = year,
                                              ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        selectAllOnFocus: true,
                                        controller: _userNameController,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        decoration: InputDecoration(
                                          labelText: strings.userName,
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                        validator: _required,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        selectAllOnFocus: true,
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        decoration: InputDecoration(
                                          labelText: strings.password,
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: _obscurePassword
                                                ? strings.showPassword
                                                : strings.hidePassword,
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                            ),
                                          ),
                                        ),
                                        validator: _required,
                                        onFieldSubmitted: (_) => _signIn(),
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        Text(
                                          localizedUiText(context, _error!),
                                          style: TextStyle(color: colors.error),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        onPressed: _signingIn ? null : _signIn,
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            52,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: _signingIn
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                strings.signIn,
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
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.simplerRental,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFD1DDF0)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? appStrings(context).signInRequired
      : null;
}
