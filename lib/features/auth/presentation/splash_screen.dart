import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_loading.dart';
import 'package:mybike_showroom/features/auth/presentation/auth_card_layout.dart';

/// Shown while the stored session is restored and the profile is loaded.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthCardLayout(children: <Widget>[AppLoading(message: 'Loading your workspace…')]);
  }
}
