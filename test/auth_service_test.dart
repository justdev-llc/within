import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:within/services/auth_service.dart';

void main() {
  group('without Supabase configured', () {
    final auth = AuthService(null);

    test('reports unavailable and signed out', () {
      expect(auth.isAvailable, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.displayName, isNull);
    });

    test('auth changes stream is empty, not an error', () async {
      expect(await auth.authChanges.isEmpty, isTrue);
    });

    test('actions fail with a friendly message', () async {
      await expectLater(
        auth.signIn(email: 'a@b.com', password: 'password'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Accounts aren’t available right now.',
          ),
        ),
      );
      await expectLater(
        auth.signUp(name: 'A', email: 'a@b.com', password: 'password'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('messageFor', () {
    String message(String? code) =>
        AuthService.messageFor(AuthException('raw server text', code: code));

    test('maps known error codes to plain language', () {
      expect(
        message('invalid_credentials'),
        'That email or password doesn’t match.',
      );
      expect(message('user_already_exists'), contains('already registered'));
      expect(message('email_exists'), contains('already registered'));
      expect(message('weak_password'), contains('stronger password'));
      expect(message('over_request_rate_limit'), contains('Too many'));
    });

    test('never leaks raw server text for unknown codes', () {
      expect(
        message('something_new'),
        'Something went wrong. Please try again.',
      );
      expect(message(null), 'Something went wrong. Please try again.');
    });

    test('network failures get a connection message', () {
      expect(
        AuthService.messageFor(AuthRetryableFetchException()),
        contains('internet connection'),
      );
    });
  });
}
