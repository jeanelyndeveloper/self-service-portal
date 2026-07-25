import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_service_portal/features/auth/domain/entities/user_entity.dart';
import 'package:self_service_portal/features/auth/presentation/providers/auth_notifier.dart';
import 'package:self_service_portal/features/auth/presentation/providers/auth_state.dart';
import 'package:self_service_portal/features/device/presentation/pages/update_ireach_page.dart';

class _AuthenticatedInterviewerNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: UserEntity(
          id: 'cbg.tests',
          username: 'cbg.tests',
          displayName: 'Test Surveyor',
          type: UserType.existingInterviewer,
          deviceId: 'IPLT569',
          sessionToken: 'test-session',
        ),
      );
}

void main() {
  testWidgets(
    'requires sync and close confirmation before enabling Start Update',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              _AuthenticatedInterviewerNotifier.new,
            ),
          ],
          child: const MaterialApp(home: UpdateIReachPage()),
        ),
      );

      expect(find.text('IPLT569'), findsOneWidget);
      final continueButton = find.text('Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      final syncStep = find.text('Sync I-Reach');
      final closeStep = find.text('Close I-Reach');
      expect(syncStep, findsOneWidget);
      expect(closeStep, findsOneWidget);
      expect(
        tester.getTopLeft(syncStep).dy,
        lessThan(tester.getTopLeft(closeStep).dy),
      );

      final startButtonFinder = find.ancestor(
        of: find.text('Start Update'),
        matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
      );
      ElevatedButton startButton() =>
          tester.widget<ElevatedButton>(startButtonFinder);

      expect(startButton().onPressed, isNull);

      final confirmationCheckbox = find.byType(Checkbox);
      await tester.ensureVisible(confirmationCheckbox);
      await tester.tap(confirmationCheckbox);
      await tester.pump();

      expect(startButton().onPressed, isNotNull);
    },
  );
}
