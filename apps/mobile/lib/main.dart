import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/design/tokens.dart';

void main() => runApp(const HastaApp());

class HastaApp extends StatelessWidget {
  const HastaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme:
            ThemeData(scaffoldBackgroundColor: HastaTokens.light['bg.canvas']),
        // S0 is a shell; S1 supplies the first product screen.
        home: const Scaffold(),
      );
}
