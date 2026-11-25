import 'package:flutter/services.dart';

import '../domain/device_transfer.dart';
import '../domain/guest_session.dart';

class SignedTransferApproval {
  const SignedTransferApproval._(this.id, this.signature);

  final String id;
  final String signature;
}

class NativeTransferApproval {
  const NativeTransferApproval();

  static const _channel = MethodChannel('app.hasta.mobile/transfer_approval');
  static final _base64url = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<String> publicKey() async =>
      _material('publicKey', null, min: 122, max: 122);

  Future<SignedTransferApproval> approve(
      TransferOffer offer, TransferProgress progress) async {
    final challenge = progress.approvalChallenge;
    if (challenge == null ||
        progress.expiresAt != offer.expiresAt ||
        !progress.expiresAt.isAfter(DateTime.now())) {
      throw const AuthFailure('transfer_approval_unavailable');
    }
    return SignedTransferApproval._(
        offer.id, await _material('approve', challenge, min: 11, max: 96));
  }

  // Callers must not render a QR before this succeeds. Unsupported platforms
  // fail closed, and the QR must be removed before setting this back to false.
  Future<void> protectQr(bool secure) => _invoke<void>('protectQr', secure);

  Future<String> _material(String method, Object? arguments,
      {required int min, required int max}) async {
    final result = await _invoke<String>(method, arguments);
    if (result == null ||
        result.length < min ||
        result.length > max ||
        !_base64url.hasMatch(result)) {
      throw const AuthFailure('transfer_approval_unavailable');
    }
    return result;
  }

  Future<T?> _invoke<T>(String method, Object? arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AuthFailure(error.code == 'transfer_approval_cancelled'
          ? error.code
          : 'transfer_approval_unavailable');
    } on MissingPluginException {
      throw const AuthFailure('transfer_approval_unavailable');
    }
  }
}
