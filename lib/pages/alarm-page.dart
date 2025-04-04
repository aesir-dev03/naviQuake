import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:naviquake/util/osm_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class AlarmPage extends StatefulWidget {
  final Map<String, dynamic>? notificationArgs;

  const AlarmPage({super.key, this.notificationArgs});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showFirstText = false;
  bool _showSecondText = false;
  bool _showNavigatingText = false;
  bool _isOnline = true;
  bool _isDownloading = false;
  late AnimationController _firstTextController;
  late AnimationController _secondTextController;
  late AnimationController _navigatingTextController;
  late Animation<Offset> _firstTextAnimation;
  late Animation<Offset> _secondTextAnimation;
  late Animation<Offset> _navigatingTextAnimation;
  Timer? _vibrationTimer;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkConnectivityAndPlay();
    _startVibration();
  }

  Future<void> _checkConnectivityAndPlay() async {
    setState(() => _isDownloading = true);
    _isOnline = await _checkConnectivity();

    if (_isOnline) {
      // Try to preload routes before starting alarm sequence
      await _preloadRoutes();
    }
    
    _playAudioSequence();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _preloadRoutes() async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLocation = LatLng(position.latitude, position.longitude);

      // Download routes for all evacuation centers
      const evacuationCenters = [
        EvacuationCenter(
          name: 'TNTS Quadrangle',
          description: 'Main evacuation field for students, teachers, and staff.',
          location: LatLng(7.420352, 125.826609),
        ),
        EvacuationCenter(
          name: 'TNTS TVE Evac',
          description: 'Secondary evacuation field for students, teachers, and staff.',
          location: LatLng(7.419977, 125.826950),
        ),
        EvacuationCenter(
          name: 'TNTS Field',
          description: 'Open field evacuation area for temporary shelter.',
          location: LatLng(7.418871, 125.826051),
        ),
      ];

      // Pre-download routes
      for (var center in evacuationCenters) {
        final url = Uri.parse(
          'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
          '${userLocation.longitude},${userLocation.latitude};'
          '${center.location.longitude},${center.location.latitude}'
          '?overview=full&geometries=geojson&steps=true'
        );

        final response = await http.get(url).timeout(
          const Duration(seconds: 5),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to preload route');
        }
      }
    } catch (e) {
      print('Failed to preload routes: $e');
      // Continue with alarm sequence even if route preload fails
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _setupAnimations() {
    // First text animation setup
    _firstTextController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _firstTextAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _firstTextController,
      curve: Curves.easeOut,
    ));

    // Second text animation setup
    _secondTextController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _secondTextAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _secondTextController,
      curve: Curves.easeOut,
    ));

    // Navigating text animation setup
    _navigatingTextController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _navigatingTextAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _navigatingTextController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _playAudioSequence() async {
    try {
      // Play alarm.mp3 immediately without delay
      _audioPlayer.play(AssetSource('audio/alarm/alarm.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      // Show first text and play knowledge1.mp3
      setState(() => _showFirstText = true);
      _firstTextController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _audioPlayer.play(AssetSource('audio/tts/knowledge1.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      // Show second text and play knowledge2.mp3
      setState(() => _showSecondText = true);
      _secondTextController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _audioPlayer.play(AssetSource('audio/tts/knowledge2.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      // Show navigating text and play navigation audio
      setState(() => _showNavigatingText = true);
      _navigatingTextController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _audioPlayer.play(AssetSource('audio/alarm/navigatingnearestroute.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      // Navigate to map with connectivity and preloaded status
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OSMMap(
              autoNavigate: true,
              isOnline: _isOnline,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error playing audio sequence: $e');
    }
  }

  void _startVibration() {
    if (Vibration.hasVibrator() != null) {
      // Create continuous vibration effect using a timer
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        Vibration.vibrate(duration: 500);
      });
    }
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    Vibration.cancel();
    _audioPlayer.dispose();
    _firstTextController.dispose();
    _secondTextController.dispose();
    _navigatingTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.red,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0, 40, 0, 0),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Text('EARTHQUAKE DETECTED!!',
                style: TextStyle(
                  fontSize: 25,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Product Sans'
                 ),
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(0, 100, 0, 0),
              child: Column(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.personal_injury_rounded,
                      size: 100,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
              ),
            ),

            if (_showFirstText)
              SlideTransition(
                position: _firstTextAnimation,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "AVOID INJURIES IN TIMES OF EARTHQUAKE",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Product Sans'
                    ),
                  ),
                ),
              ),

            if (_showSecondText)
              SlideTransition(
                position: _secondTextAnimation,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "STAY CALM AND COMPOSED",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Product Sans'
                    ),
                  ),
                ),
              ),

            if (_showNavigatingText)
              SlideTransition(
                position: _navigatingTextAnimation,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isDownloading 
                          ? "Downloading evacuation routes..."
                          : "Navigating to the nearest route...",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Product Sans'
                        ),
                      ),
                      if (_isDownloading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      )
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final notificationArgs = widget.notificationArgs ?? (routeArgs as Map<String, dynamic>?);
    
    if (notificationArgs != null) {
      // Handle notification arguments here
      final notificationType = notificationArgs['notificationType'];
      final timestamp = notificationArgs['timestamp'];
    }
  }
}