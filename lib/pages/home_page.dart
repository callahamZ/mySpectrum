import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';

class HomePageContent extends StatefulWidget {
  final bool isFirebaseMode;
  final VoidCallback toggleFirebaseMode;

  HomePageContent({
    super.key,
    required this.isFirebaseMode,
    required this.toggleFirebaseMode,
  });

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
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

  @override
  Widget build(BuildContext context) {
    if (widget.isFirebaseMode) {
      return FirebaseStreamer(
        builder: (context, chartData, tempVal, luxVal, {maxY}) {
          return _buildContent(chartData, tempVal, luxVal);
        },
      );
    } else {
      return _buildContent(
        _serialSpectrumData.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList(),
        _serialTemperature.toString(),
        _serialLux.toString(),
      );
    }
  }

  Widget _buildContent(List<FlSpot> chartData, String tempVal, String luxVal) {
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
                child: SpectrumChart(chartData: chartData),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 16.0,
                    right: 8.0,
                    top: 16.0,
                  ),
                  padding: const EdgeInsets.all(8.0),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.thermostat, color: Colors.blueAccent),
                      Text(
                        " $tempVal° C",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        " Suhu",
                        style: TextStyle(
                          color: Color.fromARGB(255, 85, 85, 85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: 16.0,
                    left: 8.0,
                    top: 16.0,
                  ),
                  padding: const EdgeInsets.all(8.0),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.brightness_medium, color: Colors.blue),
                      Text(
                        " $luxVal Lux",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const Text(
                        " Cahaya",
                        style: TextStyle(
                          color: Color.fromARGB(255, 85, 85, 85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
