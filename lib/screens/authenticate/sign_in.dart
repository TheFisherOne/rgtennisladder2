import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/main.dart';
import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/services/auth.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:rgtennisladder/shared/loading.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? playerValidator(val) {
  if (val.isEmpty) {
    return 'Your Name, first and last are required';
  }
  // if (val.substring(val.length - 1) == ' ') {
  //   return 'No trailing space at the end of your name';
  // }
  // if (val[0] == ' ') {
  //   return 'No leading space at the beginning of your name';
  // }
  // if (val.indexOf('  ') >= 0) {
  //   return 'You can not have 2 spaces together';
  // }
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
  if (kDebugMode) {
    print('setLadder: fireStoreCollectionName now: $fireStoreCollectionName');
  }
}
class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
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

    if (fireStoreCollectionName.isEmpty){
      _ladder=ladderList[0];
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
                actions: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: const <Widget>[],
                  ),
                ]),
            body: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 50.0),
                children: [Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AutofillGroup(
                          child: Column(children: [
                            const SizedBox(height: 20.0),

                            Row(
                              children: [
                                const Text(
                                  ':',
                                  style: nameStyle,
                                ),
                                FormField<String>(
                                  builder: (FormFieldState<String> state){
                                  return Expanded(
                                    child: InputDecorator(
                                      decoration: textInputDecoration,
                                      child: SizedBox(
                                        height: 25,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            style: nameStyle,
                                            items: ladderList.map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            }).toList(),
                                            value: _ladder,
                                            onChanged: (val) {
                                              if (val != null) {
                                                if (val == 'testing') {
                                                  val = 'rgtennisladdermonday600';
                                                }
                                                setState(() {
                                                  _setLadder(val!);
                                                });
                                              }
                                            },
                                ),
                                        ),
                                      ),
                                    ),
                                  );}),
                              ],
                            ),
                            // TextFormField(
                            //   initialValue: _ladder,
                            //   decoration: textInputDecoration.copyWith(
                            //     hintText: 'Ladder Name',
                            //     suffixIcon: const Icon(Icons.group),
                            //   ),
                            //   validator: ladderValidator,
                            //   onChanged: (val) {
                            //
                            //     setState(() {
                            //       setLadder(val);
                            //     });
                            //   },
                            // ),
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
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              validator: (val) => val!.isEmpty
                                  ? 'A valid email is required'
                                  : null,
                              onChanged: (val) {
                                setState(() => email = val);
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
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              onChanged: (val) {
                                setState(() => password = val);
                              },
                            ),
                            const SizedBox(height: 20.0),
                            ElevatedButton(
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
                                      error =
                                          'could not sign in with those credentials';
                                      loading = false;
                                    });
                                  } else {
                                    loggedInPlayerName = _player!;
                                    fireStoreCollectionName = _ladder;
                                    signedInEmail = email;
                                    Player.setEmail(loggedInPlayerName!, signedInEmail);
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
                            )
                          ]),
                        ),
                      ],
                    ))]));
  }
}
