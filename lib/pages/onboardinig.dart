import 'package:flutter/material.dart';

class Onboardiing extends StatefulWidget {
  const Onboardiing({super.key});

  @override
  State<Onboardiing> createState() => _OnboardiingState();
}

class _OnboardiingState extends State<Onboardiing> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffb51837), Color(0xff661c31), Color(0xff301939)],
            begin: Alignment.topLeft,
            end: Alignment.topRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "images/pngwing.com.png",
              color: Colors.white,
              height: 90,
              width: 90,
              fit: BoxFit.cover,
            ),
            Text("Yogai", style: TextStyle(color: Colors.white, fontSize: 30)),
            SizedBox(height: 80),
            Text(
              "Welcome Back",
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40),
            Container(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              margin: EdgeInsets.only(left: 40, right: 40, top: 10),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white60, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  "Sign in",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            SizedBox(height: 40),
            Container(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              margin: EdgeInsets.only(left: 40, right: 40, top: 10),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white60, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  "Sign up",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
