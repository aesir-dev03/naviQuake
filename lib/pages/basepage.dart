import 'package:flutter/material.dart';
import 'package:naviquake/util/SharedPreferencesHelper.dart';
import 'settings.dart';
import 'evacuateLocations.dart';
import 'dart:io';
import 'accessibility_page.dart';

class BasePage extends StatefulWidget {
  const BasePage({super.key});

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  String name = '';
  int age = 0;
  String gender = '';
  String phoneNumber = '';
  String? profileImagePath;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefsHelper = SharedPreferencesHelper();
      if (mounted) {
        setState(() {
          name = prefsHelper.getString('name') ?? 'Not provided';
          age = prefsHelper.getInt('age') ?? 0;
          gender = prefsHelper.getString('gender') ?? 'Not provided';
          phoneNumber = prefsHelper.getString('phoneNumber') ?? 'Not provided';
          profileImagePath = prefsHelper.getString('profile_image');
          
          if (profileImagePath != null) {
            _profileImage = File(profileImagePath!);
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 40, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome, $name',
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Product Sans',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10,),

          Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: _profileImage != null
                    ? Image.file(
                        _profileImage!,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/image-placeholder.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsPage())
                          );
                          await _loadUserData();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.settings,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Settings', style: TextStyle(fontFamily: 'Product Sans')),
                  ],
                ),

                Container(
                  margin: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => const EvacuateLocations()
                            ));
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.location_pin,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Location', style: TextStyle(fontFamily: 'Product Sans')),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}