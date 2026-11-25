import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Identificadores públicos do projeto; o acesso aos dados é protegido pelas
/// regras em firestore.rules.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? _android : _web;

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'AIzaSyArHt23zKWOBsgQt4BZfk-o8VXLFl5vmxQ',
    projectId: 'caronauni',
    storageBucket: 'caronauni.firebasestorage.app',
    messagingSenderId: '1047321195973',
    appId: '1:1047321195973:android:b3e9133500a4f6cf1f87ac',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'AIzaSyArHt23zKWOBsgQt4BZfk-o8VXLFl5vmxQ',
    authDomain: 'caronauni.firebaseapp.com',
    projectId: 'caronauni',
    storageBucket: 'caronauni.firebasestorage.app',
    messagingSenderId: '1047321195973',
    appId: '1:1047321195973:web:6decd979140a45711f87ac',
  );
}
