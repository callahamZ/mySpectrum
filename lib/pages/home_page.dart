import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HomePageContent extends StatelessWidget {
  final DatabaseReference spektrumData =
      FirebaseDatabase.instance.ref().child('sensorSpektrum/F1');

  HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: spektrumData.onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final realTimeValue = snapshot.data!.snapshot.value.toString();

          return Container(
            color: Colors.lightBlue[100],
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Welcome to Home Page',
                      style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  Text("Data F1 = $realTimeValue"),
                ],
              ),
            ),
          );
        } else {
          return Container(
            color: Colors.lightBlue[100],
            padding: const EdgeInsets.all(16.0),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Welcome to Home Page',
                      style: TextStyle(fontSize: 24)),
                  SizedBox(height: 20),
                  Text("Data F1 = 0"), // or any default value
                ],
              ),
            ),
          );
        }
      },
    );
  }
}