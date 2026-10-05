import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable interactive OpenStreetMap view for rendering GPS routes.
class RouteMapView extends StatefulWidget {
  final List<dynamic> points;
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

  void _recenterRoute(LatLngBounds? bounds, LatLng fallbackCenter) {
    if (bounds == null ||
        (bounds.north == bounds.south && bounds.east == bounds.west)) {
      _mapController.move(fallbackCenter, 16.0);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(32.0),
        ),
      );
    }
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

    final latLngs = widget.points.map((p) {
      if (p is LatLng) return p;
      return LatLng(
        (p.latitude as num).toDouble(),
        (p.longitude as num).toDouble(),
      );
    }).toList(growable: false);

    final LatLng centerPoint = latLngs.first;
    final isSinglePoint = latLngs.length == 1;

    final LatLngBounds? rawBounds =
        isSinglePoint ? null : LatLngBounds.fromPoints(latLngs);

    final bool isZeroArea = rawBounds != null &&
        rawBounds.north == rawBounds.south &&
        rawBounds.east == rawBounds.west;

    final LatLngBounds? bounds = isZeroArea ? null : rawBounds;

    final mapContent = ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: bounds != null ? bounds.center : centerPoint,
              initialZoom: bounds != null ? 14.0 : 16.0,
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
                fallbackUrl:
                    'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cadence.cadence',
                maxZoom: 19,
                minZoom: 1,
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
                  // Finish Pin (if multiple distinct points)
                  if (!isSinglePoint && !isZeroArea)
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
          if (widget.interactive && (bounds != null || rawBounds != null || latLngs.length > 1))
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Recenter Trail',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
                onPressed: () => _recenterRoute(bounds, centerPoint),
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
