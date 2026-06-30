// Entry point aplikasi provider Jasaku Mitra dengan tema teal dan route khusus provider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/provider_welcome_screen.dart';
import 'features/auth/presentation/screens/provider_login_screen.dart';
import 'features/auth/presentation/screens/provider_register_category_screen.dart';
import 'features/auth/presentation/providers/register_state.dart';
import 'features/auth/presentation/screens/provider_faq_screen.dart';
import 'features/auth/presentation/screens/provider_terms_screen.dart';
import 'features/provider/presentation/screens/provider_shell.dart';
import 'core/bootstrap.dart';


void main() {
  bootstrap(
    const ProviderScope(
      child: JasakuProviderApp(),
    ),
  );
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
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const ProviderWelcomeScreen(),
        '/login': (_) => const ProviderLoginScreen(),
        '/register': (_) => ProviderRegisterCategoryScreen(state: RegisterState()),
        '/faq': (_) => const ProviderFaqScreen(),
        '/terms': (_) => const ProviderTermsScreen(),
        '/provider/shell': (_) => const ProviderShell(),
      },
    );
  }
}
