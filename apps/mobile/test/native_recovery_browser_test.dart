import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/native_recovery_browser.dart';
import 'package:mobile/features/auth/domain/gmail_recovery.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.hasta.mobile/recovery');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final redirect =
      Uri.https('recovery.example.invalid', '/auth/recovery/callback');
  GmailRecoveryConsent consent() => GmailRecoveryConsent(
        consentUrl: Uri.https('accounts.google.com', '/o/oauth2/v2/auth'),
        redirectUri: redirect,
        state: 'pending-state',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );

  Future<void> callback(Uri uri) async {
    final acknowledged = Completer<void>();
    await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('callback', uri.toString())),
        (_) => acknowledged.complete());
    await acknowledged.future;
  }

  test('T30: keeps the native callback pending until origin and state match',
      () async {
    final browser = NativeRecoveryBrowser(channel: channel);
    var opened = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openConsent');
      opened++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final pending = consent();
    final authorized = browser.authorize(pending);
    await expectLater(
        browser.authorize(pending),
        throwsA(isA<AuthFailure>()
            .having((x) => x.code, 'code', 'request_in_progress')));
    final valid = redirect.replace(
        queryParameters: {'state': pending.state, 'code': 'local-code'});
    await callback(valid.replace(host: 'wrong.example.invalid'));
    await callback(valid.replace(query: 'state=wrong&code=local-code'));
    await callback(valid);
    expect(await authorized, valid);
    expect(opened, 1);
    await callback(valid); // No listener remains after the accepted callback.
  });

  test('T30: matched cancellation and timeout release the native listener',
      () async {
    final browser = NativeRecoveryBrowser(channel: channel);
    final pending = consent();
    final cancelled = browser.waitForCallback(pending, open: () async {});
    final checked = expectLater(
        cancelled,
        throwsA(isA<AuthFailure>()
            .having((x) => x.code, 'code', 'recovery_cancelled')));
    await callback(redirect.replace(
        queryParameters: {'state': pending.state, 'error': 'access_denied'}));
    await checked;
    await expectLater(
        browser.waitForCallback(pending,
            open: () async {}, timeout: const Duration(milliseconds: 5)),
        throwsA(
            isA<AuthFailure>().having((x) => x.code, 'code', 'token_expired')));
  });
}
