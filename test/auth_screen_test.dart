import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:within/app/within_app.dart';
import 'package:within/screens/auth_screen.dart';
import 'package:within/screens/home_screen.dart';
import 'package:within/services/auth_service.dart';
import 'package:within/services/teaching_service.dart';
import 'package:within/services/widget_service.dart';

class _FakeWidgetService extends WidgetService {
  @override
  Future<void> refresh() async {}
}

/// A configured AuthService without a real Supabase client. Signing in flips
/// [isSignedIn] and announces it, as Supabase does.
class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.signedIn = false,
    this.failure,
    this.outcome = SignUpOutcome.signedIn,
  }) : super(null);

  bool signedIn;
  final AuthFailure? failure;
  final SignUpOutcome outcome;
  final _changes = StreamController<AuthState>.broadcast();
  final signUps = <String>[];
  final logIns = <String>[];
  final resets = <String>[];

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<AuthState> get authChanges => _changes.stream;

  void _signIn() {
    signedIn = true;
    _changes.add(AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    signUps.add(email);
    if (failure != null) throw failure!;
    if (outcome == SignUpOutcome.signedIn) _signIn();
    return outcome;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    logIns.add(email);
    if (failure != null) throw failure!;
    _signIn();
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  /// What the Apple sheet does: true signs in, false is the user closing it.
  bool appleResult = true;
  int appleAttempts = 0;

  @override
  Future<bool> signInWithApple() async {
    appleAttempts++;
    if (failure != null) throw failure!;
    if (appleResult) _signIn();
    return appleResult;
  }
}

void main() {
  final teachings = TeachingService.fromJsonString(
    File('assets/teachings/buddhism.json').readAsStringSync(),
  );

  Future<void> launch(WidgetTester tester, AuthService auth) async {
    await tester.pumpWidget(
      WithinApp(
        teachingService: teachings,
        widgetService: _FakeWidgetService(),
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(WidgetTester tester, List<String> values) async {
    final fields = find.byType(CupertinoTextField);
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(fields.at(i), values[i]);
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('launch', () {
    testWidgets('signed out opens on log in, with no way to skip', (
      tester,
    ) async {
      await launch(tester, _FakeAuthService());

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Welcome to Within'), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a saved session goes straight home', (tester) async {
      await launch(tester, _FakeAuthService(signedIn: true));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
    });

    testWidgets('without Supabase configured goes straight home', (
      tester,
    ) async {
      await launch(tester, AuthService(null));

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('log in', () {
    testWidgets('goes home on success', (tester) async {
      final auth = _FakeAuthService();
      await launch(tester, auth);

      await fillIn(tester, ['jeet@example.com', 'short']);
      await tapAndSettle(tester, 'Log in');

      // Existing passwords aren't held to the new-password length rule.
      expect(auth.logIns.single, 'jeet@example.com');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('requires email and password', (tester) async {
      final auth = _FakeAuthService();
      await launch(tester, auth);

      await tapAndSettle(tester, 'Log in');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(auth.logIns, isEmpty);
    });

    testWidgets('shows a failure as an alert and stays', (tester) async {
      final auth = _FakeAuthService(
        failure: const AuthFailure('That email or password doesn’t match.'),
      );
      await launch(tester, auth);

      await fillIn(tester, ['jeet@example.com', 'wrong password']);
      await tapAndSettle(tester, 'Log in');

      expect(find.text('Couldn’t log in'), findsOneWidget);
      expect(
        find.text('That email or password doesn’t match.'),
        findsOneWidget,
      );
      await tapAndSettle(tester, 'OK');
      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('continue with Apple', () {
    testWidgets('goes home on success', (tester) async {
      final auth = _FakeAuthService();
      await launch(tester, auth);

      await tapAndSettle(tester, 'Continue with Apple');

      expect(auth.appleAttempts, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('closing the Apple sheet quietly stays', (tester) async {
      final auth = _FakeAuthService()..appleResult = false;
      await launch(tester, auth);

      await tapAndSettle(tester, 'Continue with Apple');

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('shows a failure as an alert', (tester) async {
      final auth = _FakeAuthService(
        failure: const AuthFailure('Couldn’t sign in with Apple.'),
      );
      await launch(tester, auth);

      await tapAndSettle(tester, 'Continue with Apple');

      expect(find.text('Couldn’t sign in with Apple'), findsOneWidget);
    });

    testWidgets('is offered on sign up too', (tester) async {
      await launch(tester, _FakeAuthService());
      await tapAndSettle(tester, 'Don’t have an account? Sign up');

      expect(find.text('Continue with Apple'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('asks for an email first', (tester) async {
      final auth = _FakeAuthService();
      await launch(tester, auth);

      await tapAndSettle(tester, 'Forgot password?');

      expect(find.textContaining('Enter your email above'), findsOneWidget);
      expect(auth.resets, isEmpty);
    });

    testWidgets('sends the reset email', (tester) async {
      final auth = _FakeAuthService();
      await launch(tester, auth);

      await fillIn(tester, ['jeet@example.com']);
      await tapAndSettle(tester, 'Forgot password?');

      expect(auth.resets.single, 'jeet@example.com');
      expect(find.text('Check your inbox'), findsOneWidget);
    });
  });

  group('sign up', () {
    Future<void> openSignUp(WidgetTester tester, AuthService auth) async {
      await launch(tester, auth);
      await tapAndSettle(tester, 'Don’t have an account? Sign up');
    }

    testWidgets('switches in place, keeping the email', (tester) async {
      await launch(tester, _FakeAuthService());

      await fillIn(tester, ['jeet@example.com']);
      await tapAndSettle(tester, 'Don’t have an account? Sign up');

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsNWidgets(3));
      expect(find.text('jeet@example.com'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);

      await tapAndSettle(tester, 'Already have an account? Log in');
      expect(find.text('Welcome to Within'), findsOneWidget);
    });

    testWidgets('validates before calling the service', (tester) async {
      final auth = _FakeAuthService();
      await openSignUp(tester, auth);

      await fillIn(tester, ['  ', 'nope', 'short']);
      await tapAndSettle(tester, 'Create account');

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(auth.signUps, isEmpty);
    });

    testWidgets('goes home on success', (tester) async {
      final auth = _FakeAuthService();
      await openSignUp(tester, auth);

      await fillIn(tester, ['Jeet', 'jeet@example.com', 'correct horse']);
      await tapAndSettle(tester, 'Create account');

      expect(auth.signUps.single, 'jeet@example.com');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('with email confirmation, returns to log in', (tester) async {
      final auth = _FakeAuthService(outcome: SignUpOutcome.confirmEmail);
      await openSignUp(tester, auth);

      await fillIn(tester, ['Jeet', 'jeet@example.com', 'correct horse']);
      await tapAndSettle(tester, 'Create account');

      expect(find.text('Check your inbox'), findsOneWidget);
      await tapAndSettle(tester, 'OK');
      expect(find.text('Welcome to Within'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
