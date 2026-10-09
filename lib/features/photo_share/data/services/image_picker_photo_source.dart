import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../domain/services/photo_source.dart';

class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    final file = await _picker.pickImage(
      source: origin == PhotoOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Exports are 1080 px wide; keep some headroom for cropping.
      maxWidth: 2160,
      maxHeight: 2160,
      imageQuality: 92,
    );
    return file?.readAsBytes();
  }
}
