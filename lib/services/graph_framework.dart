import 'dart:math'; // For the 'max' function in _calculateMaxY
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpectrumChart extends StatelessWidget {
  final bool showGraph;
  final List<FlSpot>? colorChartData;
  final List<FlSpot>? redChartData; // New: Optional reference data
  final List<FlSpot>? secondLineData;
  final List<FlSpot>? thirdLineData;
  final double? maxY; // Optional maxY if external control is desired

  const SpectrumChart({
    Key? key,
    required this.showGraph,
    this.colorChartData,
    this.redChartData,
    this.secondLineData,
    this.thirdLineData,
    this.maxY,
  }) : super(key: key);

  // Helper function to calculate appropriate maxY based on data
  double _calculateDynamicMaxY(List<FlSpot> data, List<FlSpot>? referenceData) {
    List<double> allValues = [];
    if (data.isNotEmpty) {
      allValues.addAll(data.map((e) => e.y));
    }
    if (referenceData != null && referenceData.isNotEmpty) {
      allValues.addAll(referenceData.map((e) => e.y));
    }

    if (allValues.isEmpty) return 1000.0; // Default if no data

    double maxValue = allValues.reduce(max);

    const maxList = [
      0.5,
      1.0,
      1000.0,
      5000.0,
      10000.0,
      25000.0,
      50000.0,
      70000.0,
    ];
    double calculatedMaxY = 1000.0;
    for (var maxPoints in maxList) {
      if (maxValue < maxPoints) {
        calculatedMaxY = maxPoints;
        break;
      }
    }
    return calculatedMaxY;
  }

  @override
  Widget build(BuildContext context) {
    // Determine the actual maxY for the chart
    final double chartMaxY =
        maxY ?? _calculateDynamicMaxY(colorChartData!, redChartData);

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 1:
                    return const Text('F1');
                  case 2:
                    return const Text('F2');
                  case 3:
                    return const Text('F3');
                  case 4:
                    return const Text('F4');
                  case 5:
                    return const Text('F5');
                  case 6:
                    return const Text('F6');
                  case 7:
                    return const Text('F7');
                  case 8:
                    return const Text('F8');
                  default:
                    return const Text('');
                }
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black, width: 2),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.white,
            tooltipBorder: const BorderSide(color: Colors.black),
          ),
        ),
        minX: 1,
        maxX: 8,
        minY: 0,
        maxY: chartMaxY, // Use the determined maxY
        lineBarsData: [
          if (colorChartData != null && colorChartData!.isNotEmpty)
            LineChartBarData(
              spots: colorChartData!,
              isCurved: true,
              barWidth: 2, // Adjusted barWidth as per your snippet
              color:
                  Colors.black, // Set line color to black as per your snippet
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
                  stops: [
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
          // Reference Data Line
          if (redChartData != null && redChartData!.isNotEmpty)
            LineChartBarData(
              spots: redChartData!,
              isCurved: true,
              color: Colors.red, // Distinct color for reference data
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: false,
              ), // Reference data does not have area
              dashArray: [5, 5], // Dashed line for distinction
            ),
          if (secondLineData != null && secondLineData!.isNotEmpty)
            LineChartBarData(
              spots: secondLineData!,
              isCurved: true,
              color: Colors.red, // Distinct color for Basic Count
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          // Third Line Data (e.g., Data Sensor Corr on Home Page)
          if (thirdLineData != null && thirdLineData!.isNotEmpty)
            LineChartBarData(
              spots: thirdLineData!,
              isCurved: true,
              color:
                  Colors
                      .purple
                      .shade700, // Distinct color for Data Sensor (Corr)
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}
