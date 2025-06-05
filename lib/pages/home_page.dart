import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';
import 'package:spectrumapp/services/database_service.dart'; // Import the database service

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
  List<FlSpot> _chartData = [];
  String _temperature = "N/A";
  String _lux = "N/A";

  final SerialService _serialService = SerialService();

  @override
  void initState() {
    super.initState();
    if (!widget.isFirebaseMode) {
      _serialService.onDataReceived = _updateSerialData;
    } else {
      _loadLatestFirebaseData(); // Load data from DB when in Firebase mode
    }
  }

  @override
  void didUpdateWidget(covariant HomePageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFirebaseMode != oldWidget.isFirebaseMode) {
      if (!widget.isFirebaseMode) {
        _serialService.onDataReceived = _updateSerialData;
        // Clear Firebase data when switching to serial mode
        setState(() {
          _chartData = [];
          _temperature = "N/A";
          _lux = "N/A";
        });
      } else {
        _serialService.onDataReceived = null; // Stop serial listening
        _loadLatestFirebaseData(); // Load data from DB when switching to Firebase mode
      }
    }
  }

  void _updateSerialData(
    List<double> spektrumData,
    double temperature,
    double lux,
  ) {
    if (mounted && !widget.isFirebaseMode) {
      setState(() {
        _chartData =
            spektrumData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();
        _temperature = temperature.toString();
        _lux = lux.toString();
      });
    }
  }

  // New method to load the latest data from the local database
  Future<void> _loadLatestFirebaseData() async {
    final latestMeasurement =
        await DatabaseHelper.instance.getLatestMeasurement();
    if (latestMeasurement != null) {
      setState(() {
        // Parse spectrum data from string to List<double>
        final spectrumDataString =
            latestMeasurement[DatabaseHelper.columnSpectrumData] as String?;
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          _chartData =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                    return FlSpot(entry.key.toDouble() + 1, entry.value);
                  })
                  .toList();
        } else {
          _chartData = [];
        }
        _temperature =
            (latestMeasurement[DatabaseHelper.columnTemperature] as double?)
                ?.toString() ??
            "N/A";
        _lux =
            (latestMeasurement[DatabaseHelper.columnLux] as double?)
                ?.toString() ??
            "N/A";
      });
    } else {
      // If no data in DB, reset display
      setState(() {
        _chartData = [];
        _temperature = "N/A";
        _lux = "N/A";
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // This FirebaseStreamer is now just for saving data, not displaying
          if (widget.isFirebaseMode)
            FirebaseStreamer(
              onDataSaved: _loadLatestFirebaseData, // Callback to refresh UI
            ),
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
                child: SpectrumChart(
                  chartData: _chartData,
                ), // Use local state data
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
                        " $_temperature° C", // Use local state data
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
                        " $_lux Lux", // Use local state data
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
