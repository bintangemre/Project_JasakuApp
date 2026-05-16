// Entry point aplikasi provider Jasaku Mitra dengan tema teal dan route khusus provider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/provider/presentation/screens/provider_shell.dart';

void main() {
  runApp(const ProviderScope(child: JasakuProviderApp()));
}

class JasakuProviderApp extends StatelessWidget {
  const JasakuProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jasaku Mitra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F766E),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(expectedRole: 'provider'),
        '/register': (_) => const RegisterScreen(),
        '/provider/shell': (_) => const ProviderShell(),
      },
    );
  }
}
