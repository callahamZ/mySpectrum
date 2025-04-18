import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/serial_service.dart';

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

  final SerialService _serialService =
      SerialService(); // Get the singleton instance

  @override
  void initState() {
    super.initState();
    _serialService.onDataReceived = _updateSerialData;
  }

  void _updateSerialData(
    List<double> spektrumData,
    double temperature,
    double lux,
  ) {
    if (!widget.isFirebaseMode) {
      setState(() {
        _serialSpectrumData = spektrumData;
        _serialTemperature = temperature;
        _serialLux = lux;
      });
    }
  }

  Widget bottomChartAxisLabel(double value, TitleMeta meta) {
    final xAxisLabels = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"];
    final arrIndex = value.toInt() - 1;
    return SideTitleWidget(
      meta: meta,
      child: Text(xAxisLabels[arrIndex], style: const TextStyle(fontSize: 13)),
    );
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

          return _buildContent(chartData, tempVal, luxVal);
        },
      );
    } else {
      // Use serial data directly
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
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: bottomChartAxisLabel,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: const Color.fromARGB(255, 0, 0, 1),
                        width: 2,
                      ),
                    ),
                    minX: 1,
                    maxX: 8,
                    minY: 0,
                    maxY: 5000,
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
                        isCurved: true,
                        barWidth: 2,
                        color: Colors.black,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromRGBO(111, 47, 159, 0.8),
                              Color.fromRGBO(0, 31, 95, 0.8),
                              Color.fromRGBO(63, 146, 207, 0.8),
                              Color.fromRGBO(0, 175, 239, 0.8),
                              Color.fromRGBO(0, 175, 80, 0.8),
                              Color.fromRGBO(255, 255, 0, 0.8),
                              Color.fromRGBO(247, 149, 70, 0.8),
                              Color.fromRGBO(255, 0, 0, 0.8),
                            ],
                            stops: const [
                              0,
                              0.14285714285714285,
                              0.2857142857142857,
                              0.42857142857142855,
                              0.5714285714285714,
                              0.7142857142857143,
                              0.8571428571428571,
                              1,
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ],
                  ),
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

          Container(child: Text("$_serialSpectrumData")),
        ],
      ),
    );
  }
}
