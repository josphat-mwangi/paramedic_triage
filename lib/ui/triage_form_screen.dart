import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/triage_record.dart';
import '../domain/triage_validator.dart';
import '../state/triage_providers.dart';
import 'widgets/priority_selector.dart';

class TriageFormScreen extends ConsumerStatefulWidget {
  const TriageFormScreen({super.key});

  @override
  ConsumerState<TriageFormScreen> createState() => _TriageFormScreenState();
}

class _TriageFormScreenState extends ConsumerState<TriageFormScreen> {
  final _nameCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  int? _priority;
  TriageStatus _status = TriageStatus.pending;
  TriageValidationResult _errors = const TriageValidationResult();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = TriageValidator.validate(
      patientName: _nameCtrl.text,
      conditionDescription: _conditionCtrl.text,
      priority: _priority,
    );
    setState(() => _errors = result);
    if (!result.isValid) return;

    await ref.read(triageNotifierProvider.notifier).submit(
          patientName: _nameCtrl.text,
          conditionDescription: _conditionCtrl.text,
          priority: _priority!,
          status: _status,
        );

    if (!mounted) return;
    _nameCtrl.clear();
    _conditionCtrl.clear();
    setState(() {
      _priority = null;
      _status = TriageStatus.pending;
      _errors = const TriageValidationResult();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved locally · will sync when online'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Patient name',
              border: const OutlineInputBorder(),
              errorText: _errors.patientName,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conditionCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Condition description',
              border: const OutlineInputBorder(),
              errorText: _errors.conditionDescription,
            ),
          ),
          const SizedBox(height: 20),
          PrioritySelector(
            selected: _priority,
            onChanged: (p) => setState(() => _priority = p),
            errorText: _errors.priority,
          ),
          const SizedBox(height: 20),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<TriageStatus>(
            segments: const [
              ButtonSegment(
                  value: TriageStatus.pending, label: Text('Pending')),
              ButtonSegment(
                  value: TriageStatus.inTransit, label: Text('In-Transit')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Submit triage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
