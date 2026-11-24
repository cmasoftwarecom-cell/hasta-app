import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mobile/core/design/tokens.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('S0-SMOKE: Flutter app shell mounts', (tester) async {
    await tester.pumpWidget(const HastaApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
