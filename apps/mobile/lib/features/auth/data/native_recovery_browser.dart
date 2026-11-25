import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/gmail_recovery.dart';
import '../domain/guest_session.dart';
import 'guest_repository.dart';

class NativeRecoveryBrowser {
  NativeRecoveryBrowser({
    MethodChannel channel = const MethodChannel('app.hasta.mobile/recovery'),
  }) : _channel = channel;

  final MethodChannel _channel;
  static bool _busy = false;
  void Function()? _cancel;

  Future<Uri> trustedRedirect() async {
    final raw = await _channel.invokeMethod<String>('trustedRedirect');
    final redirect = raw == null ? null : Uri.tryParse(raw);
    if (redirect == null ||
        redirect.scheme != 'https' ||
        redirect.port != 443 ||
        redirect.host.isEmpty ||
        redirect.host.endsWith('.invalid') ||
        redirect.path != '/auth/recovery/callback' ||
        redirect.userInfo.isNotEmpty ||
        redirect.hasQuery ||
        redirect.hasFragment) {
      throw const AuthFailure('configuration');
    }
    return redirect;
  }

  Future<Uri> authorize(GmailRecoveryConsent consent, {Duration? timeout}) =>
      waitForCallback(
        consent,
        open: () => _channel.invokeMethod<void>(
            'openConsent', consent.consentUrl.toString()),
        timeout: timeout,
      );

  void cancel() => _cancel?.call();

  Future<Uri> waitForCallback(
    GmailRecoveryConsent consent, {
    required Future<void> Function() open,
    Uri? Function(Uri)? mapCallback,
    Duration? timeout,
  }) async {
    if (_busy) throw const AuthFailure('request_in_progress');
    _busy = true;
    final result = Completer<Uri>();
    _cancel = () {
      if (result.isCompleted) return;
      result.completeError(const AuthFailure('recovery_cancelled'));
    };
    Timer? timer;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'callback' ||
          call.arguments is! String ||
          result.isCompleted) {
        return;
      }
      final raw = Uri.tryParse(call.arguments as String);
      if (raw == null) return;
      final callback = mapCallback == null ? raw : mapCallback(raw);
      if (callback == null) return;
      try {
        consent.acceptCallback(callback);
        result.complete(callback);
      } on AuthFailure catch (error) {
        if (error.code == 'recovery_cancelled') result.completeError(error);
        // Unrelated/malformed links must not interrupt the active request.
      }
    });
    try {
      final left = consent.expiresAt.difference(DateTime.now());
      if (left <= Duration.zero) throw const AuthFailure('token_expired');
      final maxWait = timeout != null && timeout < left ? timeout : left;
      timer = Timer(maxWait, () {
        if (!result.isCompleted) {
          result.completeError(const AuthFailure('token_expired'));
        }
      });
      final values = await Future.wait<Object?>([
        result.future,
        Future<void>.sync(open),
      ], eagerError: true);
      return values.first! as Uri;
    } on PlatformException {
      throw const AuthFailure('recovery_browser_unavailable');
    } finally {
      timer?.cancel();
      _cancel = null;
      _channel.setMethodCallHandler(null);
      _busy = false;
    }
  }
}

abstract interface class GmailLinkActions {
  Future<String?> status(String accountId);
  Future<String> connect(String accountId);
  void cancel();
}

class GmailLinkFlow implements GmailLinkActions {
  GmailLinkFlow(this.repository);

  final GuestRepository repository;
  final browser = NativeRecoveryBrowser();
  int _attempt = 0;

  @override
  Future<String?> status(String accountId) => repository.linkedGmail(accountId);

  @override
  Future<String> connect(String accountId) async {
    final attempt = ++_attempt;
    void requireActive() {
      if (attempt != _attempt) throw const AuthFailure('recovery_cancelled');
    }

    final consent = await repository.beginGmailRecovery(
        await browser.trustedRedirect(),
        linkAccountId: accountId);
    requireActive();
    final callback = await browser.authorize(consent);
    requireActive();
    return repository.finishGmailLink(accountId, consent, callback);
  }

  @override
  void cancel() {
    _attempt++;
    browser.cancel();
  }
}

/// For an explicitly initiated lost-device recovery surface, never Welcome.
class GmailRecoveryFlow {
  GmailRecoveryFlow(this.repository, {NativeRecoveryBrowser? browser})
      : browser = browser ?? NativeRecoveryBrowser();

  final GuestRepository repository;
  final NativeRecoveryBrowser browser;

  Future<GuestProfile> recover() async {
    final consent =
        await repository.beginGmailRecovery(await browser.trustedRedirect());
    final callback = await browser.authorize(consent);
    return repository.finishGmailRecovery(consent, callback);
  }
}
