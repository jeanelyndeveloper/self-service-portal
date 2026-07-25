import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/auth/presentation/pages/new_interviewer_page.dart';
import '../features/auth/presentation/pages/existing_interviewer_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/device/presentation/pages/device_setup_page.dart';
import '../features/device/presentation/pages/update_ireach_page.dart';
import '../features/support/presentation/pages/knowledge_base_page.dart';
import '../features/support/presentation/pages/support_ticket_page.dart';

abstract final class AppRouter {
  static final config = GoRouter(
    initialLocation: '/',
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AuthPage()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
      GoRoute(
          path: '/new-interviewer',
          builder: (_, __) => const NewInterviewerPage()),
      GoRoute(
          path: '/existing-interviewer',
          builder: (_, __) => const ExistingInterviewerPage()),
      GoRoute(
          path: '/existing-interviewer-dashboard',
          builder: (_, __) => const DashboardPage()),
      GoRoute(
          path: '/device-setup', builder: (_, __) => const DeviceSetupPage()),
      GoRoute(
          path: '/update-ireach', builder: (_, __) => const UpdateIReachPage()),
      GoRoute(
          path: '/knowledge-base',
          builder: (_, __) => const KnowledgeBasePage()),
      GoRoute(
          path: '/support-ticket',
          builder: (_, __) => const SupportTicketPage()),
    ],
    errorBuilder: (_, __) => const AuthPage(),
  );
}
