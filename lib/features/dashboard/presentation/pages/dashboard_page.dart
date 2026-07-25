import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../app/theme.dart';
import '../../../../core/widgets/page_content.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 26),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
              context.go('/auth');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageContent(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeCard(context, authState.user?.displayName),
            const SizedBox(height: 36),
            Text(
              'What would you like to do?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _buildActionCard(
              context,
              title: 'Update I-Reach',
              description: 'Confirm your device and run the update checklist',
              icon: Icons.system_update_alt_rounded,
              onTap: () => context.go('/update-ireach'),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'Knowledge Base',
              description: 'Guides for sync, updates, and connectivity',
              icon: Icons.menu_book_rounded,
              onTap: () => context.go('/knowledge-base'),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'Create Support Ticket',
              description: 'Send a Help Desk request with your details',
              icon: Icons.support_agent_rounded,
              onTap: () => context.go('/support-ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, String? displayName) {
    final surveyorName = displayName?.trim();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.tealDark, AppTheme.primaryTeal],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sentiment_satisfied_alt_rounded,
                size: 36, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surveyorName == null || surveyorName.isEmpty
                      ? 'Welcome back'
                      : 'Welcome back,\n$surveyorName',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to continue?',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: isEnabled ? Colors.white : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.tealMuted, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color:
                      isEnabled ? AppTheme.primaryTeal : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isEnabled ? null : Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(description,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isEnabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_clock_rounded,
                size: 20,
                color: isEnabled ? AppTheme.tealLight : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
