import 'package:firebase_core/firebase_core.dart';

/// Identificadores públicos do projeto; o acesso aos dados é protegido pelas
/// regras em firestore.rules.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyArHt23zKWOBsgQt4BZfk-o8VXLFl5vmxQ',
    authDomain: 'caronauni.firebaseapp.com',
    projectId: 'caronauni',
    storageBucket: 'caronauni.firebasestorage.app',
    messagingSenderId: '1047321195973',
    appId: '1:1047321195973:web:6decd979140a45711f87ac',
  );
}
