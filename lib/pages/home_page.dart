import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePageContent extends StatelessWidget {
  final DatabaseReference spektrumDatabase = FirebaseDatabase.instance.ref();

  HomePageContent({super.key});

  Widget bottomChartAxisLabel(double value, TitleMeta meta) {
    final xAxisLabels = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"];
    final arrIndex = value.toInt() - 1;
    return SideTitleWidget(
      meta: meta,
      child: Text(xAxisLabels[arrIndex], style: TextStyle(fontSize: 13)),
    );
  }

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
            if(spektrumData != null){
              for (int i = 1; i <= 8; i++) {
                String key = 'F$i';
                if (spektrumData.containsKey(key)) {
                  double value = double.parse(
                    spektrumData[key].toString(),
                  );
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

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    // Added boxShadow
                    BoxShadow(
                      color: Color.fromARGB(50, 0, 0, 0),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.whatshot, color: Colors.white, size: 24.0),
                    const SizedBox(width: 8.0),
                    const Text(
                      "Firebase Connected",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                  boxShadow: [
                    // Added boxShadow
                    BoxShadow(
                      color: const Color.fromARGB(50, 0, 0, 0),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
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
                        maxY: 1000,
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartData,
                            isCurved: true,
                            barWidth: 2,
                            color: Colors.black,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color.fromRGBO(111, 47, 159, 0.8),
                                  const Color.fromRGBO(0, 31, 95, 0.8),
                                  const Color.fromRGBO(63, 146, 207, 0.8),
                                  const Color.fromRGBO(0, 175, 239, 0.8),
                                  const Color.fromRGBO(0, 175, 80, 0.8),
                                  const Color.fromRGBO(255, 255, 0, 0.8),
                                  const Color.fromRGBO(247, 149, 70, 0.8),
                                  const Color.fromRGBO(255, 0, 0, 0.8),
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
                        boxShadow: [
                          // Added boxShadow
                          BoxShadow(
                            color: const Color.fromARGB(50, 0, 0, 0),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.thermostat,
                            color: Colors.blueAccent,
                          ),
                          Text(
                            " $tempVal° C",
                            style: TextStyle(
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
                        boxShadow: [
                          // Added boxShadow
                          BoxShadow(
                            color: const Color.fromARGB(50, 0, 0, 0),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.brightness_medium,
                            color: Colors.blue,
                          ),
                          Text(
                            " $luxVal Lux",
                            style: TextStyle(
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
      },
    );
  }
}
