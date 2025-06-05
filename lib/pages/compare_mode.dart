import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';
import 'package:spectrumapp/pages/reference_data.dart'; // Import the new page

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
  List<double> _serialSpectrumData = List.filled(8, 0.0);

  List<FlSpot> _currentChartData =
      []; // Data from current measurement (live or from DB)
  List<double> _currentSpectrumValues = List.filled(8, 0.0);

  // State variables to hold the selected reference data
  List<double> _referenceSpectrumValues = List.filled(8, 0.0);
  String _referenceTimestamp = "No Reference Selected";

  final SerialService _serialService = SerialService();

  @override
  void initState() {
    super.initState();
    if (!widget.isFirebaseMode) {
      _serialService.onDataReceived = _updateSerialData;
    } else {
      _loadLatestFirebaseData(); // Load current data from DB when in Firebase mode
    }
  }

  @override
  void didUpdateWidget(covariant CompareModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFirebaseMode != oldWidget.isFirebaseMode) {
      if (!widget.isFirebaseMode) {
        _serialService.onDataReceived = _updateSerialData;
        // Clear Firebase data when switching to serial mode
        setState(() {
          _currentChartData = [];
          _currentSpectrumValues = List.filled(8, 0.0);
        });
      } else {
        _serialService.onDataReceived = null; // Stop serial listening
        _loadLatestFirebaseData(); // Load current data from DB when switching to Firebase mode
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
        _currentSpectrumValues = spektrumData;
        _currentChartData =
            spektrumData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();
      });
    }
  }

  // Method to load the latest current data from the local database
  Future<void> _loadLatestFirebaseData() async {
    final latestMeasurement =
        await DatabaseHelper.instance.getLatestMeasurement();
    if (latestMeasurement != null) {
      setState(() {
        final spectrumDataString =
            latestMeasurement[DatabaseHelper.columnSpectrumData] as String?;
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          _currentSpectrumValues =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList();
          _currentChartData =
              _currentSpectrumValues.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble() + 1, entry.value);
              }).toList();
        } else {
          _currentSpectrumValues = List.filled(8, 0.0);
          _currentChartData = [];
        }
      });
    } else {
      setState(() {
        _currentSpectrumValues = List.filled(8, 0.0);
        _currentChartData = [];
      });
    }
  }

  // Method to handle reference data selection
  Future<void> _selectReferenceData() async {
    final selectedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReferenceDataSelectionPage(),
      ),
    );

    if (selectedData != null && selectedData is Map<String, dynamic>) {
      setState(() {
        final spectrumDataString =
            selectedData[DatabaseHelper.columnSpectrumData] as String?;
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          _referenceSpectrumValues =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList();
        } else {
          _referenceSpectrumValues = List.filled(8, 0.0);
        }
        _referenceTimestamp = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.parse(selectedData[DatabaseHelper.columnTimestamp]));
      });
    }
  }

  // --- Delta Calculation Functions ---
  String _calculateDeltaAvg() {
    if (_currentSpectrumValues.isEmpty ||
        _referenceSpectrumValues.isEmpty ||
        _currentSpectrumValues.length != _referenceSpectrumValues.length) {
      return "N/A";
    }
    double currentAvg =
        _currentSpectrumValues.reduce((a, b) => a + b) /
        _currentSpectrumValues.length;
    double referenceAvg =
        _referenceSpectrumValues.reduce((a, b) => a + b) /
        _referenceSpectrumValues.length;
    return (currentAvg - referenceAvg).toStringAsFixed(1);
  }

  String _calculateDeltaHighest() {
    if (_currentSpectrumValues.isEmpty ||
        _referenceSpectrumValues.isEmpty ||
        _currentSpectrumValues.length != _referenceSpectrumValues.length) {
      return "N/A";
    }
    double currentHighest = _currentSpectrumValues.reduce(max);
    double referenceHighest = _referenceSpectrumValues.reduce(max);
    int currentHighestIndex =
        _currentSpectrumValues.indexOf(currentHighest) + 1;
    int referenceHighestIndex =
        _referenceSpectrumValues.indexOf(referenceHighest) + 1;

    String highestInfo = "";
    double delta = currentHighest - referenceHighest;

    // Determine which Fx value has the highest change (absolute difference)
    double maxDeltaFx = 0.0;
    int maxDeltaFxIndex = -1;
    for (int i = 0; i < _currentSpectrumValues.length; i++) {
      double deltaFx =
          (_currentSpectrumValues[i] - _referenceSpectrumValues[i]).abs();
      if (deltaFx > maxDeltaFx) {
        maxDeltaFx = deltaFx;
        maxDeltaFxIndex = i + 1;
      }
    }
    highestInfo = " (${maxDeltaFxIndex != -1 ? 'F$maxDeltaFxIndex' : 'N/A'})";

    return "${delta.toStringAsFixed(1)}$highestInfo";
  }

  String _calculateDeltaFx(int index) {
    if (index < 0 ||
        index >= _currentSpectrumValues.length ||
        index >= _referenceSpectrumValues.length ||
        _currentSpectrumValues.isEmpty ||
        _referenceSpectrumValues.isEmpty) {
      return "N/A";
    }
    double delta =
        _currentSpectrumValues[index] - _referenceSpectrumValues[index];
    return delta.toStringAsFixed(1);
  }
  // --- End Delta Calculation Functions ---

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
                  chartData:
                      widget.isFirebaseMode
                          ? _currentChartData
                          : _serialSpectrumData.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble() + 1,
                              entry.value,
                            );
                          }).toList(),
                ),
              ),
            ),
          ),
          // Reference Data Button
          GestureDetector(
            onTap:
                _selectReferenceData, // Call the new method to select reference data
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blue,
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
                  const Icon(
                    Icons.data_saver_on,
                    color: Colors.white,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      "Reference Data: $_referenceTimestamp", // Display selected reference timestamp
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevent text overflow
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Delta Calculations Display
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: 8.0,
                    left: 16.0,
                    bottom: 8.0,
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
                      const Icon(Icons.add_chart, color: Colors.blue),
                      Text(
                        _calculateDeltaAvg(), // Dynamic value
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color:
                              double.tryParse(
                                        _calculateDeltaAvg(),
                                      )?.isNegative ==
                                      true
                                  ? Colors.red
                                  : Colors.green, // Color based on value
                        ),
                      ),
                      const Text(
                        " ΔAvg",
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
                    bottom: 8.0,
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
                      const Icon(Icons.trending_up, color: Colors.blue),
                      Text(
                        _calculateDeltaHighest(), // Dynamic value
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color:
                              double.tryParse(
                                        _calculateDeltaHighest().split(' ')[0],
                                      )?.isNegative ==
                                      true
                                  ? Colors.red
                                  : Colors.green, // Color based on value
                        ),
                      ),
                      const Text(
                        " ΔHighest",
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
          // ΔF1 to ΔF8 Displays
          GridView.builder(
            shrinkWrap:
                true, // Use this as GridView is inside SingleChildScrollView
            physics:
                const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 columns for F1-F8
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 1.0, // Adjust as needed for square cells
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final deltaValue = _calculateDeltaFx(index);
              return Container(
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
                    Text(
                      deltaValue, // Dynamic value
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color:
                            double.tryParse(deltaValue)?.isNegative == true
                                ? Colors.red
                                : Colors.green, // Color based on value
                      ),
                    ),
                    Text(
                      " ΔF${index + 1}",
                      style: const TextStyle(
                        color: Color.fromARGB(255, 85, 85, 85),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
