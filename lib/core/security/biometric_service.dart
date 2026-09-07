import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service managing hardware biometric authentication via local_auth.
class BiometricService {
  final LocalAuthentication _auth;
  final bool forceMock;
  final bool mockAuthSuccess;

  BiometricService({
    LocalAuthentication? auth,
    this.forceMock = false,
    this.mockAuthSuccess = true,
  }) : _auth = auth ?? LocalAuthentication();

  /// Check whether biometric sensors or device passcode authentication are available.
  Future<bool> canAuthenticate() async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Check available biometric types on the device (e.g. fingerprint, face).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return [BiometricType.fingerprint];
    }

    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompt the user for biometric or device credential authentication.
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to access Cadence',
  }) async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return mockAuthSuccess;
    }

    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
