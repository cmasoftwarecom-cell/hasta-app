import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/design/tokens.dart';
import '../domain/guest_session.dart';

const _environment = String.fromEnvironment('HASTA_ENV');
const _qa = !kReleaseMode &&
    bool.fromEnvironment('HASTA_QUICK_TEST_ACCOUNTS_ENABLED') &&
    (_environment == 'dev' || _environment == 'test' || _environment == 'beta');

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key, required this.session});
  final GuestSession session;

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  GuestProfile? _profile;
  AuthFailure? _failure;
  bool _busy = true;
  bool _settings = false;
  Timer? _press;
  Future<void> Function()? _retry;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _press?.cancel();
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() => _run(() async {
        final cached = await widget.session.cached();
        if (!mounted) return;
        if (cached != null) setState(() => _profile = cached);
        final restored = await widget.session.restore();
        if (mounted) _profile = restored;
      });

  Future<void> _enter(String locale) => _run(() async {
        final profile = await widget.session.enter(locale);
        if (mounted) _profile = profile;
      });

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
    return Scaffold(
      appBar: profile == null
          ? null
          : AppBar(
              title: Text(_settings ? copy.settings : copy.profile),
              leading: _settings
                  ? BackButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _settings = false))
                  : null,
              actions: [
                if (!_settings)
                  IconButton(
                      tooltip: copy.settings,
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _settings = true)),
              ],
            ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(space[7]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  SizedBox(height: space[6]),
                ] else if (_settings) ...[
                  Text(copy.account, style: style.titleLarge),
                  Text(copy.guestRisk),
                  SizedBox(height: space[5]),
                  OutlinedButton(
                      onPressed: _busy ? null : _signOut,
                      child: Text(copy.signOut)),
                ] else ...[
                  Text(profile.displayName ?? copy.guestProfile,
                      style: style.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      profile.username == null
                          ? copy.emptyProfile
                          : '@${profile.username}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (_busy) ...[
                  SizedBox(height: space[4]),
                  LinearProgressIndicator(semanticsLabel: copy.loading),
                ],
                if (failure != null) ...[
                  SizedBox(height: space[4]),
                  Semantics(
                      liveRegion: true,
                      child: Text(offline
                          ? copy.offline
                          : failure.status == 429
                              ? copy.rateLimited
                              : copy.genericError)),
                  if (profile != null && retry != null)
                    TextButton(
                        onPressed: _busy ? null : () => _run(retry),
                        child: Text(copy.retry)),
                ],
                if (profile == null) ...[
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _enter(
                            Localizations.localeOf(context).languageCode),
                    child: Text(copy.welcomeContinue),
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
