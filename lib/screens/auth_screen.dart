import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app/theme.dart';
import '../services/auth_service.dart';

enum AuthMode { logIn, signUp }

/// Log in or sign up, switchable in place. Shown whenever nobody is signed
/// in; the app swaps to the home screen on its own once a session exists.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    this.initialMode = AuthMode.logIn,
  });

  final AuthService authService;
  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const minPasswordLength = 8;

  late AuthMode _mode = widget.initialMode;
  // Replaced on mode switch so old validation errors don't carry over.
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  bool get _signingUp => _mode == AuthMode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode([AuthMode? mode]) {
    setState(() {
      _mode = mode ?? (_signingUp ? AuthMode.logIn : AuthMode.signUp);
      _formKey = GlobalKey<FormState>();
    });
  }

  // Loose on purpose; Supabase does the real check.
  static bool _looksLikeEmail(String email) =>
      email.contains('@') && email.contains('.');

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    var outcome = SignUpOutcome.signedIn;
    try {
      if (_signingUp) {
        outcome = await widget.authService.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.authService.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _loading = false);
      return _alert(
        _signingUp ? 'Couldn’t create account' : 'Couldn’t log in',
        failure.message,
      );
    }

    // Lets iOS offer to save the password to Keychain.
    TextInput.finishAutofillContext();
    // On success the app replaces this screen, so usually we stop here.
    if (!mounted || outcome != SignUpOutcome.confirmEmail) return;

    setState(() => _loading = false);
    await _alert(
      'Check your inbox',
      'We sent a link to ${_email.text.trim()}. Tap it, then log in.',
    );
    if (mounted) _switchMode(AuthMode.logIn);
  }

  Future<void> _continueWithApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.authService.signInWithApple();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _loading = false);
      return _alert('Couldn’t sign in with Apple', failure.message);
    }
    // On success the app swaps to home; if the sheet was closed, stay here.
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_looksLikeEmail(email)) {
      return _alert(
        'Forgot password?',
        'Enter your email above, then tap “Forgot password?” again.',
      );
    }
    setState(() => _loading = true);
    try {
      await widget.authService.sendPasswordReset(email);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _loading = false);
      return _alert('Couldn’t send reset email', failure.message);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    await _alert(
      'Check your inbox',
      'If there’s an account for $email, we sent a link to reset the '
          'password.',
    );
  }

  Future<void> _alert(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WithinColors.ink,
      // There's no Material ancestor here, so give plain Text a real style
      // (otherwise Flutter's yellow-underline fallback shows).
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                // Centres the form vertically, and still scrolls when the
                // keyboard takes the space.
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(child: _form()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Intro(mode: _mode),
            ),
            const SizedBox(height: 16),
            _fields(),
            if (!_signingUp)
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  onPressed: _loading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, _signingUp ? 24 : 8, 20, 0),
              child: _SubmitButton(
                label: _signingUp ? 'Create account' : 'Log in',
                loading: _loading,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: CupertinoButton(
                onPressed: _loading ? null : _switchMode,
                child: Text(
                  _signingUp
                      ? 'Already have an account? Log in'
                      : 'Don’t have an account? Sign up',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const _OrDivider(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // The button has no disabled state, so block taps while busy.
              child: IgnorePointer(
                ignoring: _loading,
                child: SignInWithAppleButton(
                  text: 'Continue with Apple',
                  style: SignInWithAppleButtonStyle.white,
                  height: 50,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onPressed: _continueWithApple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fields() {
    return CupertinoFormSection.insetGrouped(
      backgroundColor: WithinColors.ink,
      decoration: BoxDecoration(
        color: WithinColors.inkRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      footer: _signingUp
          ? Text(
              'Your name is what friends will see.',
              style: TextStyle(
                fontSize: 13,
                color: WithinColors.paper.withValues(alpha: 0.45),
              ),
            )
          : null,
      children: [
        if (_signingUp)
          CupertinoTextFormFieldRow(
            controller: _name,
            placeholder: 'Name',
            enabled: !_loading,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter your name.' : null,
          ),
        CupertinoTextFormFieldRow(
          controller: _email,
          placeholder: 'Email',
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (value) => _looksLikeEmail((value ?? '').trim())
              ? null
              : 'Enter a valid email address.',
        ),
        CupertinoTextFormFieldRow(
          controller: _password,
          placeholder: 'Password',
          enabled: !_loading,
          obscureText: true,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          autofillHints: [
            _signingUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onFieldSubmitted: (_) => _submit(),
          // Length rules only apply to new passwords.
          validator: (value) {
            final password = value ?? '';
            if (!_signingUp) {
              return password.isEmpty ? 'Enter your password.' : null;
            }
            return password.length < minPasswordLength
                ? 'Use at least $minPasswordLength characters.'
                : null;
          },
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.mode});

  final AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final signingUp = mode == AuthMode.signUp;
    return Column(
      children: [
        // The logo's background is the same ink as the page, so it blends in.
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/images/logo.png', width: 72, height: 72),
        ),
        const SizedBox(height: 20),
        Text(
          signingUp ? 'Create your account' : 'Welcome to Within',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: WithinTheme.serif,
            fontSize: 28,
            color: WithinColors.paper,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          signingUp
              ? 'So friends can send a few kind words to your widget.'
              : 'Log in to see today’s teaching and words from friends.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: WithinColors.paper.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 0.5,
        color: WithinColors.paper.withValues(alpha: 0.2),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or',
              style: TextStyle(
                fontSize: 13,
                color: WithinColors.paper.withValues(alpha: 0.45),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(
      color: WithinColors.sage,
      disabledColor: WithinColors.sage.withValues(alpha: 0.5),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const CupertinoActivityIndicator(color: WithinColors.ink)
          : Text(
              label,
              style: const TextStyle(
                color: WithinColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
