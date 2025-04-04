import 'dart:math' show pow, pi, log, tan, cos;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_coordinates.dart';
import 'tile_cache.dart';

class MapDownloader {
  final TileCacheProvider tileProvider;
  final LatLng northEast;
  final LatLng southWest;
  final int minZoom;
  final int maxZoom;

  MapDownloader({
    required this.tileProvider,
    required this.northEast,
    required this.southWest,
    this.minZoom = 14,
    this.maxZoom = 18,
  });

  Future<void> downloadArea({
    required Function(double progress, String status) onProgress,
    required Function() onComplete,
    required Function(String error) onError,
  }) async {
    try {
      int totalTiles = _calculateTotalTiles();
      int downloadedTiles = 0;

      for (int z = minZoom; z <= maxZoom; z++) {
        for (int x = _getTileX(southWest, z); x <= _getTileX(northEast, z); x++) {
          for (int y = _getTileY(northEast, z); y <= _getTileY(southWest, z); y++) {
            try {
              await tileProvider.downloadTile(
                TileCoordinates(x, y, z)
              );
              downloadedTiles++;
              
              double progress = downloadedTiles / totalTiles;
              onProgress(
                progress,
                'Downloading tiles: ${(progress * 100).toStringAsFixed(1)}%\n'
                'Tiles: $downloadedTiles/$totalTiles'
              );
            } catch (e) {
              print('Error downloading tile at z:$z, x:$x, y:$y - $e');
            }
          }
        }
      }
      onComplete();
    } catch (e) {
      onError(e.toString());
    }
  }

  int _calculateTotalTiles() {
    int total = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      int xTiles = _getTileX(northEast, z) - _getTileX(southWest, z) + 1;
      int yTiles = _getTileY(southWest, z) - _getTileY(northEast, z) + 1;
      total += xTiles * yTiles;
    }
    return total;
  }

  int _getTileX(LatLng point, int zoom) {
    return ((point.longitude + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int _getTileY(LatLng point, int zoom) {
    double latRad = point.latitude * pi / 180.0;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << zoom)).floor();
  }
} 