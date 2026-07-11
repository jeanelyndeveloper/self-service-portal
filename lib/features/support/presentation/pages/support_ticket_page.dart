import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/page_content.dart';
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

  static const _subjects = [
    'I-Reach update',
    'I-Reach sync issue',
    'Login issue',
    'Device setup',
    'Other',
  ];

  static const _projects = [
    'General Interviewing',
    'CBG',
    'ETTS',
    'Other',
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

    final user = ref.read(authNotifierProvider).user;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Support ticket prepared for ${user?.displayName ?? 'interviewer'}. Connect the backend ticket API to submit it.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Help Desk'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/existing-interviewer-dashboard'),
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
                        'Create Support Ticket',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signed in as ${user?.displayName ?? 'interviewer'}${user?.deviceId == null ? '' : ' on ${user!.deviceId}'}.',
                        style: Theme.of(context).textTheme.bodyLarge,
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
                controller: _issueController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Reporting Issue',
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
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _project,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                items: [
                  for (final project in _projects)
                    DropdownMenuItem(value: project, child: Text(project)),
                ],
                onChanged: (value) => setState(() => _project = value),
                validator: (value) =>
                    value == null ? 'Please select a project' : null,
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
