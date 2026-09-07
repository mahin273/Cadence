import '../../../core/database/app_database.dart';

/// Spatial geometry serialization utilities for PostGIS and GeoJSON standards.
class GeoSerializer {
  /// Convert a sequence of route breadcrumbs to a GeoJSON Geometry map.
  ///
  /// Strictly follows OGC standards: Longitude is index 0, Latitude is index 1.
  /// - Empty list returns null.
  /// - Single coordinate returns a GeoJSON `Point`.
  /// - Multiple coordinates returns a GeoJSON `LineString`.
  static Map<String, dynamic>? toGeoJsonGeometry(List<RoutePoint> points) {
    if (points.isEmpty) return null;

    if (points.length == 1) {
      final p = points.first;
      return {
        'type': 'Point',
        'coordinates': [p.longitude, p.latitude],
      };
    }

    final coordinates = points
        .map((p) => [p.longitude, p.latitude])
        .toList(growable: false);

    return {
      'type': 'LineString',
      'coordinates': coordinates,
    };
  }

  /// Convert a sequence of route breadcrumbs to OGC Well-Known Text (WKT).
  ///
  /// Examples:
  /// - `POINT(-122.4194 37.7749)`
  /// - `LINESTRING(-122.4194 37.7749, -122.4180 37.7755)`
  static String? toWktGeometry(List<RoutePoint> points) {
    if (points.isEmpty) return null;

    if (points.length == 1) {
      final p = points.first;
      return 'POINT(${p.longitude} ${p.latitude})';
    }

    final coordsStr =
        points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    return 'LINESTRING($coordsStr)';
  }

  /// Convert to Extended Well-Known Text (EWKT) including spatial reference ID (SRID).
  ///
  /// Standard GPS uses WGS 84 (SRID 4326).
  /// Example: `SRID=4326;LINESTRING(-122.4194 37.7749, -122.4180 37.7755)`
  static String? toEwktGeometry(List<RoutePoint> points, {int srid = 4326}) {
    final wkt = toWktGeometry(points);
    if (wkt == null) return null;
    return 'SRID=$srid;$wkt';
  }
}
