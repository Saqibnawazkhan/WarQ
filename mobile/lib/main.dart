import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'presentation/screens/splash/splash_screen.dart';

/// Entry point.
///
/// The dependency graph (local database, repositories, services) is built
/// before the first frame so no screen ever has to guard against a half-ready
/// data layer.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first: the app targets phones and every layout is designed for a
  // single column. Tablets still get the wider, centred content column.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const _Bootstrap());
}

/// Shows the splash screen while [AppDependencies.bootstrap] runs.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppDependencies> _future = AppDependencies.bootstrap();

  void _retry() {
    setState(() => _future = AppDependencies.bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDependencies>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AppDependencies> snapshot) {
        if (snapshot.hasError) {
          return _StartupErrorApp(error: snapshot.error!, onRetry: _retry);
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashScreen(),
          );
        }
        return EduManagerApp(dependencies: snapshot.data!);
      },
    );
  }
}

/// Last-resort screen when local storage cannot be opened at all.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 16),
                const Text(
                  'EDU Manager could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
