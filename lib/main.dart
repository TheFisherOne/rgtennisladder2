import 'package:flutter/services.dart';
import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/screens/wrapper.dart';
import 'package:rgtennisladder/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:rgtennisladder/services/player_db.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebaseAuth.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    fireStoreCollectionName = context.read<SharedPreferences>().getString('ladderName')??'';
    if (kDebugMode) {
      print('in main build: fireStoreCollectionName set to $fireStoreCollectionName');
    }
    loggedInPlayerName = context.read<SharedPreferences>().getString('playerName')??'';

    return FutureBuilder(
      future: kIsWeb ? Firebase.initializeApp(options:firebaseConfig):Firebase.initializeApp(),
      builder: (context,snapshot) {
        if (snapshot.hasError){
          return Text('ERROR!${snapshot.error.toString()}',textDirection: TextDirection.ltr);
        }
        if (snapshot.connectionState == ConnectionState.done){

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

