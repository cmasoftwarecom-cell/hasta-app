import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/main.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final until = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T40/T41: fresh native install enters and then resumes guest',
      (tester) async {
    // No injected credentials, native ID, cache or HTTP fake.
    final initial = GuestRepository();
    await tester
        .pumpWidget(HastaApp(session: initial, locale: const Locale('en')));
    final welcome = find.widgetWithText(FilledButton, 'Continue');
    await waitFor(tester, welcome);
    await tester.pumpAndSettle();
    expect(await initial.cached(), isNull,
        reason: 'Run on a freshly erased simulator or emulator');
    expect(tester.widget<FilledButton>(welcome).onPressed, isNotNull);
    await tester.tap(welcome);
    await waitFor(tester, find.text('Guest profile'));
    await tester.pumpAndSettle();
    final account = (await initial.cached())!.accountId;

    await tester.pumpWidget(const SizedBox.shrink());
    await initial.close();
    final reopened = GuestRepository();
    addTearDown(reopened.close);
    await tester
        .pumpWidget(HastaApp(session: reopened, locale: const Locale('en')));
    await waitFor(tester, find.text('Guest profile'));
    await tester.pumpAndSettle();
    expect((await reopened.restore())?.accountId, account);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await waitFor(tester, welcome);
    await tester.pumpAndSettle();
    expect(await reopened.cached(), isNull);
    await tester.tap(welcome);
    await waitFor(tester, find.text('Guest profile'));
    await tester.pumpAndSettle();
    expect((await reopened.cached())?.accountId, account);
  });
}
