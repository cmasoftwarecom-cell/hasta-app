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
      'If you lose this device without linking Gmail, you can’t recover this account.';

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

  @override
  String get transferSend => 'Change device';

  @override
  String get transferReceive => 'Receive Hasta account';

  @override
  String get transferSendHelp =>
      'Keep both devices online. On the new device, open Receive Hasta account from the Hasta app icon.';

  @override
  String get transferReceiveHelp =>
      'Scan the QR shown in Settings on your old device. Don’t create a guest account on this device first.';

  @override
  String get transferShow => 'Show transfer QR';

  @override
  String get transferScan => 'Open camera to scan';

  @override
  String get transferApprove => 'Codes match. Approve transfer';

  @override
  String get transferCompare =>
      'Compare this code on both devices. Approve on the old device only if the codes match.';

  @override
  String get transferQrLabel => 'Transfer QR. Scan it using your new device.';

  @override
  String get transferEnded =>
      'This transfer has ended. Start a new transfer on your old device.';

  @override
  String transferReceiverEnded(String continueLabel) {
    return 'If you approved the transfer on your old device, close this screen and tap “$continueLabel” on this device to resume your account. If you did not approve it, start a new transfer on your old device.';
  }

  @override
  String get transferGuestExists =>
      'Delete the guest account on this device before transferring.';

  @override
  String get transferAccountExists =>
      'This device already has a Hasta account. It can’t receive a transfer.';

  @override
  String get transferCameraDenied =>
      'Allow camera access in system settings to scan the transfer QR.';

  @override
  String get transferCameraUnavailable =>
      'A camera is not available on this device.';

  @override
  String get transferInvalid =>
      'This is not a Hasta transfer QR. Scan the code on your old device.';

  @override
  String get transferApprovalCancelled =>
      'Approval was cancelled. Your account has not moved.';

  @override
  String get transferUnavailable =>
      'Protected transfer is not available on this device. Check that your device has a screen lock.';

  @override
  String transferTime(int seconds) {
    return '$seconds seconds remaining';
  }
}
