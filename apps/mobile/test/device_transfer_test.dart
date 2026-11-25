import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/features/auth/data/native_transfer_approval.dart';
import 'package:mobile/features/auth/data/profile_cache.dart';
import 'package:mobile/features/auth/domain/device_transfer.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';

class _Credentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.hasta.mobile/transfer_approval');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const native = NativeTransferApproval();
  const id = '019ab40b-08bb-7159-8000-000000000001';
  final token = 'tt_${'A' * 43}';
  final payload = jsonEncode({'v': 1, 'token': token});
  final challenge = 'a1' * 32;
  const match = 'A1A1A1A1';
  Matcher failure(String code) =>
      isA<AuthFailure>().having((x) => x.code, 'code', code);

  test('T25/T27: rejects malformed payloads and does not prompt after expiry',
      () async {
    expect(parseTransferQr(payload), token);
    for (final bad in [
      'https://example.invalid/transfer',
      jsonEncode({'v': 2, 'token': token}),
      jsonEncode({'v': 1, 'token': '$token\n'}),
      jsonEncode({'v': 1, 'token': token, 'redirect': ''}),
    ]) {
      expect(
          () => parseTransferQr(bad), throwsA(failure('transfer_qr_invalid')));
    }
    var prompts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      prompts++;
      throw PlatformException(code: 'transfer_approval_cancelled');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<void> approve(int seconds) {
      final deadline = DateTime.timestamp()
          .add(Duration(seconds: seconds))
          .toIso8601String();
      final offer = TransferOffer.fromReply({
        'transfer_id': id,
        'qr_payload': payload,
        'expires_at': deadline,
      });
      final snapshot = TransferProgress.fromReply({
        'status': 'awaiting_confirmation',
        'approval_challenge': challenge,
        'match_code': match,
        'expires_at': deadline,
      });
      return native.approve(offer, snapshot);
    }

    await expectLater(
        approve(-1), throwsA(failure('transfer_approval_unavailable')));
    expect(prompts, 0);
    await expectLater(
        approve(60), throwsA(failure('transfer_approval_cancelled')));
    expect(prompts, 1);
  });

  test(
      'T27/T28/T29 repository: waits for approval, retries the same write and clears the source',
      () => HttpOverrides.runWithHttpOverrides(() async {
            final saved = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
            driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
            addTearDown(() =>
                driftRuntimeOptions.dontWarnAboutMultipleDatabases = saved);
            final publicKey = 'p' * 122;
            final signature = 's' * 94;
            messenger.setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'publicKey') return publicKey;
              expect(call.method, 'approve');
              expect(call.arguments, challenge);
              return signature;
            });
            addTearDown(
                () => messenger.setMockMethodCallHandler(channel, null));
            final local =
                await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            addTearDown(() => local.close(force: true));
            final deadline = DateTime.timestamp()
                .add(const Duration(seconds: 120))
                .toIso8601String();
            final account = {'id': 'same-account', 'is_guest': true};
            final calls = <(String, String?, String?, Document)>[];
            var confirmed = false;
            var confirmations = 0;
            var occupied = true;
            local.listen((request) async {
              final path = request.uri.path;
              final auth = request.headers.value('authorization');
              final body = request.method == 'GET'
                  ? <String, dynamic>{}
                  : jsonDecode(await utf8.decoder.bind(request).join())
                      as Document;
              calls.add(
                  (path, auth, request.headers.value('idempotency-key'), body));
              final response = request.response;
              response.headers.contentType = ContentType.json;
              Document error(int status, String code) {
                response.statusCode = status;
                return {
                  'error': {'code': code}
                };
              }

              final reply = switch (path.split('/').last) {
                'register' => {'device_token': body['raw_device_id']},
                'guest' => {
                    'account': account,
                    'access_token': 'old-access',
                    'refresh_token': 'old-refresh',
                  },
                'me' => {'account': account, 'profile': account},
                'start' => {
                    'transfer_id': id,
                    'qr_payload': payload,
                    'expires_at': deadline,
                  },
                id => {
                    'status': 'awaiting_confirmation',
                    'approval_challenge': challenge,
                    'match_code': match,
                    'expires_at': deadline,
                  },
                'redeem' when occupied => error(409, 'guest_exists_on_target'),
                'redeem' => {
                    'transfer_id': id,
                    'status': 'awaiting_confirmation',
                    'expires_at': deadline,
                    'match_code': match,
                  },
                'claim' when !confirmed => error(409, 'request_in_progress'),
                'confirm' when confirmations++ == 0 =>
                  error(503, 'unavailable'),
                'confirm' => {'status': 'confirmed'},
                'claim' => {
                    'account': account,
                    'is_new_account': false,
                    'access_token': 'new-access',
                    'refresh_token': 'new-refresh',
                  },
                _ => error(404, 'not_found'),
              };
              if (path.endsWith('/confirm') && response.statusCode == 200) {
                confirmed = true;
              }
              response.write(jsonEncode(reply));
              await response.close();
            });
            final oldStore = _Credentials(), newStore = _Credentials();
            GuestRepository repository(
                String device, _Credentials credentials) {
              final repo = GuestRepository(
                baseUrl: 'http://127.0.0.1:${local.port}',
                credentials: credentials,
                cache: ProfileCache.memory(),
                deviceInfo: () async => {
                  'raw_device_id': device,
                  'platform': 'android',
                  'os_version': '34',
                },
              );
              addTearDown(repo.close);
              return repo;
            }

            final old = repository('source-device', oldStore);
            final target = repository('target-device', newStore);
            await old.enter('en');
            final offer = await old.startDeviceTransfer(native);
            await expectLater(target.redeemDeviceTransfer(offer.qrPayload),
                throwsA(failure('guest_exists_on_target')));
            occupied = false;
            final receipt = await target.redeemDeviceTransfer(offer.qrPayload);
            final progress = await old.deviceTransferStatus(offer);
            expect(progress.matchCode, receipt.matchCode);
            await expectLater(target.claimDeviceTransfer(receipt),
                throwsA(failure('request_in_progress')));
            expect(await target.cached(), isNull);
            final approval = await native.approve(offer, progress);
            await expectLater(old.confirmDeviceTransfer(approval),
                throwsA(failure('unavailable')));
            expect((await old.cached())?.accountId, account['id']);
            await old.confirmDeviceTransfer(approval);
            expect(await old.cached(), isNull);
            expect((await target.claimDeviceTransfer(receipt)).accountId,
                account['id']);
            expect((await target.cached())?.accountId, account['id']);
            final starts =
                calls.where((call) => call.$1.endsWith('/start')).single;
            expect(starts.$2, 'Bearer old-access');
            expect(starts.$4['approval_key'], publicKey);
            final confirms =
                calls.where((call) => call.$1.endsWith('/confirm')).toList();
            expect(confirms[0].$3, confirms[1].$3);
            expect(confirms[1].$4['approval_signature'], signature);
            final claims =
                calls.where((call) => call.$1.endsWith('/claim')).toList();
            expect(claims[0].$3, claims[1].$3);
            expect(claims[1].$2, isNull);
            expect(claims[1].$4['device_token'], 'target-device');
            expect(
                newStore.values.values
                    .any((value) => value.contains('new-refresh')),
                isTrue);
            for (final secret in [token, signature, 'old-refresh']) {
              expect(
                  [...oldStore.values.values, ...newStore.values.values]
                      .any((value) => value.contains(secret)),
                  isFalse);
            }
          }, _LoopbackHttpOverrides()));
}
