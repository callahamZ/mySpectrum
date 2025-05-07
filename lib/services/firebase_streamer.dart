import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/database_service.dart';

class FirebaseStreamer extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    List<FlSpot> chartData,
    String tempVal,
    String luxVal,
  )
  builder;

  const FirebaseStreamer({super.key, required this.builder});

  @override
  State<FirebaseStreamer> createState() => _FirebaseStreamerState();
}

class _FirebaseStreamerState extends State<FirebaseStreamer> {
  final DatabaseReference spektrumDatabase = FirebaseDatabase.instance.ref();
  bool _isFirstBuild = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: spektrumDatabase.onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        List<double> spektrumDataIntVal = [];
        Map<dynamic, dynamic>? rootData;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          rootData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
        }

        if (rootData != null) {
          try {
            Map<dynamic, dynamic>? spektrumData = rootData["sensorSpektrum"];
            if (spektrumData != null) {
              for (int i = 1; i <= 8; i++) {
                String key = 'F$i';
                if (spektrumData.containsKey(key)) {
                  double value = double.parse(spektrumData[key].toString());
                  spektrumDataIntVal.add(value);
                }
              }
            }
          } catch (e) {
            print("Error processing data: $e");
          }
        }

        String tempVal = "N/A";
        if (rootData?["sensorSuhu"]["Suhu"] != null) {
          tempVal = rootData!["sensorSuhu"]["Suhu"].toString();
        }

        String luxVal = "N/A";
        if (rootData?["sensorCahaya"]["Lux"] != null) {
          luxVal = rootData!["sensorCahaya"]["Lux"].toString();
        }

        if (!_isFirstBuild) {
          DatabaseHelper.instance.insertMeasurement(
            timestamp: DateTime.now(),
            spectrumData: spektrumDataIntVal,
            temperature: double.parse(tempVal),
            lux: double.parse(luxVal),
          );
        }

        _isFirstBuild = false;

        List<FlSpot> chartData =
            spektrumDataIntVal.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();

        return widget.builder(context, chartData, tempVal, luxVal);
      },
    );
  }
}
