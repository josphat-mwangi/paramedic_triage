import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paramedic_triage/app.dart';
import 'package:paramedic_triage/data/local/local_data_source.dart';
import 'package:paramedic_triage/data/remote/remote_data_source.dart';
import 'package:paramedic_triage/data/repository/triage_repository_impl.dart';
import 'package:paramedic_triage/domain/triage_record.dart';
import 'package:paramedic_triage/state/triage_providers.dart';
import 'package:paramedic_triage/sync/connectivity_monitor.dart';
import 'package:paramedic_triage/sync/sync_engine.dart';

/// In-memory outbox so the widget test never touches Hive.
class _InMemoryLocalDataSource implements LocalDataSource {
  final _store = <String, TriageRecord>{};

  @override
  Future<void> upsert(TriageRecord record) async => _store[record.id] = record;

  @override
  Future<TriageRecord?> getById(String id) async => _store[id];

  @override
  Future<List<TriageRecord>> getAll() async => _store.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

class _FakeConnectivity implements ConnectivityMonitor {
  bool online;
  _FakeConnectivity(this.online);

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<void> get onOnline => const Stream.empty();
}

void main() {
  Future<void> pumpApp(WidgetTester tester, {required bool online}) async {
    final repository = TriageRepositoryImpl(
      local: _InMemoryLocalDataSource(),
      remote: MockRemoteDataSource(latency: Duration.zero, failureRate: 0),
    );
    final engine = SyncEngine(
      repository: repository,
      connectivity: _FakeConnectivity(online),
    );
    addTearDown(() {
      engine.dispose();
      repository.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          triageRepositoryProvider.overrideWithValue(repository),
          syncEngineProvider.overrideWithValue(engine),
        ],
        child: TriageApp(remote: MockRemoteDataSource()),
      ),
    );
  }

  testWidgets('intake form renders the required fields', (tester) async {
    await pumpApp(tester, online: true);

    expect(find.text('New triage record'), findsOneWidget);
    expect(find.text('Priority level'), findsOneWidget);
    expect(find.text('Submit triage'), findsOneWidget);
  });

  testWidgets('submitting a blank form surfaces validation, not a crash',
      (tester) async {
    await pumpApp(tester, online: true);

    await tester.ensureVisible(find.text('Submit triage'));
    await tester.tap(find.text('Submit triage'));
    await tester.pump();

    expect(find.text('Patient name is required'), findsOneWidget);
    expect(find.text('Condition description is required'), findsOneWidget);
    expect(find.text('Select a priority (1–5)'), findsOneWidget);
  });

  testWidgets('a valid submission while online confirms success and syncing',
      (tester) async {
    await pumpApp(tester, online: true);

    await tester.enterText(find.byType(TextField).first, 'Jane Doe');
    await tester.enterText(find.byType(TextField).last, 'Chest pain');
    await tester.tap(find.byKey(const ValueKey('priority-chip-1')));
    await tester.ensureVisible(find.text('Submit triage'));
    await tester.tap(find.text('Submit triage'));
    // Elapse past the background sync's zero-latency Future.delayed so it
    // settles inside this test's fake-async zone instead of leaking a timer.
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Triage record saved'), findsOneWidget);
    expect(find.text('Syncing to the server now.'), findsOneWidget);
  });

  testWidgets('a valid submission while offline reassures rather than alarms',
      (tester) async {
    await pumpApp(tester, online: false);

    await tester.enterText(find.byType(TextField).first, 'Jane Doe');
    await tester.enterText(find.byType(TextField).last, 'Chest pain');
    await tester.tap(find.byKey(const ValueKey('priority-chip-1')));
    await tester.ensureVisible(find.text('Submit triage'));
    await tester.tap(find.text('Submit triage'));
    // Elapse past the background sync's zero-latency Future.delayed so it
    // settles inside this test's fake-async zone instead of leaking a timer.
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Triage record saved'), findsOneWidget);
    expect(find.textContaining("It'll sync automatically"), findsOneWidget);
  });
}
