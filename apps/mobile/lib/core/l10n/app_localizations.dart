import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('my'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hasta'**
  String get appTitle;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again in a moment. (E-500)'**
  String get genericError;

  /// No description provided for @welcomeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get welcomeContinue;

  /// No description provided for @welcomeGuest.
  ///
  /// In en, this message translates to:
  /// **'No email or phone number needed. Get started on this device.'**
  String get welcomeGuest;

  /// No description provided for @guestRisk.
  ///
  /// In en, this message translates to:
  /// **'If you lose this device without linking Gmail, you can’t recover this account.'**
  String get guestRisk;

  /// No description provided for @privacyTerms.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Terms'**
  String get privacyTerms;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'To keep your guest account on this device, Hasta uses a device identifier and stores your credentials securely. This preview does not include final privacy and terms documents.'**
  String get privacySummary;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. Connect to the internet and try again.'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @guestProfile.
  ///
  /// In en, this message translates to:
  /// **'Guest profile'**
  String get guestProfile;

  /// No description provided for @emptyProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile details yet.'**
  String get emptyProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @rateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment, then try again.'**
  String get rateLimited;

  /// No description provided for @transferSend.
  ///
  /// In en, this message translates to:
  /// **'Change device'**
  String get transferSend;

  /// No description provided for @transferReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive Hasta account'**
  String get transferReceive;

  /// No description provided for @transferSendHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep both devices online. On the new device, open Receive Hasta account from the Hasta app icon.'**
  String get transferSendHelp;

  /// No description provided for @transferReceiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR shown in Settings on your old device. Don’t create a guest account on this device first.'**
  String get transferReceiveHelp;

  /// No description provided for @transferShow.
  ///
  /// In en, this message translates to:
  /// **'Show transfer QR'**
  String get transferShow;

  /// No description provided for @transferScan.
  ///
  /// In en, this message translates to:
  /// **'Open camera to scan'**
  String get transferScan;

  /// No description provided for @transferApprove.
  ///
  /// In en, this message translates to:
  /// **'Codes match. Approve transfer'**
  String get transferApprove;

  /// No description provided for @transferCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare this code on both devices. Approve on the old device only if the codes match.'**
  String get transferCompare;

  /// No description provided for @transferQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer QR. Scan it using your new device.'**
  String get transferQrLabel;

  /// No description provided for @transferEnded.
  ///
  /// In en, this message translates to:
  /// **'This transfer has ended. Start a new transfer on your old device.'**
  String get transferEnded;

  /// No description provided for @transferReceiverEnded.
  ///
  /// In en, this message translates to:
  /// **'If you approved the transfer on your old device, close this screen and tap “{continueLabel}” on this device to resume your account. If you did not approve it, start a new transfer on your old device.'**
  String transferReceiverEnded(String continueLabel);

  /// No description provided for @transferGuestExists.
  ///
  /// In en, this message translates to:
  /// **'Delete the guest account on this device before transferring.'**
  String get transferGuestExists;

  /// No description provided for @transferAccountExists.
  ///
  /// In en, this message translates to:
  /// **'This device already has a Hasta account. It can’t receive a transfer.'**
  String get transferAccountExists;

  /// No description provided for @transferCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in system settings to scan the transfer QR.'**
  String get transferCameraDenied;

  /// No description provided for @transferCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A camera is not available on this device.'**
  String get transferCameraUnavailable;

  /// No description provided for @transferInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a Hasta transfer QR. Scan the code on your old device.'**
  String get transferInvalid;

  /// No description provided for @transferApprovalCancelled.
  ///
  /// In en, this message translates to:
  /// **'Approval was cancelled. Your account has not moved.'**
  String get transferApprovalCancelled;

  /// No description provided for @transferUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Protected transfer is not available on this device. Check that your device has a screen lock.'**
  String get transferUnavailable;

  /// No description provided for @transferTime.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds remaining'**
  String transferTime(int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
