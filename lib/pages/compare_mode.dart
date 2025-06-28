import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';
import 'package:spectrumapp/pages/reference_data.dart'; // Ensure correct import
import 'package:spectrumapp/services/data_process.dart'; // Import the new data processing service

// Define an enum for the graph view mode in compare page
enum CompareGraphView { rawData, processedData }

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

  // _currentChartData and _redChartData are FlSpot lists specifically for F1-F8 for the chart
  List<FlSpot> _currentChartData = [];
  List<FlSpot> _redChartData = [];

  // _currentSpectrumValues and _referenceSpectrumValues hold all 10 raw double values (F1-F8, Clear, NIR) for calculations
  List<double> _currentSpectrumValues = List.filled(10, 0.0);
  List<double> _referenceSpectrumValues = List.filled(10, 0.0);

  // Processed data for current measurement
  List<double> _currentBasicCounts = List.filled(10, 0.0);
  List<double> _currentDataSensorCorr = List.filled(10, 0.0);

  // Processed data for reference measurement
  List<double> _referenceBasicCounts = List.filled(10, 0.0);
  List<double> _referenceDataSensorCorr = List.filled(10, 0.0);

  String _referenceTimestamp = "Click to Select";

  // State variable to control the graph view in compare mode (Raw Data vs. Processed Data)
  CompareGraphView _currentCompareGraphView = CompareGraphView.rawData;

  final SerialService _serialService = SerialService();

  final List<Map<String, String>> _channelCharacteristics = [
    {
      "Channel": "F1",
      "Rentang Jangkauan": "405 - 425 nm",
      "Representasi": "Purple",
    },
    {
      "Channel": "F2",
      "Rentang Jangkauan": "435 - 455 nm",
      "Representasi": "Navy",
    },
    {
      "Channel": "F3",
      "Rentang Jangkauan": "470 - 490 nm",
      "Representasi": "Blue",
    },
    {
      "Channel": "F4",
      "Rentang Jangkauan": "505 - 525 nm",
      "Representasi": "Aqua",
    },
    {
      "Channel": "F5",
      "Rentang Jangkauan": "545 - 565 nm",
      "Representasi": "Green",
    },
    {
      "Channel": "F6",
      "Rentang Jangkauan": "580 - 600 nm",
      "Representasi": "Yellow",
    },
    {
      "Channel": "F7",
      "Rentang Jangkauan": "620 - 640 nm",
      "Representasi": "Orange",
    },
    {
      "Channel": "F8",
      "Rentang Jangkauan": "670 - 690 nm",
      "Representasi": "Red",
    },
    {
      "Channel": "Clear",
      "Rentang Jangkauan": "350 - 980 nm",
      "Representasi": "White", // Changed to White for clarity
    },
    {
      "Channel": "NIR",
      "Rentang Jangkauan": "850 - 980 nm",
      "Representasi": "Infrared", // Changed from "Black" to "Infrared"
    },
  ];

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
          _redChartData = [];
          _referenceSpectrumValues = List.filled(
            10,
            0.0,
          ); // Reset to 10 for serial
          _currentBasicCounts = List.filled(10, 0.0); // Reset processed data
          _currentDataSensorCorr = List.filled(10, 0.0); // Reset processed data
          _referenceBasicCounts = List.filled(10, 0.0); // Reset processed data
          _referenceDataSensorCorr = List.filled(
            10,
            0.0,
          ); // Reset processed data
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

        // Calculate processed data for current serial measurement
        _currentBasicCounts = DataProcessor.calculateBasicCount(spektrumData);
        _currentDataSensorCorr = DataProcessor.calculateDataSensorCorr(
          _currentBasicCounts,
        );
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

          // Calculate processed data for current Firebase measurement
          _currentBasicCounts = DataProcessor.calculateBasicCount(
            rawSpectrumData,
          );
          _currentDataSensorCorr = DataProcessor.calculateDataSensorCorr(
            _currentBasicCounts,
          );
        } else {
          _currentSpectrumValues = List.filled(10, 0.0);
          _currentChartData = [];
          _currentBasicCounts = List.filled(10, 0.0); // Reset
          _currentDataSensorCorr = List.filled(10, 0.0); // Reset
        }
      });
    } else {
      setState(() {
        _currentSpectrumValues = List.filled(10, 0.0);
        _currentChartData = [];
        _currentBasicCounts = List.filled(10, 0.0); // Reset
        _currentDataSensorCorr = List.filled(10, 0.0); // Reset
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

          // Calculate processed data for the selected reference measurement
          _referenceBasicCounts = DataProcessor.calculateBasicCount(
            _referenceSpectrumValues,
          );
          _referenceDataSensorCorr = DataProcessor.calculateDataSensorCorr(
            _referenceBasicCounts,
          );

          // _redChartData for raw data view (first 8 values)
          _redChartData =
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
          _redChartData = [];
          _referenceBasicCounts = List.filled(10, 0.0); // Reset
          _referenceDataSensorCorr = List.filled(10, 0.0); // Reset
        }
        _referenceTimestamp = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.parse(selectedData[DatabaseHelper.columnTimestamp]));
      });
    } else {
      setState(() {
        _referenceSpectrumValues = List.filled(10, 0.0);
        _redChartData = [];
        _referenceBasicCounts = List.filled(10, 0.0); // Reset
        _referenceDataSensorCorr = List.filled(10, 0.0); // Reset
        _referenceTimestamp = "Nothing";
      });
    }
  }

  // Modified _calculateDeltaAvg to use selected data mode
  double _calculateDeltaAvg(
    List<double> currentData,
    List<double> referenceData,
  ) {
    // Ensure calculation only uses F1-F8
    if (currentData.isEmpty ||
        referenceData.isEmpty ||
        currentData.length < 8 ||
        referenceData.length < 8) {
      return 0.0; // Return 0.0 or handle as an error
    }

    double totalDelta = 0.0;
    for (int i = 0; i < 8; i++) {
      // Loop only up to 8 for F1-F8
      totalDelta += (currentData[i] - referenceData[i]);
    }
    return (totalDelta / 8);
  }

  // Modified _calculateDeltaHighest to use selected data mode
  double _calculateDeltaHighest(
    List<double> currentData,
    List<double> referenceData,
  ) {
    // Ensure calculation only uses F1-F8
    if (currentData.isEmpty ||
        referenceData.isEmpty ||
        currentData.length < 8 ||
        referenceData.length < 8) {
      return 0.0; // Return 0.0 or handle as an error
    }

    double maxDeltaFx = 0.0;
    // Track if any meaningful delta was found to avoid showing "N/A" for empty data
    bool hasMeaningfulDelta = false;

    for (int i = 0; i < 8; i++) {
      // Loop only up to 8 for F1-F8
      double deltaFx = (currentData[i] - referenceData[i]);
      if (!hasMeaningfulDelta || deltaFx.abs() > maxDeltaFx.abs()) {
        maxDeltaFx = deltaFx;
        hasMeaningfulDelta = true;
      }
    }
    return maxDeltaFx;
  }

  // Modified _calculateDeltaFx to use selected data mode
  double _calculateDeltaFx(
    int index,
    List<double> currentData,
    List<double> referenceData,
  ) {
    if (index < 0 ||
        index >= currentData.length ||
        index >= referenceData.length ||
        currentData.isEmpty ||
        referenceData.isEmpty) {
      return 0.0; // Return 0.0 or handle as an error
    }
    double delta = currentData[index] - referenceData[index];
    return delta;
  }

  @override
  void dispose() {
    if (!widget.isFirebaseMode) {
      print("Resetting onDataReceived");
      _serialService.onDataReceived = null;
    }
    super.dispose();
  }

  String _getChannelName(int index) {
    if (index >= 0 && index < 8) {
      return "F${index + 1}";
    } else if (index == 8) {
      return "Clear";
    } else if (index == 9) {
      return "NIR";
    }
    return ""; // Should not happen with current loop
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case "purple":
        return Colors.purple;
      case "navy":
        return Colors.indigo; // Using indigo as a close approximation for navy
      case "blue":
        return Colors.blue;
      case "aqua":
        return Colors.cyan; // Using cyan as a close approximation for aqua
      case "green":
        return Colors.green;
      case "yellow":
        return Colors.yellow;
      case "orange":
        return Colors.orange;
      case "red":
        return Colors.red;
      case "white light": // Handle "White light" as white
      case "white":
        return Colors.white;
      case "infrared": // Handle "Infrared" as black since it's not visible
      case "black": // Keep black for the color box representation for infrared
        return Colors.black;
      default:
        return Colors.grey; // Default color for unrecognized names
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          child: Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Channel Characteristics",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16.0),
                // Wrap the Table with SingleChildScrollView to make it scrollable
                SizedBox(
                  height: 380,
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1), // Channel
                        1: FlexColumnWidth(2.5), // Rentang Jangkauan
                        2: FlexColumnWidth(1.5),
                      },
                      border: TableBorder.all(color: Colors.grey.shade300),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
                          children: const [
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Wave Length",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Color",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (var char in _channelCharacteristics)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  char["Channel"]!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  char["Rentang Jangkauan"]!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                  child:
                                      char["Representasi"] ==
                                              "Infrared" // Check if it's "Infrared"
                                          ? const Text(
                                            // Display as plain text
                                            "Infrared",
                                            style: TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          )
                                          : Container(
                                            width:
                                                24, // Size of the color square
                                            height:
                                                24, // Size of the color square
                                            decoration: BoxDecoration(
                                              color: _getColorFromName(
                                                char["Representasi"]!,
                                              ),
                                              border: Border.all(
                                                color:
                                                    char["Representasi"] ==
                                                            "White"
                                                        ? Colors.black
                                                        : Colors
                                                            .transparent, // Add border for white color
                                                width:
                                                    char["Representasi"] ==
                                                            "White"
                                                        ? 1.0
                                                        : 0.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    4.0,
                                                  ), // Slightly rounded corners
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<FlSpot> currentChartDataForDisplay;
    List<FlSpot> referenceChartDataForDisplay;

    // Determine which data lists to use for calculation and display based on the selected mode
    List<double> currentDataForCalculation;
    List<double> referenceDataForCalculation;

    // Determine the number of decimal places for display
    int decimalPlaces =
        _currentCompareGraphView == CompareGraphView.processedData ? 3 : 1;

    if (_currentCompareGraphView == CompareGraphView.rawData) {
      // For raw data view, the chart displays F1-F8 from _serialSpectrumData (for serial)
      // or _currentChartData (for firebase)
      currentChartDataForDisplay =
          widget.isFirebaseMode
              ? _currentChartData
              : _serialSpectrumData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble() + 1, entry.value);
              }).toList();

      // For raw data, _redChartData is already populated with raw reference data
      referenceChartDataForDisplay = _redChartData;

      currentDataForCalculation = _currentSpectrumValues;
      referenceDataForCalculation = _referenceSpectrumValues;
    } else {
      // For processed data view, the chart displays Basic Counts for current data
      // and Data Sensor (Corr) for reference data
      currentChartDataForDisplay =
          _currentBasicCounts.sublist(0, 8).asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble() + 1, entry.value);
          }).toList();

      referenceChartDataForDisplay =
          _referenceDataSensorCorr.sublist(0, 8).asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble() + 1, entry.value);
          }).toList();

      currentDataForCalculation = _currentDataSensorCorr;
      referenceDataForCalculation = _referenceDataSensorCorr;
    }

    // Calculate delta values
    double deltaAvg = _calculateDeltaAvg(
      currentDataForCalculation,
      referenceDataForCalculation,
    );
    double deltaHighest = _calculateDeltaHighest(
      currentDataForCalculation,
      referenceDataForCalculation,
    );

    String highestInfo = "";
    if (currentDataForCalculation.isNotEmpty &&
        referenceDataForCalculation.isNotEmpty &&
        currentDataForCalculation.length >= 8 &&
        referenceDataForCalculation.length >= 8) {
      double maxDeltaFxVal = 0.0;
      int maxDeltaFxIndex = -1;
      bool hasMeaningfulDelta = false;

      for (int i = 0; i < 8; i++) {
        double deltaFx =
            (currentDataForCalculation[i] - referenceDataForCalculation[i]);
        if (!hasMeaningfulDelta || deltaFx.abs() > maxDeltaFxVal.abs()) {
          maxDeltaFxVal = deltaFx;
          maxDeltaFxIndex = i + 1;
          hasMeaningfulDelta = true;
        }
      }
      highestInfo = " (${maxDeltaFxIndex != -1 ? 'F$maxDeltaFxIndex' : 'N/A'})";
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.isFirebaseMode)
            FirebaseStreamer(onDataSaved: _loadLatestFirebaseData),
          GestureDetector(
            onTap: widget.toggleFirebaseMode,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
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
          // Add the Raw Data / Processed Data toggle buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentCompareGraphView = CompareGraphView.rawData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentCompareGraphView == CompareGraphView.rawData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Raw Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentCompareGraphView =
                            CompareGraphView.processedData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentCompareGraphView ==
                                  CompareGraphView.processedData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Processed Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
                  showGraph: true,
                  colorChartData: currentChartDataForDisplay,
                  redChartData: referenceChartDataForDisplay,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 4.0),
            child: Text(
              "Comparing to reference data :",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          // Reference Data Button
          GestureDetector(
            onTap: _selectReferenceData,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                      "Reference : $_referenceTimestamp",
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
                        deltaAvg.toStringAsFixed(decimalPlaces),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              deltaAvg.isNegative ? Colors.red : Colors.green,
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
                        "${deltaHighest.toStringAsFixed(decimalPlaces)}$highestInfo",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              deltaHighest.isNegative
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
                          _calculateDeltaFx(
                            i,
                            currentDataForCalculation,
                            referenceDataForCalculation,
                          ).toStringAsFixed(decimalPlaces),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _calculateDeltaFx(
                                      i,
                                      currentDataForCalculation,
                                      referenceDataForCalculation,
                                    ).isNegative
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
          GestureDetector(
            onTap: () => _showAboutDialog(context),
            child: Container(
              margin: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16,
              ),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.purple, // A distinct color for the about button
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 24.0),
                  SizedBox(width: 8.0),
                  Text(
                    "About Channels",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
