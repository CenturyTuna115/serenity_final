import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class WeeklyGraph extends StatefulWidget {
  const WeeklyGraph({Key? key}) : super(key: key);

  @override
  _WeeklyGraphState createState() => _WeeklyGraphState();
}

class _WeeklyGraphState extends State<WeeklyGraph> {
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = true;
  double _minY = 0;
  double _maxY = 5; // Default range; will be recalculated if data is found

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData();
  }

  Future<void> _fetchWeeklyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef
          .child('administrator/users/${user.uid}/all_answers')
          .get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> allAnswers = [];

        // Parse each entry in Firebase
        values.forEach((key, value) {
          if (value == null) {
            debugPrint('Skipping null entry');
            return;
          }
          try {
            final dynamic timestampValue = value['timestamp'];
            final dynamic totalValueValue = value['total_value'];

            final timestamp = timestampValue is int
                ? timestampValue
                : timestampValue is String
                    ? int.tryParse(timestampValue) ?? 0
                    : 0;

            final totalValue = totalValueValue is num
                ? totalValueValue.toDouble()
                : totalValueValue is String
                    ? double.tryParse(totalValueValue) ?? 0.0
                    : 0.0;

            // Only add valid data
            if (timestamp != 0 || totalValue != 0.0) {
              allAnswers.add({
                'timestamp': timestamp,
                'total_value': totalValue,
              });
            }
          } catch (e) {
            debugPrint('Skipping invalid entry (key: $key): $e');
          }
        });

        // Group answers by "yyyy-ww"
        Map<String, List<double>> weeklyGroups = {};
        final dateFormat = DateFormat('yyyy-ww');

        for (var answer in allAnswers) {
          DateTime date =
              DateTime.fromMillisecondsSinceEpoch(answer['timestamp']);
          String weekKey = dateFormat.format(date);
          weeklyGroups
              .putIfAbsent(weekKey, () => [])
              .add(answer['total_value']);
        }

        // Calculate weekly averages
        List<Map<String, dynamic>> weeklyData = [];
        weeklyGroups.forEach((week, valuesList) {
          if (valuesList.isNotEmpty) {
            double sum = valuesList.reduce((a, b) => a + b);
            double average = sum / valuesList.length;
            weeklyData.add({
              'week': week,
              'average': average,
            });
          }
        });

        // Sort by chronological order of "yyyy-ww"
        weeklyData.sort((a, b) {
          int aValue =
              int.parse(a['week'].replaceAll('-', '')); // "2025-12" -> "202512"
          int bValue = int.parse(b['week'].replaceAll('-', ''));
          return aValue.compareTo(bValue);
        });

        // Compute dynamic y-axis bounds if data is available
        if (weeklyData.isNotEmpty) {
          double minVal = weeklyData.first['average'];
          double maxVal = weeklyData.first['average'];
          for (var item in weeklyData) {
            double val = item['average'];
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
          }
          double padding = (maxVal - minVal) * 0.1;
          setState(() {
            _weeklyData = weeklyData;
            _minY = (minVal - padding) < 0 ? 0 : (minVal - padding);
            _maxY = maxVal + padding;
            _isLoading = false;
          });
        } else {
          setState(() {
            _weeklyData = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _weeklyData = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_weeklyData.isEmpty) {
      return const Center(child: Text("No weekly data available"));
    }

    // Convert weekly data to FlSpot format
    List<FlSpot> spots = [];
    for (int i = 0; i < _weeklyData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _weeklyData[i]['average']));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    // Show the week number and average value
                    final dataIndex = spot.x.toInt();
                    final weekLabel =
                        _weeklyData[dataIndex]['week']; // "2025-12"
                    final averageValue = spot.y.toStringAsFixed(2);
                    return LineTooltipItem(
                      'Week ${weekLabel.split('-')[1]}\nValue: $averageValue',
                      const TextStyle(color: Colors.white),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < _weeklyData.length) {
                      // Show "Wxx" from "yyyy-ww"
                      final weekKey = _weeklyData[index]['week'];
                      return Text('W${weekKey.split('-')[1]}',
                          style: const TextStyle(fontSize: 10));
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toStringAsFixed(1));
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom:
                    BorderSide(color: Colors.blue.withOpacity(0.2), width: 2),
                left: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
                top: const BorderSide(color: Colors.transparent),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                color: Colors.blue,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                spots: spots,
              ),
            ],
            minX: 0,
            maxX: (_weeklyData.length - 1).toDouble(),
            minY: _minY,
            maxY: _maxY,
          ),
        ),
      ),
    );
  }
}
