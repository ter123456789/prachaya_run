import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/route_shape.dart';
import '../../domain/services/image_sink.dart';
import '../../domain/services/photo_source.dart';

enum OverlayLayout {
  /// Strava-style: centred label/value stack, route below, wordmark.
  classic,
  glass,
  full,
  statsOnly,
  routeOnly,
}

/// Language of the labels and units drawn on the image.
enum OverlayLanguage { th, en }

enum OverlayFrame {
  portrait(4 / 5, '4:5'),
  story(9 / 16, '9:16'),
  square(1, '1:1');

  const OverlayFrame(this.aspectRatio, this.label);
  final double aspectRatio;
  final String label;
}

enum OverlayTint { white, black, brand }

/// Numbers that can appear on the image, in display order.
enum OverlayStat { distance, avgSpeed, pace, time, elevation }

/// What sits behind the graphic when no photo is chosen.
enum OverlayBackground {
  /// Branded dark card: ready to post anywhere.
  card,

  /// Transparent PNG for layering on an IG story.
  transparent,
}

enum PhotoOverlayStatus { editing, picking, exporting, saved, shared, failure }

enum PhotoOverlayFailure { permissionDenied, pickFailed, exportFailed }

final class PhotoOverlayState extends Equatable {
  const PhotoOverlayState({
    this.photo,
    this.layout = OverlayLayout.classic,
    this.frame = OverlayFrame.portrait,
    this.tint = OverlayTint.white,
    this.stats = defaultStats,
    this.background = OverlayBackground.card,
    this.language = OverlayLanguage.th,
    this.status = PhotoOverlayStatus.editing,
    this.failure,
  });

  static const defaultStats = [
    OverlayStat.distance,
    OverlayStat.avgSpeed,
    OverlayStat.time,
  ];
  static const maxStats = 4;

  /// Background photo; null falls back to [background].
  final Uint8List? photo;
  final OverlayLayout layout;
  final OverlayFrame frame;
  final OverlayTint tint;

  /// Selected stats, always sorted in [OverlayStat] order, 1–[maxStats].
  final List<OverlayStat> stats;
  final OverlayBackground background;
  final OverlayLanguage language;
  final PhotoOverlayStatus status;
  final PhotoOverlayFailure? failure;

  bool get isBusy =>
      status == PhotoOverlayStatus.picking ||
      status == PhotoOverlayStatus.exporting;

  PhotoOverlayState copyWith({
    Uint8List? photo,
    bool clearPhoto = false,
    OverlayLayout? layout,
    OverlayFrame? frame,
    OverlayTint? tint,
    List<OverlayStat>? stats,
    OverlayBackground? background,
    OverlayLanguage? language,
    PhotoOverlayStatus? status,
    PhotoOverlayFailure? failure,
  }) => PhotoOverlayState(
    photo: clearPhoto ? null : photo ?? this.photo,
    layout: layout ?? this.layout,
    frame: frame ?? this.frame,
    tint: tint ?? this.tint,
    stats: stats ?? this.stats,
    background: background ?? this.background,
    language: language ?? this.language,
    status: status ?? this.status,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    // Compare photo by identity; deep-comparing megabytes on every emit
    // would be wasteful.
    identityHashCode(photo),
    layout,
    frame,
    tint,
    stats,
    background,
    language,
    status,
    failure,
  ];
}

class PhotoOverlayCubit extends Cubit<PhotoOverlayState> {
  PhotoOverlayCubit({
    required PhotoSource photoSource,
    required ImageSink imageSink,
    required this.activity,
  }) : _photoSource = photoSource,
       _imageSink = imageSink,
       route = RouteShape.fromSegments(activity.segments),
       super(const PhotoOverlayState());

  final PhotoSource _photoSource;
  final ImageSink _imageSink;
  final Activity activity;
  final RouteShape route;

  String get _fileName => 'prachaya_run_${activity.id}';

  Future<void> pickPhoto(PhotoOrigin origin) async {
    if (state.isBusy) return;
    emit(state.copyWith(status: PhotoOverlayStatus.picking));
    try {
      final photo = await _photoSource.pick(origin);
      emit(state.copyWith(photo: photo, status: PhotoOverlayStatus.editing));
    } catch (_) {
      emit(
        state.copyWith(
          status: PhotoOverlayStatus.failure,
          failure: PhotoOverlayFailure.pickFailed,
        ),
      );
    }
  }

  void removePhoto() => emit(
    state.copyWith(clearPhoto: true, status: PhotoOverlayStatus.editing),
  );

  void setLayout(OverlayLayout layout) =>
      emit(state.copyWith(layout: layout, status: PhotoOverlayStatus.editing));

  void setFrame(OverlayFrame frame) =>
      emit(state.copyWith(frame: frame, status: PhotoOverlayStatus.editing));

  void setTint(OverlayTint tint) =>
      emit(state.copyWith(tint: tint, status: PhotoOverlayStatus.editing));

  /// Adds or removes a stat, keeping between 1 and [PhotoOverlayState.maxStats].
  void toggleStat(OverlayStat stat) {
    final current = state.stats;
    final List<OverlayStat> next;
    if (current.contains(stat)) {
      if (current.length == 1) return;
      next = [...current]..remove(stat);
    } else {
      if (current.length >= PhotoOverlayState.maxStats) return;
      next = [...current, stat]..sort((a, b) => a.index.compareTo(b.index));
    }
    emit(state.copyWith(stats: next, status: PhotoOverlayStatus.editing));
  }

  void setLanguage(OverlayLanguage language) => emit(
    state.copyWith(language: language, status: PhotoOverlayStatus.editing),
  );

  void setBackground(OverlayBackground background) => emit(
    state.copyWith(background: background, status: PhotoOverlayStatus.editing),
  );

  /// [render] produces the PNG; it lives in the UI because only the widget
  /// tree can rasterize itself.
  Future<void> save(Future<Uint8List> Function() render) => _export(
    render,
    (png) => _imageSink.saveToGallery(png, name: _fileName),
    PhotoOverlayStatus.saved,
  );

  Future<void> share(
    Future<Uint8List> Function() render, {
    ShareAnchor? anchor,
  }) => _export(
    render,
    (png) => _imageSink.share(png, name: _fileName, anchor: anchor),
    PhotoOverlayStatus.shared,
  );

  Future<void> _export(
    Future<Uint8List> Function() render,
    Future<void> Function(Uint8List png) deliver,
    PhotoOverlayStatus done,
  ) async {
    if (state.isBusy) return;
    emit(state.copyWith(status: PhotoOverlayStatus.exporting));
    try {
      await deliver(await render());
      emit(state.copyWith(status: done));
    } on ImageSinkPermissionDenied {
      emit(
        state.copyWith(
          status: PhotoOverlayStatus.failure,
          failure: PhotoOverlayFailure.permissionDenied,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PhotoOverlayStatus.failure,
          failure: PhotoOverlayFailure.exportFailed,
        ),
      );
    }
  }
}
