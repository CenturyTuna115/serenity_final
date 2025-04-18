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

  String _currentMood = '';
  String _currentCondition = '';

  Future<void> _fetchWeeklyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef
          .child('administrator/users/${user.uid}/all_answers')
          .get();

      debugPrint('Fetching data for user: ${user.uid}');

      if (snapshot.exists) {
        debugPrint('Found data in snapshot');
        Map<dynamic, dynamic> conditions =
            snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> allAnswers = [];
        DateTime? latestDate;
        double? latestValue;

        conditions.forEach((condition, timestamps) {
          debugPrint('Processing condition: $condition');
          if (timestamps == null || !(timestamps is Map)) {
            debugPrint('Invalid timestamps data for condition: $condition');
            return;
          }

          (timestamps as Map<dynamic, dynamic>).forEach((timestamp, data) {
            if (data == null || !(data is Map)) {
              debugPrint('Invalid data for timestamp: $timestamp');
              return;
            }

            try {
              final totalValue = data['total_value'];
              final timestampStr = data['timestamp'] as String?;

              debugPrint(
                  'Processing entry - Timestamp: $timestampStr, Value: $totalValue');

              if (totalValue != null && timestampStr != null) {
                final double numericValue = (totalValue is num)
                    ? totalValue.toDouble()
                    : double.tryParse(totalValue.toString()) ?? 0.0;

                final DateTime date = DateTime.parse(timestampStr);

                allAnswers.add({
                  'condition': condition,
                  'timestamp': date.millisecondsSinceEpoch,
                  'date': date,
                  'total_value': numericValue,
                });

                if (latestDate == null || date.isAfter(latestDate!)) {
                  latestDate = date;
                  latestValue = numericValue;
                }
              }
            } catch (e) {
              debugPrint(
                  'Error processing answer for $condition at $timestamp: $e');
            }
          });
        });

        debugPrint('Total answers collected: ${allAnswers.length}');

        // Determine current mood based on latest value
        if (latestValue != null) {
          debugPrint('Latest value: $latestValue');
          if (latestValue! < 10) {
            _currentMood = 'mild';
            _currentCondition = 'mild';
          } else if (latestValue! < 20) {
            _currentMood = 'moderate';
            _currentCondition = 'moderate';
          } else {
            _currentMood = 'severe';
            _currentCondition = 'severe';
          }
          debugPrint('Set mood to: $_currentMood ($_currentCondition)');
        }

        // Group answers by week
        Map<String, List<double>> weeklyGroups = {};
        final dateFormat = DateFormat('yyyy-MM');

        for (var answer in allAnswers) {
          DateTime date = answer['date'];
          String monthKey = dateFormat.format(date);
          int weekInMonth = ((date.day - 1) ~/ 7) + 1;
          String weekKey = '$monthKey-W$weekInMonth';

          weeklyGroups
              .putIfAbsent(weekKey, () => [])
              .add(answer['total_value']);
        }

        debugPrint('Weekly groups created: ${weeklyGroups.length}');

        // Calculate weekly averages
        List<Map<String, dynamic>> weeklyData = [];
        weeklyGroups.forEach((weekKey, valuesList) {
          if (valuesList.isNotEmpty) {
            double sum = valuesList.reduce((a, b) => a + b);
            double average = sum / valuesList.length;
            weeklyData.add({
              'week': weekKey,
              'average': average,
            });
            debugPrint('Week: $weekKey, Average: $average');
          }
        });

        // Sort by chronological order
        weeklyData.sort((a, b) => a['week'].compareTo(b['week']));

        // Compute dynamic y-axis bounds
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

          debugPrint('Graph bounds set - Min: $_minY, Max: $_maxY');
          debugPrint('Weekly data points: ${_weeklyData.length}');
        } else {
          debugPrint('No weekly data available');
          setState(() {
            _weeklyData = [];
            _isLoading = false;
          });
        }
      } else {
        debugPrint('No data found in snapshot');
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

    List<FlSpot> spots = [];
    for (int i = 0; i < _weeklyData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _weeklyData[i]['average']));
    }

    return Column(
      mainAxisSize: MainAxisSize.min, // Use minimum space needed
      children: [
        if (_currentMood.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0), // Reduced padding
            child: Text(
              'Current Mood: $_currentMood ($_currentCondition)',
              style: const TextStyle(fontSize: 14), // Slightly smaller font
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (_weeklyData.length - 1).toDouble(),
                minY: 0,
                maxY: 30,
                clipData: FlClipData.all(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final dataIndex = spot.x.toInt();
                        final weekKey = _weeklyData[dataIndex]['week'];
                        final parts = weekKey.split('-');
                        final year = parts[0];
                        final monthNum = int.parse(parts[1]);
                        final weekNum = parts[2].substring(1);
                        final averageValue = spot.y.toStringAsFixed(2);
                        String moodState = spot.y < 10
                            ? 'mild'
                            : spot.y < 20
                                ? 'moderate'
                                : 'severe';
                        return LineTooltipItem(
                          'Week $weekNum\n$averageValue ($moodState)', // Simplified tooltip
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 15,
                  verticalInterval: 1,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 22, // Reduced reserved size
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _weeklyData.length) {
                          final weekKey = _weeklyData[index]['week'];
                          final parts = weekKey.split('-');
                          final weekNum = parts[2].substring(1);
                          return RotatedBox(
                            quarterTurns: 1,
                            child: Text(
                              'W$weekNum', // Simplified label
                              style: const TextStyle(
                                fontSize: 9, // Smaller font
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35, // Reduced reserved size
                      interval: 15,
                      getTitlesWidget: (value, meta) {
                        String label;
                        if (value == 0) {
                          label = 'Mild';
                        } else if (value == 15) {
                          label = 'Mod'; // Shortened label
                        } else if (value == 30) {
                          label = 'Severe';
                        } else {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10, // Smaller font
                              color: Colors.black87,
                            ),
                          ),
                        );
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
                  border: Border.all(color: Colors.black12),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    spots: spots,
                    gradient: const LinearGradient(
                      colors: [
                        Colors.green,
                        Colors.yellow,
                        Colors.red,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.3),
                          Colors.yellow.withOpacity(0.3),
                          Colors.red.withOpacity(0.3),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
