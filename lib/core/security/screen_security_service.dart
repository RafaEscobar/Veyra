import 'package:flutter/services.dart';

abstract interface class ScreenSecurityService {
  Future<void> setSecure(bool secure);
}

final class MethodChannelScreenSecurityService
    implements ScreenSecurityService {
  const MethodChannelScreenSecurityService();

  static const MethodChannel _channel = MethodChannel(
    'com.veyra.app/screen_security',
  );

  @override
  Future<void> setSecure(bool secure) {
    return _channel.invokeMethod<void>(
      secure ? 'enableSecure' : 'disableSecure',
    );
  }
}
