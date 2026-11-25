// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hasta';

  @override
  String get genericError =>
      'Something went wrong. Try again in a moment. (E-500)';

  @override
  String get welcomeContinue => 'Continue';

  @override
  String get welcomeGuest =>
      'No email or phone number needed. Get started on this device.';

  @override
  String get guestRisk =>
      'If you lose this device, you may lose access to this guest account.';

  @override
  String get privacyTerms => 'Privacy & Terms';

  @override
  String get privacySummary =>
      'To keep your guest account on this device, Hasta uses a device identifier and stores your credentials securely. This preview does not include final privacy and terms documents.';

  @override
  String get close => 'Close';

  @override
  String get offline =>
      'You’re offline. Connect to the internet and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get profile => 'Profile';

  @override
  String get guestProfile => 'Guest profile';

  @override
  String get emptyProfile => 'No profile details yet.';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get rateLimited => 'Too many attempts. Wait a moment, then try again.';
}
