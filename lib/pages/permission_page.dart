import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import 'survey-page.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _requestPermissions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Requesting permissions...';
    });

    try {
      // Ensure we're mounted before proceeding
      if (!mounted) return;

      final permissions = await PermissionService.requestAllPermissions();
      
      if (!mounted) return;

      bool allGranted = permissions.values.every((granted) => granted);

      if (allGranted) {
        await PermissionService.markPermissionsRequested();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SurveyPage()),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _status = 'Please grant all permissions from settings';
        });
        // Show settings dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text('Please enable all required permissions in settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error requesting permissions. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to NaviQuake',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Product Sans',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'We need the following permissions to help keep you safe:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const _PermissionItem(
                icon: Icons.location_on,
                title: 'Location',
                description: 'To navigate you to safety',
              ),
              const _PermissionItem(
                icon: Icons.storage,
                title: 'Storage',
                description: 'To save offline maps and routes',
              ),
              const _PermissionItem(
                icon: Icons.message,
                title: 'SMS',
                description: 'To receive emergency alerts',
              ),
              const SizedBox(height: 30),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _status.contains('Error') ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
