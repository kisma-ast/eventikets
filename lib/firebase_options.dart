import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuration par défaut pour l'application Firebase Eventikets
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
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'a pas été configuré pour macOS - '
          'vous devez créer le projet Firebase pour cette plateforme.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'a pas été configuré pour Windows - '
          'vous devez créer le projet Firebase pour cette plateforme.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'a pas été configuré pour Linux - '
          'vous devez créer le projet Firebase pour cette plateforme.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'est pas disponible pour cette plateforme.',
        );
    }
  }

  // Configuration pour Web - Configuration Firebase pour le projet eventikets-app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGX-_Wpl24EbybrECOarVsuIvL4BwZHhg',
    appId: '1:113284066244:web:322318daeca754a50d5291',
    messagingSenderId: '113284066244',
    projectId: 'eventikets-app',
    authDomain: 'eventikets-app.firebaseapp.com',
    storageBucket: 'eventikets-app.firebasestorage.app',
    measurementId: 'G-CLY0KDD48M',
  );

  // Configuration pour Android - Configuration Firebase pour le projet eventikets-app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDGX-_Wpl24EbybrECOarVsuIvL4BwZHhg',
    appId: '1:113284066244:android:322318daeca754a50d5291', // Note: Ceci est une approximation, à ajuster si nécessaire
    messagingSenderId: '113284066244',
    projectId: 'eventikets-app',
    storageBucket: 'eventikets-app.firebasestorage.app',
  );

  // Configuration pour iOS - Configuration Firebase pour le projet eventikets-app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDGX-_Wpl24EbybrECOarVsuIvL4BwZHhg',
    appId: '1:113284066244:ios:322318daeca754a50d5291', // Note: Ceci est une approximation, à ajuster si nécessaire
    messagingSenderId: '113284066244',
    projectId: 'eventikets-app',
    storageBucket: 'eventikets-app.firebasestorage.app',
    iosClientId: '113284066244-app.apps.googleusercontent.com', // Note: Ceci est une approximation, à ajuster si nécessaire
    iosBundleId: 'com.eventikets.app',
  );
}
