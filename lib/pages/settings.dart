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
  UsbPort? _serialPort;
  String? _selectedBaudRate = '115200';
  final List<String> _baudRates = ['9600', '115200', '19200'];

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

      if (_serialPort != null && _selectedBaudRate != null) {
        int baudRate = int.parse(_selectedBaudRate!);
        _serialPort!.setPortParameters(
          baudRate,
          UsbPort.DATABITS_8,
          UsbPort.STOPBITS_1,
          UsbPort.PARITY_NONE,
        );
      }

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
                    margin: EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Available Ports",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Divider(),
                              FutureBuilder<List<UsbDevice>>(
                                future: _serialPortListFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text("Loading...");
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else if (snapshot.hasData &&
                                      snapshot.data!.isNotEmpty) {
                                    final serialPortList = snapshot.data!;
                                    final device = serialPortList[0];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                        ),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _refreshSerialPortList,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: EdgeInsets.only(left: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Container(
              margin: EdgeInsets.only(left: 8, top: 4),
              child: Text(
                "*Koneksi OTG harus diaktifkan di pengaturan smartphone",
                style: TextStyle(fontSize: 10),
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: Row(
                children: [
                  Text(
                    "Baud Rate :",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedBaudRate,
                      isExpanded: true,
                      items:
                          _baudRates.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedBaudRate = newValue!;
                        });
                      },
                      hint: const Text("Select Baud Rate"),
                    ),
                  ),
                ],
              ),
            ),

            ElevatedButton(
              onPressed: _connectToSerial,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white, // Background color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0), // Border radius
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                "Connect",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
