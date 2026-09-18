import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/config/env_config.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Standalone [MaterialApp] shown before the router when environment
/// validation failed.  Uses the brand [AppTheme] so even the error screen
/// matches MyBike visual identity.
final class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyBike — configuration error',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const ConfigErrorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Full-screen config error shown when the build is misconfigured.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({this.validation, super.key});

  /// Pre-computed validation; defaults to [EnvConfig.current.validate()]
  /// when called from the non-router error path.
  final EnvValidation? validation;

  @override
  Widget build(BuildContext context) {
    final EnvValidation v = validation ?? EnvConfig.current.validate();
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.warning_amber_outlined, size: 80),
                const SizedBox(height: AppDimensions.space24),
                Text(
                  AppStrings.configErrorTitle,
                  style: AppTypography.resolved.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space12),
                Text(
                  AppStrings.configErrorIntro,
                  style: AppTypography.resolved.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (v.problems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Problems:',
                          style: AppTypography.resolved.bodyMedium?.copyWith(
                            color: palette.danger,
                          ),
                        ),
                        for (final String problem in v.problems)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppDimensions.space4,
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.error_outline, size: 16),
                                const SizedBox(width: AppDimensions.space8),
                                Expanded(
                                  child: Text(
                                    problem,
                                    style: AppTypography.resolved.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppDimensions.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
