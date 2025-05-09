import 'package:flutter/material.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'package:usb_serial/usb_serial.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<UsbDevice>> _serialPortListFuture;
  String? _selectedBaudRate = '115200';
  final List<String> _baudRates = ['9600', '115200', '19200'];
  final SerialService _serialService = SerialService();

  @override
  void initState() {
    super.initState();
    _refreshSerialPortList();
  }

  @override
  void dispose() {
    // Remove the callback when the widget is disposed
    _serialService.onRawDataReceived = null;
    super.dispose();
  }

  Future<void> _refreshSerialPortList() async {
    setState(() {
      _serialPortListFuture = Future.delayed(
        const Duration(milliseconds: 500),
        () => UsbSerial.listDevices(),
      );
    });
  }

  Future<void> _connectToSerial() async {
    try {
      await _serialService.connectToSerial(_selectedBaudRate!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Serial port connected.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error connecting: $e')));
    }
  }

  Future<void> _disconnectFromSerial() async {
    try {
      await _serialService.disconnectSerial();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Serial port disconnected')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error disconnecting: $e')));
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
              onPressed:
                  _serialService.serialStatus
                      ? _disconnectFromSerial
                      : _connectToSerial,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _serialService.serialStatus ? Colors.red : Colors.blue,
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
                _serialService.serialStatus ? "Disconnect" : "Connect",
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
