import 'dart:core';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/main.dart';
import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/services/auth.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:rgtennisladder/shared/loading.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

int ladderHour=-1;
int ladderMin=-1;

String? playerValidator(val) {
  if (val.isEmpty) {
    return 'Your Name, first and last are required';
  }
  if (val.substring(val.length - 1) == ' ') {
    return 'No trailing space at the end of your name';
  }
  if (val[0] == ' ') {
    return 'No leading space at the beginning of your name';
  }
  if (val.indexOf('  ') >= 0) {
    return 'You can not have 2 spaces together';
  }
  if (val[0].toUpperCase() != val[0]) {
    return 'Your first name should start with an upper case letter';
  }
  int index = val.indexOf(' ');
  if (index < 0) {
    return 'You must enter 2 names, First and Last';
  } else {
    if (val[index + 1].toUpperCase() != val[index + 1]) {
      return 'Your last name should start with an upper case letter';
    }
  }
  return null;
}

void setLadder(String val) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  prefs.setString('ladderName', val);
  fireStoreCollectionName = val;
  final regexp = RegExp(r'(\d+)([abc]?)$');  // from $ end of line, optional a,b,c preceded by 1 or more numeric digits
  final match = regexp.firstMatch(fireStoreCollectionName);
  if (match == null){
    ladderHour=0;
    ladderMin=0;
    return;
  }
  String? timeStr = match.group(1);
  if (timeStr == null){
    ladderHour=0;
    ladderMin=0;
    return;
  }
  // print("timeStr: $timeStr, match: ${match[0]}, ${match[1]}, ${match[2]}");
  int minutes = int.parse(timeStr);
  ladderHour = minutes ~/ 100;
  ladderMin = minutes % 100;
  if  ( ladderHour < 9 ) { // assume anything less than 8:59 is PM, you can also use 24 hour clock
    ladderHour += 12;
  }

  if (kDebugMode) {
    print('setLadder: fireStoreCollectionName now: $fireStoreCollectionName');
    print('setLadder: time of ladder now: $timeStr $ladderHour : $ladderMin' );

  }
}

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  SignInState createState() => SignInState();
}

class SignInState extends State<SignIn> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  String _ladder = fireStoreCollectionName;
  String? _player = loggedInPlayerName;
  String email = '';
  String password = '';
  String error = '';

  String? ladderValidator(val) {
    return val!.isEmpty ? 'The ladder you are in is required' : null;
  }

  void _setLadder(String val) async {
    _ladder = val;
    setLadder(val);
  }

  void setPlayer(String val) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _player = val;

    prefs.setString('playerName', val);
    loggedInPlayerName = val;
  }

  @override
  Widget build(BuildContext context) {
    if (fireStoreCollectionName.isEmpty) {
      _ladder = ladderList[0];
      setCollectionName(ladderList[0]);
    }

    return loading
        ? const Loading()
        : Scaffold(
            backgroundColor: Colors.brown[100],
            appBar: AppBar(
                backgroundColor: Colors.brown[400],
                toolbarHeight: 80.0,
                elevation: 0.0,
                title: const Text('Please sign in'),
                actions: const <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[],
                  ),
                ]),
            body: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 50.0),
                children: [
                  AutofillGroup(
                    child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Column(children: [
                              const SizedBox(height: 20.0),

                              Row(
                                children: [
                                  // const Text(
                                  //   ':',
                                  //   style: nameStyle,
                                  // ),
                                  FormField<String>(
                                      builder: (FormFieldState<String> state) {
                                    return Expanded(
                                      child: InputDecorator(
                                        decoration: textInputDecoration,
                                        child: SizedBox(
                                          height: 45,
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              style: nameStyle,
                                              items: ladderList
                                                  .map((String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                );
                                              }).toList(),
                                              value: _ladder,
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _setLadder(val);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),

                              const SizedBox(height: 20.0),
                              TextFormField(
                                initialValue: _player,
                                decoration: textInputDecoration.copyWith(
                                  hintText: 'First Name AND Last name',
                                  suffixIcon: const Icon(Icons.verified_user),
                                ),
                                validator: playerValidator,
                                onChanged: (val) {
                                  String newVal = val.trim();
                                  newVal = newVal.replaceAll('  ', ' ');
                                  setState(() {
                                    setPlayer(newVal);
                                  });
                                },
                              ),
                              const SizedBox(height: 20.0),
                              TextFormField(
                                decoration: textInputDecoration.copyWith(
                                    hintText: 'Email',
                                    suffixIcon: const Icon(Icons.email)),
                                keyboardType: TextInputType.emailAddress,
                                // autofillHints: const [
                                //   AutofillHints.username,
                                //   AutofillHints.email,
                                // ],
                                validator: (val) => (val!.isEmpty || val.contains(" ")||val.contains(".."))
                                    ? 'A valid email is required, no spaces'
                                    : null,
                                onChanged: (val) {
                                  setState(() => email = val);
                                  error='';
                                },
                              ),
                              const SizedBox(height: 20.0),
                              TextFormField(
                                decoration: textInputDecoration.copyWith(
                                    hintText: 'Password',
                                    suffixIcon: const Icon(Icons.password)),
                                validator: (val) => (val!.length < 6)
                                    ? 'Password has to be at least 6 chars long'
                                    : null,
                                // obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                onChanged: (val) {
                                  setState(() => password = val);
                                },
                              ),
                              const SizedBox(height: 20.0),
                              ElevatedButton(
                                style: const ButtonStyle(
                                  backgroundColor: MaterialStatePropertyAll<Color>(Colors.green)
                                ),
                                onPressed: () async {
                                  dynamic result;
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => loading = true);
                                    setCollectionName(_ladder);
                                    result =
                                        await _auth.signInWithEmailAndPassword(
                                            email, password);

                                    if (result == null) {
                                      setState(() {
                                        error = signInErrorString;
                                            // 'could not sign in with those credentials';
                                        loading = false;
                                      });
                                    } else {
                                        if (kDebugMode) {
                                          print('sign_in new player: $_player');
                                        }
                                        loggedInPlayerName = _player!;
                                        fireStoreCollectionName = _ladder;
                                        signedInEmail = email;
                                        bool success= await Player.setEmail(
                                            loggedInPlayerName!, signedInEmail);
                                        if (!success){
                                          // the entered name does not match a current document in the database
                                          // so fail the login.
                                          if (kDebugMode) {
                                            print('FAILED to find name $_player! in the database $fireStoreCollectionName');
                                          }
                                        }
                                    }
                                  }
                                },
                                child: const Text('Sign In',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                error,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: appFontSize),
                              ),
                              const SizedBox(height: 12.0),
                              (email.contains('@'))?
                              OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.blue),
                                  onPressed: () {
                                    if (kDebugMode) {
                                      print('password reset to $email');
                                    }

                                    FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                        email: email)
                                    .then((value){
                                      if (kDebugMode) {
                                        print('RESET Password for $email');
                                      }
                                      setState(() {
                                        error = 'Email sent to $email';
                                      });
                                    })
                                    .catchError((e){
                                      setState(() {
                                        error = e.toString();
                                      });

                                      if (kDebugMode) {
                                        print('got error on password reset for $email : $e.');
                                      }
                                    });
                                  },

                                  child: const Text('Send Password Reset Email')):const SizedBox(height: 44.0,
                                  child: Text('First Enter Email Address,\nto request a password reset')),
                            ]),
                          ],
                        )),
                  )
                ]));
  }
}
