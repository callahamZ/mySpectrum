import 'package:flutter/material.dart';
import 'package:spectrumapp/services/database_service.dart'; // Import your DatabaseHelper

class DataRecordPage extends StatefulWidget {
  const DataRecordPage({Key? key}) : super(key: key);

  @override
  _DataRecordPageState createState() => _DataRecordPageState();
}

class _DataRecordPageState extends State<DataRecordPage> {
  late Future<List<Map<String, dynamic>>> _measurementsFuture;

  @override
  void initState() {
    super.initState();
    _measurementsFuture = DatabaseHelper.instance.getAllMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Records')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _measurementsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final measurements = snapshot.data!;
            return ListView.builder(
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final measurement = measurements[index];
                return ListTile(
                  title: Text('Timestamp: ${measurement['timestamp']}'),
                  subtitle: Text(
                    'Temp: ${measurement['temperature']}, Lux: ${measurement['lux']}',
                  ),
                  // Add more details as needed
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
