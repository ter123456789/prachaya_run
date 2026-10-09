import 'dart:typed_data';

/// Screen rectangle the share sheet anchors to (required on iPad).
typedef ShareAnchor = ({double left, double top, double width, double height});

/// Port for delivering a finished PNG.
abstract interface class ImageSink {
  /// Throws [ImageSinkPermissionDenied] if gallery access is refused.
  Future<void> saveToGallery(Uint8List png, {required String name});

  Future<void> share(
    Uint8List png, {
    required String name,
    ShareAnchor? anchor,
  });
}

class ImageSinkPermissionDenied implements Exception {
  const ImageSinkPermissionDenied();
}
