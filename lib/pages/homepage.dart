import 'package:flutter/material.dart';
import 'package:naviquake/pages/disclaimer-page.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              padding: const EdgeInsets.all(20),
               child: GradientText(
              'Welcome to naviQuake',
                colors: [
                 Colors.red,
                Colors.red.shade400,
                 Colors.red.shade800,
               ],
                style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Product Sans',
                ),
              ),
            ),
          ),

          Center(
            child: Container(
              child: Image.asset('assets/images/splash-logo.png',
              width: 200,
              height: 200,
              ),
            ),
          ),
          

          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 60),
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DisclaimerPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text(
                  'Go to Next Page',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Product Sans',
                  ),
                ),
              ),
            ),
          ),

          Container(
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 320, 0, 0),
                  child: const Text('TNTS RESEARCH PROJECT',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.fromLTRB(80, 320, 0, 0),
                  child: const Text('2024-2025',
                  style: TextStyle(
                    color: Colors.grey,
                  ),),
                )
              ],
            ),
          )
        ],
      )
    );
  }
}