import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../util/osm_map.dart';
import '../util/tile_cache.dart';
import '../util/map_downloader.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class EvacuateLocations extends StatefulWidget {
  const EvacuateLocations({super.key});

  @override
  State<EvacuateLocations> createState() => _EvacuateLocationsState();
}

class _EvacuateLocationsState extends State<EvacuateLocations> {
  static const platform = MethodChannel('com.naviquake/permissions');
  bool _isDownloading = false;
  String _downloadStatus = '';
  double _downloadProgress = 0;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _setupPermissionChannel();
    _requestNativePermission();
  }

  void _setupPermissionChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionResult') {
        final bool granted = call.arguments as bool;
        setState(() {
          _hasPermission = granted;
        });
        if (!granted) {
          _showPermissionDeniedDialog();
        }
      }
    });
  }

  Future<void> _requestNativePermission() async {
    try {
      final status = await Permission.manageExternalStorage.request();
      setState(() {
        _hasPermission = status.isGranted;
      });
      if (!status.isGranted) {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print("Failed to get permissions: '$e'.");
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Storage permission is required for offline maps. '
            'Please grant permission in settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDialog() {
    _requestNativePermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Evacuation Centers',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Product Sans',
          ),
        ),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_hasPermission)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _isDownloading ? null : _downloadMapArea,
              tooltip: 'Download map for offline use',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasPermission)
            const OSMMap()
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Storage Permission Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Please grant storage permission to view and cache maps for offline use.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showPermissionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            ),
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _downloadStatus,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadMapArea() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadStatus = 'Preparing download...';
    });

    try {
      final tileProvider = TileCacheProvider(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        headers: {'User-Agent': 'com.naviquake.app'},
      );
      await tileProvider.initialize();

      final downloader = MapDownloader(
        tileProvider: tileProvider,
        northEast: const LatLng(7.421352, 125.827609),
        southWest: const LatLng(7.417871, 125.825051),
        minZoom: 15,
        maxZoom: 18,
      );

      await downloader.downloadArea(
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _downloadStatus = status;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadStatus = 'Download complete!';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Map downloaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadStatus = 'Error: $error';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to download map: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Error: $e';
        });
      }
    }
  }
}

class EvacuationCenterTile extends StatelessWidget {
  final String name;
  final String address;
  final String distance;

  const EvacuationCenterTile({super.key, 
    required this.name,
    required this.address,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Product Sans',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          address,
          style: const TextStyle(fontFamily: 'Product Sans'),
        ),
        trailing: Text(
          distance,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Product Sans',
          ),
        ),
        onTap: () {
          // TODO: Implement navigation to this location on the map
        },
      ),
    );
  }
}
