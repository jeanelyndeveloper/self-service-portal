import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class SupportTicketPage extends ConsumerStatefulWidget {
  const SupportTicketPage({super.key});

  @override
  ConsumerState<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends ConsumerState<SupportTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  String? _subject;
  String? _project;
  String? _category;
  String? _priority;

  static const _subjects = [
    'I-Reach update',
    'I-Reach sync issue',
    'Login issue',
    'Device setup',
    'Other',
  ];

  static const _categories = [
    'I-Reach',
    'Connectivity',
    'Login',
    'Device',
    'Other',
  ];

  static const _priorities = [
    'Normal',
    'High',
    'Urgent',
  ];

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final user = ref.read(authNotifierProvider).user;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Support ticket prepared for ${user?.displayName ?? 'interviewer'}: $_subject, $_category, $_priority, ${_project ?? 'no project'}. Connect the backend ticket API to submit it.',
        ),
      ),
    );
  }

  void _goBack(UserType? userType) {
    if (userType == UserType.newInterviewer) {
      context.go('/new-interviewer');
      return;
    }
    context.go('/existing-interviewer-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Support Ticket'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(user?.type),
        ),
      ),
      body: PageContent(
        maxWidth: 760,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help Desk ticket',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your known details are attached automatically so Help Desk can respond faster.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      _AutoField(
                        icon: Icons.person_outline_rounded,
                        label: 'Name',
                        value: user?.displayName ?? 'Not available',
                      ),
                      _AutoField(
                        icon: Icons.alternate_email_rounded,
                        label: 'Username',
                        value: user?.username ?? 'Not available',
                      ),
                      _AutoField(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user?.email ?? 'Not available',
                      ),
                      _AutoField(
                        icon: Icons.devices_rounded,
                        label: 'Device',
                        value: user?.deviceId ?? 'Not available',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                value: _subject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.subject_rounded),
                ),
                items: [
                  for (final subject in _subjects)
                    DropdownMenuItem(value: subject, child: Text(subject)),
                ],
                onChanged: (value) => setState(() => _subject = value),
                validator: (value) =>
                    value == null ? 'Please select a subject' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: user?.project,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                onChanged: (value) => _project = value.trim(),
                onSaved: (value) => _project = value?.trim(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a project';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.priority_high_rounded),
                ),
                items: [
                  for (final priority in _priorities)
                    DropdownMenuItem(value: priority, child: Text(priority)),
                ],
                onChanged: (value) => setState(() => _priority = value),
                validator: (value) =>
                    value == null ? 'Please select a priority' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _issueController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.report_problem_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit Ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoField extends StatelessWidget {
  const _AutoField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 86,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
