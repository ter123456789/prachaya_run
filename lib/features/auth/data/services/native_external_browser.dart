import 'package:flutter/services.dart';

import '../../domain/services/external_browser.dart';

/// `prachaya/browser` `open {url}` (AppDelegate.swift / MainActivity.kt):
/// the system browser, no plugin.
class NativeExternalBrowser implements ExternalBrowser {
  const NativeExternalBrowser({
    MethodChannel channel = const MethodChannel('prachaya/browser'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> open(Uri url) async {
    try {
      return await _channel.invokeMethod<bool>('open', {
            'url': url.toString(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
