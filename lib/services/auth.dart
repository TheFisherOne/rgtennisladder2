import 'package:firebase_auth/firebase_auth.dart';
import 'package:rgtennisladder/models/appuser.dart';
import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/services/player_db.dart';


class AuthService {
  final FirebaseAuth _auth= FirebaseAuth.instance;

  Appuser? _userFromFirebaseUser(User? user){
    return user!=null ? Appuser(user.uid): null;
  }

  // auth change user stream
  Stream<Appuser?> get user {
    return _auth.authStateChanges().map((User? user) => _userFromFirebaseUser(user));
    // .map(_userFromFirebaseUser)
  }

  // sign in with email and password

  Future signInWithEmailAndPassword(String email, String password) async {
    try {
      Player.admin1Enabled=false;
      Player.admin2Enabled=false;

      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password);

      User? fbUser= result.user;
      return _userFromFirebaseUser(fbUser);
    } catch(e){
      if (kDebugMode) {
        print('e5 ${e.toString()}');
      }
      return null;
    }
  }


  // sign out
  Future signOut() async{
    try {
      Player.admin1Enabled=false;
      Player.admin2Enabled=false;
      return await _auth.signOut();
    } catch(e){
      if (kDebugMode) {
        print('e6 ${e.toString()}');
      }
      return null;
    }
  }
}