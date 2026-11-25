import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/device_transfer.dart';
import '../domain/gmail_recovery.dart';
import '../domain/guest_session.dart';
import 'native_transfer_approval.dart';
import 'profile_cache.dart';

const _identityChannel = MethodChannel('app.hasta.mobile/device');
const _backend = String.fromEnvironment('HASTA_API_BASE_URL');
const _version =
    String.fromEnvironment('HASTA_APP_VERSION', defaultValue: '1.0.0');
typedef Document = Map<String, dynamic>;

abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureCredentials implements CredentialStore {
  const SecureCredentials();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions:
        IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
List<int> _random(int count) {
  final random = Random.secure();
  return List.generate(count, (_) => random.nextInt(256));
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
String _uuid7() {
  final bytes = _random(16);
  final ms = DateTime.now().millisecondsSinceEpoch;
  for (var index = 0; index < 6; index++) {
    bytes[index] = (ms >> (8 * (5 - index))) & 255;
  }
  bytes[6] = (bytes[6] & 15) | 112;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = _hex(bytes);
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

Future<Document> _loadNativeDeviceInfo() async =>
    await _identityChannel.invokeMapMethod<String, dynamic>('info') ??
    (throw const AuthFailure('device_unavailable'));

class GuestRepository implements GuestSession {
  GuestRepository({
    String baseUrl = _backend,
    CredentialStore credentials = const SecureCredentials(),
    ProfileCache? cache,
    Future<Document> Function()? deviceInfo,
  })  : _url = Uri.tryParse(baseUrl),
        _store = credentials,
        _db = cache ?? ProfileCache(),
        _deviceInfo = deviceInfo ?? _loadNativeDeviceInfo,
        _namespace = 'hasta.auth.${_digest(baseUrl)}.',
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          followRedirects: false,
          validateStatus: (status) => status != null,
        ));

  final Uri? _url;
  final CredentialStore _store;
  final ProfileCache _db;
  final Future<Document> Function() _deviceInfo;
  final String _namespace;
  final Dio _dio;

  Future<String?> _read(String key) => _store.read('$_namespace$key');
  Future<void> _save(String key, String? value) =>
      _store.write('$_namespace$key', value);

  Uri _endpoint(String path) {
    final base = _url;
    const local = {'127.0.0.1', '::1', 'localhost', '10.0.2.2'};
    if (base == null ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path != '' && base.path != '/') ||
        (base.scheme != 'https' &&
            (kReleaseMode ||
                base.scheme != 'http' ||
                !local.contains(base.host)))) {
      throw const AuthFailure('configuration');
    }
    return base.replace(path: '/v1/$path');
  }

  Future<Document> _request(String path,
      {Document? body, String? key, String? access}) async {
    try {
      final response = await _dio.requestUri<dynamic>(
        _endpoint(path),
        data: body,
        options: Options(method: body == null ? 'GET' : 'POST', headers: {
          if (key != null) 'Idempotency-Key': key,
          if (access != null) 'Authorization': 'Bearer $access',
        }),
      );
      final status = response.statusCode!;
      if (status < 200 || status >= 300) {
        final data = response.data;
        final error = data is Map ? data['error'] : null;
        throw AuthFailure(error is Map ? '${error['code']}' : 'generic',
            status: status);
      }
      return response.data is Map<String, dynamic>
          ? response.data as Document
          : {};
    } on DioException catch (error) {
      const connection = {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout
      };
      throw AuthFailure('network',
          offline: connection.contains(error.type) ||
              error.error is SocketException);
    }
  }

  Future<T> _write<T>(
      String path, Document body, Future<T> Function(Document) apply,
      {String? access}) async {
    // Persist the UUID before the network request. No plaintext inputs are stored in the pending record.
    final slot = 'pending.${_digest(jsonEncode([path, body, access]))}';
    final key = await _read(slot) ?? _uuid7();
    await _save(slot, key);
    try {
      final reply = await _request(path, body: body, key: key, access: access);
      final value = await apply(reply);
      await _save(slot, null);
      return value;
    } on AuthFailure catch (error) {
      if (!error.offline &&
          error.status != null &&
          error.status! < 500 &&
          error.code != 'request_in_progress') {
        await _save(slot, null);
      }
      rethrow;
    }
  }

  Future<String> _proof() async {
    final existing = await _read('proof');
    if (existing != null) return existing;
    final value = _hex(_random(32));
    await _save('proof', value);
    return value;
  }

  Future<String> _deviceToken(String proof) async {
    final existing = await _read('device');
    if (existing != null) return existing;
    final native = await _deviceInfo();
    return _write('auth/device/register', {
      ...native,
      'app_version': _version,
      'device_proof': proof,
    }, (reply) async {
      final token = reply['device_token'] as String;
      await _save('device', token);
      return token;
    });
  }

  Future<GuestProfile> _remember(Document reply, String token,
      {bool qa = false}) async {
    final account = reply['account'] as Document;
    final profile = _project(account);
    await _save(
        'session',
        jsonEncode({
          'account_id': profile.accountId,
          'access': reply['access_token'],
          'refresh': reply['refresh_token'],
          'device': token,
          'qa': qa,
        }));
    await _put(profile);
    return profile;
  }

  @override
  Future<GuestProfile> enter(String locale) async {
    final proof = await _proof();
    final token = await _deviceToken(proof);
    try {
      return await _write(
          'auth/guest',
          {
            'device_token': token,
            'device_proof': proof,
            'locale': locale,
          },
          (reply) => _remember(reply, token));
    } on AuthFailure catch (error) {
      if (error.status == 401) await _save('device', null);
      rethrow;
    }
  }

  Future<GmailRecoveryConsent> beginGmailRecovery(Uri trustedRedirect) async {
    if (trustedRedirect.scheme != 'https' ||
        trustedRedirect.host.isEmpty ||
        trustedRedirect.userInfo.isNotEmpty ||
        trustedRedirect.hasQuery ||
        trustedRedirect.hasFragment) {
      throw const AuthFailure('configuration');
    }
    final proof = await _proof();
    final device = await _deviceToken(proof);
    return _write('auth/recover:start', {
      'provider': 'google',
      'device_token': device,
      'device_proof': proof,
    }, (reply) async {
      final rawUrl = reply['auth_url'];
      final state = reply['state'];
      final nonce = reply['nonce'];
      final ttl = reply['expires_in'];
      final consent = rawUrl is String ? Uri.tryParse(rawUrl) : null;
      final challenge = RegExp(r'^[A-Za-z0-9_-]{43}$');
      if (consent == null ||
          consent.scheme != 'https' ||
          consent.host != 'accounts.google.com' ||
          consent.port != 443 ||
          consent.userInfo.isNotEmpty ||
          consent.path != '/o/oauth2/v2/auth' ||
          consent.hasFragment ||
          state is! String ||
          !challenge.hasMatch(state) ||
          nonce is! String ||
          !challenge.hasMatch(nonce) ||
          ttl is! int ||
          ttl != 300) {
        throw const AuthFailure('recovery_consent_invalid');
      }
      final parameters = consent.queryParametersAll;
      bool matches(String name, String value) {
        final entries = parameters[name];
        return entries != null &&
            entries.length == 1 &&
            entries.single == value;
      }

      if (!matches('redirect_uri', trustedRedirect.toString()) ||
          !matches('response_type', 'code') ||
          !matches('code_challenge_method', 'S256') ||
          !matches('state', state) ||
          !matches('nonce', nonce)) {
        throw const AuthFailure('recovery_consent_invalid');
      }
      return GmailRecoveryConsent(
          consentUrl: consent,
          redirectUri: trustedRedirect,
          state: state,
          expiresAt: DateTime.now().add(Duration(seconds: ttl)));
    });
  }

  Future<GuestProfile> finishGmailRecovery(
      GmailRecoveryConsent consent, Uri browserCallback) async {
    final code = consent.acceptCallback(browserCallback);
    final proof = await _proof();
    final device = await _deviceToken(proof);
    return _write('auth/recover:complete', {
      'device_token': device,
      'device_proof': proof,
      'state': consent.state,
      'code': code,
    }, (reply) {
      final account = reply['account'];
      final access = reply['access_token'];
      final refresh = reply['refresh_token'];
      if (reply['is_new_account'] != false ||
          account is! Document ||
          account['id'] is! String ||
          account['is_guest'] != false ||
          access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        throw const AuthFailure('recovery_reply_invalid');
      }
      return _remember(reply, device);
    });
  }

  Future<Document> _transferSource() async {
    final current = await _session();
    if (current == null || current['qa'] == true) {
      throw const AuthFailure('unauthenticated', status: 401);
    }
    return current;
  }

  Future<TransferOffer> startDeviceTransfer(
      NativeTransferApproval approval) async {
    if (await restore() == null) {
      throw const AuthFailure('unauthenticated', status: 401);
    }
    final source = await _transferSource();
    return _write(
        'auth/transfer/start',
        {
          'device_token': source['device'],
          'device_proof': await _proof(),
          'approval_key': await approval.publicKey(),
        },
        (reply) async => TransferOffer.fromReply(reply),
        access: source['access'] as String);
  }

  Future<TransferProgress> deviceTransferStatus(TransferOffer offer) async {
    final source = await _transferSource();
    return TransferProgress.fromReply(await _request(
        'auth/transfer/${transferId(offer.id)}',
        access: source['access'] as String));
  }

  Future<TransferReceipt> redeemDeviceTransfer(String qrPayload) async {
    final token = parseTransferQr(qrPayload);
    final proof = await _proof();
    final device = await _deviceToken(proof);
    return _write(
        'auth/transfer/redeem',
        {
          'device_token': device,
          'device_proof': proof,
          'token': token,
        },
        (reply) async => TransferReceipt.fromReply(reply));
  }

  Future<void> confirmDeviceTransfer(SignedTransferApproval approval) async {
    final source = await _transferSource();
    await _write('auth/transfer/confirm', {
      'device_token': source['device'],
      'device_proof': await _proof(),
      'transfer_id': transferId(approval.id),
      'approval_signature': approval.signature,
    }, (reply) async {
      if (reply['status'] != 'confirmed') {
        throw const AuthFailure('transfer_reply_invalid');
      }
      if ((await _session())?['account_id'] == source['account_id']) {
        await _forgetSession();
      }
    }, access: source['access'] as String);
  }

  Future<void> rejectDeviceTransfer(TransferOffer offer) async {
    final source = await _transferSource();
    await _write('auth/transfer/reject', {
      'device_token': source['device'],
      'device_proof': await _proof(),
      'transfer_id': transferId(offer.id),
    }, (reply) async {
      if (reply['status'] != 'rejected') {
        throw const AuthFailure('transfer_reply_invalid');
      }
    }, access: source['access'] as String);
  }

  Future<GuestProfile> claimDeviceTransfer(TransferReceipt receipt) async {
    final proof = await _proof();
    final device = await _deviceToken(proof);
    return _write('auth/transfer/claim', {
      'device_token': device,
      'device_proof': proof,
      'transfer_id': transferId(receipt.id),
    }, (reply) {
      final account = reply['account'];
      if (reply['is_new_account'] != false ||
          account is! Document ||
          account['id'] is! String ||
          account['is_guest'] is! bool ||
          reply['access_token'] is! String ||
          reply['refresh_token'] is! String) {
        throw const AuthFailure('transfer_reply_invalid');
      }
      return _remember(reply, device);
    });
  }

  @override
  Future<GuestProfile> enterQa(String handle, {required bool reset}) async {
    final proof = await _proof();
    final token = await _deviceToken(proof);
    return _write(
        'qa/guest',
        {
          'device_token': token,
          'device_proof': proof,
          'handle': handle,
          'reset': reset,
        },
        (reply) => _remember(reply, reply['device_token'] as String, qa: true));
  }

  Future<Document?> _session() async {
    final json = await _read('session');
    return json == null ? null : jsonDecode(json) as Document;
  }

  @override
  Future<GuestProfile?> cached() async {
    final session = await _session();
    if (session == null) return null;
    final id = session['account_id'] as String;
    final saved = await _db.load(id);
    return GuestProfile(id,
        displayName: saved?.displayName, username: saved?.username);
  }

  @override
  Future<GuestProfile?> restore() async {
    final session = await _session();
    if (session == null) return null;
    Document me;
    try {
      me = await _request('me', access: session['access'] as String);
    } on AuthFailure catch (error) {
      if (error.status != 401) rethrow;
      try {
        final next = await _refresh(session);
        me = await _request('me', access: next['access'] as String);
      } on AuthFailure catch (refreshError) {
        if (refreshError.status != 401) rethrow;
        if (session['qa'] != true) await _save('device', null);
        await _forgetSession();
        return null;
      }
    }
    final profile =
        _project(me['account'] as Document, body: me['profile'] as Document);
    await _put(profile);
    return profile;
  }

  Future<Document> _refresh(Document current) async {
    return _write('auth/refresh', {
      'device_token': current['device'],
      'device_proof': await _proof(),
      'refresh_token': current['refresh'],
    }, (reply) async {
      final next = {
        ...current,
        'access': reply['access_token'],
        'refresh': reply['refresh_token']
      };
      await _save('session', jsonEncode(next));
      return next;
    });
  }

  @override
  Future<void> signOut() async {
    final session = await _session();
    if (session == null) return;
    final live = await restore();
    if (live == null) return;
    final current = (await _session())!;
    await _write(
        'auth/logout',
        {
          'device_token': current['device'],
          'device_proof': await _proof(),
          'everywhere': false,
        },
        (_) => _forgetSession(),
        access: current['access'] as String);
  }

  Future<void> _forgetSession() async {
    await _save('session', null);
    await _db.clear();
  }

  GuestProfile _project(Document account, {Document? body}) =>
      GuestProfile(account['id'] as String,
          displayName: (body ?? account)['display_name'] as String?,
          username: (body ?? account)['username'] as String?);

  Future<void> _put(GuestProfile profile) => _db.store(CachedProfile(
      accountId: profile.accountId,
      displayName: profile.displayName,
      username: profile.username));

  @override
  Future<void> close() async {
    _dio.close(force: true);
    await _db.close();
  }
}
