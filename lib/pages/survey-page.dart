import 'package:flutter/material.dart';
import 'package:naviquake/util/SharedPreferencesHelper.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'basepage.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  //Lists
  String? selectedGender;
  final List<String> genderOptions = ['Male', 'Female', 'Helicopter', 'Others'];
  
  // Button press counter
  int _pressCount = 0;

  // Input decoration theme
  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  Future<void> _checkExistingData() async {
    final prefsHelper = SharedPreferencesHelper();
    await prefsHelper.init();

    final existingName = prefsHelper.getString('name');
    final existingAge = prefsHelper.getInt('age');
    final existingGender = prefsHelper.getString('gender');
    final existingPhone = prefsHelper.getString('phoneNumber');

    // If all required data exists, navigate to BasePage
    if (existingName != null && existingName.isNotEmpty && existingAge > 0 &&
        existingGender != null && existingGender.isNotEmpty &&
        existingPhone != null && existingPhone.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BasePage()),
        );
      }
    }
  }

  Future<void> _saveSurveyData() async {
    final prefsHelper = SharedPreferencesHelper();
    await prefsHelper.init(); // Wait for initialization
    
    // Save all data at once
    await Future.wait([
      prefsHelper.setString('name', nameController.text.trim()),
      prefsHelper.setInt('age', int.tryParse(ageController.text) ?? 0),
      prefsHelper.setString('gender', selectedGender ?? ''),
      prefsHelper.setString('phoneNumber', phoneNumberController.text.trim()),
    ]);
  }

  bool _isFormValid() {
    return nameController.text.isNotEmpty &&
           ageController.text.isNotEmpty &&
           selectedGender != null &&
           phoneNumberController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 0, 40),
                child: GradientText(
                'Please fill up these forms to continue.',
                colors: [
                  Colors.red,
                  Colors.red.shade400,
                  Colors.red.shade600,
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'Product Sans'
                ),),
              )
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: nameController,
                onChanged: (value) {
                  _saveSurveyData();
                  setState(() {});
                },
                decoration: _buildInputDecoration(
                  'Name',
                  'e.g Juan Dela Cruz',
                  Icons.person,
                ),
              ),
            ),
            const SizedBox(height: 20,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: ageController,
                onChanged: (value) {
                  _saveSurveyData();
                  setState(() {});
                },
                keyboardType: TextInputType.number,
                maxLength: 3,
                decoration: _buildInputDecoration(
                  'Age',
                  'e.g 18',
                  Icons.date_range,
                ),
              ),
            ),
            const SizedBox(height: 20,),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: _buildInputDecoration(
                  'Gender',
                  'Select Gender',
                  Icons.person_outline,
                ),
                items: genderOptions.map((String gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    selectedGender = value;
                  });
                  _saveSurveyData();
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              child: TextField(
                controller: phoneNumberController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                onChanged: (value) {
                  _saveSurveyData();
                  setState(() {});
                },
                decoration: _buildInputDecoration(
                  'Phone Number',
                  '09123456789',
                  Icons.phone
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid() ? Colors.red : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              onPressed: _isFormValid() ? () async {
                setState(() {
                  _pressCount++;
                  if (_pressCount >= 2) {
                    _saveSurveyData().then((_) {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (context) => const BasePage())
                      );
                    });
                  }
                });
              } : null,
              child: Text(
                _isFormValid() 
                  ? (_pressCount == 0 ? 'Press twice to continue' : 'Press again for confirmation')
                  : 'Please fill all fields',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }
}