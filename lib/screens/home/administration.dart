import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/screens/authenticate/sign_in.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home.dart';

class Administration extends StatefulWidget {
  const Administration({Key? key}) : super(key: key);

  @override
  AdministrationState createState() => AdministrationState();
}

class AdministrationState extends State<Administration> {
  String _enteredName = '';
  String _selectedPlayer = Player.db.first.playerName;
  int _newRank = 0;
  int _newAdminLevel = 0;
  final TextEditingController _createUserController = TextEditingController();
  String _newEmail='';
  String _newPassword='';
  String _newUserErrorMessage='';

  void createUser() async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _newEmail,
        password: _newPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        if (kDebugMode) {
          print('The password provided is too weak.');
        }
        _newUserErrorMessage='The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('The account already exists for that email.');
        }
        _newUserErrorMessage='The account already exists for that email.';
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      _newUserErrorMessage=e.toString();
      return;
    }
    _newEmail='';
    _newPassword='';
    _newUserErrorMessage='';
  }

  @override
  Widget build(BuildContext context) {
    OutlinedButton makeDoubleConfirmationButton(
        {buttonText,
        buttonColor = Colors.blue,
        dialogTitle,
        dialogQuestion,
        disabled,
        onOk}) {
      // print('administration build ${Player.admin1Enabled}');
      return OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black, backgroundColor: buttonColor),
          onPressed: disabled
              ? null
              : () => showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text(dialogTitle),
                        content: Text(dialogQuestion),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('cancel')),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  onOk();
                                });

                                Navigator.pop(context);
                              },
                              child: const Text('OK')),
                        ],
                      )),
          child: Text(buttonText));
    }



    return StreamBuilder<bool>(
        stream: Player.onUpdate.stream,
        //note the snapshot is not used, this stream is used to detect updates to the Player.db
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {

          var listOfPlayers = Player.db.map((Player pl) {
            return DropdownMenuItem<String>(
                value: pl.playerName,
                child: Text('${pl.currentRank}: ${pl.playerName}'));
          }).toList();

          return Scaffold(
              backgroundColor: Colors.brown[50],
              appBar: AppBar(
                title: const Text('Administration:'),
                backgroundColor: Colors.brown[400],
                elevation: 0.0,
                actions: const [],
              ),
              body: ListView(shrinkWrap: true, children: [
                // OutlinedButton(
                //   style: OutlinedButton.styleFrom(
                //       foregroundColor: Colors.black, backgroundColor: Colors.blue),
                //   onPressed: () {
                //     Navigator.push(context, MaterialPageRoute(builder:(context)=>const ShowRules()));
                //   },
                //   child: const Text('Open PDF of rules'),
                // ),
                const SizedBox(height:10),
                makeDoubleConfirmationButton(
                    buttonText: 'Send Reset Password Email',
                    dialogTitle: 'The reset expires in 1 hour',
                    dialogQuestion: 'Are you sure you want to reset your password?',
                    disabled: false,
                    onOk: () {
                      //print('PASSWORD RESET REQUESTED $signedInEmail');
                      FirebaseAuth.instance.sendPasswordResetEmail(email: signedInEmail);
                    }),

                CheckboxListTile(
                    title: const Text('Administrator 1 Mode'),
                    value: Player.admin1Enabled,
                    onChanged: !Player.loggedInUserIsAdmin1()
                        ? null
                        : (value) {
                            if (homeStateInstance != null) {
                              setState(() {
                                Player.admin1Enabled = !(Player.admin1Enabled);
                                homeStateInstance!.updateAdmin1();
                              });
                            }
                          }),
                CheckboxListTile(
                    title: const Text('Administrator 2 Mode'),
                    value: Player.admin2Enabled,
                    onChanged: !Player.loggedInUserIsAdmin2() |
                            !Player.admin1Enabled
                        ? null
                        : (value) {
                            if (homeStateInstance != null) {
                              setState(() {
                                Player.admin2Enabled = !(Player.admin2Enabled);
                              });
                            }
                          }),
                CheckboxListTile(
                    title: const Text('Freeze Check Ins'),
                    value: Player.freezeCheckins,
                    onChanged: !Player.admin1Enabled
                        ? null
                        : (value) {
                            if (homeStateInstance != null) {
                              setState(() {
                                Player.updateFreezeCheckIns(value!);
                              });
                            }
                          }),
                makeDoubleConfirmationButton(
                    buttonText: 'Zero Scores',
                    dialogTitle: 'Zero Scores',
                    dialogQuestion: 'Are you sure you want to start from zero?',
                    disabled: !Player.admin2Enabled,
                    onOk: () {
                      Player.clearAllScores(clearPresentAsWell: false);
                    }),
                Row(
                  children: [
                    const Expanded(
                        child: Text(
                      'Courts available:',
                      style: nameStyle,
                    )),
                    Expanded(
                      child: TextFormField(
                          initialValue: Player.courtsAvailable.toString(),
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.center,
                          // decoration: decoration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  int result = 4;
                                  try {
                                    result = int.parse(value);
                                    Player.setCourtsAvailable(result);
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print('e1 ${e.toString()}');
                                    }
                                  }
                                }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                        child: Text(
                      'Shift for 5 players:',
                      style: nameStyle,
                    )),
                    Expanded(
                      child: TextFormField(
                          initialValue: Player.shift5Player.toString(),
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.center,
                          // decoration: decoration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  if (kDebugMode) {
                                    print('FUTURE:write shift5player');
                                  }
                                }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                        child: Text(
                      'How Close:',
                      style: nameStyle,
                    )),
                    Expanded(
                      child: TextFormField(
                          initialValue: Player.rgHowClose.toString(),
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.center,
                          // decoration: decoration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  if (kDebugMode) {
                                    print('FUTURE:write rgHowClose');
                                  }
                                }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                        child: Text(
                      'Club latitude:',
                      style: nameStyle,
                    )),
                    Expanded(
                      child: TextFormField(
                          initialValue: Player.rgLatitude.toString(),
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.center,
                          // decoration: decoration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  if (kDebugMode) {
                                    print('FUTURE:write latitude');
                                  }
                                }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                        child: Text(
                      'Club longitude:',
                      style: nameStyle,
                    )),
                    Expanded(
                      child: TextFormField(
                          initialValue: Player.rgLongitude.toString(),
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.center,
                          // decoration: decoration,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  if (kDebugMode) {
                                    print('FUTURE:write rgLatitude');
                                  }
                                }),
                    ),
                  ],
                ),
                makeDoubleConfirmationButton(
                    buttonText: 'Finalize Scores and Move Players',
                    dialogTitle: 'Finalize Scores',
                    dialogQuestion: 'Are you sure you want to move everyone?',
                    disabled: !Player.admin2Enabled,
                    onOk: () {
                      Player.applyMovement();
                    }),
                Row(
                  children: [
                    makeDoubleConfirmationButton(
                        buttonText: 'Create User',
                        dialogTitle: 'Create User',
                        dialogQuestion:
                            'Are you sure you want to create a user named $_enteredName?',
                        disabled:
                            (!Player.admin2Enabled | _enteredName.isEmpty),
                        onOk: () {
                          String val=_enteredName.trim();
                          val=val.replaceAll('  ', ' ');
                          if (playerValidator(val)==null) {
                            Player.createUser(_enteredName);
                            setState(() {
                              _enteredName = '';
                              _createUserController.text = '';
                            });
                          } else {
                            if (kDebugMode) {
                              print('ERROR invalid name entered for new player');
                            }
                          }
                        }),
                    Expanded(
                      child: TextFormField(
                          controller: _createUserController,
                          enabled: Player.admin2Enabled,
                          style: nameStyle,
                          textAlign: TextAlign.start,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter,
                            LengthLimitingTextInputFormatter(20)
                          ],
                          onChanged: !Player.admin2Enabled
                              ? null
                              : (String value) {
                                  setState(() {
                                    _enteredName = value.trim();
                                  });
                                }),
                    ),
                  ],
                ),
                Row(children: [
                  Expanded(
                    child: DropdownButton(
                      items: listOfPlayers,
                      onChanged: (widSelected) {
                        setState(() {
                          _selectedPlayer = widSelected.toString();
                        });
                      },
                      value: _selectedPlayer,
                    ),
                  ),
                  makeDoubleConfirmationButton(
                      buttonText: 'Delete User',
                      dialogTitle: 'Delete User',
                      dialogQuestion:
                          'Are you sure you want to delete a user named $_selectedPlayer?',
                      disabled: (!Player.admin2Enabled),
                      onOk: () {
                        Player.deleteUser(_selectedPlayer);
                        setState(() {
                          if (_selectedPlayer==Player.db.first.playerName){
                            _selectedPlayer= Player.db[1].playerName;
                          }else {
                            _selectedPlayer = Player.db.first.playerName;
                          }
                        });
                      })
                ]),
                Row(children: [
                  makeDoubleConfirmationButton(
                      buttonText: 'Change Rank',
                      dialogTitle: 'Set a new Rank',
                      dialogQuestion:
                          'Are you sure you want to set the rank of the user named $_selectedPlayer to $_newRank?',
                      disabled: (!Player.admin2Enabled |
                          (_newRank <= 0) |
                          (_newRank > Player.db.length)),
                      onOk: () {
                        Player.updateRank(_selectedPlayer, _newRank);
                      }),
                  Expanded(
                    child: TextFormField(
                        initialValue: _newRank.toString(),
                        enabled: Player.admin2Enabled,
                        style: nameStyle,
                        textAlign: TextAlign.center,
                        // decoration: decoration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2)
                        ],
                        onChanged: !Player.admin2Enabled
                            ? null
                            : (String value) {
                                setState(() {
                                  _newRank = 0;
                                  try {
                                    _newRank = int.parse(value);
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print('e2 ${e.toString()}');
                                    }
                                  }
                                });
                              }),
                  ),
                ]),
                Row(children: [
                  makeDoubleConfirmationButton(
                      buttonText: 'Change Admin Level',
                      dialogTitle: 'Change Admin Level',
                      dialogQuestion:
                          'Are you sure you want to set the admin level of the user named $_selectedPlayer to $_newAdminLevel?',
                      disabled: (!Player.admin2Enabled | (_newAdminLevel < 0)),
                      onOk: () {
                        Player.setAdminLevel(_selectedPlayer, _newAdminLevel);
                      }),
                  Expanded(
                    child: TextFormField(
                        initialValue: '0',
                        enabled: Player.admin2Enabled,
                        style: nameStyle,
                        textAlign: TextAlign.center,
                        // decoration: decoration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2)
                        ],
                        onChanged: !Player.admin2Enabled
                            ? null
                            : (String value) {
                                setState(() {
                                  _newAdminLevel = 0;
                                  try {
                                    _newAdminLevel = int.parse(value);
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print('e3 ${e.toString()}');
                                    }
                                  }
                                });
                              }),
                  ),
                ]),
                (fireStoreCollectionName.substring(0,9)=='rg_monday')?
                makeDoubleConfirmationButton(
                    buttonText: 'Move to other Ladder',
                    dialogTitle: 'Move to other Ladder',
                    dialogQuestion:
                    'Are you sure you want to move $_selectedPlayer? to the other ladder',
                    disabled: (!Player.admin2Enabled),
                    onOk: () {
                      Player.moveToOtherLadder(_selectedPlayer);
                      setState(() {


                      if (_selectedPlayer==Player.db.first.playerName){
                        _selectedPlayer= Player.db[1].playerName;
                      }else {
                        _selectedPlayer = Player.db.first.playerName;
                      }
                      });
                    }):const Text(''),
                const SizedBox(height: 10.0),
                TextFormField(
                  enabled: (Player.admin2Enabled),
                  decoration: textInputDecoration.copyWith(
                      hintText: 'Email',
                      suffixIcon: const Icon(Icons.email)),
                  obscureText: false,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (val) {
                    setState(() => _newEmail = val);
                  },
                ),
                const SizedBox(height: 10.0),
                TextFormField(
                  enabled: (Player.admin2Enabled),
                  decoration: textInputDecoration.copyWith(
                      hintText: 'Password',
                      suffixIcon: const Icon(Icons.password)),
                  validator: (val) => (val!.length < 6)
                      ? 'Password has to be at least 6 chars long'
                      : null,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (val) {
                    setState(() => _newPassword = val);
                  },
                ),
                const SizedBox(height: 10.0),
                ((_newEmail.length>=6)&&(_newPassword.length>=6))?
                makeDoubleConfirmationButton(
                    buttonText: 'create new Login',
                    dialogTitle: 'Create a new login for $_newEmail ?',
                    dialogQuestion:
                    'Are you sure you want to create a new login for $_newEmail?\n NOTE: YOU WILL BE LOGGED IN AS THEM\nYou will need to logout!',
                    disabled: (!Player.admin2Enabled),
                    onOk: () {
                      createUser(); // this is async

                    }):const Text(''),
                Text(_newUserErrorMessage),
                const SizedBox(height: 10.0),
                makeDoubleConfirmationButton(
                    buttonText: 'Disassociate this Name with any email',
                    dialogTitle: 'Disassociate this Name with any email',
                    dialogQuestion:
                        'Are you sure you want a new email to attach to this account  $_selectedPlayer?',
                    disabled: (!Player.admin2Enabled),
                    onOk: () {
                      Player.clearUID(_selectedPlayer);
                    }),
              ]));
        });
  }
}
