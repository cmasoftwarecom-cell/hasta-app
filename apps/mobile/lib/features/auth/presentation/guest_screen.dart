import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/design/tokens.dart';
import '../data/guest_repository.dart';
import '../data/native_qr_surface.dart';
import '../data/native_recovery_browser.dart';
import '../domain/guest_session.dart';
import 'device_transfer_screen.dart';

const _environment = String.fromEnvironment('HASTA_ENV');
const _qa = !kReleaseMode &&
    bool.fromEnvironment('HASTA_QUICK_TEST_ACCOUNTS_ENABLED') &&
    (_environment == 'dev' || _environment == 'test' || _environment == 'beta');

class GuestScreen extends StatefulWidget {
  const GuestScreen(
      {super.key, required this.session, this.transferSurface, this.gmail});
  final GuestSession session;
  final NativeQrSurface? transferSurface;
  final GmailLinkActions? gmail;

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  GuestProfile? _profile;
  AuthFailure? _failure;
  bool _busy = true;
  bool _settings = false;
  bool _linkedAccounts = false, _gmailReady = false, _connectingGmail = false;
  bool _submittingGmail = false;
  String? _maskedGmail;
  Timer? _press;
  Future<void> Function()? _retry;
  bool _transferReady = false;
  bool _transferOpen = false;
  bool _receiveRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
    unawaited(_prepareTransfer());
  }

  @override
  void dispose() {
    _press?.cancel();
    widget.transferSurface?.detach();
    widget.gmail?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
      _retry = action;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _failure = error is AuthFailure ? error : const AuthFailure('generic');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _receiveIfReady();
      }
    }
  }

  Future<void> _restore() => _run(() async {
        final cached = await widget.session.cached();
        if (!mounted) return;
        if (cached != null) setState(() => _profile = cached);
        final restored = await widget.session.restore();
        if (mounted) _profile = restored;
      });

  Future<void> _prepareTransfer() async {
    final surface = widget.transferSurface;
    if (surface == null || widget.session is! GuestRepository) return;
    try {
      final launched = await surface.arm(() {
        if (!mounted || _transferOpen) return;
        _receiveRequested = true;
        _receiveIfReady();
      });
      if (!mounted) return;
      setState(() {
        _transferReady = true;
        _receiveRequested = _receiveRequested || launched;
      });
      _receiveIfReady();
    } on AuthFailure {
      // The transfer UI is intentionally unavailable without its native guard.
    }
  }

  void _receiveIfReady() {
    if (!_receiveRequested || !_transferReady || _busy || _transferOpen) return;
    _receiveRequested = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openTransfer(receiving: true));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openTransfer({required bool receiving}) async {
    final session = widget.session;
    final surface = widget.transferSurface;
    if (!_transferReady ||
        _transferOpen ||
        _busy ||
        surface == null ||
        session is! GuestRepository ||
        (!receiving && _profile == null)) {
      return;
    }
    _transferOpen = true;
    try {
      final result = await Navigator.of(context).push<TransferResult>(
        MaterialPageRoute(
          builder: (_) => DeviceTransferScreen(
            repository: session,
            surface: surface,
            receiving: receiving,
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _profile = result.profile;
          _settings = _linkedAccounts = _gmailReady = false;
          _maskedGmail = null;
          _failure = null;
        });
      } else if (!receiving && mounted) {
        await _restore();
      }
    } finally {
      _transferOpen = false;
    }
  }

  Future<void> _enter(String locale) => _run(() async {
        final profile = await widget.session.enter(locale);
        if (mounted) _profile = profile;
      });

  Future<void> _gmail({bool connect = false}) => _run(() async {
        final gmail = widget.gmail!;
        final account = _profile!.accountId;
        setState(() {
          _linkedAccounts = true;
          _connectingGmail = connect;
        });
        try {
          _maskedGmail = connect
              ? await gmail.connect(account, onSubmitting: () {
                  if (mounted) setState(() => _submittingGmail = true);
                })
              : await gmail.status(account);
          _gmailReady = true;
        } catch (error) {
          if (!mounted ||
              (error is AuthFailure && error.code == 'recovery_cancelled')) {
            return;
          }
          if (!_submittingGmail || !_gmailResultUncertain(error)) rethrow;
          // A missing completion reply does not mean the server failed.
          _gmailReady = false;
          try {
            _maskedGmail = await gmail.status(account);
          } catch (_) {
            // Keep Connect disabled until an explicit status check succeeds.
          }
          if (_maskedGmail == null) {
            throw const AuthFailure('gmail_link_status_unknown');
          }
          _gmailReady = true;
        } finally {
          _submittingGmail = _connectingGmail = false;
        }
      });

  bool _gmailResultUncertain(Object error) => switch (error) {
        AuthFailure(code: 'gmail_link_restart' || 'token_expired') => false,
        AuthFailure(code: 'request_in_progress') => true,
        AuthFailure(:final status) => status == null || status >= 500,
        _ => true,
      };

  void _backFromSettings() {
    setState(() {
      _settings = _linkedAccounts;
      if (_linkedAccounts) _failure = null;
      _linkedAccounts = _gmailReady = false;
      _maskedGmail = null;
    });
  }

  Future<void> _signOut() => _run(() async {
        await widget.session.signOut();
        if (mounted) {
          _profile = null;
          _settings = false;
        }
      });

  Future<void> _privacy(AppLocalizations copy) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(copy.privacyTerms),
          content: SingleChildScrollView(child: Text(copy.privacySummary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(copy.close))
          ],
        ),
      );

  Future<void> _openQa() async {
    if (!mounted || _busy || _profile != null) return;
    final selection = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => const _QaFixturePicker(),
    );
    if (selection != null && mounted) {
      await _run(() async {
        final profile =
            await widget.session.enterQa(selection.$1, reset: selection.$2);
        if (mounted) _profile = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final profile = _profile;
    final style = Theme.of(context).textTheme;
    const space = HastaTokens.spacing;
    final failure = _failure;
    final offline = failure?.offline == true;
    final retry = _retry;
    final heading = Text(copy.appTitle, style: style.headlineMedium);
    final title = _linkedAccounts
        ? copy.linkedAccounts
        : _settings
            ? copy.settings
            : copy.profile;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: profile == null ? Alignment.center : Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(space[7]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile != null) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: space[10]),
                    child: Row(
                      children: [
                        if (_settings && !_busy)
                          BackButton(onPressed: _backFromSettings),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(title, style: style.titleLarge),
                          ),
                        ),
                        if (!_settings)
                          IconButton(
                            tooltip: copy.settings,
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: _busy
                                ? null
                                : () => setState(() => _settings = true),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: space[4]),
                ],
                if (profile == null) ...[
                  if (_qa)
                    Listener(
                      onPointerDown: (_) {
                        _press?.cancel();
                        _press = Timer(const Duration(seconds: 3), _openQa);
                      },
                      onPointerUp: (_) => _press?.cancel(),
                      onPointerCancel: (_) => _press?.cancel(),
                      child: heading,
                    )
                  else
                    heading,
                  SizedBox(height: space[4]),
                  Text(copy.welcomeGuest),
                  SizedBox(height: space[4]),
                  Text(copy.guestRisk),
                  SizedBox(height: space[6]),
                ] else if (_linkedAccounts) ...[
                  if (_maskedGmail case final masked?) ...[
                    Text(copy.gmailLinked(masked)),
                    Text(copy.gmailUnlinkGuard),
                  ] else ...[
                    Text(copy.guestRisk),
                    StreamBuilder<bool>(
                      stream: widget.gmail!.networkAvailable,
                      builder: (context, network) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!offline && network.data == false)
                            Semantics(
                                liveRegion: true, child: Text(copy.offline)),
                          if (!offline && network.hasError)
                            Semantics(
                                liveRegion: true,
                                child: Text(copy.genericError)),
                          FilledButton(
                            onPressed: _busy ||
                                    !_gmailReady ||
                                    offline ||
                                    network.connectionState !=
                                        ConnectionState.active ||
                                    network.data != true ||
                                    failure?.status == 404 ||
                                    failure?.code == 'configuration'
                                ? null
                                : () {
                                    if (!_busy) _gmail(connect: true);
                                  },
                            child: Text(copy.connectGmail),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_submittingGmail)
                    Semantics(
                        liveRegion: true, child: Text(copy.gmailFinishing))
                  else if (_connectingGmail)
                    TextButton(
                        onPressed: widget.gmail!.cancel,
                        child: Text(copy.gmailCancel)),
                ] else if (_settings) ...[
                  Text(copy.account, style: style.titleLarge),
                  Text(copy.guestRisk),
                  SizedBox(height: space[5]),
                  if (widget.gmail != null)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _gmail(),
                      child: Text(copy.linkedAccounts),
                    ),
                  if (_transferReady)
                    OutlinedButton(
                      onPressed: _busy || offline
                          ? null
                          : () => _openTransfer(receiving: false),
                      child: Text(copy.transferSend),
                    ),
                  OutlinedButton(
                      onPressed: _busy ? null : _signOut,
                      child: Text(copy.signOut)),
                ] else ...[
                  Semantics(
                    identifier: 'hasta_signed_in_profile',
                    child: Text(profile.displayName ?? copy.guestProfile,
                        style: style.titleLarge),
                  ),
                  Text(
                    profile.username == null
                        ? copy.emptyProfile
                        : '@${profile.username}',
                  ),
                ],
                if (_busy) ...[
                  SizedBox(height: space[4]),
                  LinearProgressIndicator(semanticsLabel: copy.loading),
                ],
                if (failure != null) ...[
                  SizedBox(height: space[4]),
                  Semantics(
                      liveRegion: true,
                      child: Text(switch (failure) {
                        AuthFailure(offline: true) => copy.offline,
                        AuthFailure(code: 'identity_in_use') => copy.gmailInUse,
                        AuthFailure(code: 'gmail_link_status_unknown') =>
                          copy.gmailStatusUnknown,
                        AuthFailure(
                          code: 'gmail_link_restart' || 'token_expired'
                        )
                            when _linkedAccounts =>
                          copy.gmailRestart,
                        AuthFailure(code: 'google_email_unverified') =>
                          copy.gmailUnverified,
                        AuthFailure(status: 429) => copy.rateLimited,
                        _ => copy.genericError,
                      })),
                  if (profile != null && retry != null)
                    TextButton(
                        onPressed: () =>
                            _linkedAccounts ? _gmail() : _run(retry),
                        child: Text(failure.code == 'gmail_link_status_unknown'
                            ? copy.gmailCheckStatus
                            : copy.retry)),
                ],
                if (profile == null) ...[
                  Semantics(
                    identifier: 'hasta_welcome_continue',
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _enter(
                              Localizations.localeOf(context).languageCode),
                      child: Text(copy.welcomeContinue),
                    ),
                  ),
                  TextButton(
                      onPressed: () => _privacy(copy),
                      child: Text(copy.privacyTerms)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QaFixturePicker extends StatefulWidget {
  const _QaFixturePicker();

  @override
  State<_QaFixturePicker> createState() => _QaFixturePickerState();
}

class _QaFixturePickerState extends State<_QaFixturePicker> {
  bool _reset = false;

  @override
  Widget build(BuildContext context) => SimpleDialog(
        title: const Text('Hasta QA fixtures',
            semanticsLabel: 'HASTA_QA_FIXTURE_PANEL_V1'),
        children: [
          SwitchListTile(
              value: _reset,
              onChanged: (value) => setState(() => _reset = value),
              title: const Text('Reset fixture before opening')),
          for (final handle in [
            'tester.a',
            'tester.b',
            'tester.social',
            'tester.premium',
            'tester.minor',
            'tester.fresh'
          ])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, (handle, _reset)),
                child: Text(handle)),
        ],
      );
}
