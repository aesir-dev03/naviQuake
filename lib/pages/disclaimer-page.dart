import 'package:flutter/material.dart';
import 'survey-page.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: GradientText('DISCLAIMER',
              colors: [
                Colors.red,
                Colors.red.shade400,
                Colors.red.shade600,
              ],
              style: const TextStyle(
                fontSize: 25,
                fontFamily: 'Product Sans',
                fontWeight: FontWeight.bold,
              ),
              ),
            ),
          ),

          Center(
            child: Image.asset('assets/images/warning-splash.png',
            width: 200,
            height: 200,),
          ),

          Center(
            child: Container(
              child: const Text('This app is in prototype stage and is not ready for production use.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Product Sans',
              ),),
          ),
          ),

          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return StreamBuilder<int>(
                    stream: Stream.periodic(const Duration(milliseconds: 100), (i) => i)
                      .take(51), // 5 seconds = 50 intervals of 100ms
                    builder: (context, snapshot) {
                      double progress = snapshot.hasData 
                          ? (snapshot.data! / 50) 
                          : 0.0;
                      bool isEnabled = snapshot.connectionState == ConnectionState.done;
                      
                      return ElevatedButton(
                        onPressed: isEnabled 
                          ? () {
                              Navigator.pushReplacement(
                                context, 
                                MaterialPageRoute(builder: (context) => const SurveyPage())
                              );
                            }
                          : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          minimumSize: const Size(200, 50),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEnabled ? 'Continue' : 'Please wait...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Product Sans',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 4,
                                width: 160,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      )
    );
  }
}