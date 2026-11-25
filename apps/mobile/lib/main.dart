import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/design/tokens.dart';
import 'features/auth/data/guest_repository.dart';
import 'features/auth/data/native_qr_surface.dart';
import 'features/auth/data/native_recovery_browser.dart';
import 'features/auth/domain/guest_session.dart';
import 'features/auth/presentation/guest_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const env = String.fromEnvironment('HASTA_ENV');
  const qrQa = kDebugMode &&
      bool.fromEnvironment('HASTA_AUTH_QR_TRANSFER_ENABLED') &&
      (env == 'dev' || env == 'test' || env == 'beta');
  const gmailQa =
      kDebugMode && bool.fromEnvironment('HASTA_AUTH_GOOGLE_LINK_ENABLED');
  final session = GuestRepository();
  runApp(HastaApp(
    session: session,
    gmail: gmailQa &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
        ? GmailLinkFlow(session)
        : null,
    transferSurface: qrQa && defaultTargetPlatform == TargetPlatform.android
        ? const NativeQrSurface()
        : null,
  ));
}

class HastaApp extends StatelessWidget {
  const HastaApp(
      {super.key,
      required this.session,
      this.locale,
      this.transferSurface,
      this.gmail});

  final GuestSession session;
  final Locale? locale;
  final NativeQrSurface? transferSurface;
  final GmailLinkActions? gmail;

  @override
  Widget build(BuildContext context) {
    const palette = HastaTokens.light;
    final colors = ColorScheme.light(
      primary: palette['bg.brand']!,
      onPrimary: palette['text.onBrand']!,
      surface: palette['bg.surface']!,
      onSurface: palette['text.primary']!,
      error: palette['text.danger']!,
    );
    const type = HastaTokens.myanmarType;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: palette['bg.canvas'],
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.disabled)) {
                return palette['bg.brandDisabled']!;
              }
              if (states.contains(WidgetState.pressed)) {
                return palette['bg.brandPressed']!;
              }
              return palette['bg.brand']!;
            }),
            // The pressed fill already represents the interaction. Keep the
            // Material defaults for focus and hover without tinting that fill.
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.transparent
                  : null,
            ),
          ),
        ),
        textTheme: TextTheme(
          headlineMedium: type['display'],
          titleLarge: type['h1'],
          bodyLarge: type['body'],
          bodyMedium: type['body'],
          labelLarge: type['button'] ?? type['body'],
        ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
        fontFamily: HastaTokens.myanmarFontFamily,
      ),
      home: GuestScreen(
          session: session, transferSurface: transferSurface, gmail: gmail),
    );
  }
}
