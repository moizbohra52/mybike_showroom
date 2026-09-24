import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/screens/config_error_screen.dart';
import 'package:mybike_showroom/core/config/app_config.dart';
import 'package:mybike_showroom/core/config/env_config.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entry point.
///
/// Bootstraps (1) device-local preferences and the persisted theme mode,
/// (2) validates the build configuration, (3) initialises Supabase (the SDK
/// restores and refreshes the stored session), then launches the app inside a
/// [ProviderScope]. The session controller + router guard take it from there.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Local preferences (non-sensitive UI state only) ───────────────────
  final SharedPreferencesStore preferenceStore =
      await SharedPreferencesStore.create();
  final String? storedTheme = await preferenceStore.readString(
    StorageKeys.themeMode,
  );

  // ── 2. Environment validation (blocking in prod, advisory in dev) ─────────
  final EnvValidation validation = EnvConfig.current.validate();
  if (!validation.isValid) {
    // A misconfigured production build must never reach the login flow.
    runApp(const ConfigErrorApp());
    return;
  }

  // Only the anon/publishable key ever reaches the client (G4); validate()
  // refuses service-role / secret keys.
  await Supabase.initialize(
    url: EnvConfig.current.supabaseUrl,
    publishableKey: EnvConfig.current.supabaseAnonKey,
  );

  // ── 3. Launch ───────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [
        bootstrapThemeModeProvider.overrideWithValue(
          AppThemeMode.fromStorage(storedTheme),
        ),
        preferenceStoreProvider.overrideWithValue(preferenceStore),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root widget — theme + guarded router.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode.materialThemeMode,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'mybike',
    );
  }
}
