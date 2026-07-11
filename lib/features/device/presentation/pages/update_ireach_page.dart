import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_dialog.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/device_notifier.dart';

class UpdateIReachPage extends ConsumerStatefulWidget {
  const UpdateIReachPage({super.key});

  @override
  ConsumerState<UpdateIReachPage> createState() => _UpdateIReachPageState();
}

class _UpdateIReachPageState extends ConsumerState<UpdateIReachPage> {
  bool _iReachClosed = false;

  @override
  void dispose() {
    ref.read(deviceNotifierProvider.notifier).reset();
    super.dispose();
  }

  void _confirmDeviceId() {
    final deviceId = ref.read(authNotifierProvider).user?.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      _showMissingDeviceIdMessage();
      return;
    }

    ref
        .read(deviceNotifierProvider.notifier)
        .confirmAssignedDevice(deviceId.trim());
  }

  Future<void> _executeUpdate() async {
    final deviceId = ref.read(authNotifierProvider).user?.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      _showMissingDeviceIdMessage();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Initiating update...'),
    );

    final success = await ref
        .read(deviceNotifierProvider.notifier)
        .executeIReachUpdate(deviceId.trim());

    if (mounted) {
      Navigator.of(context).pop();
      if (!success) {
        final error = ref.read(deviceNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Update failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceNotifierProvider);
    final user = ref.watch(authNotifierProvider).user;
    final deviceId = user?.deviceId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update iReach'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(deviceNotifierProvider.notifier).reset();
            context.go('/existing-interviewer-dashboard');
          },
        ),
      ),
      body: PageContent(
        maxWidth: 760,
        child: deviceState.updateStarted
            ? _buildUpdateSuccess(context,
                deviceState.updateMessage ?? 'Update started successfully')
            : deviceState.isValidated
                ? _buildUpdatePrompt(context)
                : _buildDeviceConfirmation(
                    context, user?.displayName, deviceId),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupportSheet(context),
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Help'),
      ),
    );
  }

  Widget _buildDeviceConfirmation(
    BuildContext context,
    String? displayName,
    String? deviceId,
  ) {
    final hasDeviceId = deviceId != null && deviceId.trim().isNotEmpty;

    return Column(
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
                    Icon(Icons.system_update,
                        size: 36, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(
                            displayName == null || displayName.trim().isEmpty
                                ? 'Update iReach Application'
                                : 'Welcome, ${displayName.trim()}',
                            style: Theme.of(context).textTheme.headlineSmall)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  hasDeviceId
                      ? 'Please confirm that your device ID is ${deviceId.trim()}. If this is correct, please click continue. Otherwise, contact help desk for assistance.'
                      : 'Your interviewer record does not include a device ID. Please contact help desk for assistance.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned Device ID',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.devices_rounded, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        hasDeviceId ? deviceId.trim() : 'No device ID found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  hasDeviceId
                      ? 'This device ID was pulled from your interviewer profile.'
                      : 'The update cannot continue until a device ID is available.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (hasDeviceId) ...[
          ElevatedButton.icon(
            onPressed: _confirmDeviceId,
            icon: const Icon(Icons.check_circle_outline, size: 24),
            label: const Text('Continue'),
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: () => context.go('/existing-interviewer-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          label: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildUpdatePrompt(BuildContext context) {
    final device = ref.watch(deviceNotifierProvider).device;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUpdateProgress(context, 2),
        const SizedBox(height: 24),
        if (device != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF2E9D5C)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Confirmed device ID: ${device.deviceId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 36, color: Colors.orange.shade700),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Important: Sync and Close iReach First',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Before the update starts, sync iReach so your saved work is sent to the server, then close the application completely.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow These Steps:',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildStep(
                  context,
                  'Please sync I-Reach. This pushes local work to the server.',
                ),
                _buildStep(
                  context,
                  'Close I-Reach before you proceed with the update.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        CheckboxListTile(
          value: _iReachClosed,
          onChanged: (value) => setState(() => _iReachClosed = value ?? false),
          title: Text(
              'I have synced and closed I-Reach and am ready for update.',
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('Confirm you are ready for the update to start',
              style: Theme.of(context).textTheme.bodyMedium),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _iReachClosed ? _executeUpdate : null,
          icon: const Icon(Icons.play_arrow, size: 24),
          label: const Text('Start Update'),
        ),
      ],
    );
  }

  Widget _buildUpdateSuccess(BuildContext context, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUpdateProgress(context, 3),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green.shade600, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Update Started Successfully',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.green.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(message,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200, width: 2),
                  ),
                  child: Text(
                    'Estimated time: 5-10 minutes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 32, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'What to Expect Next',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildStep(
                    context, 'The remote management script has been requested'),
                _buildStep(context, 'Please keep your device powered on'),
                _buildStep(
                    context, 'Your device may restart during the process'),
                _buildStep(
                    context, 'iReach will reopen automatically when complete'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(deviceNotifierProvider.notifier).reset();
            context.go('/existing-interviewer-dashboard');
          },
          icon: const Icon(Icons.home, size: 24),
          label: const Text('Return to Dashboard'),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.check, size: 20, color: Colors.green.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateProgress(BuildContext context, int currentStep) {
    const steps = [
      'Confirm device',
      'Close iReach',
      'Run update',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: i < currentStep
                          ? const Color(0xFF2E9D5C)
                          : Colors.grey.shade200,
                      child: Icon(
                        i < currentStep
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        color: i < currentStep
                            ? Colors.white
                            : Colors.grey.shade500,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[i],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i < currentStep
                                ? const Color(0xFF244646)
                                : Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              if (i != steps.length - 1)
                Container(
                  width: 28,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 28),
                  color: i + 1 < currentStep
                      ? const Color(0xFF2E9D5C)
                      : Colors.grey.shade200,
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Need help?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.chat_bubble_outline_rounded),
                title: Text('Chat with helpdesk'),
                subtitle: Text('Connect the production chat widget here'),
              ),
              const ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('helpdesk@ipsos.com'),
              ),
              const ListTile(
                leading: Icon(Icons.phone_outlined),
                title: Text('1-800-IPSOS-HELP'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMissingDeviceIdMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No device ID was found on your user record. Please contact Helpdesk for assistance.',
        ),
      ),
    );
  }
}
