import 'package:flutter_test/flutter_test.dart';
import 'package:paramedic_triage/domain/triage_validator.dart';

void main() {
  group('TriageValidator', () {
    test('rejects blank patient name', () {
      final r = TriageValidator.validate(
          patientName: '  ', conditionDescription: 'chest pain', priority: 1);
      expect(r.patientName, isNotNull);
      expect(r.isValid, isFalse);
    });

    test('rejects blank condition', () {
      final r = TriageValidator.validate(
          patientName: 'Jane', conditionDescription: '', priority: 1);
      expect(r.conditionDescription, isNotNull);
    });

    test('rejects missing priority', () {
      final r = TriageValidator.validate(
          patientName: 'Jane',
          conditionDescription: 'fracture',
          priority: null);
      expect(r.priority, isNotNull);
    });

    test('rejects out-of-range priority', () {
      expect(
        TriageValidator.validate(
                patientName: 'Jane',
                conditionDescription: 'x',
                priority: 6)
            .priority,
        isNotNull,
      );
    });

    test('accepts a complete valid record', () {
      final r = TriageValidator.validate(
          patientName: 'Jane Doe',
          conditionDescription: 'severe bleeding',
          priority: 1);
      expect(r.isValid, isTrue);
    });
  });
}
