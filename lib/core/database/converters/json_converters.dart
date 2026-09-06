import 'dart:convert';
import 'package:drift/drift.dart';

/// Converts between a Dart [List<String>] and a JSON-encoded [String] in SQLite.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      final decoded = json.decode(fromDb);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

/// Converts between a Dart [Map<String, dynamic>] and a JSON-encoded [String] in SQLite.
class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      final decoded = json.decode(fromDb);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return json.encode(value);
  }
}
