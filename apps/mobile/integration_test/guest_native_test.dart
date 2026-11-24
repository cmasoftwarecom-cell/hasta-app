import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';
import 'package:mobile/main.dart';

class _ObservedGuestRepository extends GuestRepository {
  String? failure;

  @override
  Future<GuestProfile> enter(String locale) async {
    failure = null;
    try {
      return await super.enter(locale);
    } on AuthFailure catch (error) {
      const known = {
        'configuration',
        'network',
        'validation_failed',
        'unauthenticated',
        'internal_error',
        'rate_limited',
        'device_cooldown',
        'idempotency_conflict',
        'device_unavailable'
      };
      failure =
          'Auth failure: ${known.contains(error.code) ? error.code : 'other'}; '
          'HTTP ${error.status}';
      rethrow;
    } on PlatformException catch (error) {
      final detail = error.details;
      failure = 'Platform failure: ${error.code}; '
          'numeric result ${detail is int ? detail : 'unavailable'}';
      rethrow;
    } catch (error) {
      failure = 'Unexpected failure: ${error.runtimeType}';
      rethrow;
    }
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder,
    {String? Function()? failure}) async {
  final until = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(until)) {
    final diagnosis = failure?.call();
    if (diagnosis != null) fail(diagnosis);
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T40/T41: fresh native install enters and then resumes guest',
      (tester) async {
    const baseUrl = String.fromEnvironment('HASTA_API_BASE_URL');
    expect(baseUrl, isNotEmpty, reason: 'The test API URL was not passed');
    final health = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await health.getUrl(Uri.parse(baseUrl).replace(path: '/health'));
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      expect(response.statusCode, 200,
          reason: 'Simulator cannot reach test API');
      await response.drain<void>();
    } finally {
      health.close(force: true);
    }
    const channel = MethodChannel('app.hasta.mobile/device');
    final device = await channel.invokeMapMethod<String, Object?>('info');
    expect(device?['platform'], Platform.isIOS ? 'ios' : 'android');
    expect((device?['raw_device_id'] as String?)?.isNotEmpty ?? false, isTrue);
    // Exercise the real Keychain/Keystore without reporting its values.
    const store = SecureCredentials();
    const probe = 'hasta.ci.storage-probe';
    var stored = false;
    try {
      await store.write(probe, 'available');
      stored = true;
      expect((await store.read(probe)) == 'available', isTrue);
    } on PlatformException catch (error) {
      final detail = error.details;
      fail('Secure storage preflight: ${error.code}; '
          'numeric result ${detail is int ? detail : 'unavailable'}');
    } finally {
      if (stored) await store.write(probe, null);
    }

    // The UI still drives real device enrollment, Keychain, Drift and HTTP.
    final initial = _ObservedGuestRepository();
    await tester
        .pumpWidget(HastaApp(session: initial, locale: const Locale('en')));
    final welcome = find.widgetWithText(FilledButton, 'Continue');
    await waitFor(tester, welcome);
    await tester.pumpAndSettle();
    expect(await initial.cached(), isNull,
        reason: 'Run on a freshly erased simulator or emulator');
    expect(tester.widget<FilledButton>(welcome).onPressed, isNotNull);
    await tester.tap(welcome);
    await waitFor(tester, find.text('Guest profile'),
        failure: () => initial.failure);
    await tester.pumpAndSettle();
    final account = (await initial.cached())!.accountId;

    await tester.pumpWidget(const SizedBox.shrink());
    await initial.close();
    final reopened = _ObservedGuestRepository();
    addTearDown(reopened.close);
    await tester
        .pumpWidget(HastaApp(session: reopened, locale: const Locale('en')));
    await waitFor(tester, find.text('Guest profile'),
        failure: () => reopened.failure);
    await tester.pumpAndSettle();
    expect((await reopened.restore())?.accountId, account);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await waitFor(tester, welcome);
    await tester.pumpAndSettle();
    expect(await reopened.cached(), isNull);
    await tester.tap(welcome);
    await waitFor(tester, find.text('Guest profile'),
        failure: () => reopened.failure);
    await tester.pumpAndSettle();
    expect((await reopened.cached())?.accountId, account);
  });
}
