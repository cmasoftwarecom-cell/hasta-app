import 'dart:convert';

import 'guest_session.dart';

final _id = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
final _token = RegExp(r'^tt_[A-Za-z0-9_-]{43}$');
final _challenge = RegExp(r'^[0-9a-f]{64}$');
final _code = RegExp(r'^[0-9A-F]{8}$');

Never _invalid() => throw const AuthFailure('transfer_reply_invalid');

String transferId(Object? value) =>
    value is String && value.length == 36 && _id.hasMatch(value)
        ? value
        : _invalid();

DateTime _expires(Object? value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc) _invalid();
  return date;
}

String parseTransferQr(String payload) {
  if (payload.length <= 128) {
    try {
      final value = jsonDecode(payload);
      if (value is Map &&
          value.length == 2 &&
          value['v'] is int &&
          value['v'] == 1 &&
          value['token'] is String) {
        final token = value['token'] as String;
        if (token.length == 46 && _token.hasMatch(token)) return token;
      }
    } on FormatException {
      // Never surface the untrusted QR contents in error messages.
    }
  }
  throw const AuthFailure('transfer_qr_invalid');
}

enum TransferStatus {
  pending,
  awaitingConfirmation,
  confirmed,
  rejected,
  expired
}

class TransferOffer {
  TransferOffer.fromReply(Map<String, dynamic> reply)
      : id = transferId(reply['transfer_id']),
        expiresAt = _expires(reply['expires_at']),
        qrPayload = reply['qr_payload'] is String
            ? reply['qr_payload'] as String
            : _invalid() {
    parseTransferQr(qrPayload);
  }

  final String id;
  final DateTime expiresAt;
  final String qrPayload;
}

class TransferReceipt {
  TransferReceipt.fromReply(Map<String, dynamic> reply)
      : id = transferId(reply['transfer_id']),
        expiresAt = _expires(reply['expires_at']),
        matchCode = _matchCode(reply['match_code']) {
    if (reply['status'] != 'awaiting_confirmation') _invalid();
  }

  final String id;
  final DateTime expiresAt;
  final String matchCode;
}

String _matchCode(Object? value) =>
    value is String && value.length == 8 && _code.hasMatch(value)
        ? value
        : _invalid();

class TransferProgress {
  TransferProgress.fromReply(Map<String, dynamic> reply)
      : expiresAt = _expires(reply['expires_at']),
        status = switch (reply['status']) {
          'pending' => TransferStatus.pending,
          'awaiting_confirmation' => TransferStatus.awaitingConfirmation,
          'confirmed' => TransferStatus.confirmed,
          'rejected' => TransferStatus.rejected,
          'expired' => TransferStatus.expired,
          _ => _invalid(),
        } {
    if (status == TransferStatus.awaitingConfirmation) {
      final challenge = reply['approval_challenge'];
      if (challenge is! String ||
          challenge.length != 64 ||
          !_challenge.hasMatch(challenge) ||
          _matchCode(reply['match_code']) !=
              challenge.substring(0, 8).toUpperCase()) {
        _invalid();
      }
      _challengeValue = challenge;
    }
  }

  final DateTime expiresAt;
  final TransferStatus status;
  String? _challengeValue;
  String? get approvalChallenge => _challengeValue;
  String? get matchCode => _challengeValue?.substring(0, 8).toUpperCase();
}
