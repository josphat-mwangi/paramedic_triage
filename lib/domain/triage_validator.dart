/// Pure, framework-free validation so it can be unit-tested without a widget.
class TriageValidationResult {
  final String? patientName;
  final String? conditionDescription;
  final String? priority;

  const TriageValidationResult({
    this.patientName,
    this.conditionDescription,
    this.priority,
  });

  bool get isValid =>
      patientName == null && conditionDescription == null && priority == null;
}

class TriageValidator {
  static TriageValidationResult validate({
    required String patientName,
    required String conditionDescription,
    required int? priority,
  }) {
    return TriageValidationResult(
      patientName:
          patientName.trim().isEmpty ? 'Patient name is required' : null,
      conditionDescription: conditionDescription.trim().isEmpty
          ? 'Condition description is required'
          : null,
      priority: (priority == null || priority < 1 || priority > 5)
          ? 'Select a priority (1–5)'
          : null,
    );
  }
}
