import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/firebase_streamer.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:spectrumapp/services/data_process.dart'; // Import the new data processing service
import 'package:spectrumapp/services/correction_matrix.dart'; // Import correction_matrix.dart
import 'dart:math'; // Import for math functions like sum, if needed. For now, manual sum is fine.

enum GraphView { rawData, processedData, cieData } // Added cieData

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
  List<double> _basicCounts = List.filled(10, 0.0); // Adjusted to 10 channels
  List<double> _dataSensorCorr = List.filled(
    10,
    0.0,
  ); // Adjusted to 10 channels
  List<double> _dataSensorCorrNor = List.filled(
    10,
    0.0,
  ); // Adjusted to 10 channels
  List<double> _finalCorrectedData = List.filled(
    correctionMatrix.length,
    0.0,
  ); // State for the final corrected data
  List<double> _calculatedX = List.filled(XN.length, 0.0);
  List<double> _calculatedY = List.filled(YN.length, 0.0);
  List<double> _calculatedZ = List.filled(ZN.length, 0.0);

  // New variables for CIE 1931 calculations
  double _cieX = 0.0;
  double _cieY = 0.0;
  double _cieZ = 0.0;
  String _cieSmallX = "N/A";
  String _cieSmallY = "N/A";
  String _cieSmallZ = "N/A";
  String _spectralLux = "N/A";

  // New list to store CIE chart spots
  List<FlSpot> _cieChartSpots = [];

  GraphView _currentGraphView = GraphView.rawData;

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
        // Clear data when switching to serial mode
        setState(() {
          _chartData = [];
          _temperature = "N/A";
          _lux = "N/A";
          _basicCounts = List.filled(10, 0.0);
          _dataSensorCorr = List.filled(10, 0.0);
          _dataSensorCorrNor = List.filled(10, 0.0);
          _finalCorrectedData = List.filled(
            correctionMatrix.length,
            0.0,
          ); // Clear final data
          _cieX = 0.0;
          _cieY = 0.0;
          _cieZ = 0.0;
          _cieSmallX = "N/A";
          _cieSmallY = "N/A";
          _cieSmallZ = "N/A";
          _spectralLux = "N/A";
          _cieChartSpots = []; // Clear CIE chart data
        });
      } else {
        _serialService.onDataReceived = null; // Stop serial listening
        _loadLatestFirebaseData(); // Load data from DB when switching to Firebase mode
      }
    }
  }

  void _updateSerialData(
    List<double>
    spektrumData, // This might need to be adjusted if serial sends 10 values
    double temperature,
    double lux,
  ) {
    if (mounted && !widget.isFirebaseMode) {
      setState(() {
        // Apply linear regression to temperature and lux
        double processedTemperature = DataProcessor.processTemperature(
          temperature,
        );
        double processedLux = DataProcessor.processLux(lux);

        // Assuming spektrumData will now contain 10 values (F1-F8, Clear, NIR).
        _chartData =
            spektrumData.sublist(0, 8).asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();
        _temperature = processedTemperature.toStringAsFixed(1);
        _lux = processedLux.toStringAsFixed(1);

        _basicCounts = DataProcessor.calculateBasicCount(spektrumData);
        _dataSensorCorr = DataProcessor.calculateDataSensorCorr(_basicCounts);
        _dataSensorCorrNor = DataProcessor.calculateDataSensorCorrNor(
          _dataSensorCorr,
        );

        // Perform matrix multiplication here
        _finalCorrectedData = DataProcessor.multiplyVectorMatrix(
          _dataSensorCorr,
          correctionMatrix,
        ); // Perform the multiplication

        _calculatedX = DataProcessor.calculateXYZ(_finalCorrectedData, XN);
        _calculatedY = DataProcessor.calculateXYZ(_finalCorrectedData, YN);
        _calculatedZ = DataProcessor.calculateXYZ(_finalCorrectedData, ZN);

        // Calculate CIE 1931 values
        _cieX = _calculatedX.fold(0.0, (sum, item) => sum + item);
        _cieY = _calculatedY.fold(0.0, (sum, item) => sum + item);
        _cieZ = _calculatedZ.fold(0.0, (sum, item) => sum + item);

        double sumXYZ = _cieX + _cieY + _cieZ;
        if (sumXYZ > 0) {
          _cieSmallX = (_cieX / sumXYZ).toStringAsFixed(4);
          _cieSmallY = (_cieY / sumXYZ).toStringAsFixed(4);
          _cieSmallZ = (_cieZ / sumXYZ).toStringAsFixed(4);
        } else {
          _cieSmallX = "0.0000";
          _cieSmallY = "0.0000";
          _cieSmallZ = "0.0000";
        }
        _spectralLux = (_cieY * 683).toStringAsFixed(2);

        // Add the current CIE point to the list for the graph
        if (_cieSmallX != "N/A" && _cieSmallY != "N/A") {
          try {
            double x = double.parse(_cieSmallX);
            double y = double.parse(_cieSmallY);
            _cieChartSpots.add(FlSpot(x, y));
            // Optional: Limit the number of points in _cieChartSpots to keep the graph manageable
            if (_cieChartSpots.length > 50) {
              // Keep last 50 points
              _cieChartSpots.removeAt(0);
            }
          } catch (e) {
            print("Error parsing CIE x,y values: $e");
          }
        }
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
          _chartData =
              rawSpectrumData.sublist(0, 8).asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble() + 1, entry.value);
              }).toList();
        } else {
          _chartData = [];
        }

        // Retrieve raw temperature and lux values
        double rawTemperature =
            (latestMeasurement[DatabaseHelper.columnTemperature] as double?) ??
            0.0;
        double rawLux =
            (latestMeasurement[DatabaseHelper.columnLux] as double?) ?? 0.0;

        // Apply linear regression to temperature and lux
        double processedTemperature = DataProcessor.processTemperature(
          rawTemperature,
        );
        double processedLux = DataProcessor.processLux(rawLux);

        _temperature = processedTemperature.toStringAsFixed(1);
        _lux = processedLux.toStringAsFixed(1);

        _basicCounts = DataProcessor.calculateBasicCount(rawSpectrumData);
        _dataSensorCorr = DataProcessor.calculateDataSensorCorr(_basicCounts);
        _dataSensorCorrNor = DataProcessor.calculateDataSensorCorrNor(
          _dataSensorCorr,
        );

        // Perform matrix multiplication here
        _finalCorrectedData = DataProcessor.multiplyVectorMatrix(
          _dataSensorCorr,
          correctionMatrix,
        ); // Perform the multiplication

        _calculatedX = DataProcessor.calculateXYZ(_finalCorrectedData, XN);
        _calculatedY = DataProcessor.calculateXYZ(_finalCorrectedData, YN);
        _calculatedZ = DataProcessor.calculateXYZ(_finalCorrectedData, ZN);

        // Calculate CIE 1931 values
        _cieX = _calculatedX.fold(0.0, (sum, item) => sum + item);
        _cieY = _calculatedY.fold(0.0, (sum, item) => sum + item);
        _cieZ = _calculatedZ.fold(0.0, (sum, item) => sum + item);

        double sumXYZ = _cieX + _cieY + _cieZ;
        if (sumXYZ > 0) {
          _cieSmallX = (_cieX / sumXYZ).toStringAsFixed(4);
          _cieSmallY = (_cieY / sumXYZ).toStringAsFixed(4);
          _cieSmallZ = (_cieZ / sumXYZ).toStringAsFixed(4);
        } else {
          _cieSmallX = "0.0000";
          _cieSmallY = "0.0000";
          _cieSmallZ = "0.0000";
        }
        _spectralLux = (_cieY * 683).toStringAsFixed(2);

        // Add the current CIE point to the list for the graph
        if (_cieSmallX != "N/A" && _cieSmallY != "N/A") {
          try {
            double x = double.parse(_cieSmallX);
            double y = double.parse(_cieSmallY);
            _cieChartSpots.add(FlSpot(x, y));
            // Optional: Limit the number of points in _cieChartSpots to keep the graph manageable
            if (_cieChartSpots.length > 50) {
              // Keep last 50 points
              _cieChartSpots.removeAt(0);
            }
          } catch (e) {
            print("Error parsing CIE x,y values: $e");
          }
        }
      });
    } else {
      setState(() {
        _chartData = [];
        _temperature = "N/A";
        _lux = "N/A";
        _basicCounts = List.filled(10, 0.0);
        _dataSensorCorr = List.filled(10, 0.0);
        _dataSensorCorrNor = List.filled(10, 0.0);
        _finalCorrectedData = List.filled(
          correctionMatrix.length,
          0.0,
        ); // Clear final data
        _cieX = 0.0;
        _cieY = 0.0;
        _cieZ = 0.0;
        _cieSmallX = "N/A";
        _cieSmallY = "N/A";
        _cieSmallZ = "N/A";
        _spectralLux = "N/A";
        _cieChartSpots = []; // Clear CIE chart data
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

  @override
  Widget build(BuildContext context) {
    List<FlSpot> basicCountChartData =
        _basicCounts.sublist(0, 8).asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList();

    List<FlSpot> dataSensorCorrChartData =
        _dataSensorCorr.sublist(0, 8).asMap().entries.map((entry) {
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentGraphView = GraphView.rawData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.rawData
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
                        _currentGraphView = GraphView.processedData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.processedData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Calc Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Add spacing for the new button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentGraphView = GraphView.cieData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.cieData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'CIE 1931',
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
                child:
                    _currentGraphView == GraphView.rawData
                        ? SpectrumChart(
                          showGraph: true,
                          colorChartData: _chartData,
                        ) // Displays Raw F1-F8 data
                        : _currentGraphView == GraphView.processedData
                        ? SpectrumChart(
                          showGraph: true,
                          colorChartData:
                              basicCountChartData, // Primary line for Basic Count
                          secondLineData:
                              dataSensorCorrChartData, // Second line for Data Sensor (Corr)
                        )
                        : Stack(
                          // Use Stack to layer image and chart
                          children: [
                            // Background image for CIE 1931 chart
                            Positioned.fill(
                              child: Image.asset(
                                // This is a placeholder URL. Replace it with your actual asset path.
                                // For local assets, use Image.asset('assets/images/CIE1931_bg.png')
                                // Make sure to declare your assets in pubspec.yaml
                                'assets/CIE1931_bg.png',
                                fit: BoxFit.fitWidth,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text(
                                      'Error loading image',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // SpectrumChart on top
                            SpectrumChart(
                              showGraph: true,
                              thirdLineData:
                                  _cieChartSpots, // Pass the list of CIE spots to thirdLineData
                              minXOverride: 0.0,
                              maxXOverride: 0.8,
                              minYOverride: 0.0,
                              maxYOverride: 0.9,
                              isCIEChart: true, // Indicate it's a CIE chart
                            ),
                          ],
                        ),
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
                        " $_temperature° C",
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
                        " $_lux Lux",
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
          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Measured Data Correction",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Channel
                    1: FlexColumnWidth(2), // Basic Count
                    2: FlexColumnWidth(2), // Data Sensor (Corr)
                    3: FlexColumnWidth(2), // Data Sensor (Corr/Nor)
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        TableCell(
                          // Use TableCell to apply vertical alignment
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Channel",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          // Use TableCell to apply vertical alignment
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Basic Count",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          // Use TableCell to apply vertical alignment
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Data Sensor (Corr)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          // Use TableCell to apply vertical alignment
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Data Sensor (Corr/Nor)",
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
                    for (int i = 0; i < _basicCounts.length; i++)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _getChannelName(i),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _basicCounts[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _dataSensorCorr[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _dataSensorCorrNor[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          // New section for Final Corrected Data (Matrix Multiplication Result)
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 16.0,
            ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Spectral Reconstruction",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  // Fixed height for the scrollable table
                  height: 200, // Adjust height as needed
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2), // Index
                        1: FlexColumnWidth(3), // Value
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
                                  "Wavelength",
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
                                  "Sensor Reconstruction",
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
                        for (int i = 0; i < _finalCorrectedData.length; i++)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  (i + 380).toString(),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _finalCorrectedData[i].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: 16.0,
            ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Calculated XYZ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  // Fixed height for the scrollable table
                  height: 200, // Adjust height as needed
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2), // Index
                        1: FlexColumnWidth(2), // Value
                        2: FlexColumnWidth(2), // Value
                        3: FlexColumnWidth(2), // Value
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
                                  "Wavelength",
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
                                  "X",
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
                                  "Y",
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
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Z",
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
                        for (int i = 0; i < _calculatedX.length; i++)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  (i + 380).toString(),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedX[i].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedY[i].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedZ[i].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // New section for CIE 1931 Calculated Values
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: 16.0,
            ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CIE 1931 Calculated Values",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1), // Label
                    1: FlexColumnWidth(1), // Value
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum X:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieX.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum Y:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieY.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum Z:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieZ.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "x:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallX),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "y:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallY),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "z:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallZ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Spectral Lux:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("$_spectralLux lm"),
                        ),
                      ],
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
