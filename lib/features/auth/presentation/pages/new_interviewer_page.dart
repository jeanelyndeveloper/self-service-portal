import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/loading_dialog.dart';
import '../../../../core/widgets/page_content.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_notifier.dart';

class NewInterviewerPage extends ConsumerStatefulWidget {
  const NewInterviewerPage({super.key});

  @override
  ConsumerState<NewInterviewerPage> createState() => _NewInterviewerPageState();
}

class _NewInterviewerPageState extends ConsumerState<NewInterviewerPage> {
  final _emailController = TextEditingController();
  final _lastFourController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _lastFourController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Verifying details...'),
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .authenticateNewInterviewer(
          _emailController.text.trim(),
          _lastFourController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
    if (!success) {
      final error = ref.read(authNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Verification failed')),
      );
    }
  }

  void _returnToStart() {
    ref.read(authNotifierProvider.notifier).logout();
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final isVerifiedNewInterviewer = user?.type == UserType.newInterviewer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Interviewer Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToStart,
        ),
      ),
      body: PageContent(
        maxWidth: 820,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? 24 : 40,
          vertical: 28,
        ),
        child: isVerifiedNewInterviewer
            ? _buildSetupGuide(context, user!)
            : _buildVerificationForm(context),
      ),
    );
  }

  Widget _buildVerificationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 36,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Verify your identity',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter the email address registered with Ipsos and the last 4 digits of your mobile number. We will use this to find your assigned device and setup details.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'name@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Email address is required';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _lastFourController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: 'Last 4 digits of mobile number',
              hintText: '2235',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              counterText: '',
            ),
            onFieldSubmitted: (_) => _verify(),
            validator: (value) {
              final digits = value?.trim() ?? '';
              if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
                return 'Enter exactly 4 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _verify,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Verify Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupGuide(BuildContext context, UserEntity user) {
    final firstName = user.displayName.trim().split(RegExp(r'\s+')).first;
    final deviceType = _displayDeviceType(user.deviceType);
    final instructions = _instructionsFor(user.deviceType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your details have been verified. Follow the setup steps for your assigned device.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildDeviceSummary(context, user, deviceType),
        const SizedBox(height: 20),
        if (user.devicePin != null && user.devicePin!.trim().isNotEmpty) ...[
          _buildPinCard(context, user.devicePin!.trim()),
          const SizedBox(height: 20),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$deviceType setup',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                for (final instruction in instructions)
                  _buildSetupStep(context, instruction),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/knowledge-base'),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Knowledge Base'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.go('/support-ticket'),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Create Ticket'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceSummary(
    BuildContext context,
    UserEntity user,
    String deviceType,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned device',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            _buildDetailRow(
              context,
              Icons.devices_rounded,
              'Device',
              user.deviceId ?? 'Not available',
            ),
            _buildDetailRow(
              context,
              Icons.laptop_mac_rounded,
              'Type',
              deviceType,
            ),
            _buildDetailRow(
              context,
              Icons.work_outline_rounded,
              'Project',
              user.project ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinCard(BuildContext context, String pin) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.tealDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your device PIN is $pin',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 14),
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupStep(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.tealSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.tealMuted),
            ),
            child: const Icon(Icons.check_rounded,
                size: 20, color: AppTheme.tealDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }

  String _displayDeviceType(String? rawType) {
    final type = rawType?.trim();
    if (type == null || type.isEmpty) {
      return 'Assigned device';
    }
    if (type.toLowerCase().contains('android')) {
      return 'Android tablet';
    }
    if (type.toLowerCase().contains('win') ||
        type.toLowerCase().contains('laptop')) {
      return 'Windows laptop';
    }
    return type;
  }

  List<String> _instructionsFor(String? rawType) {
    final type = rawType?.toLowerCase() ?? '';
    if (type.contains('android')) {
      return const [
        'Power on the Android tablet.',
        'Connect to WiFi using your local network details.',
        'Unlock the tablet with the assigned PIN shown above.',
        'Open I-Reach and complete first-time setup.',
        'Sync before starting any live interviewer work.',
      ];
    }

    return const [
      'Turn on the laptop and wait for the Windows login screen.',
      'Use the assigned PIN shown above to log in.',
      'Connect the laptop to WiFi.',
      'Launch I-Reach from the desktop or Start menu.',
      'Complete the first sync before starting interviewer work.',
    ];
  }
}
