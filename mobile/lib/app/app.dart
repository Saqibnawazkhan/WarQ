import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../presentation/state/app_settings_controller.dart';
import '../presentation/state/session_controller.dart';
import 'app_dependencies.dart';
import 'root_gate.dart';

/// Root widget.
///
/// Providers that must outlive individual screens — the dependency graph, the
/// session and user preferences — are installed above [MaterialApp] so pushed
/// routes can reach them.
class EduManagerApp extends StatelessWidget {
  const EduManagerApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppDependencies>.value(value: dependencies),
        ChangeNotifierProvider<AppSettingsController>(
          create: (_) => AppSettingsController(
            dependencies.database.store,
            // Keeps the WhatsApp provider in step with the saved dialling code.
            onCountryCodeChanged: dependencies.setDefaultCountryCode,
          )..load(),
        ),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(dependencies)..load(),
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (BuildContext context, AppSettingsController settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
            home: const RootGate(),
            builder: (BuildContext context, Widget? child) {
              // Clamp the system font scale so dense screens (the marks grid,
              // the attendance sheet) stay usable at extreme accessibility
              // settings without truncating content.
              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  // The floor sits at 1.0 now: the app's own scale is already
                  // sized for a classroom, and letting the system shrink it
                  // below that undoes the point. Enlarging is still honoured.
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 1.0,
                    maxScaleFactor: 1.35,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
