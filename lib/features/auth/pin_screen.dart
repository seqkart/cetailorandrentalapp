import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/biometric_authenticator.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({
    required this.isSetup,
    required this.useBiometrics,
    required this.onSetupComplete,
    required this.onPinAccepted,
    required this.biometricAuthenticator,
    this.onForgotPin,
    this.savedPin,
    this.userName = '',
    super.key,
  });

  final bool isSetup;
  final bool useBiometrics;
  final Future<void> Function(({String pin, bool useBiometrics}) settings)
  onSetupComplete;
  final VoidCallback onPinAccepted;
  final BiometricAuthenticator biometricAuthenticator;
  final Future<void> Function()? onForgotPin;
  final String? savedPin;
  final String userName;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _biometricsAvailable = false;
  bool _useBiometrics = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useBiometrics = widget.useBiometrics;
    _checkBiometrics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final available = await widget.biometricAuthenticator.canAuthenticate;
      if (mounted) {
        setState(() => _biometricsAvailable = available);
      }
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on LocalAuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.description ?? error.code.name);
      }
    }
  }

  Future<void> _submitPin() async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text;
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a 4-digit MPIN.');
      return;
    }
    if (widget.isSetup) {
      if (_confirmController.text != pin) {
        setState(() => _error = 'The MPINs do not match.');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await widget.onSetupComplete((
          pin: pin,
          useBiometrics: _useBiometrics && _biometricsAvailable,
        ));
      } on Object catch (error) {
        if (mounted) setState(() => _error = error.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (pin != widget.savedPin) {
      setState(() => _error = 'That MPIN is not correct. Try again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.onPinAccepted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await widget.biometricAuthenticator.authenticate() && mounted) {
        widget.onPinAccepted();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'Biometric unlock failed.');
      }
    } on LocalAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.description ?? 'Biometric unlock failed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgetPin() async {
    try {
      await widget.onForgotPin?.call();
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not sign out: $error');
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
            colors: [Color(0xFF101A30), Color(0xFF1B4674), Color(0xFF087A75)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        widget.isSetup
                            ? Icons.shield_outlined
                            : Icons.lock_person_outlined,
                        size: 42,
                        color: const Color(0xFF246C72),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.isSetup
                            ? 'Protect your account'
                            : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isSetup
                            ? 'Create a 4-digit MPIN for quick, secure access.'
                            : widget.userName.isEmpty
                            ? 'Enter your MPIN to continue.'
                            : 'Signed in as ${widget.userName}. Enter your MPIN.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      _pinField(
                        controller: _pinController,
                        label: widget.isSetup ? 'Create MPIN' : '4-digit MPIN',
                        key: const Key('mpin-field'),
                      ),
                      if (widget.isSetup) ...[
                        const SizedBox(height: 14),
                        _pinField(
                          controller: _confirmController,
                          label: 'Confirm MPIN',
                          key: const Key('confirm-mpin-field'),
                        ),
                        if (_biometricsAvailable) ...[
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _useBiometrics,
                              onChanged: (enabled) =>
                                  setState(() => _useBiometrics = enabled),
                              secondary: const Icon(Icons.fingerprint_rounded),
                              title: const Text('Enable fingerprint unlock'),
                              subtitle: const Text(
                                'You can still use your MPIN',
                              ),
                            ),
                          ),
                        ],
                      ] else if (widget.useBiometrics &&
                          _biometricsAvailable) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _unlockWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Unlock with fingerprint'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submitPin,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.isSetup ? 'SAVE MPIN' : 'UNLOCK'),
                      ),
                      if (!widget.isSetup && widget.onForgotPin != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _forgetPin,
                          child: const Text('Forgot MPIN? Sign in again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required Key key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.dialpad_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onSubmitted: (_) => _submitPin(),
    );
  }
}
