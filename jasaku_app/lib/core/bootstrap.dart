import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../firebase/firebase_options.dart';
import '../features/notifications/data/services/fcm_manager.dart';
import '../services/routing_service.dart';

Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FcmManager().initialize();

  RoutingService.init(
    const String.fromEnvironment('ORS_API_KEY', defaultValue: ''),
  );

  runApp(app);
}
