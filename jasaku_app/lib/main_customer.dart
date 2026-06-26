// Entry point aplikasi customer Jasaku dengan tema biru dan route khusus customer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/customer_login_screen.dart';
import 'features/auth/presentation/screens/customer_register_screen.dart';
import 'features/customer/presentation/screens/customer_shell.dart';
import 'core/bootstrap.dart';


void main() {
  bootstrap(
    const ProviderScope(
      child: JasakuCustomerApp(),
    ),
  );
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
        '/login': (_) => const CustomerLoginScreen(),
        '/register': (_) => const CustomerRegisterScreen(),
        '/customer/shell': (_) => const CustomerShell(),
      },
    );
  }
}
