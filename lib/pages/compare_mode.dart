import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_service.dart';

class CompareModePage extends StatefulWidget {
  final bool isFirebaseMode;
  final VoidCallback toggleFirebaseMode;

  const CompareModePage({
    super.key,
    required this.isFirebaseMode,
    required this.toggleFirebaseMode,
  });

  @override
  State<CompareModePage> createState() => _CompareModePageState();
}

class _CompareModePageState extends State<CompareModePage> {
  final DatabaseReference spektrumDatabase = FirebaseDatabase.instance.ref();
  List<double> _serialSpectrumData = List.filled(8, 0.0);
  double _serialTemperature = 0.0;
  double _serialLux = 0.0;

  final SerialService _serialService = SerialService();

  @override
  void initState() {
    super.initState();
    if (!widget.isFirebaseMode) {
      _serialService.onDataReceived = _updateSerialData;
    }
  }

  void _updateSerialData(
    List<double> spektrumData,
    double temperature,
    double lux,
  ) {
    if (mounted && !widget.isFirebaseMode) {
      setState(() {
        _serialSpectrumData = spektrumData;
        _serialTemperature = temperature;
        _serialLux = lux;
      });
    }
  }

  @override
  void dispose() {
    if (!widget.isFirebaseMode) {
      print("Resetting onDataReceived");
      _serialService.onDataReceived = null;
    }
    super.dispose();
  }

  double _calculateMaxY(List<double> data) {
    double maxY_Val = 1000.0;
    if (data.isEmpty) return maxY_Val; // Default if no data

    const maxList = [1000.0, 5000.0, 10000.0, 25000.0, 50000.0, 70000.0];
    double maxValue = data.reduce(max);
    for (var maxPoints in maxList) {
      if (maxValue < maxPoints) {
        maxY_Val = maxPoints;
        break;
      }
    }
    return maxY_Val;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFirebaseMode) {
      return StreamBuilder<DatabaseEvent>(
        stream: spektrumDatabase.onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          List<double> spektrumDataIntVal = [];
          Map<dynamic, dynamic>? rootData;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData &&
              snapshot.data!.snapshot.value != null) {
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

          List<FlSpot> chartData =
              spektrumDataIntVal.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble() + 1, entry.value);
              }).toList();

          final maxYValue = _calculateMaxY(spektrumDataIntVal);

          return _buildContent(chartData, tempVal, luxVal, maxY: maxYValue);
        },
      );
    } else {
      final maxYValue = _calculateMaxY(_serialSpectrumData);
      return _buildContent(
        _serialSpectrumData.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList(),
        _serialTemperature.toString(),
        _serialLux.toString(),
        maxY: maxYValue,
      );
    }
  }

  Widget _buildContent(
    List<FlSpot> chartData,
    String tempVal,
    String luxVal, {
    double maxY = 5000,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.toggleFirebaseMode,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: widget.isFirebaseMode ? Colors.green : Colors.blue,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(50, 0, 0, 0),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isFirebaseMode ? Icons.wifi : Icons.cable,
                    color: Colors.white,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    widget.isFirebaseMode ? "Firebase Mode" : "Serial Mode",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromARGB(50, 0, 0, 0),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: SpectrumChart(chartData: chartData, maxY: maxY),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
