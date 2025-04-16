import 'package:flutter/material.dart';
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

  void toggleFirebaseMode() {
    setState(() {
      isFirebaseMode = !isFirebaseMode;
      print("Status navigator : $isFirebaseMode");
      _updateHomePageContent();
    });
  }

    void _updateHomePageContent() {
    _widgetOptions[0] = HomePageContent(
      key: ValueKey(isFirebaseMode),
      isFirebaseMode: isFirebaseMode,
      toggleFirebaseMode: toggleFirebaseMode,
    );
  }

  @override
  void initState() {
    super.initState();
    _updateHomePageContent(); // Initialize HomePageContent
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateHomePageContent(); // Update HomePageContent on widget update
  }


  late final List<Widget> _widgetOptions = <Widget>[
    HomePageContent(
      key: ValueKey(isFirebaseMode),
      isFirebaseMode: isFirebaseMode,
      toggleFirebaseMode: toggleFirebaseMode,
    ),
    CompareModePage(),
    DataRecordPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      body: _widgetOptions.elementAt(_selectedIndex),
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
