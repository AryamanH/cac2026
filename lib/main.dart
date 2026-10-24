import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';
import 'data/firestore_service_graph_repository.dart';
import 'data/service_graph_repository.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'state/service_graph_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Live backend when Firebase is configured, local demo data otherwise,
  // so the app always runs.
  ServiceGraphRepository repo;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    repo = FirestoreServiceGraphRepository(uid: user.uid);
    debugPrint('Service Graph: live on Firebase as ${user.uid}');
  } catch (e) {
    debugPrint('Service Graph: Firebase unavailable, using demo data ($e)');
    repo = InMemoryServiceGraphRepository();
  }
  runApp(FirstNinetyDaysApp(repo: repo));
}

class FirstNinetyDaysApp extends StatefulWidget {
  const FirstNinetyDaysApp({super.key, required this.repo});
  final ServiceGraphRepository repo;

  @override
  State<FirstNinetyDaysApp> createState() => _FirstNinetyDaysAppState();
}

class _FirstNinetyDaysAppState extends State<FirstNinetyDaysApp> {
  late final AppState _app = AppState()..load();
  late final ServiceGraphController _graph = ServiceGraphController(widget.repo)
    ..load();

  @override
  void dispose() {
    _app.dispose();
    _graph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The First 90 Days',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AppShell(app: _app, graph: _graph),
    );
  }
}
