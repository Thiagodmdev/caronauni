import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';

class RideMap extends StatelessWidget {
  const RideMap({super.key, required this.origin, required this.destination});

  final GeoPoint origin;
  final GeoPoint destination;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final from = LatLng(origin.lat, origin.lng);
    final to = LatLng(destination.lat, destination.lng);
    Marker marker(LatLng point, IconData icon) => Marker(
      point: point,
      child: Icon(icon, color: color, size: 30),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [from, to],
              padding: const EdgeInsets.all(40),
              maxZoom: 15,
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.caronauni.caronauni',
            ),
            MarkerLayer(
              markers: [
                marker(from, Icons.radio_button_checked),
                marker(to, Icons.location_on),
              ],
            ),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
      ),
    );
  }
}
