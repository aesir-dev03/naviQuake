import 'package:flutter/material.dart';
import 'package:naviquake/util/SharedPreferencesHelper.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:naviquake/pages/alarm-page.dart';
import 'package:naviquake/services/background_service.dart';
import 'dart:async';



class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String name = '';
  int age = 0;
  String gender = '';
  String phoneNumber = '';
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController arduinoSimController = TextEditingController();
  
  bool isNameEditing = false;
  bool isAgeEditing = false;
  bool isGenderEditing = false;
  bool isPhoneEditing = false;
  bool isArduinoConnecting = false;

  String? selectedGender;
  final List<String> genderOptions = ['Male', 'Female', 'Helicopter', 'Others'];

  String? profileImagePath;
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;

  Timer? _statusUpdateTimer;
  bool _isServiceRunning = false;
  String _lastUpdateTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadArduinoSim();
    _checkServiceStatus();
    // Update status every 30 seconds
    _statusUpdateTimer = Timer.periodic(
      const Duration(seconds: 30), 
      (_) => _checkServiceStatus()
    );
  }

  Future<void> _loadUserData() async {
    final prefsHelper = SharedPreferencesHelper();
    await prefsHelper.init();

    setState(() {
      name = prefsHelper.getString('name') ?? 'Null';
      age = prefsHelper.getInt('age');
      gender = prefsHelper.getString('gender') ?? 'Null';
      phoneNumber = prefsHelper.getString('phoneNumber') ?? 'Null';
      profileImagePath = prefsHelper.getImagePath();
      nameController.text = name;
      ageController.text = age.toString();
      genderController.text = gender;
      phoneController.text = phoneNumber;
      selectedGender = gender;
    });
  }

  Future<void> _loadArduinoSim() async {
    final prefsHelper = SharedPreferencesHelper();
    await prefsHelper.init();
    setState(() {
      arduinoSimController.text = prefsHelper.getString('arduino_sim') ?? '';
    });
  }

  Future<void> _updateUserData() async {
    final prefsHelper = SharedPreferencesHelper();
    await prefsHelper.init();

    await prefsHelper.setString('name', nameController.text);
    await prefsHelper.setInt('age', int.tryParse(ageController.text) ?? 0);
    await prefsHelper.setString('gender', selectedGender ?? gender);
    await prefsHelper.setString('phoneNumber', phoneController.text);

    _loadUserData();
  }

  Future<void> _connectArduino() async {
    if (arduinoSimController.text.isEmpty) return;

    setState(() {
      isArduinoConnecting = true;
    });

    try {
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));
      
      final prefsHelper = SharedPreferencesHelper();
      await prefsHelper.init();
      await prefsHelper.setString('arduino_sim', arduinoSimController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arduino SIM connected successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect Arduino SIM')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isArduinoConnecting = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      // Check Android version
      if (Platform.isAndroid) {
        if (await _requestPermissions()) {
          await _proceedWithImagePicking();
        } else {
          // Show dialog if permission denied
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'This app needs access to your photos to set a profile picture. '
                  'Please grant access in your device settings.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text('Open Settings'),
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // For iOS or other platforms
        await _proceedWithImagePicking();
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    // For Android 13 and above
    if (await Permission.photos.request().isGranted) {
      return true;
    }
    // For Android 12 and below
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  Future<void> _proceedWithImagePicking() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
      
      // Save to SharedPreferences
      final prefsHelper = SharedPreferencesHelper();
      await prefsHelper.init();
      await prefsHelper.setString('profile_image', image.path);
      
      print('Image saved successfully: ${image.path}');
    }
  }

  Future<void> _checkServiceStatus() async {
    final status = await BackgroundServiceHelper.getServiceStatus();
    if (mounted) {
      setState(() {
        _isServiceRunning = status['isRunning'];
        _lastUpdateTime = status['lastUpdate'] != null 
          ? _formatDateTime(status['lastUpdate'])
          : 'Never';
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView( // Add SingleChildScrollView here
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Center(
                child: GradientText(
              'Settings',
               colors: [
                Colors.red,
                Colors.red.shade400,
                Colors.red.shade600
               ],
               style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold
               ),),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: const OutlineInputBorder(),
                        enabled: isNameEditing,
                      ),
                      onSubmitted: (value) async {
                        setState(() {
                          isNameEditing = false;
                        });
                        await _updateUserData();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(isNameEditing ? Icons.check : Icons.edit),
                    onPressed: () {
                      setState(() {
                        isNameEditing = !isNameEditing;
                        if (!isNameEditing) {
                          _updateUserData();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        border: const OutlineInputBorder(),
                        enabled: isAgeEditing,
                      ),
                      onSubmitted: (value) async {
                        setState(() {
                          isAgeEditing = false;
                        });
                        await _updateUserData();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(isAgeEditing ? Icons.check : Icons.edit),
                    onPressed: () {
                      setState(() {
                        isAgeEditing = !isAgeEditing;
                        if (!isAgeEditing) {
                          _updateUserData();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: const OutlineInputBorder(),
                        enabled: isGenderEditing,
                      ),
                      items: genderOptions.map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: isGenderEditing ? (String? value) {
                        setState(() {
                          selectedGender = value;
                          genderController.text = value ?? '';
                        });
                        _updateUserData();
                      } : null,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isGenderEditing ? Icons.check : Icons.edit),
                    onPressed: () {
                      setState(() {
                        isGenderEditing = !isGenderEditing;
                        if (!isGenderEditing) {
                          _updateUserData();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: const OutlineInputBorder(),
                        enabled: isPhoneEditing,
                      ),
                      onSubmitted: (value) async {
                        setState(() {
                          isPhoneEditing = false;
                        });
                        await _updateUserData();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPhoneEditing ? Icons.check : Icons.edit),
                    onPressed: () {
                      setState(() {
                        isPhoneEditing = !isPhoneEditing;
                        if (!isPhoneEditing) {
                          _updateUserData();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 300,
              child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlarmPage(),
                ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'Debug Alarm',
                style: TextStyle(color: Colors.white),
              ),
              ),
            ),

            const SizedBox(height: 20),
            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!)
                        : (profileImagePath != null && File(profileImagePath!).existsSync()
                            ? FileImage(File(profileImagePath!))
                            : const AssetImage('assets/images/image-placeholder.png')) as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Change Profile Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),
            
            // Add service status indicator
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: _isServiceRunning ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Background Service',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isServiceRunning 
                            ? 'Running - Last update: $_lastUpdateTime'
                            : 'Stopped',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    arduinoSimController.dispose();
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}