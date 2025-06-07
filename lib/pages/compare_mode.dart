import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';
import 'package:spectrumapp/pages/reference_data.dart'; // Ensure correct import

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
  // _serialSpectrumData holds the raw 8 Fx values for serial mode's chart
  List<double> _serialSpectrumData = List.filled(8, 0.0);

  // _currentChartData and _referenceChartData are FlSpot lists specifically for F1-F8 for the chart
  List<FlSpot> _currentChartData = [];
  List<FlSpot> _referenceChartData = [];

  // _currentSpectrumValues and _referenceSpectrumValues hold all 10 raw double values (F1-F8, Clear, NIR) for calculations
  List<double> _currentSpectrumValues = List.filled(10, 0.0);
  List<double> _referenceSpectrumValues = List.filled(10, 0.0);

  String _referenceTimestamp = "Nothing";

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
        setState(() {
          _currentChartData = [];
          _currentSpectrumValues = List.filled(
            10,
            0.0,
          ); // Reset to 10 for serial
          _referenceChartData = [];
          _referenceSpectrumValues = List.filled(
            10,
            0.0,
          ); // Reset to 10 for serial
          _referenceTimestamp = "Nothing";
        });
      } else {
        _serialService.onDataReceived = null;
        _loadLatestFirebaseData();
      }
    }
  }

  void _updateSerialData(
    List<double> spektrumData, // Assuming this contains 8 Fx values for serial
    double temperature,
    double lux,
  ) {
    if (mounted && !widget.isFirebaseMode) {
      setState(() {
        _serialSpectrumData = spektrumData; // This should only be 8 values
        _currentSpectrumValues = List.from(
          spektrumData,
        ); // If serial sends 8, this will be 8. Extend or handle as needed.
        // For serial, _currentChartData is directly derived from _serialSpectrumData in build method.
        // No need to set _currentChartData explicitly here for serial mode.
      });
    }
  }

  Future<void> _loadLatestFirebaseData() async {
    final latestMeasurement =
        await DatabaseHelper.instance.getLatestMeasurement();
    if (latestMeasurement != null) {
      setState(() {
        final spectrumDataString =
            latestMeasurement[DatabaseHelper.columnSpectrumData] as String?;
        List<double> rawSpectrumData = [];
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          rawSpectrumData =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList();
          _currentSpectrumValues =
              rawSpectrumData; // Store all 10 for calculations

          // Only map F1 to F8 (first 8 elements) for the chart display
          _currentChartData =
              rawSpectrumData
                  .sublist(0, min(8, rawSpectrumData.length))
                  .asMap()
                  .entries
                  .map((entry) {
                    return FlSpot(entry.key.toDouble() + 1, entry.value);
                  })
                  .toList();
        } else {
          _currentSpectrumValues = List.filled(10, 0.0);
          _currentChartData = [];
        }
      });
    } else {
      setState(() {
        _currentSpectrumValues = List.filled(10, 0.0);
        _currentChartData = [];
      });
    }
  }

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
                  .toList(); // Store all 10 for calculations
          // Only map F1 to F8 (first 8 elements) for the reference chart display
          _referenceChartData =
              _referenceSpectrumValues
                  .sublist(0, min(8, _referenceSpectrumValues.length))
                  .asMap()
                  .entries
                  .map((entry) {
                    return FlSpot(entry.key.toDouble() + 1, entry.value);
                  })
                  .toList();
        } else {
          _referenceSpectrumValues = List.filled(10, 0.0);
          _referenceChartData = [];
        }
        _referenceTimestamp = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.parse(selectedData[DatabaseHelper.columnTimestamp]));
      });
    } else {
      setState(() {
        _referenceSpectrumValues = List.filled(10, 0.0);
        _referenceChartData = [];
        _referenceTimestamp = "Nothing";
      });
    }
  }

  String _calculateDeltaAvg() {
    // Ensure calculation only uses F1-F8
    if (_currentSpectrumValues.isEmpty ||
        _referenceSpectrumValues.isEmpty ||
        _currentSpectrumValues.length < 8 ||
        _referenceSpectrumValues.length < 8) {
      return "N/A";
    }

    double totalDelta = 0.0;
    for (int i = 0; i < 8; i++) {
      // Loop only up to 8 for F1-F8
      totalDelta += (_currentSpectrumValues[i] - _referenceSpectrumValues[i]);
    }
    return (totalDelta / 8).toStringAsFixed(1);
  }

  String _calculateDeltaHighest() {
    // Ensure calculation only uses F1-F8
    if (_currentSpectrumValues.isEmpty ||
        _referenceSpectrumValues.isEmpty ||
        _currentSpectrumValues.length < 8 ||
        _referenceSpectrumValues.length < 8) {
      return "N/A";
    }

    String highestInfo = "";
    double maxDeltaFx = 0.0;
    int maxDeltaFxIndex = -1;
    for (int i = 0; i < 8; i++) {
      // Loop only up to 8 for F1-F8
      double deltaFx =
          (_currentSpectrumValues[i] - _referenceSpectrumValues[i]);
      if (deltaFx.abs() > maxDeltaFx.abs()) {
        maxDeltaFx = deltaFx;
        maxDeltaFxIndex = i + 1;
      }
    }
    highestInfo = " (${maxDeltaFxIndex != -1 ? 'F$maxDeltaFxIndex' : 'N/A'})";
    return "${maxDeltaFx.toStringAsFixed(1)}$highestInfo";
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
    List<FlSpot> displayedChartData =
        widget.isFirebaseMode
            ? _currentChartData
            : _serialSpectrumData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.isFirebaseMode)
            FirebaseStreamer(onDataSaved: _loadLatestFirebaseData),
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
                  chartData: displayedChartData,
                  referenceChartData: _referenceChartData,
                ),
              ),
            ),
          ),
          // Reference Data Button
          GestureDetector(
            onTap: _selectReferenceData,
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
                      "Reference Data: $_referenceTimestamp",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                        _calculateDeltaAvg(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              double.tryParse(
                                        _calculateDeltaAvg(),
                                      )?.isNegative ==
                                      true
                                  ? Colors.red
                                  : Colors.green,
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
                        _calculateDeltaHighest(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              double.tryParse(
                                        _calculateDeltaHighest().split(' ')[0],
                                      )?.isNegative ==
                                      true
                                  ? Colors.red
                                  : Colors.green,
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Channel",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Difference (Δ)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                for (int i = 0; i < 8; i++) // Loop only for F1 to F8
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "F${i + 1}",
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _calculateDeltaFx(i),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                double.tryParse(
                                          _calculateDeltaFx(i),
                                        )?.isNegative ==
                                        true
                                    ? Colors.red
                                    : Colors.green,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
