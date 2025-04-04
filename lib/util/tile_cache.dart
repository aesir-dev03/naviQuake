import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class TileCacheProvider extends TileProvider {
  final String urlTemplate;
  @override
  final Map<String, String> headers;
  final Duration maxStale;
  late final Directory cacheDir;
  bool isInitialized = false;

  TileCacheProvider({
    required this.urlTemplate,
    this.headers = const {},
    this.maxStale = const Duration(days: 30),
  });

  Future<void> initialize() async {
    if (!isInitialized) {
      final appDir = await getApplicationDocumentsDirectory();
      cacheDir = Directory('${appDir.path}/map_tiles');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      isInitialized = true;
    }
  }

  String _getTileFilePath(TileCoordinates coords) {
    return path.join(cacheDir.path, '${coords.z}_${coords.x}_${coords.y}.png');
  }

  Future<bool> _isCacheValid(File file) async {
    final lastModified = await file.lastModified();
    return DateTime.now().difference(lastModified) <= maxStale;
  }

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    return _CachedTileImageProvider(
      coords: coords,
      provider: this,
      options: options,
    );
  }

  Future<File> downloadTile(TileCoordinates coords) async {
    return _downloadTile(coords);
  }

  Future<File> _downloadTile(TileCoordinates coords) async {
    await initialize();
    final tileFile = File(_getTileFilePath(coords));

    try {
      if (await tileFile.exists() && await _isCacheValid(tileFile)) {
        return tileFile;
      }

      final url = urlTemplate
          .replaceAll('{z}', coords.z.toString())
          .replaceAll('{x}', coords.x.toString())
          .replaceAll('{y}', coords.y.toString());

      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        await tileFile.writeAsBytes(response.bodyBytes);
        return tileFile;
      }
      
      throw Exception('Failed to load tile');
    } catch (e) {
      print('Error loading tile: $e');
      if (await tileFile.exists()) {
        return tileFile; // Return cached tile even if expired when offline
      }
      rethrow;
    }
  }
}

class _CachedTileImageProvider extends ImageProvider<_CachedTileImageProvider> {
  final TileCoordinates coords;
  final TileCacheProvider provider;
  final TileLayer options;

  _CachedTileImageProvider({
    required this.coords,
    required this.provider,
    required this.options,
  });

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final file = await provider._downloadTile(coords);
      final bytes = await file.readAsBytes();
      return await decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (e) {
      print('Error loading tile image: $e');
      rethrow;
    }
  }

  @override
  Future<_CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _CachedTileImageProvider &&
        other.coords == coords &&
        other.provider == provider;
  }

  @override
  int get hashCode => Object.hash(coords, provider);
} 