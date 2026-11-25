import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mobile/core/design/tokens.dart';
import 'package:mobile/features/auth/data/native_recovery_browser.dart';
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

class _GmailActions implements GmailLinkActions {
  bool offline = true;
  bool expireFirstAttempt = true;
  String? connectedAccount;

  @override
  Future<String?> status(String accountId) async {
    if (offline) throw const AuthFailure('network', offline: true);
    return null;
  }

  @override
  Future<String> connect(String accountId) async {
    if (expireFirstAttempt) {
      expireFirstAttempt = false;
      throw const AuthFailure('gmail_link_restart');
    }
    connectedAccount = accountId;
    return 'a***@example.invalid';
  }

  @override
  void cancel() {}
}

void main() {
  testWidgets('DS primary fill: welcome button renders brand and brandPressed',
      (tester) async {
    await tester.pumpWidget(
        HastaApp(session: _GuestSession(), locale: const Locale('en')));
    await tester.pumpAndSettle();
    final button = find.byType(FilledButton);
    Color? fill() => tester
        .widget<Material>(find.descendant(
          of: button,
          matching: find.byType(Material),
        ))
        .color;
    expect(fill(), HastaTokens.light['bg.brand']);
    final press = await tester.startGesture(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(fill(), HastaTokens.light['bg.brandPressed']);
    await press.cancel();
    await tester.pumpAndSettle();
    expect(fill(), HastaTokens.light['bg.brand']);
  });

  testWidgets('DS primary fill: busy welcome button renders brandDisabled',
      (tester) async {
    await tester.pumpWidget(
        HastaApp(session: _GuestSession(), locale: const Locale('en')));
    final button = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    final fill = tester
        .widget<Material>(find.descendant(
          of: button,
          matching: find.byType(Material),
        ))
        .color;
    expect(fill, HastaTokens.light['bg.brandDisabled']);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  test('DS 1.0.2 primary fill: disabled opacity is 40% in all palettes', () {
    expect(HastaTokens.light['bg.brandDisabled']!.alpha, (255 * .4).round());
    expect(HastaTokens.dark['bg.brandDisabled']!.alpha, (255 * .4).round());
    expect(HastaTokens.amoled['bg.brandDisabled']!.alpha, (255 * .4).round());
  });

  void setLargeTextViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('T40 text-scale: fixed-height control overflows at 200%',
      (tester) async {
    setLargeTextViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: SizedBox(
          height: 24,
          child: Column(children: [
            Text('Guest profile', style: TextStyle(fontSize: 24)),
          ]),
        ),
      ),
    ));
    expect(
        tester.takeException().toString(), contains('RenderFlex overflowed'));
  });

  for (final language in ['en', 'my']) {
    testWidgets('T37/T43: Gmail linking in Settings, with restart ($language)',
        (tester) async {
      final copy = await AppLocalizations.delegate.load(Locale(language));
      final gmail = _GmailActions();
      Future<void> tap(Finder target) async {
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(HastaApp(
          session: _GuestSession(), locale: Locale(language), gmail: gmail));
      await tester.pumpAndSettle();
      expect(find.text(copy.connectGmail), findsNothing);
      await tap(find.text(copy.welcomeContinue));
      await tap(find.byTooltip(copy.settings));
      await tap(find.text(copy.linkedAccounts));
      final connect = find.widgetWithText(FilledButton, copy.connectGmail);
      expect(find.text(copy.offline), findsOneWidget);
      expect(tester.widget<FilledButton>(connect).onPressed, isNull);
      gmail.offline = false;
      await tap(find.text(copy.retry));
      await tap(connect);
      expect(find.text(copy.gmailRestart), findsOneWidget);
      await tap(connect);
      expect(gmail.connectedAccount, 'guest');
      expect(
          find.text(copy.gmailLinked('a***@example.invalid')), findsOneWidget);
      expect(find.text(copy.gmailUnlinkGuard), findsOneWidget);
    });

    testWidgets('T30/T40: Welcome explains unlinked account loss ($language)',
        (tester) async {
      setLargeTextViewport(tester);
      final locale = Locale(language);
      final session = _GuestSession();
      await tester.pumpWidget(HastaApp(session: session, locale: locale));
      await tester.pumpAndSettle();

      final warning = find.text(language == 'en'
          ? 'If you lose this device without linking Gmail, you can’t recover this account.'
          : 'ဖုန်းပျောက်ပါက ဤအကောင့်ကို ပြန်ရနိုင်မည် မဟုတ်ပါ။ Gmail ချိတ်ဆက်ထားရန် အကြံပြုသည်။');
      expect(warning, findsOneWidget);
      await tester.ensureVisible(warning);
      expect(warning.hitTestable(), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(warning);
      expect(paragraph.maxLines, isNull);
      expect(paragraph.text.style!.height, greaterThanOrEqualTo(1.65));
      expect(tester.takeException(), isNull);
      expect(session.lastLocale, isNull);
    });

    testWidgets('T37: only Guest and Privacy actions before login ($language)',
        (tester) async {
      final locale = Locale(language);
      final copy = await AppLocalizations.delegate.load(locale);
      final session = _GuestSession();
      await tester.pumpWidget(HastaApp(session: session, locale: locale));

      // Check accessible actions, not button types or provider names. Keep
      // this scoped to unauthenticated states so Settings can link Gmail.
      void expectWelcomeActions({required bool canEnterGuest}) {
        final actions = <String>[];
        bool collect(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.hasAction(SemanticsAction.tap)) {
            actions.add('tap: ${data.label}');
          }
          if (data.hasAction(SemanticsAction.longPress)) {
            actions.add('hold: ${data.label}');
          }
          node.visitChildren(collect);
          return true;
        }

        collect(tester.binding.renderViews.single.owner!.semanticsOwner!
            .rootSemanticsNode!);
        expect(
            actions,
            unorderedEquals([
              if (canEnterGuest) 'tap: ${copy.welcomeContinue}',
              'tap: ${copy.privacyTerms}',
            ]));
      }

      expectWelcomeActions(canEnterGuest: false);
      await tester.pumpAndSettle();
      expectWelcomeActions(canEnterGuest: true);

      session.offline = true;
      await tester.tap(find.text(copy.welcomeContinue));
      await tester.pumpAndSettle();
      expect(find.text(copy.offline), findsOneWidget);
      expectWelcomeActions(canEnterGuest: true);

      session.offline = false;
      await tester.tap(find.text(copy.welcomeContinue));
      await tester.pumpAndSettle();
      expect(session.lastLocale, language);
      expect(find.text(copy.guestProfile), findsOneWidget);
      await tester.tap(find.byTooltip(copy.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(copy.signOut));
      await tester.pumpAndSettle();
      expectWelcomeActions(canEnterGuest: true);
    });

    testWidgets('T40 text-scale: profile and Settings at 200% ($language)',
        (tester) async {
      setLargeTextViewport(tester);
      final locale = Locale(language);
      final copy = await AppLocalizations.delegate.load(locale);
      final session = _GuestSession()..profile = const GuestProfile('guest');
      await tester.pumpWidget(HastaApp(session: session, locale: locale));
      await tester.pumpAndSettle();
      final layoutIssues = <String>[];

      void checkText(Finder texts) {
        expect(texts, findsWidgets);
        for (final element in texts.evaluate()) {
          final widget = element.widget as Text;
          final richText = find.descendant(
            of: find.byWidget(widget),
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(richText);
          if (MediaQuery.textScalerOf(element).scale(10) != 20) {
            layoutIssues.add('${widget.data}: text scale is capped');
          }
          if (language == 'my') {
            final span = paragraph.text as TextSpan;
            expect(span.style!.height,
                greaterThanOrEqualTo(HastaTokens.myanmarLineHeight));
          }
          if (paragraph.didExceedMaxLines ||
              paragraph.size.height + 0.01 <
                  paragraph.getMaxIntrinsicHeight(paragraph.size.width)) {
            layoutIssues.add('${widget.data}: truncated or clipped');
          }
        }
        expect(tester.takeException(), isNull);
      }

      checkText(find.text(copy.guestProfile));
      checkText(find.text(copy.emptyProfile));
      final settings = find.byTooltip(copy.settings);
      await tester.ensureVisible(settings);
      expect(settings.hitTestable(), findsOneWidget);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      checkText(find.text(copy.settings));
      expect(layoutIssues, isEmpty);
    });
  }

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
