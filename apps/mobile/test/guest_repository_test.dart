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
    expect((await second.restore())?.accountId, 'guest');
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
