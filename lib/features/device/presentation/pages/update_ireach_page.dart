import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/device_notifier.dart';

class UpdateIReachPage extends ConsumerStatefulWidget {
  const UpdateIReachPage({super.key});

  @override
  ConsumerState<UpdateIReachPage> createState() => _UpdateIReachPageState();
}

class _UpdateIReachPageState extends ConsumerState<UpdateIReachPage> {
  bool _iReachSynced = false;
  bool _iReachClosed = false;
  late final DeviceNotifier _deviceNotifier;

  @override
  void initState() {
    super.initState();
    _deviceNotifier = ref.read(deviceNotifierProvider.notifier);
  }

  @override
  void dispose() {
    _deviceNotifier.reset();
    super.dispose();
  }

  void _confirmComputerName() {
    final deviceId = ref.read(authNotifierProvider).user?.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      _showMissingComputerNameMessage();
      return;
    }

    ref
        .read(deviceNotifierProvider.notifier)
        .confirmAssignedDevice(deviceId.trim());
  }

  Future<void> _confirmSyncCompleted(bool? value) async {
    if (value != true) {
      setState(() => _iReachSynced = false);
      return;
    }

    final confirmed = await _showSafetyDialog(
      title: 'Confirm I-Reach Sync',
      icon: Icons.sync_problem_rounded,
      iconColor: const Color(0xFFB26A00),
      message:
          'I-Reach stores work offline. Starting the update before syncing may cause unsaved interviewer work on this device to be lost.',
      checklist: const [
        'I opened I-Reach.',
        'I clicked Sync.',
        'I waited until synchronization completed.',
      ],
      confirmLabel: 'Yes, Sync Completed',
    );

    if (mounted) {
      setState(() => _iReachSynced = confirmed);
    }
  }

  Future<void> _confirmIReachClosed(bool? value) async {
    if (value != true) {
      setState(() => _iReachClosed = false);
      return;
    }

    final confirmed = await _showSafetyDialog(
      title: 'Confirm I-Reach Is Closed',
      icon: Icons.close_fullscreen_rounded,
      iconColor: AppTheme.tealDark,
      message:
          'The updater cannot safely run while I-Reach is open. Please close the app completely before continuing.',
      checklist: const [
        'I saved or completed anything still open.',
        'I closed I-Reach completely.',
        'I returned to this portal after closing it.',
      ],
      confirmLabel: 'Yes, I-Reach Is Closed',
    );

    if (mounted) {
      setState(() => _iReachClosed = confirmed);
    }
  }

  Future<void> _startUpdateWithConfirmation() async {
    if (!_iReachSynced || !_iReachClosed) {
      await _showSafetyDialog(
        title: 'Confirmation Required',
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFB26A00),
        message:
            'Please confirm that I-Reach has been synchronized and closed before starting the update.',
        checklist: const [
          'Sync I-Reach first.',
          'Close I-Reach completely.',
        ],
        confirmLabel: 'Review Steps',
        showCancel: false,
      );
      return;
    }

    final confirmed = await _showSafetyDialog(
      title: 'Start I-Reach Update?',
      icon: Icons.system_update_alt_rounded,
      iconColor: AppTheme.tealDark,
      message:
          'The update will be sent to your confirmed device. Keep the device powered on and do not reopen I-Reach until the update finishes.',
      checklist: const [
        'I-Reach has been synchronized.',
        'I-Reach is fully closed.',
        'I am ready to update this assigned device.',
      ],
      confirmLabel: 'Start Update',
    );

    if (confirmed) {
      await _executeUpdate();
    }
  }

  Future<void> _executeUpdate() async {
    final deviceId = ref.read(authNotifierProvider).user?.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      _showMissingComputerNameMessage();
      return;
    }

    final success = await ref
        .read(deviceNotifierProvider.notifier)
        .executeIReachUpdate(deviceId.trim());

    if (mounted) {
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

    return PopScope(
      canPop: !deviceState.isUpdating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && deviceState.isUpdating) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait while the update request is running.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Update I-Reach Application'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: deviceState.isUpdating
                ? null
                : () {
                    ref.read(deviceNotifierProvider.notifier).reset();
                    context.go('/existing-interviewer-dashboard');
                  },
          ),
        ),
        body: PageContent(
          maxWidth: 760,
          child: deviceState.isUpdating
              ? _buildUpdating(context)
              : deviceState.updateStarted
                  ? _buildUpdateSuccess(
                      context,
                      deviceState.updateMessage ??
                          'I-Reach has been updated. You can now reopen it.',
                    )
                  : deviceState.error != null
                      ? _buildUpdateFailure(context, deviceState.error!)
                      : deviceState.isValidated
                          ? _buildUpdatePrompt(context)
                          : _buildComputerConfirmation(context, deviceId),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSupportSheet(context),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Help'),
        ),
      ),
    );
  }

  Widget _buildComputerConfirmation(
    BuildContext context,
    String? deviceId,
  ) {
    final hasComputerName = deviceId != null && deviceId.trim().isNotEmpty;

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
                        'Update I-Reach Application',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  hasComputerName
                      ? 'Please confirm that your device ID is ${deviceId.trim()} by clicking Continue.\n\nIf this is not your current device, please contact the Help Desk for assistance.'
                      : 'Your interviewer record does not include a device ID. Please contact the Help Desk for assistance.',
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
                Text('Retrieved Device ID',
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
                        hasComputerName
                            ? deviceId.trim()
                            : 'No device ID found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  hasComputerName
                      ? 'This device ID was retrieved from your interviewer profile.'
                      : 'The update cannot continue until a device ID is available.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (hasComputerName) ...[
          ElevatedButton.icon(
            onPressed: _confirmComputerName,
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
    final isReadyForUpdate = _iReachSynced && _iReachClosed;

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
        _buildSyncWarningCard(context),
        const SizedBox(height: 24),
        _buildInstructionTimeline(context),
        const SizedBox(height: 24),
        _buildConfirmationPanel(context),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _startUpdateWithConfirmation,
          icon: const Icon(Icons.play_arrow, size: 24),
          label:
              Text(isReadyForUpdate ? 'Start Update' : 'Confirm Steps First'),
        ),
      ],
    );
  }

  Widget _buildSyncWarningCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0C36A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB26A00).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3AA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB26A00),
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before Updating I-Reach',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF8A5200),
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Failure to sync may result in unsaved offline work being lost. Complete the checklist below before starting the update.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionTimeline(BuildContext context) {
    const steps = [
      'Open I-Reach.',
      'Click Sync.',
      'Wait until synchronization completes.',
      'Close I-Reach completely.',
      'Return to this portal.',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Instructions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 22),
            for (var index = 0; index < steps.length; index++)
              _buildTimelineStep(context, index + 1, steps[index]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.tealSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.tealMuted),
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.tealDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationPanel(BuildContext context) {
    final isReadyForUpdate = _iReachSynced && _iReachClosed;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isReadyForUpdate ? const Color(0xFF7BC99B) : AppTheme.tealMuted,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReadyForUpdate
                    ? Icons.verified_rounded
                    : Icons.fact_check_outlined,
                color: isReadyForUpdate
                    ? const Color(0xFF2E9D5C)
                    : AppTheme.tealDark,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Required Confirmation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildConfirmationTile(
            context,
            value: _iReachSynced,
            onChanged: _confirmSyncCompleted,
            title: 'I have synchronized I-Reach',
            subtitle: 'All offline work saved on this device is on the server.',
          ),
          _buildConfirmationTile(
            context,
            value: _iReachClosed,
            onChanged: _confirmIReachClosed,
            title: 'I have closed I-Reach',
            subtitle: 'The app is fully closed and ready for the update.',
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTile(
    BuildContext context, {
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FBF5) : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? const Color(0xFF7BC99B) : AppTheme.tealMuted,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  Widget _buildUpdating(BuildContext context) {
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
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(strokeWidth: 5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Updating I-Reach',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please keep this page open while the update request is running.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
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
                  'I-Reach has been updated',
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
                    'You can now reopen I-Reach.',
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
                        'What to do next',
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
                    context, 'Reopen I-Reach when you are ready to continue.'),
                _buildStep(
                    context, 'Contact the Help Desk if anything looks wrong.'),
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

  Widget _buildUpdateFailure(BuildContext context, String message) {
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
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 80),
                const SizedBox(height: 24),
                Text(
                  'The update could not be completed',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please contact the Help Desk for assistance.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
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
      'Prepare I-Reach',
      'Update',
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

  Future<bool> _showSafetyDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
    required List<String> checklist,
    required String confirmLabel,
    bool showCancel = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: iconColor, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.tealMuted),
                    ),
                    child: Column(
                      children: [
                        for (final item in checklist)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: AppTheme.tealDark,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (showCancel) ...[
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Not Yet'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(confirmLabel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
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

  void _showMissingComputerNameMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No computer name was found on your user record. Please contact Helpdesk for assistance.',
        ),
      ),
    );
  }
}
