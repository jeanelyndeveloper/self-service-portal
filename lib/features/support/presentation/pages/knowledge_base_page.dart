import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/page_content.dart';

class KnowledgeBasePage extends StatelessWidget {
  const KnowledgeBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/existing-interviewer-dashboard'),
        ),
      ),
      body: PageContent(
        maxWidth: 760,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Common Guides',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const _GuideCard(
              icon: Icons.sync_rounded,
              title: 'How to sync I-Reach',
              steps: [
                'Open I-Reach on your device.',
                'Select the sync option from the application.',
                'Wait until the sync is complete before closing I-Reach.',
                'Return to the portal when your local work has been sent to the server.',
              ],
            ),
            const SizedBox(height: 16),
            const _GuideCard(
              icon: Icons.system_update_alt_rounded,
              title: 'Before updating I-Reach',
              steps: [
                'Sync I-Reach first.',
                'Close I-Reach before you proceed with the update.',
                'Keep your laptop powered on while the update runs.',
              ],
            ),
            const SizedBox(height: 16),
            const _GuideCard(
              icon: Icons.wifi_rounded,
              title: 'Basic connection checks',
              steps: [
                'Confirm your device is connected to WiFi.',
                'Open Microsoft Teams if you need help desk support.',
                'Contact Help Desk if you cannot complete sync or login.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: Theme.of(context).primaryColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
