// graph_service.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class SpectrumChart extends StatelessWidget {
  final List<FlSpot> chartData;

  const SpectrumChart({Key? key, required this.chartData}) : super(key: key);

  double _calculateMaxY() {
    if (chartData.isEmpty) return 1000.0; // Default if no data

    List<double> yValues = chartData.map((spot) => spot.y).toList();
    double maxValue = yValues.reduce(max);
    const maxList = [1000.0, 5000.0, 10000.0, 25000.0, 50000.0, 70000.0];

    for (var maxPoint in maxList) {
      if (maxValue < maxPoint) {
        return maxPoint;
      }
    }
    return 70000.0; // Return the largest value in maxList if maxValue is larger.
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
    final double maxYValue = _calculateMaxY();

    return Center(
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
            maxY: maxYValue, // Use the calculated maxYValue
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
            ],
          ),
        ),
      ),
    );
  }
}
