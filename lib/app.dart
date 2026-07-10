import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/remote/remote_data_source.dart';
import 'state/triage_providers.dart';
import 'ui/records_list_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/triage_form_screen.dart';

class TriageApp extends StatelessWidget {
  final RemoteDataSource remote; // exposed only so the debug menu can flip forceFailure
  const TriageApp({super.key, required this.remote});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paramedic Triage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const _CalmScrollBehavior(),
      home: HomeShell(remote: remote),
    );
  }
}

/// Swaps the rubbery iOS-style bounce and Android stretch overscroll for a
/// firm clamp — a paramedic tapping through a form under stress shouldn't
/// feel the screen wobble past its limits.
class _CalmScrollBehavior extends MaterialScrollBehavior {
  const _CalmScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
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

  void _openDeveloperOptions(MockRemoteDataSource mock) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Developer options',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Debug-only. Forces every simulated upload to fail so you can '
                'watch the retry/backoff queue in action.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Force uploads to fail'),
                value: mock.forceFailure,
                onChanged: (v) => setSheetState(() {
                  setState(() => mock.forceFailure = v);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mock = widget.remote;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramedic Triage'),
        actions: [
          // Debug-only escape hatch to demo the retry/backoff path — never
          // shown in a release build, and tucked behind an icon rather than a
          // switch sitting in the primary chrome.
          if (kDebugMode && mock is MockRemoteDataSource)
            IconButton(
              tooltip: 'Developer options',
              icon: Icon(
                Icons.bug_report_outlined,
                color: mock.forceFailure
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              onPressed: () => _openDeveloperOptions(mock),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [TriageFormScreen(), RecordsListScreen()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.hairline)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box),
              label: 'Intake',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Queue',
            ),
          ],
        ),
      ),
    );
  }
}
