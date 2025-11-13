import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:mobidata_bw_flutter/services/gtfs_database_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = GtfsDatabaseService.instance;
  await service.init(useBundledSeed: false, allowDownload: true);

  final sourcePath = service.databasePath;
  if (sourcePath == null || !await File(sourcePath).exists()) {
    throw Exception('GTFS-Datenbank konnte nicht erzeugt werden.');
  }

  final outDir = Directory(p.join(Directory.current.path, 'assets', 'gtfs'));
  await outDir.create(recursive: true);
  final outputPath = p.join(outDir.path, 'gtfs_seed.sqlite');
  await File(sourcePath).copy(outputPath);

  // ignore: avoid_print
  print('GTFS seed database written to $outputPath');
}
