import 'package:flutter/services.dart';

import '../domain/device_transfer.dart';
import '../domain/guest_session.dart';

class QrModules {
  QrModules(this.size, this.modules);
  final int size;
  final Uint8List modules;
}

class NativeQrSurface {
  const NativeQrSurface();
  static const _channel = MethodChannel('app.hasta.mobile/qr_surface');

  Future<bool> arm(void Function() receive) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'receive' && call.arguments == null) receive();
    });
    return await _invoke<bool>('arm') == true;
  }

  void detach() => _channel.setMethodCallHandler(null);

  Future<void> protect() async {
    if (await _invoke<bool>('protect') != true) {
      throw const AuthFailure('transfer_surface_unavailable');
    }
  }

  Future<QrModules> encode(String payload) async {
    parseTransferQr(payload);
    final matrix = await _invoke<Map<dynamic, dynamic>>('encode', payload);
    final size = matrix?['size'];
    final modules = matrix?['modules'];
    if (size is! int ||
        size < 29 ||
        size > 185 ||
        modules is! Uint8List ||
        modules.length != size * size ||
        modules.any((cell) => cell > 1)) {
      throw const AuthFailure('transfer_surface_unavailable');
    }
    return QrModules(size, modules);
  }

  Future<String?> scan() => _invoke<String>('scan');

  Future<T?> _invoke<T>(String method, [Object? value]) async {
    try {
      return await _channel.invokeMethod<T>(method, value);
    } on MissingPluginException {
      throw const AuthFailure('transfer_surface_unavailable');
    } on PlatformException catch (error) {
      throw AuthFailure(switch (error.code) {
        'transfer_camera_denied' ||
        'transfer_camera_unavailable' ||
        'transfer_qr_invalid' =>
          error.code,
        _ => 'transfer_surface_unavailable',
      });
    }
  }
}
