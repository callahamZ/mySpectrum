// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyADIx4Bxv0SO8nUIAzv-1n53oYEFi1h14I',
    appId: '1:1016576536089:web:a1334d1537a22e9de4c488',
    messagingSenderId: '1016576536089',
    projectId: 'esp32-light-spectrum-analyzer',
    authDomain: 'esp32-light-spectrum-analyzer.firebaseapp.com',
    databaseURL: 'https://esp32-light-spectrum-analyzer-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'esp32-light-spectrum-analyzer.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdx9y-G47inDvJM7EXr2jbtDMphkLvVqQ',
    appId: '1:1016576536089:android:f67082fd8fe6938ee4c488',
    messagingSenderId: '1016576536089',
    projectId: 'esp32-light-spectrum-analyzer',
    databaseURL: 'https://esp32-light-spectrum-analyzer-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'esp32-light-spectrum-analyzer.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA04rru_dJy2kPDl91XHvLQl6lii-FMDIE',
    appId: '1:1016576536089:ios:c55620d55516fbbae4c488',
    messagingSenderId: '1016576536089',
    projectId: 'esp32-light-spectrum-analyzer',
    databaseURL: 'https://esp32-light-spectrum-analyzer-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'esp32-light-spectrum-analyzer.firebasestorage.app',
    iosBundleId: 'com.example.spectrumapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA04rru_dJy2kPDl91XHvLQl6lii-FMDIE',
    appId: '1:1016576536089:ios:c55620d55516fbbae4c488',
    messagingSenderId: '1016576536089',
    projectId: 'esp32-light-spectrum-analyzer',
    databaseURL: 'https://esp32-light-spectrum-analyzer-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'esp32-light-spectrum-analyzer.firebasestorage.app',
    iosBundleId: 'com.example.spectrumapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCR5phZMrFXhhey-SyrBwHpHZsBYORHb_Y',
    appId: '1:1016576536089:web:c53fedcf0c5f7547e4c488',
    messagingSenderId: '1016576536089',
    projectId: 'esp32-light-spectrum-analyzer',
    authDomain: 'esp32-light-spectrum-analyzer.firebaseapp.com',
    databaseURL: 'https://esp32-light-spectrum-analyzer-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'esp32-light-spectrum-analyzer.firebasestorage.app',
  );
}
