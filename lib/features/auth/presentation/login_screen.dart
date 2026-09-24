import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_text_field.dart';
import 'package:mybike_showroom/core/config/app_config.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/presentation/auth_card_layout.dart';

/// Email + password sign-in. Accounts are created by administrators (no
/// self sign-up); errors are always the mapped, user-safe message.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool busy = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      busy = true;
      errorMessage = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(email: emailController.text, password: passwordController.text);
    } on Object catch (error, stackTrace) {
      final AppFailure failure = ErrorMapper.map(error, stackTrace);
      if (mounted) {
        setState(() => errorMessage = failure.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AuthCardLayout(
      children: <Widget>[
        Text(
          AppConfig.tagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppDimensions.space24),
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: emailController,
                label: 'Email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                validator: Validators.email,
              ),
              const SizedBox(height: AppDimensions.space16),
              AppTextField(
                controller: passwordController,
                label: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !busy,
                onSubmitted: (_) => submit(),
                validator: (String? v) => Validators.required(v, field: 'Password'),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: AppDimensions.space16),
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.danger),
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.space24),
        AppButton(text: 'Sign in', expanded: true, loading: busy, onPressed: busy ? null : submit),
      ],
    );
  }
}
