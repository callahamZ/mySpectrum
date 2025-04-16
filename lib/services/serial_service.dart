import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

class SerialService {
  static final SerialService _instance = SerialService._internal();

  factory SerialService() {
    return _instance;
  }

  SerialService._internal();

  UsbPort? serialPort;
  Function(List<double>, double, double)? onDataReceived;

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
      serialPort!.setPortParameters(
        baudRateInt,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      serialPort!.inputStream?.listen((Uint8List event) {
        _processSerialData(event);
      });

    } catch (e) {
      rethrow;
    }
  }

  void _processSerialData(Uint8List data) {
    String dataString = String.fromCharCodes(data);
    List<String> values = dataString.split(',');

    if (values.isNotEmpty && values[0] == '@DataCapture') {
      if (values.length >= 11) {
        try {
          List<double> spektrumData = values.sublist(1, 9).map(double.parse).toList();
          double temperature = double.parse(values[9]);
          double lux = double.parse(values[10]);

          if (onDataReceived != null) {
            onDataReceived!(spektrumData, temperature, lux);
          }
        } catch (e) {
          print("Error parsing serial data: $e");
        }
      }
    } else {
      print("Received data is not a DataCapture: $dataString");
    }
  }

  Future<void> disconnectSerial() async {
    if (serialPort != null) {
      await serialPort!.close();
      serialPort = null;
    }
  }
}