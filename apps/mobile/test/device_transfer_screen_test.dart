import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/features/auth/data/native_qr_surface.dart';
import 'package:mobile/features/auth/data/native_transfer_approval.dart';
import 'package:mobile/features/auth/data/profile_cache.dart';
import 'package:mobile/features/auth/domain/device_transfer.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';
import 'package:mobile/main.dart';

const _id = '019ab40b-08bb-7159-8000-000000000002';
const _code = 'ABCD1234';
final _qr = jsonEncode({'v': 1, 'token': 'tt_${'Q' * 43}'});
const _profile = GuestProfile('existing-account');

class _Session extends GuestRepository {
  _Session(this.order, this.profile) : super(cache: ProfileCache.memory());
  final List<String> order;
  GuestProfile? profile;
  int guests = 0;
  bool scanned = false;
  Future<void> Function()? reject;
  bool expireOnRedeem = false;
  bool expireOnClaim = false;
  var expires =
      DateTime.timestamp().add(const Duration(seconds: 120)).toIso8601String();

  @override
  Future<GuestProfile?> cached() async => profile;
  @override
  Future<GuestProfile?> restore() async => profile;
  @override
  Future<GuestProfile> enter(String locale) async {
    guests++;
    return profile = _profile;
  }

  @override
  Future<TransferOffer> startDeviceTransfer(NativeTransferApproval _) async {
    order.add('start');
    return TransferOffer.fromReply(
        {'transfer_id': _id, 'qr_payload': _qr, 'expires_at': expires});
  }

  @override
  Future<TransferProgress> deviceTransferStatus(TransferOffer offer) async =>
      TransferProgress.fromReply({
        'status': scanned ? 'awaiting_confirmation' : 'pending',
        'expires_at': expires,
        if (scanned) 'approval_challenge': 'abcd1234${'0' * 56}',
        if (scanned) 'match_code': _code,
      });

  @override
  Future<void> confirmDeviceTransfer(SignedTransferApproval approval) async {
    expect(approval.id, _id);
    order.add('confirmed');
    profile = null;
  }

  @override
  Future<void> rejectDeviceTransfer(TransferOffer offer) async {
    expect(offer.id, _id);
    order.add('reject');
    await reject?.call();
  }

  @override
  Future<TransferReceipt> redeemDeviceTransfer(String qrPayload) async {
    order.add('redeem');
    expect(qrPayload, _qr);
    if (expireOnRedeem) throw const AuthFailure('token_expired', status: 410);
    return TransferReceipt.fromReply({
      'transfer_id': _id,
      'status': 'awaiting_confirmation',
      'match_code': _code,
      'expires_at': expires,
    });
  }

  @override
  Future<GuestProfile> claimDeviceTransfer(TransferReceipt receipt) async {
    order.add('claim');
    if (expireOnClaim) throw const AuthFailure('token_expired', status: 410);
    return profile = _profile;
  }
}

class _Surface extends NativeQrSurface {
  _Surface(this.order);
  final List<String> order;
  bool blocked = false;
  bool cameraDenied = false;
  late void Function() launch;
  @override
  Future<bool> arm(void Function() receive) async {
    launch = receive;
    return false;
  }

  @override
  void detach() {}
  @override
  Future<void> protect() async {
    order.add('protect');
    if (blocked) throw const AuthFailure('transfer_surface_unavailable');
  }

  @override
  Future<QrModules> encode(String payload) async {
    order.add('encode');
    expect(payload, _qr);
    return QrModules(37, Uint8List(37 * 37));
  }

  @override
  Future<String?> scan() async {
    order.add('scan');
    if (cameraDenied) throw const AuthFailure('transfer_camera_denied');
    return _qr;
  }
}

void main() {
  for (final language in ['en', 'my']) {
    for (final receiving in [false, true]) {
      testWidgets(
          'T28/DS QR ${receiving ? 'receiver' : 'sender'} title fits at 200% ($language)',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        tester.view.padding = const FakeViewPadding(top: 24);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final order = <String>[];
        final session = _Session(order, receiving ? null : _profile);
        addTearDown(session.close);
        final surface = _Surface(order);
        await tester.pumpWidget(HastaApp(
            session: session,
            locale: Locale(language),
            transferSurface: surface));
        await tester.pumpAndSettle();
        final copy =
            AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
        if (receiving) {
          surface.launch();
        } else {
          await tester.tap(find.byTooltip(copy.settings));
          await tester.pumpAndSettle();
          final changeDevice = find.text(copy.transferSend).hitTestable();
          await tester.scrollUntilVisible(changeDevice, 100);
          await tester.tap(changeDevice);
        }
        await tester.pumpAndSettle();

        final heading =
            find.text(receiving ? copy.transferReceive : copy.transferSend);
        final help = find
            .text(receiving ? copy.transferReceiveHelp : copy.transferSendHelp);
        final bounds = tester.getRect(heading);
        expect(bounds.top, greaterThanOrEqualTo(24),
            reason: 'No part of the heading may extend above the safe area');
        expect(bounds.bottom, lessThanOrEqualTo(tester.getTopLeft(help).dy),
            reason: 'The entire heading must fit before the body');
        final paragraph = tester.renderObject<RenderParagraph>(heading);
        expect(paragraph.maxLines, isNull);
        expect(paragraph.textScaler.scale(24), 48);
        expect(paragraph.text.style!.height, greaterThanOrEqualTo(1.65));
        expect(
            find.ancestor(
                of: heading,
                matching: find.byWidgetPredicate((widget) =>
                    widget is Semantics && widget.properties.header == true)),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (language, expiry) in [
    ('en', 'timer'),
    ('my', 'claim'),
    ('en', 'redeem'),
  ]) {
    testWidgets('T25/T28 receiver guidance for $expiry expiry ($language)',
        (tester) async {
      final order = <String>[];
      final session = _Session(order, null)
        ..expireOnRedeem = expiry == 'redeem'
        ..expireOnClaim = expiry == 'claim';
      if (expiry == 'timer') {
        session.expires = DateTime.utc(2000).toIso8601String();
      }
      addTearDown(session.close);
      final surface = _Surface(order);
      final my = language == 'my';
      final welcome = my ? 'စတင်အသုံးပြုရန်' : 'Continue';
      await tester.pumpWidget(HastaApp(
          session: session,
          locale: Locale(language),
          transferSurface: surface));
      await tester.pumpAndSettle();
      surface.launch();
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(my ? 'ကင်မရာဖွင့်ပြီး စကင်ဖတ်ရန်' : 'Open camera to scan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(order.contains('claim'), expiry == 'claim');
      if (expiry == 'redeem') {
        expect(find.textContaining('Start a new transfer on your old device.'),
            findsOneWidget);
        expect(find.textContaining('If you approved'), findsNothing);
      } else {
        expect(
            find.textContaining(my
                ? 'အတည်ပြုပြီးပါက ဤစက်တွင်'
                : 'If you approved the transfer on your old device'),
            findsOneWidget);
        expect(find.textContaining('“$welcome”'), findsOneWidget);
      }
      expect(session.guests, 0);
      await tester.tap(find.text(my ? 'ပိတ်ရန်' : 'Close'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, welcome), findsOneWidget);
      expect(session.guests, 0);
    });
  }

  for (final failFirst in [false, true]) {
    testWidgets(
        failFirst
            ? 'T27 Back retains failed cancellation, and Close retries it'
            : 'T27 Back hides the QR and waits for exactly one rejection',
        (tester) async {
      final order = <String>[];
      final response = Completer<void>();
      final session = _Session(order, _profile)..reject = () => response.future;
      addTearDown(session.close);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(HastaApp(
          session: session,
          locale: const Locale('en'),
          transferSurface: _Surface(order)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show transfer QR'));
      await tester.pumpAndSettle();
      final qr =
          find.bySemanticsLabel('Transfer QR. Scan it using your new device.');
      expect(qr, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(order.where((event) => event == 'reject'), hasLength(1));
      expect(qr, findsNothing);
      expect(find.text('Close'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(order.where((event) => event == 'reject'), hasLength(1));
      if (failFirst) {
        response.completeError(const AuthFailure('network', offline: true));
        await tester.pumpAndSettle();
        expect(find.text('Close'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(qr, findsNothing);
        session.reject = () async {};
        await tester.tap(find.text('Close'));
      } else {
        response.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(order.where((event) => event == 'reject'),
          hasLength(failFirst ? 2 : 1));
      expect(order, isNot(contains('confirmed')));
      semantics.dispose();
    });
  }

  testWidgets('T25/T27/T28 sender fails closed and hides QR after optical scan',
      (tester) async {
    final order = <String>[];
    final session = _Session(order, _profile);
    addTearDown(session.close);
    final surface = _Surface(order)..blocked = true;
    final semantics = tester.ensureSemantics();
    const approval = MethodChannel('app.hasta.mobile/transfer_approval');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(approval, (call) async {
      expect(call.method, 'approve');
      expect(call.arguments, 'abcd1234${'0' * 56}');
      return 'A' * 94;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(approval, null));
    await tester.pumpWidget(HastaApp(
        session: session,
        locale: const Locale('en'),
        transferSurface: surface));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show transfer QR'));
    await tester.pumpAndSettle();
    expect(order, ['protect']);
    const qrLabel = 'Transfer QR. Scan it using your new device.';
    expect(find.bySemanticsLabel(qrLabel), findsNothing);
    surface.blocked = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(order, ['protect', 'protect', 'start', 'encode']);
    expect(find.bySemanticsLabel(qrLabel), findsOneWidget);
    expect(find.bySemanticsLabel(_qr), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.bySemanticsLabel(qrLabel), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    session.scanned = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(qrLabel), findsNothing);
    expect(find.text(_code), findsOneWidget);
    await tester.tap(find.text('Codes match. Approve transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(order.last, 'confirmed');
    semantics.dispose();
  });

  testWidgets(
      'T28/T37 receiver uses separate launcher and gates camera permission',
      (tester) async {
    final order = <String>[];
    final session = _Session(order, null);
    addTearDown(session.close);
    final surface = _Surface(order)..cameraDenied = true;
    await tester.pumpWidget(HastaApp(
        session: session,
        locale: const Locale('en'),
        transferSurface: surface));
    await tester.pumpAndSettle();
    expect(find.text('Receive Hasta account'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    surface.launch();
    await tester.pumpAndSettle();
    expect(find.text('Receive Hasta account'), findsOneWidget);
    await tester.tap(find.text('Open camera to scan'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Allow camera access in system settings to scan the transfer QR.'),
        findsOneWidget);
    expect(order, ['protect', 'scan']);
    surface.cameraDenied = false;
    await tester.tap(find.text('Open camera to scan'));
    await tester.pumpAndSettle();
    expect(find.text(_code), findsOneWidget);
    expect(order, ['protect', 'scan', 'protect', 'scan', 'redeem']);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Guest profile'), findsOneWidget);
    expect(order.last, 'claim');
    expect(session.guests, 0);
  });

  testWidgets('T28 receiver stays scrollable in Myanmar at 320×568 and 200%',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final order = <String>[];
    final session = _Session(order, null);
    addTearDown(session.close);
    final surface = _Surface(order)..cameraDenied = true;
    await tester.pumpWidget(HastaApp(
        session: session,
        locale: const Locale('my'),
        transferSurface: surface));
    await tester.pumpAndSettle();
    surface.launch();
    await tester.pumpAndSettle();
    final scan = find.text('ကင်မရာဖွင့်ပြီး စကင်ဖတ်ရန်').hitTestable();
    final scrollable = find.descendant(
        of: find.byType(ListView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(scan, 110, scrollable: scrollable);
    await tester.tap(scan);
    await tester.pumpAndSettle();
    expect(order, ['protect', 'scan']);
    final denial = find
        .text(
            'QR ကုဒ် စကင်ဖတ်ရန် စက်၏ ဆက်တင်များတွင် ကင်မရာ အသုံးပြုခွင့် ပေးပါ။')
        .hitTestable();
    await tester.scrollUntilVisible(denial, -110, scrollable: scrollable);
    expect(denial, findsOneWidget);
    final close = find.text('ပိတ်ရန်').hitTestable();
    await tester.scrollUntilVisible(close, 110, scrollable: scrollable);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('စတင်အသုံးပြုရန်'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
