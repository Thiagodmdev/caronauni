import 'package:flutter/material.dart';

import 'app.dart';
import 'data/auth_repository.dart';
import 'data/ride_repository.dart';

void main() {
  runApp(
    CaronaUniApp(
      authRepository: MockAuthRepository(),
      rideRepository: MockRideRepository(),
    ),
  );
}
