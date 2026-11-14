import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider), c = ref.read(authProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: BrandLockup(height: 46)),
                  SizedBox(height: 16),
                  Text(
                    'Business & Community',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: context.nx.textSecondary,
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(switch (state.stage) {
                    'email' => 'Verify your recovery email',
                    'otp' => 'Check your email',
                    'signup' => 'Create your account',
                    _ => 'Welcome back',
                  }, style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  if (state.stage == 'login' || state.stage == 'signup') ...[
                    NativeInput(
                      value: state.phone,
                      onChanged: c.phone,
                      hint: 'Phone number',
                      type: TextInputType.phone,
                    ),
                    SizedBox(height: 12),
                  ],
                  if (state.stage == 'signup') ...[
                    Text(
                      'No email code at signup. This device signs you in from now on; the email above is only for recovering the account on a new device.',
                    ),
                    SizedBox(height: 12),
                  ],
                  if (state.stage == 'email' || state.stage == 'signup') ...[
                    NativeInput(
                      value: state.email,
                      onChanged: c.email,
                      hint: 'Recovery email (Gmail)',
                      type: TextInputType.emailAddress,
                    ),
                    if (state.stage == 'signup')
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Used for account recovery',
                          style: TextStyle(fontSize: 11, color: Tokens.muted),
                        ),
                      ),
                  ],
                  if (state.stage == 'otp') ...[
                    Text(
                      'Paste the complete verification capability from your email (selector.secret). It expires after 10 minutes and is single-use.',
                    ),
                    SizedBox(height: 12),
                    NativeInput(
                      value: state.otp,
                      onChanged: c.otp,
                      hint: 'Email verification code',
                      maxLength: 66,
                      type: TextInputType.visiblePassword,
                    ),
                    TextButton(
                      onPressed: state.busy || state.resendSeconds > 0
                          ? null
                          : c.resend,
                      child: Text(
                        state.resendSeconds > 0
                            ? 'Resend in ${state.resendSeconds}s'
                            : 'Resend email',
                      ),
                    ),
                  ],
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Tokens.alert),
                      ),
                    ),
                  SizedBox(height: 18),
                  FilledButton(
                    onPressed: state.busy ? null : c.submit,
                    child: Text(
                      state.busy
                          ? 'Please wait…'
                          : switch (state.stage) {
                              'email' => 'Send email code',
                              'otp' => 'Verify and continue',
                              'signup' => 'Create account',
                              _ => 'Device login',
                            },
                    ),
                  ),
                  if (state.stage == 'login')
                    TextButton(
                      onPressed: c.signup,
                      child: const Text('Create an account'),
                    ),
                  if (state.stage != 'login')
                    TextButton(
                      onPressed: state.busy ? null : c.back,
                      child: const Text('Back to login'),
                    ),
                  SizedBox(height: 16),
                  Text(
                    'Your device identifier and session are protected in secure device storage.',
                    style: TextStyle(fontSize: 11, color: Tokens.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
