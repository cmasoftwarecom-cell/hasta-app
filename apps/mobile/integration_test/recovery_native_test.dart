import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/features/auth/data/native_recovery_browser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T30: native recovery fixture phase', (tester) async {
    const phase = String.fromEnvironment('HASTA_T30_PHASE');
    const base = String.fromEnvironment('HASTA_API_BASE_URL');
    const channel = MethodChannel('app.hasta.mobile/recovery');
    final api = Uri.tryParse(base);
    expect(
        kDebugMode &&
            Platform.isAndroid &&
            api?.scheme == 'http' &&
            api?.host == '127.0.0.1' &&
            api!.hasPort,
        isTrue,
        reason: 'T30 requires an Android debug emulator and reversed loopback');
    expect(const {'seed', 'recover'}.contains(phase), isTrue);
    final repository = GuestRepository(baseUrl: base);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.runAsync(() async {
      try {
        expect(await repository.cached(), isNull,
            reason: 'The app install must start without a stored account');
        if (phase == 'seed') {
          final original = await repository.enter('en');
          expect(original.accountId.isNotEmpty, isTrue);
          return;
        }
        final redirect =
            Uri.https('recovery.example.invalid', '/auth/recovery/callback');
        final consent = await repository.beginGmailRecovery(redirect);
        final oauth = consent.consentUrl.queryParameters;
        final fixture =
            api!.replace(path: '/_native/recovery/consent', queryParameters: {
          for (final key in ['state', 'nonce', 'code_challenge'])
            key: oauth[key]!,
        });
        final browser = NativeRecoveryBrowser(channel: channel);
        final returned = await browser.waitForCallback(consent,
            open: () => channel.invokeMethod<void>(
                'openLocalRecoveryFixture', fixture.toString()),
            mapCallback: (raw) {
              if (raw.scheme != 'hasta-recovery-qa' ||
                  raw.host != 'callback' ||
                  raw.path != '/complete') {
                return null;
              }
              return redirect.replace(query: raw.query);
            },
            timeout: const Duration(seconds: 110));
        final recovered =
            await repository.finishGmailRecovery(consent, returned);
        expect((await repository.restore())?.accountId == recovered.accountId,
            isTrue,
            reason: 'The reinstalled app must open the recovered session');
      } finally {
        await repository.close();
      }
    });
  });
}
