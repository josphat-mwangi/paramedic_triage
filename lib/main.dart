import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/local/local_data_source.dart';
import 'data/remote/remote_data_source.dart';
import 'data/repository/triage_repository.dart';
import 'data/repository/triage_repository_impl.dart';
import 'state/triage_providers.dart';
import 'sync/connectivity_monitor.dart';
import 'sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Composition root: wire the layers once, at startup. ---
  await Hive.initFlutter();
  final box = await Hive.openBox<String>(HiveLocalDataSource.boxName);

  final local = HiveLocalDataSource(box);
  final remote = MockRemoteDataSource(); // 2s latency, 30% random failure
  final TriageRepository repository =
      TriageRepositoryImpl(local: local, remote: remote);
  final connectivity = ConnectivityPlusMonitor();
  final syncEngine =
      SyncEngine(repository: repository, connectivity: connectivity)..start();

  runApp(
    ProviderScope(
      overrides: [
        triageRepositoryProvider.overrideWithValue(repository),
        syncEngineProvider.overrideWithValue(syncEngine),
      ],
      child: TriageApp(remote: remote),
    ),
  );
}
