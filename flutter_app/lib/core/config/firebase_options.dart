import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _web;
    }

    if (Platform.isAndroid) {
      return _android;
    }

    if (Platform.isIOS) {
      return _ios;
    }

    throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
  }

  static FirebaseOptions get _android => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get _ios => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get _web => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        authDomain: const String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      );
}
