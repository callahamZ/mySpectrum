import 'package:flutter/material.dart';
import 'package:spectrumapp/services/serial_service.dart';
import 'data_record.dart';
import 'settings.dart';
import 'home_page.dart';
import 'compare_mode.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool isFirebaseMode = true;

  final SerialService _serialService = SerialService();

  void toggleFirebaseMode() {
    setState(() {
      isFirebaseMode = !isFirebaseMode;
      if (!_serialService.serialStatus && !isFirebaseMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No Serial Port Detected; Go to setting to set it up',
            ),
          ),
        );
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return HomePageContent(
          key: ValueKey(isFirebaseMode),
          isFirebaseMode: isFirebaseMode,
          toggleFirebaseMode: toggleFirebaseMode,
        );
      case 1:
        return CompareModePage(
          key: ValueKey(isFirebaseMode),
          isFirebaseMode: isFirebaseMode,
          toggleFirebaseMode: toggleFirebaseMode,
        );
      case 2:
        return DataRecordPage();
      case 3:
        return SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, color: Colors.black),
            children: <TextSpan>[
              TextSpan(
                text: 'My',
                style: TextStyle(fontWeight: FontWeight.normal),
              ),
              TextSpan(
                text: 'Spectrum',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: _getBody(), // Use a function to dynamically build the body
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.compare),
            label: 'Compare Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Data Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
