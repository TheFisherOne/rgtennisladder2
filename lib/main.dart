// import 'package:firebase_messaging/firebase_messaging.dart';
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

  // @override
  // void initState() {
  //   super.initState();
  //   _getInstanceId();
  // }
  //
  // void _getInstanceId() async {
  //   kIsWeb ? await Firebase.initializeApp(options:firebaseConfig):await Firebase.initializeApp();
  //   print('initializeApp #1');
  //   var token = await FirebaseMessaging.instance.getToken(vapidKey:
  //       "BIJRH946B5EhhmsTY_ktd4njzHVDrgSmBbJ_ld1_m4-v6H576G4NwBjCq1bNWFJb3jdKu5HW0fDhqWQz4MI7ytM");
  //   if (token != null) {
  //     print("Instance ID: " + token);
  //   } else {
  //     print("null token received from FirebaseMessaging");
  //   }
  // }

  // void _initMessaging()async {
  @override
  Widget build(BuildContext context) {
    // print('in main build');
    fireStoreCollectionName = context.read<SharedPreferences>().getString('ladderName')??'';

    loggedInPlayerName = context.read<SharedPreferences>().getString('playerName')??'';
    if (kDebugMode) {
      print('On startup read from device local Ladder: $fireStoreCollectionName Name: $loggedInPlayerName');
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

