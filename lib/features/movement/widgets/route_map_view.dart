import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/database/app_database.dart';

/// Reusable interactive OpenStreetMap view for rendering GPS routes.
class RouteMapView extends StatefulWidget {
  final List<RoutePoint> points;
  final bool interactive;
  final double? height;
  final Color? polylineColor;

  const RouteMapView({
    super.key,
    required this.points,
    this.interactive = true,
    this.height,
    this.polylineColor,
  });

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterRoute(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strokeColor = widget.polylineColor ?? colorScheme.primary;

    if (widget.points.isEmpty) {
      return Container(
        height: widget.height ?? 220,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, color: colorScheme.outline, size: 32),
              const SizedBox(height: 8),
              Text(
                'No GPS coordinates recorded for this route',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final latLngs = widget.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    final isSinglePoint = latLngs.length == 1;
    final LatLngBounds? bounds =
        isSinglePoint ? null : LatLngBounds.fromPoints(latLngs);

    final mapContent = ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: isSinglePoint ? latLngs.first : const LatLng(0, 0),
              initialZoom: isSinglePoint ? 15.0 : 13.0,
              initialCameraFit: bounds != null
                  ? CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(32.0),
                    )
                  : null,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cadence.app',
              ),
              if (latLngs.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngs,
                      strokeWidth: 4.5,
                      color: strokeColor,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Start Pin
                  Marker(
                    point: latLngs.first,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Finish Pin (if multiple points)
                  if (!isSinglePoint)
                    Marker(
                      point: latLngs.last,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Recenter FAB
          if (widget.interactive && bounds != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Recenter Trail',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
                onPressed: () => _recenterRoute(bounds),
                child: const Icon(Icons.center_focus_strong_rounded, size: 20),
              ),
            ),
        ],
      ),
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        child: mapContent,
      );
    }

    return mapContent;
  }
}
