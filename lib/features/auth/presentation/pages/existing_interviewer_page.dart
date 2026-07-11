import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_dialog.dart';
import '../../../../core/widgets/page_content.dart';
import '../providers/auth_notifier.dart';

class ExistingInterviewerPage extends ConsumerStatefulWidget {
  const ExistingInterviewerPage({super.key});

  @override
  ConsumerState<ExistingInterviewerPage> createState() =>
      _ExistingInterviewerPageState();
}

class _ExistingInterviewerPageState
    extends ConsumerState<ExistingInterviewerPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Authenticating...'),
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .authenticateExistingInterviewer(username, password);

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        context.go('/update-ireach');
      } else {
        final error = ref.read(authNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Authentication failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Existing Interviewer Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: PageContent(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
        child: Form(
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
                          Icon(Icons.person,
                              size: 36, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('Login to Your Account',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Enter your interviewer username and password to access your account.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Username',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 64,
                decoration: const InputDecoration(
                  hintText: 'Enter your username',
                  prefixIcon: Icon(Icons.person, size: 28),
                  counterText: '',
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) {
                    return 'Username is required';
                  }
                  if (!RegExp(r'^[A-Za-z0-9._-]{2,64}$').hasMatch(username)) {
                    return 'Enter a valid username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              Text(
                'Password',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock, size: 28),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 28),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length > 128) {
                    return 'Password is too long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.login, size: 24),
                label: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
