
import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/screens/wrapper.dart';
import 'package:rgtennisladder/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:rgtennisladder/services/player_db.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_authorization.dart';

String? loggedInPlayerName;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await SystemChrome.setPreferredOrientations([
    // DeviceOrientation.portraitUp,
    // DeviceOrientation.landscapeLeft,
    // DeviceOrientation.portraitDown,
    // DeviceOrientation.landscapeRight
  // ]);
  runApp(MultiProvider(providers: [
    Provider.value(value: await SharedPreferences.getInstance()),
  ],
      child: const MyApp(),
  )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    // print('in main build');

    String newLadder = context.read<SharedPreferences>().getString('ladderName')??'';
    setCollectionName(newLadder);

    loggedInPlayerName = context.read<SharedPreferences>().getString('playerName')??'';
    if (kDebugMode) {
      print('On startup read from SharedPreferences local Ladder: $fireStoreCollectionName Name: $loggedInPlayerName');
    }
    return FutureBuilder(
      future: kIsWeb ? Firebase.initializeApp(options:firebaseConfig):Firebase.initializeApp(),
      builder: (context,snapshot)  {
        // print('in future builder');
        // _initMessaging();
        if (snapshot.hasError){
          return Text('ERROR!${snapshot.error.toString()}',textDirection: TextDirection.ltr);
        }
        if (snapshot.connectionState == ConnectionState.done){
          // print('main.dart ${FirebaseAuth.instance.currentUser?.email}');
          return StreamProvider<Appuser?>.value(
              value: AuthService().user,
              initialData: null,
              child: const MaterialApp(
                  home: Wrapper()));
        }
        // initializeCamera();
        return const Text('LOADING...',textDirection: TextDirection.ltr);
      },
    );

  }
}

