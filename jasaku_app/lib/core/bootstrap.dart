import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../firebase/firebase_options.dart';

Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(app);
}
