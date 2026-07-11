import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/device_entity.dart';
import '../../../../core/widgets/loading_dialog.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/device_notifier.dart';
import '../widgets/setup_instruction.dart';

class DeviceSetupPage extends ConsumerStatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  ConsumerState<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends ConsumerState<DeviceSetupPage> {
  final _deviceIdController = TextEditingController();
  final Set<int> _completedSteps = {};

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _validateDevice() async {
    final assignedDeviceId = ref.read(authNotifierProvider).user?.deviceId;
    final deviceId = assignedDeviceId?.trim().isNotEmpty == true
        ? assignedDeviceId!.trim()
        : _deviceIdController.text.trim();

    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device ID was found. Please contact Helpdesk.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Validating device...'),
    );

    final success = await ref
        .read(deviceNotifierProvider.notifier)
        .validateDevice(deviceId);

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        setState(_completedSteps.clear);
      }
      if (!success) {
        final error = ref.read(deviceNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Device not found')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(deviceNotifierProvider.notifier).reset();
            context.go('/auth');
          },
        ),
      ),
      body: PageContent(
        maxWidth: 760,
        child: deviceState.isValidated
            ? _buildSetupInstructions(context, deviceState.device!)
            : _buildDeviceIdEntry(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupportSheet(context),
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Help'),
      ),
    );
  }

  Widget _buildDeviceIdEntry(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final interviewerName = authState.user?.username;
    final assignedDeviceId = authState.user?.deviceId;
    final hasAssignedDevice =
        assignedDeviceId != null && assignedDeviceId.trim().isNotEmpty;
    final pin = hasAssignedDevice ? _pinForDeviceId(assignedDeviceId) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to Ipsos',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  interviewerName == null
                      ? 'Your interviewer record has been verified.'
                      : 'Your interviewer record has been verified for $interviewerName.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  hasAssignedDevice
                      ? 'Your assigned device has been found. Confirm it below to open your setup guide.'
                      : 'Your record was verified, but no assigned device was returned. Enter the device ID from the device label or contact Helpdesk.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.devices,
                        size: 36, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                          hasAssignedDevice
                              ? 'Confirm Your Assigned Device'
                              : 'Enter Your Device ID',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  hasAssignedDevice
                      ? 'Please check that this is the device you received. If it does not match, contact Helpdesk before continuing.'
                      : 'You can find your device ID on the device label, on the device itself, or in the setup package provided to you.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (hasAssignedDevice)
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
                      const Icon(Icons.laptop_windows_rounded, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          assignedDeviceId.trim(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (pin != null) ...[
                    const SizedBox(height: 22),
                    Text('First-login PIN',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      pin,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ],
              ),
            ),
          )
        else ...[
          Text(
            'Device ID',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deviceIdController,
            decoration: const InputDecoration(
              hintText: 'e.g., IPLT671 or CBG-TAB-671',
              prefixIcon: Icon(Icons.devices, size: 28),
            ),
          ),
        ],
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: _validateDevice,
          icon: const Icon(Icons.check, size: 24),
          label:
              Text(hasAssignedDevice ? 'Open Setup Guide' : 'Validate Device'),
        ),
      ],
    );
  }

  Widget _buildSetupInstructions(BuildContext context, DeviceEntity device) {
    final instructions = _instructionsForDevice(device.type);
    final totalSteps = instructions.length;
    final completedCount = _completedSteps.length;
    final canComplete = completedCount == totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade700, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Validated',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text('Device Type: ${device.type.displayName}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (device.name != null) ...[
                        const SizedBox(height: 2),
                        Text('Device Name: ${device.name}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      if (_pinForDeviceId(device.deviceId) case final pin?) ...[
                        const SizedBox(height: 2),
                        Text('First-login PIN: $pin',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildProgressCard(context, completedCount, totalSteps),
        const SizedBox(height: 28),
        Text('Knowledge Guide',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ...instructions.map((instruction) {
          final index = instructions.indexOf(instruction) + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SetupInstruction(
              number: index,
              title: instruction.title,
              description: instruction.description,
              details: instruction.details,
              isComplete: _completedSteps.contains(index),
              onCompleteChanged: (value) {
                setState(() {
                  if (value) {
                    _completedSteps.add(index);
                  } else {
                    _completedSteps.remove(index);
                  }
                });
              },
            ),
          );
        }),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(deviceNotifierProvider.notifier).reset();
            context.go('/auth');
          },
          icon: const Icon(Icons.check),
          label: Text(canComplete
              ? 'Setup Complete'
              : 'Complete all steps to finish setup'),
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    int completedCount,
    int totalSteps,
  ) {
    final progress = totalSteps == 0 ? 0.0 : completedCount / totalSteps;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: Color(0xFF2E9D5C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$completedCount of $totalSteps steps complete',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }

  List<_InstructionData> _instructionsForDevice(DeviceType type) {
    return switch (type) {
      DeviceType.windowsLaptop => _windowsInstructions,
      DeviceType.androidTablet => _androidInstructions,
      DeviceType.iosTablet => _iosInstructions,
      DeviceType.unknown => _genericInstructions,
    };
  }

  static const _windowsInstructions = [
    _InstructionData(
        title: 'Get Your Laptop PIN',
        description:
            'Use the PIN shown above when signing in for the first time',
        details: '''
1. Keep this portal open while you set up your device
2. Power on your Ipsos laptop
3. Confirm the device ID matches the device in front of you
4. When prompted for a PIN, enter the PIN shown in this guide
5. Contact Helpdesk if the PIN is not accepted'''),
    _InstructionData(
        title: 'Connect to WiFi',
        description:
            'After signing in, connect the laptop to your home WiFi network',
        details: '''
1. Look for the WiFi icon in the bottom-right corner
2. Click on it and wait for available networks to appear
3. Select your home network from the list
4. Enter the WiFi password if required
5. Wait for connection confirmation'''),
    _InstructionData(
        title: 'Login to MS Teams',
        description: 'Open Microsoft Teams and sign in with your credentials',
        details: '''
1. Click on the Start menu and search for "Teams"
2. Open Microsoft Teams
3. Enter your work email address
4. When prompted, enter your password
5. Complete any two-factor authentication if required
6. You're ready to use Teams!'''),
    _InstructionData(
        title: 'Open Ipsos Apps',
        description: 'Review the Ipsos applications used by your project',
        details: '''
1. Open the Ipsos apps folder on your desktop
2. Confirm iReach is available for your project work
3. Open iReach and sign in with your interviewer account
4. Check whether any project-specific shortcut is listed
5. Keep Teams open if you need helpdesk guidance'''),
    _InstructionData(
        title: 'Sync to Android Showcard',
        description: 'Connect your Android tablet for data synchronization',
        details: '''
1. Install the Ipsos Sync app on your Android tablet
2. Open the app and note the device code
3. On your laptop, open Ipsos Sync settings
4. Enter the device code from your tablet
5. Confirm the connection on both devices'''),
    _InstructionData(
        title: 'Helpdesk Contact',
        description: 'Save the helpdesk contact information',
        details: '''
Email: helpdesk@ipsos.com
Phone: 1-800-IPSOS-HELP
Hours: Monday-Friday, 8AM-6PM (Your Local Time)'''),
  ];

  static const _androidInstructions = [
    _InstructionData(
        title: 'Connect to WiFi',
        description: 'Connect your tablet to your home WiFi network',
        details: '''
1. Swipe down from the top to open Settings
2. Tap "WiFi"
3. Select your home network
4. Enter the WiFi password
5. Wait for connection confirmation'''),
    _InstructionData(
        title: 'Install Microsoft Teams',
        description: 'Download Teams from Google Play Store',
        details: '''
1. Open Google Play Store
2. Search for "Microsoft Teams"
3. Tap Install
4. Once installed, tap Open
5. Sign in with your work email'''),
    _InstructionData(
        title: 'Open Ipsos Apps',
        description: 'Confirm iReach and project apps are available',
        details: '''
1. Open the app drawer
2. Locate iReach and any project-specific Ipsos apps
3. Open iReach and sign in with your interviewer account
4. Confirm the assigned project appears on the home screen
5. Return to this portal after checking the apps'''),
    _InstructionData(
        title: 'Helpdesk Contact',
        description: 'Save the helpdesk contact information',
        details: '''
Email: helpdesk@ipsos.com
Phone: 1-800-IPSOS-HELP
Hours: Monday-Friday, 8AM-6PM (Your Local Time)'''),
  ];

  static const _iosInstructions = [
    _InstructionData(
        title: 'Connect to WiFi',
        description: 'Connect your iPad to your home WiFi network',
        details: '''
1. Go to Settings
2. Tap WiFi
3. Select your home network
4. Enter the WiFi password
5. Wait for connection confirmation'''),
    _InstructionData(
        title: 'Install Microsoft Teams',
        description: 'Download Teams from App Store',
        details: '''
1. Open App Store
2. Search for "Microsoft Teams"
3. Tap Get then Install
4. Once installed, tap Open
5. Sign in with your work email'''),
    _InstructionData(
        title: 'Open Ipsos Apps',
        description: 'Confirm iReach and project apps are available',
        details: '''
1. Open the home screen
2. Locate iReach and any project-specific Ipsos apps
3. Open iReach and sign in with your interviewer account
4. Confirm the assigned project appears on the home screen
5. Return to this portal after checking the apps'''),
    _InstructionData(
        title: 'Helpdesk Contact',
        description: 'Save the helpdesk contact information',
        details: '''
Email: helpdesk@ipsos.com
Phone: 1-800-IPSOS-HELP
Hours: Monday-Friday, 8AM-6PM (Your Local Time)'''),
  ];

  static const _genericInstructions = [
    _InstructionData(
      title: 'Contact Helpdesk',
      description: 'Reach out for device-specific setup assistance',
      details: '''
Email: helpdesk@ipsos.com
Phone: 1-800-IPSOS-HELP
Hours: Monday-Friday, 8AM-6PM (Your Local Time)

Please have your device ID ready when you contact us.''',
    ),
  ];

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
              Text('Helpdesk',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Start chat'),
                subtitle: const Text('A chat widget can be connected here'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat support placeholder opened'),
                    ),
                  );
                },
              ),
              const ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('helpdesk@ipsos.com'),
              ),
              const ListTile(
                leading: Icon(Icons.phone_outlined),
                title: Text('1-800-IPSOS-HELP'),
                subtitle: Text('Monday-Friday, 8AM-6PM local time'),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _pinForDeviceId(String deviceId) {
    final digits = RegExp(r'(\d{3})$').firstMatch(deviceId.trim())?.group(1);
    if (digits == null) {
      return null;
    }

    return '8$digits';
  }
}

class _InstructionData {
  const _InstructionData({
    required this.title,
    required this.description,
    required this.details,
  });

  final String title;
  final String description;
  final String details;
}
