import 'package:flutter/material.dart';

import 'app_state.dart';
import 'core/theme.dart';
import 'features/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.create();
  runApp(SafeAlertApp(state: state));
}

/// Gives every screen access to [AppState] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class SafeAlertApp extends StatelessWidget {
  const SafeAlertApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'SafeAlert ICT',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
