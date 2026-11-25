import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/auth_repository.dart';
import 'data/demo_data.dart';
import 'data/document_store.dart';
import 'data/firebase_auth_repository.dart';
import 'data/firestore_store.dart';
import 'data/ride_repository.dart';
import 'firebase_options.dart';

/// `flutter run --dart-define=DEMO=true` usa dados de exemplo, sem Firebase.
const bool isDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(isDemo ? await _demoApp() : await _firebaseApp());
}

Future<Widget> _demoApp() async {
  final store = MemoryStore();
  await seedDemo(store, DateTime.now());
  return CaronaUniApp(
    authRepository: MockAuthRepository(store),
    rideRepository: RideRepository(store),
  );
}

Future<Widget> _firebaseApp() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;
  // Mantém as caronas já carregadas visíveis sem internet (RNF04).
  db.settings = const Settings(persistenceEnabled: true);
  final store = FirestoreStore(db);
  return CaronaUniApp(
    authRepository: FirebaseAuthRepository(FirebaseAuth.instance, store),
    rideRepository: RideRepository(store),
  );
}
