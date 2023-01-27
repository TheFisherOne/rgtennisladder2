import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/screens/home/home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'authenticate/sign_in.dart';

String loggedInUID='';
// String loggedInPlayerName='';

class Wrapper extends StatelessWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // return either Home or Authenticate
    // var currentUser = FirebaseAuth.instance.currentUser;
    var appUser = Provider.of<Appuser?>(context);
    // print('Wrapper $appUser ${appUser?.uid}');
    if (appUser!=null){
      loggedInUID=appUser.uid;
      return const Home();
    } else {
      loggedInUID='';
      return const SignIn();
    }
  }
}
