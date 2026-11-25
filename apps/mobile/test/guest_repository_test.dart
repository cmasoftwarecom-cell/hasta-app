import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/guest_repository.dart';
import 'package:mobile/features/auth/data/profile_cache.dart';
import 'package:mobile/features/auth/domain/guest_session.dart';

class _MemoryCredentials implements CredentialStore {
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

void main() {
  test('T30/T37: recovery callback is scoped and stores only the new session',
      () async {
    final secure = _MemoryCredentials();
    final cache = ProfileCache.memory();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final redirect = Uri.https('callback.example.invalid', '/recover');
    final state = List.filled(43, 'a').join();
    final nonce = List.filled(43, 'b').join();
    final requests = <(String, String?, String?, Document)>[];
    var mismatchedConsent = true;
    var retries = 0;
    server.listen((request) async {
      final data =
          jsonDecode(await utf8.decoder.bind(request).join()) as Document;
      final path = request.uri.path;
      requests.add((
        path,
        request.headers.value('idempotency-key'),
        request.headers.value('authorization'),
        data
      ));
      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (path.endsWith('/register')) {
        response.write(jsonEncode({'device_token': 'local-device'}));
      } else if (path.endsWith('/recover:start')) {
        final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'state': state,
          'nonce': nonce,
          'redirect_uri': mismatchedConsent
              ? 'https://wrong.example.invalid/recover'
              : redirect.toString(),
          'response_type': 'code',
          'code_challenge_method': 'S256',
        });
        mismatchedConsent = false;
        response.write(jsonEncode({
          'state': state,
          'nonce': nonce,
          'auth_url': authUrl.toString(),
          'expires_in': 300,
        }));
      } else if (path.endsWith('/recover:complete') && retries++ < 2) {
        response.statusCode = retries == 1 ? 503 : 409;
        response.write(jsonEncode({
          'error': {
            'code': retries == 1 ? 'unavailable' : 'request_in_progress'
          }
        }));
      } else if (path.endsWith('/recover:complete')) {
        response.write(jsonEncode({
          'is_new_account': false,
          'account': {
            'id': 'restored-account',
            'is_guest': false,
            'display_name': 'Traveler'
          },
          'access_token': 'recovered-access',
          'refresh_token': 'recovered-refresh',
        }));
      } else {
        response.statusCode = 404;
      }
      await response.close();
    });
    final repository = GuestRepository(
        baseUrl: 'http://127.0.0.1:${server.port}',
        credentials: secure,
        cache: cache,
        deviceInfo: () async => {
              'raw_device_id': 'device-identifier',
              'platform': 'ios',
              'os_version': '17.0'
            });
    addTearDown(repository.close);
    Matcher errorCode(String code) =>
        isA<AuthFailure>().having((failure) => failure.code, 'code', code);
    await expectLater(repository.beginGmailRecovery(redirect),
        throwsA(errorCode('recovery_consent_invalid')));
    final consent = await repository.beginGmailRecovery(redirect);
    expect(consent.state, state);
    expect(requests[1].$2, requests[2].$2);
    expect(requests[1].$4['provider'], 'google');
    expect(requests[1].$4['device_proof'], requests[0].$4['device_proof']);
    final callback = redirect
        .replace(queryParameters: {'state': state, 'code': 'local-code'});
    for (final invalid in [
      callback.replace(host: 'wrong.example.invalid'),
      callback.replace(path: '/other'),
      callback.replace(query: 'state=$state&state=$state&code=local-code'),
      callback.replace(query: 'state=wrong&code=local-code'),
    ]) {
      await expectLater(repository.finishGmailRecovery(consent, invalid),
          throwsA(errorCode('recovery_callback_invalid')));
    }
    await expectLater(
        repository.finishGmailRecovery(consent,
            callback.replace(query: 'state=$state&error=access_denied')),
        throwsA(errorCode('recovery_cancelled')));
    expect(requests.length, 3);
    expect(await repository.cached(), isNull);
    await expectLater(repository.finishGmailRecovery(consent, callback),
        throwsA(errorCode('unavailable')));
    await expectLater(repository.finishGmailRecovery(consent, callback),
        throwsA(errorCode('request_in_progress')));
    final profile = await repository.finishGmailRecovery(consent, callback);
    expect(profile.accountId, 'restored-account');
    expect((await repository.cached())?.displayName, 'Traveler');
    expect(requests[3].$2, requests[4].$2);
    expect(requests[3].$2, requests[5].$2);
    expect(requests[5].$4['code'], 'local-code');
    expect(requests.every((request) => request.$3 == null), isTrue);
    expect(secure.values.values.any((value) => value.contains('local-code')),
        isFalse);
    expect(
        secure.values.values
            .any((value) => value.contains('recovered-refresh')),
        isTrue);
    expect((await cache.load('restored-account'))?.displayName, 'Traveler');
  });

  test(
      'T40/T41/T42: proof durability, lost response retry, refresh, cache and logout',
      () async {
    final secure = _MemoryCredentials();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final baseUrl = 'http://127.0.0.1:${server.port}';
    final requests = <(String, String?, String?, Document)>[];
    var dropRegister = true;
    var rejectAccess = true;
    final account = {
      'id': 'guest',
      'display_name': 'Traveler',
      'username': null
    };
    final credentials = {'access_token': 'access', 'refresh_token': 'refresh'};

    server.listen((request) async {
      final path = request.uri.path;
      final body = request.method == 'POST'
          ? jsonDecode(await utf8.decoder.bind(request).join()) as Document
          : <String, dynamic>{};
      final auth = request.headers.value('authorization');
      requests
          .add((path, request.headers.value('idempotency-key'), auth, body));
      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (path.endsWith('/register') && dropRegister) {
        dropRegister = false;
        response.statusCode = 503;
      } else if (path.endsWith('/register')) {
        response.write(jsonEncode({'device_token': 'device'}));
      } else if (path.endsWith('/guest')) {
        response.write(jsonEncode({...credentials, 'account': account}));
      } else if (path.endsWith('/me') && rejectAccess) {
        response.statusCode = 401;
      } else if (path.endsWith('/me')) {
        response.write(jsonEncode({'account': account, 'profile': account}));
      } else if (path.endsWith('/refresh')) {
        rejectAccess = false;
        response.write(jsonEncode(
            {'access_token': 'next', 'refresh_token': 'next-refresh'}));
      } else if (path == '/v1/auth/sessions') {
        response.write(jsonEncode([
          {
            'id': 'fixture-session',
            'device_hash_short': 'abcdef01',
            'platform': 'android',
            'created_at': '2026-11-25T12:00:00Z',
            'last_seen_at': null,
            'current': true,
          },
        ]));
      } else if (path.endsWith('/logout')) {
        response.statusCode = 204;
      } else {
        response.statusCode = 404;
      }
      await response.close();
    });

    GuestRepository make(ProfileCache db) => GuestRepository(
          baseUrl: baseUrl,
          credentials: secure,
          cache: db,
          deviceInfo: () async => {
            'raw_device_id': 'device-identifier',
            'platform': 'android',
            'os_version': '33'
          },
        );
    final first = make(ProfileCache.memory());
    await expectLater(
        first.enter('my'),
        throwsA(isA<AuthFailure>()
            .having((error) => error.status, 'HTTP status', 503)));
    final proof = requests.single.$4['device_proof'] as String;
    expect(proof, matches(r'^[a-f0-9]{64}$'));
    expect(secure.values.values, contains(proof));
    expect(secure.values.values, isNot(contains('device-identifier')));
    await first.close();

    final db = ProfileCache.memory();
    final second = make(db);
    addTearDown(second.close);
    expect((await second.enter('my')).accountId, 'guest');
    expect(requests[1].$2, requests[0].$2,
        reason: 'same idempotency key across repository restart');
    expect(jsonEncode(requests[1].$4) == jsonEncode(requests[0].$4), isTrue,
        reason: 'same enrollment payload across repository restart');
    expect(requests[2].$4['locale'], 'my');
    expect((await second.cached())?.displayName, 'Traveler');
    expect((await db.load('guest'))!.toJson(),
        {'accountId': 'guest', 'displayName': 'Traveler', 'username': null});
    final before = requests.length;
    await expectLater(
        second.listDeviceSessions('other'),
        throwsA(
            isA<AuthFailure>().having((error) => error.status, 'status', 401)));
    expect(requests.length, before);
    expect(await second.listDeviceSessions('guest'), [
      (
        platform: 'android',
        lastActive: DateTime.utc(2026, 11, 25, 12),
        current: true
      ),
    ]);
    expect(requests.last.$1, '/v1/auth/sessions');
    expect(requests.last.$2, isNull);
    expect(requests.last.$3, 'Bearer next');
    final refresh = requests.firstWhere((item) => item.$1.endsWith('/refresh'));
    expect(refresh.$4, {
      'device_token': 'device',
      'device_proof': proof,
      'refresh_token': 'refresh'
    });
    await second.signOut();
    expect(requests.last.$3, 'Bearer next');
    expect(requests.last.$4['device_proof'], proof);
    expect(await second.cached(), isNull);
    expect(await db.load('guest'), isNull);
    for (final item in requests.where((item) => item.$4.isNotEmpty)) {
      expect(
          item.$2,
          matches(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-7[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$'));
    }
  });
}
