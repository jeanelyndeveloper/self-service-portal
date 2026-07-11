import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/widgets/page_content.dart';
import '../widgets/auth_button.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: PageContent(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              child: Column(
                children: [
                  Text(
                    'Choose the option that matches your interviewer status.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.lightText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildSetupHelpCard(context),
                  const SizedBox(height: 28),
                  AuthButton(
                    label: 'New Interviewer',
                    description:
                        'Verify your details and open the setup knowledge guide',
                    icon: Icons.person_add_rounded,
                    onPressed: () => context.go('/new-interviewer'),
                  ),
                  const SizedBox(height: 20),
                  AuthButton(
                    label: 'Existing Interviewer',
                    description: 'Sign in to update iReach or get support',
                    icon: Icons.manage_accounts_rounded,
                    onPressed: () => context.go('/existing-interviewer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupHelpCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.tealSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.tealMuted),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppTheme.tealDark, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'This portal is the self-help path normally handled during a helpdesk setup call: verify identity, confirm your assigned device, get PIN guidance, connect WiFi, open Teams, and start Ipsos apps.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          28, MediaQuery.of(context).padding.top + 28, 28, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.tealDark, Color(0xFF2FAFAF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.26)),
                ),
                child: const Icon(Icons.verified_user_rounded,
                    size: 34, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ipsos Interviewer Hub',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Self Service Portal',
                      style: GoogleFonts.nunito(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Secure interviewer access',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
