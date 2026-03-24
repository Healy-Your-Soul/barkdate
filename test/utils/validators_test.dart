import 'package:flutter_test/flutter_test.dart';
import 'package:barkdate/utils/validators.dart';

void main() {
  group('Validators - validateEmail', () {
    test('returns null for valid emails', () {
      expect(Validators.validateEmail('test@example.com'), isNull);
      expect(Validators.validateEmail('test+1@example.com'), isNull);
      expect(Validators.validateEmail('user.name@domain.co'), isNull);
      expect(Validators.validateEmail('abc_123@xyz.org'), isNull);
      expect(Validators.validateEmail('test+@example.com'), isNull);
    });

    test('returns error for empty or null email', () {
      expect(Validators.validateEmail(null), 'Please enter your email');
      expect(Validators.validateEmail(''), 'Please enter your email');
    });

    test('returns error for invalid emails', () {
      expect(Validators.validateEmail('test@'), 'Please enter a valid email');
      expect(Validators.validateEmail('@example.com'),
          'Please enter a valid email');
      expect(Validators.validateEmail('test@example'),
          'Please enter a valid email');
      expect(Validators.validateEmail('test.example.com'),
          'Please enter a valid email');
    });
  });
}
