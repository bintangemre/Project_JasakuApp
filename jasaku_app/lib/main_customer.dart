// Entry point aplikasi customer Jasaku dengan tema biru dan route khusus customer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/customer_login_screen.dart';
import 'features/auth/presentation/screens/customer_register_screen.dart';
import 'features/customer/presentation/screens/customer_shell.dart';
import 'core/bootstrap.dart';
import 'core/theme/app_theme.dart';


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
      title: 'Jasaku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.customerTheme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const CustomerLoginScreen(),
        '/register': (_) => const CustomerRegisterScreen(),
        '/customer/shell': (_) => const CustomerShell(),
      },
    );
  }
}
