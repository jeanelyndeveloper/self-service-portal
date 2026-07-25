import 'package:flutter_test/flutter_test.dart';
import 'package:self_service_portal/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('maps the real SMS Users profile field names', () {
      final model = UserModel.fromJson({
        'surveyor': 'cbg.tests',
        'surveyorName': 'Test Interviewer',
        'computerNumber': 'IPLT569',
        'email': 'interviewer@example.test',
        'sessionToken': 'test-session',
      });

      expect(model.id, 'cbg.tests');
      expect(model.username, 'cbg.tests');
      expect(model.displayName, 'Test Interviewer');
      expect(model.deviceId, 'IPLT569');
      expect(model.email, 'interviewer@example.test');
      expect(model.sessionToken, 'test-session');
      expect(model.toEntity().sessionToken, 'test-session');
    });

    test('maps a computerName alias when supplied by a backend', () {
      final model = UserModel.fromJson({
        'id': '123',
        'username': 'interviewer',
        'computerName': 'IPLT671',
      });

      expect(model.deviceId, 'IPLT671');
    });
  });
}
