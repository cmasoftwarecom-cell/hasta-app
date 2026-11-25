import 'guest_session.dart';

class GmailRecoveryConsent {
  GmailRecoveryConsent({
    required this.consentUrl,
    required this.redirectUri,
    required this.state,
    required this.expiresAt,
  });

  final Uri consentUrl;
  final Uri redirectUri;
  final String state;
  final DateTime expiresAt;

  String acceptCallback(Uri callback) {
    if (callback.scheme != redirectUri.scheme ||
        callback.host != redirectUri.host ||
        callback.port != redirectUri.port ||
        callback.path != redirectUri.path ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment) {
      throw const AuthFailure('recovery_callback_invalid');
    }
    if (!DateTime.now().isBefore(expiresAt)) {
      throw const AuthFailure('token_expired');
    }
    final Map<String, List<String>> values;
    try {
      values = callback.queryParametersAll;
    } on FormatException {
      throw const AuthFailure('recovery_callback_invalid');
    }
    final states = values['state'];
    if (states == null || states.length != 1 || states.single != state) {
      throw const AuthFailure('recovery_callback_invalid');
    }
    if (values.containsKey('error')) {
      throw const AuthFailure('recovery_cancelled');
    }
    final codes = values['code'];
    if (codes == null ||
        codes.length != 1 ||
        !RegExp(r'^[\x21-\x7e]{1,2048}$').hasMatch(codes.single)) {
      throw const AuthFailure('recovery_callback_invalid');
    }
    return codes.single;
  }
}
