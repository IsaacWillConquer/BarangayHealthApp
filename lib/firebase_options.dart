import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Mirrors the web app's config in `src/firebase.js` so both clients read and
/// write the same Firestore project.
///
/// Initialized through [FirebaseOptions] rather than `google-services.json`,
/// because Firestore only needs `apiKey` + `projectId` and this avoids
/// registering an Android app (and its SHA-1) in the Firebase console.
///
/// NOTE: this file also lives in the web repo as `src/firebase.js`. Keep the
/// values in sync.
class AppFirebase {
  AppFirebase._();

  static const projectId = 'barangayhealth-3a5a2';
  static const apiKey = 'AIzaSyBgmHQb1wZvLBTlAvGYF11l3WYGzI0A-Ec';
  static const appIdAndroid = '1:224789207387:android:0000000000000000000000';

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: kIsWeb ? '1:224789207387:web:9bb94e4a5b1e32bfdd627e' : appIdAndroid,
    messagingSenderId: '224789207387',
    projectId: projectId,
    databaseURL: 'https://barangayhealth-3a5a2-default-rtdb.firebaseio.com',
    storageBucket: 'barangayhealth-3a5a2.firebasestorage.app',
  );

  static Future<void> init() => Firebase.initializeApp(options: options);
}
