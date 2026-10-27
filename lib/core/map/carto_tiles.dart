import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// CARTO basemaps key (carto.com/basemaps/apikey), set at build time:
/// `--dart-define=CARTO_API_KEY=...` or in `dart_defines.prod.json`.
/// Without it CARTO serves "API KEY REQUIRED" tiles.
const String cartoApiKey = String.fromEnvironment('CARTO_API_KEY');

/// CARTO dark raster tiles. Pair with the OpenStreetMap / CARTO attribution.
TileLayer cartoDarkTileLayer(BuildContext context) => TileLayer(
  urlTemplate:
      'https://basemaps.cartocdn.com/rastertiles/dark_all/'
      '{z}/{x}/{y}{r}.png?key=$cartoApiKey',
  retinaMode: RetinaMode.isHighDensity(context),
  userAgentPackageName: 'com.example.prachaya_run',
);
