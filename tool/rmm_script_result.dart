final class RmmScriptResult {
  final bool succeeded;
  final String message;

  const RmmScriptResult({
    required this.succeeded,
    required this.message,
  });
}

RmmScriptResult interpretRmmScriptResponse(dynamic response) {
  if (response is Map<String, dynamic>) {
    final status = response['status']?.toString().trim().toLowerCase();
    final success = response['success'];
    if (status == 'failed' || status == 'error' || success == false) {
      return const RmmScriptResult(
        succeeded: false,
        message:
            'The update script ran but reported an error. Please contact the Help Desk.',
      );
    }
  }

  final output = switch (response) {
    String value => value,
    Map<String, dynamic> value => (value['output'] ??
                value['stdout'] ??
                value['result'] ??
                value['message'])
            ?.toString() ??
        '',
    _ => response?.toString() ?? '',
  };
  final normalized = output.toLowerCase();
  const failureSignals = [
    'fullyqualifiederrorid',
    'categoryinfo',
    'writeerror',
    'application control policy has blocked',
    'cannot access the file',
    'invalidoperationexception',
    'unauthorizedaccessexception',
  ];

  if (failureSignals.any(normalized.contains)) {
    return const RmmScriptResult(
      succeeded: false,
      message:
          'The update script ran but reported an error. Please contact the Help Desk.',
    );
  }

  return const RmmScriptResult(
    succeeded: true,
    message: 'I-Reach has been updated. You can now reopen it.',
  );
}
