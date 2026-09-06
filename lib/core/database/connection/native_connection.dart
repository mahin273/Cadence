import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Opens a persistent SQLite connection stored in the device's application documents directory.
LazyDatabase openConnection({String dbName = 'cadence.sqlite'}) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, dbName));
    return NativeDatabase.createInBackground(file);
  });
}

/// Creates an in-memory SQLite connection for tests and ephemeral runs.
QueryExecutor openInMemoryConnection() {
  return NativeDatabase.memory();
}
