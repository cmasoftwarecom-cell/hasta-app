import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mobile/core/design/tokens.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';
import 'package:mobile/main.dart';

class _GuestSession implements GuestSession {
  GuestProfile? profile;
  bool offline = false;
  String? lastLocale;
  bool? qaReset;

  @override
  Future<GuestProfile?> cached() async => profile;

  @override
  Future<GuestProfile?> restore() async {
    if (offline) throw const AuthFailure('network', offline: true);
    return profile;
  }

  @override
  Future<GuestProfile> enter(String locale) async {
    lastLocale = locale;
    if (offline) throw const AuthFailure('network', offline: true);
    return profile = const GuestProfile('guest');
  }

  @override
  Future<GuestProfile> enterQa(String handle, {required bool reset}) async {
    qaReset = reset;
    return profile = GuestProfile('qa', displayName: handle);
  }

  @override
  Future<void> signOut() async => profile = null;

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('T40: sole guest entry, offline retry, profile and sign-out',
      (tester) async {
    final session = _GuestSession();
    await tester
        .pumpWidget(HastaApp(session: session, locale: const Locale('en')));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Privacy & Terms'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    session.offline = true;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You’re offline'), findsOneWidget);
    session.offline = false;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(session.lastLocale, 'en');
    expect(find.text('No profile details yet.'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T40: cached profile remains readable offline', (tester) async {
    final session = _GuestSession()
      ..profile = const GuestProfile('guest', displayName: 'Cached')
      ..offline = true;
    await tester
        .pumpWidget(HastaApp(session: session, locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Cached'), findsOneWidget);
    expect(find.textContaining('You’re offline'), findsOneWidget);
    session.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You’re offline'), findsNothing);
  });

  testWidgets('T36: panel requires QA defines and a three-second hold',
      (tester) async {
    const enabled = bool.fromEnvironment('HASTA_QUICK_TEST_ACCOUNTS_ENABLED');
    final session = _GuestSession();
    await tester
        .pumpWidget(HastaApp(session: session, locale: const Locale('en')));
    await tester.pumpAndSettle();
    final hold =
        await tester.startGesture(tester.getCenter(find.text('Hasta')));
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(SimpleDialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await hold.up();
    await tester.pumpAndSettle();
    if (!enabled) {
      expect(find.byType(SimpleDialog), findsNothing);
      return;
    }
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.byType(SimpleDialogOption), findsNWidgets(6));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tester.minor'));
    await tester.pumpAndSettle();
    expect(session.qaReset, isTrue);
    expect(find.text('tester.minor'), findsOneWidget);
  });

  test('DS: Myanmar is the fallback and copy resolves in both locales',
      () async {
    expect(AppLocalizations.supportedLocales.first, const Locale('my'));
    final my = await AppLocalizations.delegate.load(const Locale('my'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(my.genericError, contains('မအောင်မြင်ပါ'));
    expect(en.genericError, contains('Try again'));
  });

  test('DS: Myanmar typography never drops below the minimum line height', () {
    expect(HastaTokens.light['bg.brand'], isNotNull);
    for (final type in HastaTokens.myanmarType.values) {
      expect(type.height, greaterThanOrEqualTo(HastaTokens.myanmarLineHeight));
      expect(type.fontWeight!.index, lessThanOrEqualTo(FontWeight.w600.index));
    }
  });
}
