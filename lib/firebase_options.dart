import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web; 
    }
    return android; 
  }


  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5OLdQByoRT8i1dHrrTZ__Cw2B5a34Ckw',
    appId: '1:410564122988:web:0304dc549f98cc478f3b49', 
    messagingSenderId: '410564122988',
    projectId: 'phtb-336e3',
    authDomain: 'phtb-336e3.firebaseapp.com',
    storageBucket: 'phtb-336e3.firebasestorage.app',
    measurementId: 'G-ZY8518GW0L',
  );


  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA4p4FOjs87o3qakUM3WBrJHYmJpCGE0Zw', 
    appId: '1:410564122988:android:f5440f16c2bf46da8f3b49',
    messagingSenderId: '410564122988',
    projectId: 'phtb-336e3',
    storageBucket: 'phtb-336e3.firebasestorage.app',
  );
}