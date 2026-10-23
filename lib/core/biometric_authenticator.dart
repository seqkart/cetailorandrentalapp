import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> get canAuthenticate;

  Future<bool> authenticate();
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  DeviceBiometricAuthenticator([LocalAuthentication? authentication])
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> get canAuthenticate async {
    final supported = await _authentication.isDeviceSupported();
    if (!supported) return false;
    return (await _authentication.getAvailableBiometrics()).isNotEmpty;
  }

  @override
  Future<bool> authenticate() => _authentication.authenticate(
    localizedReason: 'Unlock your tailoring and rentals workspace',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}
