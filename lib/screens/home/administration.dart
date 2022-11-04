import 'package:rgtennisladder/models/appuser.dart';
import 'package:rgtennisladder/screens/authenticate/sign_in.dart';
import 'package:rgtennisladder/screens/home/show_rules.dart';
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
  _AdministrationState createState() => _AdministrationState();
}

class _AdministrationState extends State<Administration> {
  String _enteredName = '';
  String _selectedPlayer = Player.db.first.playerName;
  int _newRank = 0;
  int _newAdminLevel = 0;
  final TextEditingController _createUserController = TextEditingController();

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
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black, backgroundColor: Colors.blue),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder:(context)=>const ShowRules()));
                  },
                  child: const Text('Open PDF of rules'),
                ),
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
                                //print('onchanged of freezecheckins');
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
                makeDoubleConfirmationButton(
                    buttonText: 'Reset Login Credentials',
                    dialogTitle: 'Reset Login Credentials',
                    dialogQuestion:
                        'Are you sure you want remove login credentials for  $_selectedPlayer?',
                    disabled: (!Player.admin2Enabled),
                    onOk: () {
                      Player.clearUID(_selectedPlayer);
                    }),
              ]));
        });
  }
}
