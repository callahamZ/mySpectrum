import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'database_service.dart';
import 'dart:async';

class SerialService {
  static final SerialService _instance = SerialService._internal();

  factory SerialService() {
    return _instance;
  }

  SerialService._internal();

  UsbPort? serialPort;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  Function(List<double>, double, double)? onDataReceived;
  Function(String)? onRawDataReceived;
  bool serialStatus = false;

  Future<void> connectToSerial(String baudRate) async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      throw Exception('No USB devices found.');
    }

    try {
      serialPort = await devices[0].create();
      bool openResult = await serialPort!.open();
      if (!openResult) {
        throw Exception('Failed to open serial port.');
      }

      await serialPort!.setDTR(false);
      await serialPort!.setRTS(false);

      int baudRateInt = int.parse(baudRate);
      await serialPort!.setPortParameters(
        baudRateInt,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      serialStatus = true;

      _transaction = Transaction.stringTerminated(
        serialPort!.inputStream as Stream<Uint8List>,
        Uint8List.fromList([13, 10]), // Assuming \r\n termination
      );

      _subscription = _transaction!.stream.listen(
        (String line) {
          if (onRawDataReceived != null) {
            onRawDataReceived!(line); // Send raw line to SettingsPage
          }
          _processSerialData(line);
        },
        onError: (error) {
          print("Serial stream error: $error");
          disconnectSerial();
        },
        onDone: () {
          print("Serial stream done");
          disconnectSerial();
        },
      );
    } catch (e) {
      disconnectSerial();
      rethrow;
    }
  }

  void _processSerialData(String rawData) {
    if (rawData.startsWith('@DataCap')) {
      List<String> values = rawData.substring('@DataCap,'.length).split(',');
      // Now expecting 12 values: F1-F8, Clear, NIR, Lux, Temperature
      if (values.length == 12) {
        // Changed from 10 to 12
        try {
          List<double> spektrumData = [];
          // Parse F1-F8
          for (int i = 0; i < 8; i++) {
            spektrumData.add(double.parse(values[i]));
          }
          // Parse Clear and NIR
          spektrumData.add(double.parse(values[8])); // Clear
          spektrumData.add(double.parse(values[9])); // NIR

          double lux = double.parse(values[10]); // Lux is now at index 10
          double temperature = double.parse(
            values[11],
          ); // Temperature is now at index 11

          DatabaseHelper.instance.insertMeasurement(
            timestamp: DateTime.now(),
            spectrumData: spektrumData,
            temperature: temperature,
            lux: lux,
          );

          if (onDataReceived != null) {
            // onDataReceived expects List<double> for spektrumData, double for temperature, double for lux
            onDataReceived!(spektrumData, temperature, lux);
          }
        } catch (e) {
          print("Error parsing serial data: $e from: $rawData");
        }
      } else {
        print(
          "Received data has incorrect number of values: $rawData. Expected 12, got ${values.length}",
        );
      }
    } else {
      print("Received data does not start with @DataCap: $rawData");
    }
  }

  Future<void> disconnectSerial() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }
    if (serialPort != null) {
      await serialPort!.close();
      serialPort = null;
    }
    serialStatus = false;
  }
}
