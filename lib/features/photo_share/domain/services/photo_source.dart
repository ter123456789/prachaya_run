import 'dart:typed_data';

enum PhotoOrigin { gallery, camera }

/// Port for picking a background photo.
abstract interface class PhotoSource {
  /// Encoded image bytes, or null if the user cancelled.
  Future<Uint8List?> pick(PhotoOrigin origin);
}
