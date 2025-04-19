import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
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
  Function(String)? onRawDataReceived; // New callback for raw data

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
      if (values.length == 10) {
        try {
          List<double> spektrumData =
              values.sublist(0, 8).map(double.parse).toList();
          double lux = double.parse(values[8]);
          double temperature = double.parse(values[9]);

          if (onDataReceived != null) {
            onDataReceived!(spektrumData, temperature, lux);
          }
        } catch (e) {
          print("Error parsing serial data: $e from: $rawData");
        }
      } else {
        print("Received data has incorrect number of values: $rawData");
      }
    } else {
      print("Received data does not start with @DataCapture: $rawData");
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
  }
}
