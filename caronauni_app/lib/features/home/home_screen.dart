import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/ride_repository.dart';
import '../auth/session_controller.dart';
import '../my_rides/my_rides_screen.dart';
import '../notices/notices_screen.dart';
import '../offer/offer_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().user!;
    context.read<RideRepository>().refreshRecurrences(user).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    // Cada aba é recriada ao abrir, para mostrar dados atualizados.
    final page = switch (_index) {
      0 => const SearchScreen(),
      1 => const MyRidesScreen(),
      2 => OfferScreen(onCreated: () => setState(() => _index = 1)),
      3 => const NoticesScreen(),
      _ => const ProfileScreen(),
    };
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            label: 'Caronas',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Oferecer',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Avisos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
