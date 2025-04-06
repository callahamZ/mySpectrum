import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<UsbDevice>> _serialPortListFuture;
  UsbPort? _serialPort; // Store the opened port

  @override
  void initState() {
    super.initState();
    _refreshSerialPortList();
  }

  Future<void> _refreshSerialPortList() async {
    setState(() {
      _serialPortListFuture = UsbSerial.listDevices();
    });
  }

  Future<void> _connectToSerial() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No USB devices found.')));
      return;
    }

    try {
      _serialPort = await devices[0].create(); // Connect to the first device

      bool openResult = await _serialPort!.open();
      if (!openResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open serial port.')),
        );
        return;
      }

      await _serialPort!.setDTR(true);
      await _serialPort!.setRTS(true);

      _serialPort!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Listen for incoming data (optional)
      _serialPort!.inputStream?.listen((Uint8List event) {
        print('Received data: $event');
        // Handle incoming data here
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Serial port connected.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error connecting: $e')));
    }
  }

  Future<void> _sendData(Uint8List data) async {
    if (_serialPort == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Serial port is not open.')));
      return;
    }
    try {
      await _serialPort!.write(data);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data sent.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending data: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Serial Connection",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Available Ports",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            new Divider(thickness: 2,),
                            FutureBuilder<List<UsbDevice>>(
                              future: _serialPortListFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text("Loading...");
                                } else if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  final serialPortList = snapshot.data!;
                                  final device = serialPortList[0];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(device.productName ?? "unknown"),
                                      Text("--> ${device.deviceName}"),
                                    ],
                                  );
                                } else {
                                  return const Text("None");
                                }
                              },
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _refreshSerialPortList,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(child: Icon(Icons.refresh, color: Colors.white)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
              width: double.infinity,
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
              child: const Text("Baud Rate"),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}