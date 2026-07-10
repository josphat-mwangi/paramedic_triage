import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/remote/remote_data_source.dart';
import 'state/triage_providers.dart';
import 'ui/records_list_screen.dart';
import 'ui/triage_form_screen.dart';

class TriageApp extends StatelessWidget {
  final RemoteDataSource remote; // exposed only so the demo can flip forceFailure
  const TriageApp({super.key, required this.remote});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paramedic Triage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFB00020),
        useMaterial3: true,
      ),
      home: HomeShell(remote: remote),
    );
  }
}

/// Hosts the lifecycle observer so a resume opportunistically drains the queue.
class HomeShell extends ConsumerStatefulWidget {
  final RemoteDataSource remote;
  const HomeShell({super.key, required this.remote});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mock = widget.remote;
    final forceFailure = mock is MockRemoteDataSource && mock.forceFailure;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramedic Triage'),
        actions: [
          if (mock is MockRemoteDataSource)
            Row(
              children: [
                const Text('Force fail', style: TextStyle(fontSize: 12)),
                Switch(
                  value: forceFailure,
                  onChanged: (v) => setState(() => mock.forceFailure = v),
                ),
              ],
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [TriageFormScreen(), RecordsListScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.add_box_outlined), label: 'Intake'),
          NavigationDestination(
              icon: Icon(Icons.list_alt), label: 'Queue'),
        ],
      ),
    );
  }
}
