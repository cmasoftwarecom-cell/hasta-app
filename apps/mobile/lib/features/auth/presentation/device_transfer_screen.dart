import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../design_tokens.g.dart';
import '../data/guest_repository.dart';
import '../data/native_qr_surface.dart';
import '../data/native_transfer_approval.dart';
import '../domain/device_transfer.dart';
import '../domain/guest_session.dart';

typedef TransferResult = ({GuestProfile? profile});

class DeviceTransferScreen extends StatefulWidget {
  const DeviceTransferScreen({
    super.key,
    required this.repository,
    required this.surface,
    required this.receiving,
    this.approval = const NativeTransferApproval(),
  });

  final GuestRepository repository;
  final NativeQrSurface surface;
  final NativeTransferApproval approval;
  final bool receiving;

  @override
  State<DeviceTransferScreen> createState() => _DeviceTransferScreenState();
}

class _DeviceTransferScreenState extends State<DeviceTransferScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  TransferOffer? _offer;
  TransferReceipt? _receipt;
  TransferProgress? _progress;
  SignedTransferApproval? _signed;
  QrModules? _matrix;
  String? _scanned;
  DateTime? _scannedUntil;
  AuthFailure? _error;
  bool _busy = false;
  bool _polling = false;
  bool _cancelling = false;
  bool _foreground = true;
  bool _done = false;
  int _ticks = 0;
  final _lease = Stopwatch();

  DateTime? get _deadline => _offer?.expiresAt ?? _receipt?.expiresAt;
  int? get _remaining {
    final deadline = _deadline;
    if (deadline == null) return null;
    final wallMs = deadline.difference(DateTime.timestamp()).inMilliseconds;
    final ms = math.min(wallMs, 120000 - _lease.elapsedMilliseconds);
    return math.max(0, (ms / 1000).ceil());
  }

  bool get _expired => _remaining == 0;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground = binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      if (_scannedUntil?.isAfter(DateTime.timestamp()) == false) {
        _scanned = null;
        _scannedUntil = null;
      }
      if (_expired && !_busy) {
        _matrix = null;
        _signed = null;
      }
      if (_deadline != null || _scanned != null) setState(() {});
      if ((++_ticks).isEven) unawaited(_poll());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _polling || _done || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _error = error is AuthFailure ? error : const AuthFailure('generic');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
        // No secret is issued before the actual Activity window is protected.
        await widget.surface.protect();
        if (!mounted) return;
        final offer =
            await widget.repository.startDeviceTransfer(widget.approval);
        if (!mounted) return;
        _offer = offer;
        _lease
          ..reset()
          ..start();
        _matrix = await widget.surface.encode(offer.qrPayload);
      });

  Future<void> _scan() => _run(() async {
        await widget.surface.protect();
        if (!mounted) return;
        final scanned = await widget.surface.scan();
        if (scanned == null || !mounted) return;
        parseTransferQr(scanned);
        _scanned = scanned;
        _scannedUntil = DateTime.timestamp().add(const Duration(seconds: 120));
        await _redeem();
      });

  Future<void> _redeem() async {
    final scanned = _scanned;
    if (scanned == null) return;
    try {
      _receipt = await widget.repository.redeemDeviceTransfer(scanned);
      _lease
        ..reset()
        ..start();
      _scanned = null;
    } on AuthFailure catch (error) {
      if (error.status != null && error.status! < 500) _scanned = null;
      rethrow;
    }
  }

  Future<void> _poll() async {
    if (!_foreground ||
        _busy ||
        _polling ||
        _cancelling ||
        _done ||
        _deadline == null ||
        _expired) return;
    if (widget.receiving
        ? _receipt == null
        : _signed != null || _matrix == null) {
      return;
    }
    // Pause on errors so an offline widget can be retried explicitly. Do not
    // erase an authentication cancellation beneath a user's prompt.
    if (_error != null) return;
    setState(() => _polling = true);
    try {
      await _check();
    } catch (error) {
      if (mounted) {
        _error = error is AuthFailure ? error : const AuthFailure('generic');
      }
    } finally {
      _polling = false;
      if (mounted && !_done) setState(() {});
    }
  }

  Future<void> _check() async {
    final receipt = _receipt;
    if (receipt != null) {
      try {
        final profile = await widget.repository.claimDeviceTransfer(receipt);
        _finish(profile);
      } on AuthFailure catch (error) {
        if (error.code != 'request_in_progress') rethrow;
      }
      return;
    }
    final offer = _offer;
    if (offer == null) return;
    final progress = await widget.repository.deviceTransferStatus(offer);
    _progress = progress;
    if (progress.status != TransferStatus.pending) _matrix = null;
  }

  Future<void> _confirm() => _run(() async {
        final offer = _offer;
        final progress = _progress;
        if (offer == null || progress == null || _expired) return;
        final signed =
            _signed ??= await widget.approval.approve(offer, progress);
        if (!mounted) return;
        await widget.repository.confirmDeviceTransfer(signed);
        _finish(null);
      });

  Future<void> _cancel() => _run(() async {
        final offer = _offer;
        _cancelling = true;
        _matrix = null;
        if (offer != null && !_expired && _signed == null) {
          try {
            await widget.repository.rejectDeviceTransfer(offer);
          } on AuthFailure catch (error) {
            if (error.code != 'token_expired') rethrow;
          }
        }
        if (mounted) Navigator.of(context).pop();
      });

  void _finish(GuestProfile? profile) {
    if (!mounted) return;
    _done = true;
    _matrix = null;
    _scanned = null;
    _signed = null;
    Navigator.of(context).pop<TransferResult>((profile: profile));
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    const space = HastaTokens.spacing;
    final error = _error;
    final terminal = _expired ||
        _progress?.status == TransferStatus.rejected ||
        _progress?.status == TransferStatus.expired ||
        error?.code == 'token_expired' ||
        error?.code == 'token_used';
    final matrix = _matrix;
    final remaining = _remaining;
    final match = _progress?.matchCode ?? _receipt?.matchCode;
    final showQr = _foreground &&
        !_done &&
        !terminal &&
        matrix != null &&
        error == null &&
        match == null;
    final status = terminal
        ? widget.receiving && _receipt != null
            ? copy.transferReceiverEnded(copy.welcomeContinue)
            : copy.transferEnded
        : switch (error) {
            AuthFailure(offline: true) => copy.offline,
            AuthFailure(status: 429) => copy.rateLimited,
            AuthFailure(code: 'guest_exists_on_target') =>
              copy.transferGuestExists,
            AuthFailure(code: 'account_exists_on_target') =>
              copy.transferAccountExists,
            AuthFailure(code: 'transfer_camera_denied') =>
              copy.transferCameraDenied,
            AuthFailure(code: 'transfer_camera_unavailable') =>
              copy.transferCameraUnavailable,
            AuthFailure(code: 'transfer_qr_invalid') => copy.transferInvalid,
            AuthFailure(code: 'transfer_approval_cancelled') =>
              copy.transferApprovalCancelled,
            AuthFailure(code: 'transfer_approval_unavailable') ||
            AuthFailure(code: 'transfer_surface_unavailable') =>
              copy.transferUnavailable,
            AuthFailure() => copy.genericError,
            null when match != null => copy.transferCompare,
            null when widget.receiving => copy.transferReceiveHelp,
            null => copy.transferSendHelp,
          };
    final action = terminal || _cancelling
        ? null
        : widget.receiving
            ? _receipt != null
                ? (error == null ? null : () => _run(_check))
                : _scanned == null
                    ? _scan
                    : () => _run(_redeem)
            : match != null
                ? _confirm
                : _offer == null
                    ? _start
                    : error == null
                        ? null
                        : matrix == null
                            ? () => _run(() async {
                                  await widget.surface.protect();
                                  _matrix = await widget.surface
                                      .encode(_offer!.qrPayload);
                                })
                            : () => _run(_check);
    return PopScope<TransferResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(space[7]),
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.receiving ? copy.transferReceive : copy.transferSend,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SizedBox(height: space[4]),
              Semantics(liveRegion: true, child: Text(status)),
              if (!terminal && remaining != null)
                Text(copy.transferTime(remaining)),
              if (_busy) ...[
                SizedBox(height: space[4]),
                LinearProgressIndicator(semanticsLabel: copy.loading),
              ],
              if (showQr) ...[
                SizedBox(height: space[5]),
                Semantics(
                  identifier: 'hasta_transfer_qr',
                  label: copy.transferQrLabel,
                  image: true,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Center(
                      child: SizedBox.square(
                        dimension:
                            math.min(constraints.maxWidth, space[10] * 5),
                        child: CustomPaint(painter: _QrPainter(matrix)),
                      ),
                    );
                  }),
                ),
              ],
              if (!terminal && match != null) ...[
                SizedBox(height: space[5]),
                Text(match, style: Theme.of(context).textTheme.titleLarge),
              ],
              SizedBox(height: space[5]),
              if (action != null)
                FilledButton(
                  onPressed: _busy || _polling ? null : action,
                  child: Text(widget.receiving
                      ? _receipt != null || _scanned != null
                          ? copy.retry
                          : copy.transferScan
                      : match != null
                          ? copy.transferApprove
                          : error == null
                              ? copy.transferShow
                              : copy.retry),
                ),
              TextButton(
                onPressed: _busy || _polling ? null : _cancel,
                child: Text(copy.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.matrix);
  final QrModules matrix;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = HastaTokens.light;
    final unit = (size.shortestSide / matrix.size).floorToDouble();
    if (unit < 1) return;
    final side = unit * matrix.size;
    final offset = ((size.shortestSide - side) / 2).floorToDouble();
    canvas.drawRect(Offset.zero & size, Paint()..color = colors['bg.canvas']!);
    final ink = Paint()
      ..color = colors['text.primary']!
      ..isAntiAlias = false;
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (matrix.modules[y * matrix.size + x] == 1) {
          canvas.drawRect(
              Rect.fromLTWH(offset + x * unit, offset + y * unit, unit, unit),
              ink);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.matrix != matrix;
}
