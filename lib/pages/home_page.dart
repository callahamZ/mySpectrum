import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HomePageContent extends StatelessWidget {
  final DatabaseReference spektrumDatabase =
      FirebaseDatabase.instance.ref().child('sensorSpektrum');

  HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: spektrumDatabase.onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        String spektrumDataArr = '0';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          spektrumDataArr = snapshot.data!.snapshot.value.toString();
        } else {
          spektrumDataArr = '0';
        }
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
                Text("Data = $spektrumDataArr"),
              ],
            ),
          ),
        );
      },
    );
  }
}