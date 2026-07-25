import 'package:flutter_test/flutter_test.dart';

import '../../tool/rmm_script_result.dart';

void main() {
  group('interpretRmmScriptResponse', () {
    test('accepts clean script output', () {
      final result = interpretRmmScriptResponse(
        'I-Reach installation completed successfully.',
      );

      expect(result.succeeded, isTrue);
      expect(result.message, contains('updated'));
    });

    test('rejects the PowerShell error returned by script 130', () {
      final result = interpretRmmScriptResponse(
        r'''
New-Item : An item with the specified name C:\temp already exists.
CategoryInfo : ResourceExists
FullyQualifiedErrorId : DirectoryExist
Start-Process : Application Control policy has blocked this file.
''',
      );

      expect(result.succeeded, isFalse);
      expect(result.message, contains('reported an error'));
    });

    test('rejects an explicit failed response', () {
      final result = interpretRmmScriptResponse({
        'status': 'failed',
        'message': 'Script failed',
      });

      expect(result.succeeded, isFalse);
    });
  });
}
