import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/image_sink.dart';

class DeviceImageSink implements ImageSink {
  @override
  Future<void> saveToGallery(Uint8List png, {required String name}) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw const ImageSinkPermissionDenied();
    }
    try {
      await Gal.putImageBytes(png, name: name);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw const ImageSinkPermissionDenied();
      }
      rethrow;
    }
  }

  @override
  Future<void> share(
    Uint8List png, {
    required String name,
    ShareAnchor? anchor,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$name.png'));
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: anchor == null
            ? null
            : Rect.fromLTWH(
                anchor.left,
                anchor.top,
                anchor.width,
                anchor.height,
              ),
      ),
    );
  }
}
