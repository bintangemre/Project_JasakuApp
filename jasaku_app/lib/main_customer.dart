// Entry point aplikasi customer Jasaku dengan tema biru dan route khusus customer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/customer/presentation/screens/customer_shell.dart';

void main() {
  runApp(const ProviderScope(child: JasakuCustomerApp()));
}

class JasakuCustomerApp extends StatelessWidget {
  const JasakuCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title ambil name pengguna
      title: 'Jasaku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E40AF),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(expectedRole: 'customer'),
        '/register': (_) => const RegisterScreen(),
        '/customer/shell': (_) => const CustomerShell(),
      },
    );
  }
}
