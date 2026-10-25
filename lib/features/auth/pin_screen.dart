import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/biometric_authenticator.dart';
import '../../l10n/app_strings.dart';

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

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  late final AnimationController _backgroundController;
  bool _biometricsAvailable = false;
  bool _useBiometrics = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useBiometrics = widget.useBiometrics;
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    _pinFocusNode.addListener(_onPinFocusChanged);
    _confirmFocusNode.addListener(_onPinFocusChanged);
    _checkBiometrics();
  }

  void _onPinFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pinFocusNode.removeListener(_onPinFocusChanged);
    _confirmFocusNode.removeListener(_onPinFocusChanged);
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocusNode.dispose();
    _confirmFocusNode.dispose();
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
      setState(() {
        _pinController.clear();
        _error = 'That MPIN is not correct. Try again.';
      });
      _pinFocusNode.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _pinFocusNode.unfocus();
    try {
      widget.onPinAccepted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onPinChanged(String value) {
    if (value.length != 4 || widget.isSetup || _busy) return;
    _submitPin();
  }

  void _onCreatePinChanged(String value) {
    if (value.length == 4) _confirmFocusNode.requestFocus();
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
    String translate(String text) => localizedUiText(context, text);
    return Scaffold(
      backgroundColor: const Color(0xFF172844),
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(
            _backgroundController.value,
          );
          return Container(
            key: const ValueKey('mpin-animated-background'),
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Image.asset(
                            'assets/images/login_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF08152C)
                                    .withValues(alpha: 0.28),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.isSetup
                                    ? translate('Protect your account')
                                    : translate('Welcome back'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.isSetup
                                    ? translate(
                                        'Create a 4-digit MPIN for quick, secure access.',
                                      )
                                    : widget.userName.isEmpty
                                    ? translate('Enter your MPIN to continue.')
                                    : translate(
                                        'Signed in as ${widget.userName}. Enter your MPIN.',
                                      ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _pinField(
                                controller: _pinController,
                                focusNode: _pinFocusNode,
                                label: widget.isSetup
                                    ? translate('Create MPIN')
                                    : translate('4-digit MPIN'),
                                key: const Key('mpin-field'),
                                onChanged: widget.isSetup
                                    ? _onCreatePinChanged
                                    : _onPinChanged,
                              ),
                              if (widget.isSetup) ...[
                                const SizedBox(height: 14),
                                _pinField(
                                  controller: _confirmController,
                                  focusNode: _confirmFocusNode,
                                  label: translate('Confirm MPIN'),
                                  key: const Key('confirm-mpin-field'),
                                ),
                                if (_biometricsAvailable) ...[
                                  const SizedBox(height: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: _useBiometrics,
                                      onChanged: (enabled) => setState(
                                        () => _useBiometrics = enabled,
                                      ),
                                      secondary: const Icon(
                                        Icons.fingerprint_rounded,
                                      ),
                                      title: Text(
                                        translate('Enable fingerprint unlock'),
                                      ),
                                      subtitle: Text(
                                        translate(
                                          'You can still use your MPIN',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (widget.useBiometrics &&
                                  _biometricsAvailable) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : _unlockWithBiometrics,
                                  icon: const Icon(Icons.fingerprint_rounded),
                                  label: Text(
                                    translate('Unlock with fingerprint'),
                                  ),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  translate(_error!),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.error),
                                ),
                              ],
                              const SizedBox(height: 18),
                              if (widget.isSetup)
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
                                      : Text(translate('SAVE MPIN')),
                                )
                              else if (_busy)
                                const Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              if (!widget.isSetup &&
                                  widget.onForgotPin != null) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busy ? null : _forgetPin,
                                  child: Text(
                                    translate('Forgot MPIN? Sign in again'),
                                  ),
                                ),
                              ],
                            ],
                          ),
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

  Widget _pinField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required Key key,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344968),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TextField(
                selectAllOnFocus: true,
                key: key,
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  setState(() {});
                  onChanged?.call(value);
                },
                onSubmitted: (_) {
                  if (widget.isSetup) _submitPin();
                },
              ),
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : 12),
                      child: AnimatedContainer(
                        key: ValueKey('pin-digit-$index'),
                        duration: const Duration(milliseconds: 140),
                        width: 52,
                        height: 54,
                        decoration: BoxDecoration(
                          color:
                              focusNode.hasFocus &&
                                  controller.text.length.clamp(0, 3) == index
                              ? const Color(0xFFFFE6A6)
                              : controller.text.length > index
                              ? const Color(0xFFDCEEFF)
                              : const Color(0xFFF3F7FC),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color:
                                focusNode.hasFocus &&
                                    controller.text.length.clamp(0, 3) == index
                                ? const Color(0xFFE19B00)
                                : controller.text.length > index
                                ? const Color(0xFF1688E8)
                                : const Color(0xFFB8CBE0),
                            width:
                                focusNode.hasFocus &&
                                    controller.text.length.clamp(0, 3) == index
                                ? 2.5
                                : controller.text.length > index
                                ? 1.5
                                : 1,
                          ),
                          boxShadow:
                              focusNode.hasFocus &&
                                  controller.text.length.clamp(0, 3) == index
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFE19B00)
                                        .withValues(alpha: 0.32),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: controller.text.length > index
                            ? Container(
                                width: 11,
                                height: 11,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1688E8),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
