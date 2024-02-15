import 'dart:async';
import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/main.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

List<int> playersOnCourt = List.filled(5, 0);
int playerToEnterScore = 0;
List<int> origScores = List.filled(25, -9);
List<int> newScores = List.filled(25, -9);
List<bool> edited = List.filled(25, false);

bool _enableScoreEntry = false;
Timer? entryTimer;
bool forceExit = false;
List<String> playerNamesOnCourt = List.filled(5, "");

class EnterScores3 extends StatefulWidget {
  const EnterScores3({Key? key}) : super(key: key);

  @override
  EnterScores3State createState() => EnterScores3State();

  static void prepareForScoreEntry(newPlayersOnCourt, newPlayerToEnterScore) {
    _enableScoreEntry = false;
    newScores.fillRange(0, newScores.length, -9);
    edited.fillRange(0, edited.length, false);
    if (Player.admin1Enabled) {
      _enableScoreEntry = true;
    }
    forceExit = false;
    if (entryTimer != null) {
      entryTimer!.cancel();
      entryTimer = null;
    }
    playersOnCourt = newPlayersOnCourt;
    playerToEnterScore = newPlayerToEnterScore;

    var pdb = Player.db;
    for (int pl = 0; pl < 5; pl++) {
      if (playersOnCourt[pl] >= 0) {
        if (playersOnCourt[pl] == newPlayerToEnterScore) {
          _enableScoreEntry = true;
        }
        playerNamesOnCourt[pl] = pdb[playersOnCourt[pl]].playerName;
      } else {
        playerNamesOnCourt[pl] = '';
      }
    }
    // print('score entry enabled? $_enableScoreEntry');
  }
}

class EnterScores3State extends State<EnterScores3> {
  int _exitCountdown = scoreEntryTimeout;
  Timer? _timer;
  String _errorString1 = '';
  List<String> scoreLastUpdatedBy = List.filled(5, '');
  bool _plusMinus = true;
  String _confirmedBy = '';
  String _lastScoreEntryBy = '';

  void startTimer() {
    _exitCountdown = scoreEntryTimeout;
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_exitCountdown == 0) {
          setState(() {
            timer.cancel();
            _timer = null;
          });
        } else {
          setState(() {
            _exitCountdown--;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    super.dispose();
  }

  final List<bool> _problemInSet = List.filled(5, false);

  Widget autoButton(int index) {
    bool courtOf5 = playerNamesOnCourt[4].isNotEmpty;
    // print("$index Court of 5? $courtOf5");

    // print('$index   &&& $newScores   ^^^  $origScores');
    List<int> scores = [
      newScores[0 * 5 + index],
      newScores[1 * 5 + index],
      newScores[2 * 5 + index],
      newScores[3 * 5 + index],
      newScores[4 * 5 + index]
    ];

    int matchingEntered = -1;
    int firstEntered = -1;

      for (int i = 0; i < 5; i++) {
        if (courtOf5) {
          if ((scores[i] < 0) && (i != (4 - index))&&(scores[i]!=(courtOf5?9:11))) {
            scores[i] = origScores[i * 5 + index];
          }
        } else if (scores[i] < 0) {
          scores[i] = origScores[i * 5 + index];
        }
      }

      for (int i = 0; i < 5; i++) {
        if (courtOf5) {
          if ((scores[i] >= 0) && (i != (4 - index))&&(scores[i]!=(courtOf5?9:11))) {
            firstEntered = i;
            break;
          }
        } else if (scores[i] >= 0) {
          firstEntered = i;
          break;
        }
      }
      // print('firstEntered $firstEntered $scores');
      if (firstEntered < 0) {
        // disable autoButton, no scores entered
        return const Text(' ');
      }

      for (int i = firstEntered + 1; i < 5; i++) {
        if (courtOf5) {
          if ((scores[i] == scores[firstEntered]) && (i != (4 - index))) {
            matchingEntered = i;
            break;
          }
        } else if (scores[i] == scores[firstEntered]) {
          matchingEntered = i;
          break;
        }
      }

    // print('matchingEntered $matchingEntered');
    if (matchingEntered < 0) {
      // disable autoButton no score matching first score
      return const Text(' ');
    }

    int unused1;
    for (unused1 = 0; unused1 < 5; unused1++) {
      if (courtOf5) {
        if ((unused1 != firstEntered) &&
            (unused1 != matchingEntered) &&
            (unused1 != (4 - index))) {
          break;
        }
      } else if ((unused1 != firstEntered) && (unused1 != matchingEntered)) {
        break;
      }
    }
    int unused2;
    for (unused2 = unused1 + 1; unused2 < 5; unused2++) {
      if (courtOf5) {
        if ((unused2 != firstEntered) &&
            (unused2 != matchingEntered) &&
            (unused2 != (4 - index))) {
          break;
        }
      } else if ((unused2 != firstEntered) && (unused2 != matchingEntered)) {
        break;
      }
    }
    // print('$firstEntered, $matchingEntered, $unused1, $unused2');
    int scoreSum = scores[firstEntered] + scores[matchingEntered] + scores[unused1] + scores[unused2];
    if (fireStoreCollectionName.substring(3,5)=='PB'){
      //pickleball
      if ((scores[unused1] == (courtOf5?9:11)) && (scores[unused1] == (courtOf5?9:11))) {
        // hide the button if all of the scores are entered
        return const Text(' ');
      }
    } else {
      //tennis
      if (scoreSum == (courtOf5?6:8)*2){
        // hide the score if its all entered
        return const Text(' ');
      }
    }
    return Container(
      margin: const EdgeInsets.all(5),
      child: ElevatedButton(
        onPressed: _enableScoreEntry
            ? () {
                // print('Auto pressed $index');
                // print('UPDATE SCORE: $unused1, $unused2 ${courtOf5?6:8} ${scores[firstEntered]}');
                setState(() {
                  if (fireStoreCollectionName.substring(3,5)=='PB'){
                    newScores[unused1 * 5 + index] = courtOf5?9:11;
                    newScores[unused2 * 5 + index] = courtOf5?9:11;
                  } else {
                    newScores[unused1 * 5 + index] =
                        (courtOf5 ? 6 : 8) - scores[firstEntered];
                    newScores[unused2 * 5 + index] =
                        (courtOf5 ? 6 : 8) - scores[firstEntered];
                  }
                  edited[unused1 * 5 + index] = true;
                  edited[unused2 * 5 + index] = true;
                });
                entryTimer?.cancel();
                entryTimer =
                    Timer(const Duration(seconds: scoreEntryTimeout), () {
                  saveScore();
                  _enableScoreEntry = false;
                  entryTimer = null;
                });
              }
            : null,
        style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
                side: const BorderSide( color: Colors.red, width:4.0 ),
                borderRadius: BorderRadius.circular(20))),
        child: const Text(''),
      ),
    );
  }

  Widget scoreBox(int index) {
    List<int> sitOff = [4, 8, 12, 16, 20];
    bool courtOf5 = true;
    if (playerNamesOnCourt[4].isEmpty) courtOf5 = false;
    bool flagProblem = _problemInSet[index % 5];
    Color color = appBarColor;
    if (flagProblem) {
      color = (edited[index]) ? (Colors.pink.shade100) : Colors.pink;
    } else if (edited[index]) {
      color = Colors.white;
    } else if (courtOf5 && (sitOff.contains(index))) {
      color = Colors.grey;
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 37,
          height: 50,
          child: Container(
              color: color,
              child: InkWell(
                  onTap: _enableScoreEntry
                      ? () {
                          setState(() {
                            edited[index] = true;
                            if ((newScores[index] < 0) &&
                                (origScores[index] < 0)) {
                              newScores[index] = _plusMinus ? 1 : 0;
                            } else if ((newScores[index] < 0) &&
                                (origScores[index] >= 0)) {
                              newScores[index] =
                                  origScores[index] + ((_plusMinus) ? 1 : -1);
                            } else {
                              newScores[index] += _plusMinus ? 1 : -1;
                            }
                            bool courtOf5 = true;
                            if (playerNamesOnCourt[4].isEmpty) courtOf5 = false;

                            if (newScores[index] == -1) {
                              if (fireStoreCollectionName.substring(3, 5) ==
                                  'PB') {
                                newScores[index] = courtOf5 ? 9 : 11;
                              } else {
                                newScores[index] = courtOf5 ? 6 : 8;
                              }
                            } else {
                              if (fireStoreCollectionName.substring(3, 5) ==
                                  'PB') {
                                if (courtOf5) {
                                  if (newScores[index] > 9) {
                                    newScores[index] = 0;
                                  }
                                } else {
                                  if (newScores[index] > 11) {
                                    newScores[index] = 0;
                                  }
                                }
                              } else {
                                if (courtOf5) {
                                  if (newScores[index] > 6) {
                                    newScores[index] = 0;
                                  }
                                } else {
                                  if (newScores[index] > 8) {
                                    newScores[index] = 0;
                                  }
                                }
                              }
                            }
                          });
                          entryTimer?.cancel();
                          entryTimer = Timer(
                              const Duration(seconds: scoreEntryTimeout), () {
                            saveScore();
                            _enableScoreEntry = false;
                            entryTimer = null;
                          });
                        }
                      : null,
                  child: Center(
                    child: Text(
                      (newScores[index] < 0)
                          ? ((origScores[index] < 0)
                              ? ' '
                              : origScores[index].toString())
                          : newScores[index].toString(),
                      style: nameStyle,
                      textAlign: TextAlign.center,
                    ),
                  ))),
        ),
      ),
    );
  }

  Widget scoreLine(int index) {
    const double wid = 40;
    const double hei = 80;
    int lineScore = 0;

    for (int box = index * 5; box < (index * 5 + 5); box++) {
      if (newScores[box] > 0) {
        lineScore += newScores[box];
      } else if (origScores[box] > 0) {
        lineScore += origScores[box];
      }
    }
    return Row(children: [
      SizedBox(
          width: 107,
          height: hei,
          child: Center(
              child: Text(playerNamesOnCourt[index],
                  textAlign: TextAlign.right, style: nameStyle))),
      const SizedBox(
        width: 5,
      ),
      SizedBox(width: wid, height: hei, child: scoreBox(index * 5 + 0)),
      SizedBox(width: wid, height: hei, child: scoreBox(index * 5 + 1)),
      SizedBox(width: wid, height: hei, child: scoreBox(index * 5 + 2)),
      SizedBox(
          width: playerNamesOnCourt[4].isNotEmpty ? wid : 0,
          height: hei,
          child: playerNamesOnCourt[4].isNotEmpty
              ? scoreBox(index * 5 + 3)
              : const SizedBox()),
      SizedBox(
          width: playerNamesOnCourt[4].isNotEmpty ? wid : 0,
          height: hei,
          child: playerNamesOnCourt[4].isNotEmpty
              ? scoreBox(index * 5 + 4)
              : const SizedBox()),
      const SizedBox(width: 5),
      Text(
        lineScore.toString().padLeft(2, '  '),
        style: nameStyle,
      ),
    ]);
  }

  Widget autoCompleteLine() {
    const double wid = 40;
    const double hei = 80;

    return Row(children: [
      const SizedBox(
          width: 107,
          height: hei,
          child: Center(
              child: Text('Auto\nComplete',
                  textAlign: TextAlign.right, style: nameStyle))),
      const SizedBox(
        width: 5,
      ),
      SizedBox(width: wid, height: hei, child: autoButton(0)),
      SizedBox(width: wid, height: hei, child: autoButton(1)),
      SizedBox(width: wid, height: hei, child: autoButton(2)),
      SizedBox(
          width: playerNamesOnCourt[4].isNotEmpty ? wid : 0,
          height: hei,
          child: playerNamesOnCourt[4].isNotEmpty
              ? autoButton(3)
              : const SizedBox()),
      SizedBox(
          width: playerNamesOnCourt[4].isNotEmpty ? wid : 0,
          height: hei,
          child: playerNamesOnCourt[4].isNotEmpty
              ? autoButton(4)
              : const SizedBox()),
      const SizedBox(width: 5),
    ]);
  }

  void saveScore() {
    if (edited.contains(true)) {
      WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
      for (int playerNumber = 0;
          playerNumber < playersOnCourt.length;
          playerNumber++) {
        if (playersOnCourt[playerNumber] >= 0) {
          DocumentReference doc = FirebaseFirestore.instance
              .collection(fireStoreCollectionName)
              .doc(Player.db[playersOnCourt[playerNumber]].playerName);
          var details = <String, dynamic>{};
          String updatedBy = '$loggedInPlayerName:';
          for (int game = 0; game < 5; game++) {
            int scr = newScores[playerNumber * 5 + game];
            if (scr >= 0) {
              updatedBy += scr.toString();
              details['Score${game + 1}'] = scr;
            } else {
              updatedBy += 'x';
            }
          }
          updatedBy += '/';
          // if (details.isNotEmpty) {
          details['ScoreLastUpdatedBy'] =
              scoreLastUpdatedBy[playerNumber] + updatedBy;
          scoreUpdate.update(doc, details);
          // print(
          //     'scoreUpdate: ${details.toString()} ${Player.db[playersOnCourt[playerNumber]].playerName}');
          // }
        }
      }
      scoreUpdate.commit();
    } else {
      if (kDebugMode) {
        print('No new scores to saveScore');
      }
    }
    // print('clearing NewScores');
    newScores.fillRange(0, newScores.length, -9);
    edited.fillRange(0, edited.length, false);
  }

  void cancelScore() {
    newScores.fillRange(0, newScores.length, -9);
    edited.fillRange(0, edited.length, false);
    entryTimer?.cancel();
  }

  String errorPairs(String errString) {
    var working = List<int>.filled(25, 0);
    for (int i = 0; i < origScores.length; i++) {
      working[i] = origScores[i];
      if (newScores[i] >= 0) {
        working[i] = newScores[i];
      }
    }
    // print('working: ${working[0]} ${working[5]} ${working[10]} ${working[15]} ${working[20]}');
    bool courtOf5 = true;
    if (playerNamesOnCourt[4].isEmpty) courtOf5 = false;
    if (courtOf5) {
      for (int match = 0; match < 5; match++) {
        List<int> sc = List.empty(growable: true);
        int totalUnedited = 0;
        for (int i = 0; i < 5; i++) {
          int val = working[i * 5 + match];
          if (val < 0) {
            val = 0;
            totalUnedited += 1;
          }
          int offset = sc.indexOf(val);
          if (offset < 0) {
            sc.add(val);
          } else {
            sc.removeAt(offset);
          }
        }

        if (totalUnedited <= 1) {
          if ((sc.length != 1) || (sc[0] != 0)) {
            _problemInSet[match] = true;
            if (errString.isNotEmpty) {
              errString += '\n';
            }
            errString +=
                'Set ${(match + 1).toString()} problem with assigning scores to pairs';
          }
        }
      }
    } else {
      for (int match = 0; match < 3; match++) {
        List<int> sc = List.empty(growable: true);
        int totalUnedited = 0;
        for (int i = 0; i < 4; i++) {
          int val = working[i * 5 + match];
          if (val < 0) {
            totalUnedited += 1;
          }
          int offset = sc.indexOf(val);
          if (offset < 0) {
            sc.add(val);
          } else {
            sc.removeAt(offset);
          }
        }

        if ((sc.isNotEmpty) && (totalUnedited == 0)) {
          // print(sc);
          _problemInSet[match] = true;
          if (errString.isNotEmpty) {
            errString += '\n';
          }
          errString +=
              'Set ${(match + 1).toString()} problem with assigning scores to pairs';
        }
      }
    }

    return errString;
  }

  String errorGameCount(String errString) {
    var working = List<int>.filled(25, 0);
    for (int i = 0; i < origScores.length; i++) {
      working[i] = origScores[i];
      if (newScores[i] >= 0) {
        working[i] = newScores[i];
      }
    }
    // print('working: $working');
    bool courtOf5 = true;
    if (playerNamesOnCourt[4].isEmpty) courtOf5 = false;

    if (courtOf5) {
      for (int match = 0; match < 5; match++) {
        // this assumes that this one is called first as it initializes this
        _problemInSet[match] = false;
        int totalUnedited = 0;
        int total = 0;
        for (int i = 0; i < 5; i++) {
          int val = working[i * 5 + match];
          if (val >= 0) {
            total += val;
          } else {
            totalUnedited += 1;
          }
        }
        if ((total != 12) && (totalUnedited <= 1)) {
          _problemInSet[match] = true;
          if (errString.isNotEmpty) {
            errString += '\n';
          }
          errString +=
              'Set ${(match + 1).toString()} should add up to 12 not:$total';
        }
      }
    } else {
      for (int match = 0; match < 3; match++) {
        _problemInSet[match] = false;
        int totalUnedited = 0;
        int total = 0;
        for (int i = 0; i < 4; i++) {
          int val = working[i * 5 + match];
          if (val >= 0) {
            total += val;
          } else {
            totalUnedited += 1;
          }
        }
        if ((total != 16) && (totalUnedited == 0)) {
          _problemInSet[match] = true;
          if (errString.isNotEmpty) {
            errString += '\n';
          }
          errString +=
              'Set ${(match + 1).toString()} should add up to 16 not:$total';
        }
      }
    }
    return errString;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (bool didPop) async {
        if (kDebugMode) {
          print('build scores PopScope!!! $didPop');
        }
        // if (didPop) return;
        saveScore();
        if (entryTimer != null) {
          entryTimer!.cancel();
          entryTimer = null;
          forceExit = true;
        }
        return;
      },
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: appBackgroundColor,
          appBar: AppBar(
            title: Text(fireStoreCollectionName.substring(3)),
            backgroundColor: appBarColor,
            elevation: 0.0,
          ),
          body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(fireStoreCollectionName)
                  .orderBy('Rank')
                  // .where('Rank', isGreaterThan: 0)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.data == null) {
                  return const LinearProgressIndicator();
                }

                origScores.fillRange(0, origScores.length, -9);
                for (var doc in snapshot.requireData.docs) {
                  // if (loggedInPlayerName == doc.id) {
                  //   _enableScoreEntry = true;
                  // }

                  int playerNum = playerNamesOnCourt.indexOf(doc.id);

                  // print('DOC: ${doc.id} PlayerNum: $playerNum');
                  if (playerNum >= 0) {
                    scoreLastUpdatedBy[playerNum] =
                        doc.get('ScoreLastUpdatedBy');
                    origScores[playerNum * 5 + 0] = doc.get('Score1');
                    origScores[playerNum * 5 + 1] = doc.get('Score2');
                    origScores[playerNum * 5 + 2] = doc.get('Score3');
                    origScores[playerNum * 5 + 3] = doc.get('Score4');
                    origScores[playerNum * 5 + 4] = doc.get('Score5');
                  }
                }
                bool scoresReadyToConfirm = true;
                bool thisPlayerEnteredScoresLast = false;
                bool allPlayersConfirmed = false;
                bool thereAreBlanksToFillIn = false;

                if (playerNamesOnCourt[4].isEmpty) {
                  // court of 4
                  for (int game = 0; game < 3; game++) {
                    if (scoresReadyToConfirm) {
                      for (int pl = 0; pl < 4; pl++) {
                        if (origScores[pl * 5 + game] < 0) {
                          scoresReadyToConfirm = false;
                          thereAreBlanksToFillIn = true;
                          // print('court4 not ready $game, $pl');
                          break;
                        }
                      }
                    }
                  }
                  // print('scoresReadyToConfirm: $scoresReadyToConfirm');
                  int numConfirmed = 0;
                  _confirmedBy = '';
                  _lastScoreEntryBy = '';
                  for (int pl = 0; pl < 4; pl++) {
                    final splitStr = scoreLastUpdatedBy[pl].split('/');
                    String lastEntry = 'NOBODY ENTERED';
                    // as there is always a trailing '/' the last entry is always empty
                    if (splitStr.length >= 2) {
                      lastEntry = splitStr[splitStr.length - 2];
                      _lastScoreEntryBy = lastEntry.split(':')[0];
                    }
                    // print('lastEntry: $lastEntry $loggedInPlayerName');
                    if (scoreLastUpdatedBy[pl].endsWith('!!/')) {
                      numConfirmed++;
                      String confirmedBy = splitStr[splitStr.length - 2];
                      _confirmedBy =
                          confirmedBy.substring(0, confirmedBy.length - 2);
                    } else if (lastEntry.contains(loggedInPlayerName!)) {
                      thisPlayerEnteredScoresLast =
                          true; //this player can not confirm
                    }
                    // print('$pl LastEntry: $lastEntry, #confirmed: $numConfirmed, $_confirmedBy thisPlLast: $thisPlayerEnteredScoresLast');
                  }
                  if (numConfirmed == 4) {
                    allPlayersConfirmed = true;
                  }
                  if ((numConfirmed == 4) || thisPlayerEnteredScoresLast) {
                    // print('court4 numConfirmed: $numConfirmed');
                    scoresReadyToConfirm = false;
                  }
                } else {
                  // court of 5
                  for (int game = 0; game < 5; game++) {
                    int numBlank = 0;
                    for (int pl = 0; pl < 5; pl++) {
                      if (origScores[pl * 5 + game] < 0) {
                        numBlank++;
                      }
                    }
                    if (numBlank > 1) {
                      scoresReadyToConfirm = false;
                      thereAreBlanksToFillIn = true;
                    }
                  }
                  int numConfirmed = 0;
                  thisPlayerEnteredScoresLast = false;
                  _lastScoreEntryBy='';
                  for (int pl = 0; pl < 5; pl++) {
                    final splitString = scoreLastUpdatedBy[pl].split('/');
                    String lastEntry = 'NOBODY ENTERED';
                    if (splitString.length >= 2) {
                      lastEntry = splitString[splitString.length - 2];
                      // as there is always a trailing '/' the last entry is always empty
                      _lastScoreEntryBy = lastEntry.split(':')[0];

                    }
                    if (scoreLastUpdatedBy[pl].endsWith('!!/')) {
                      numConfirmed++;
                    } else if (lastEntry.contains(loggedInPlayerName!)) {
                      thisPlayerEnteredScoresLast =
                          true; //this player can not confirm
                    }
                  }
                  if (numConfirmed == 5) {
                    allPlayersConfirmed = true;
                  }
                  if ((numConfirmed == 5) || thisPlayerEnteredScoresLast) {
                    scoresReadyToConfirm = false;
                  }
                }
                print('scoresReadyToConfirm: $scoresReadyToConfirm, $loggedInPlayerName');

                if (fireStoreCollectionName.substring(3, 5) != 'PB') {
                  _errorString1 = errorGameCount('');

                  _errorString1 = errorPairs(_errorString1);
                }
                // if (kDebugMode) {
                //   print('This last: $thisPlayerEnteredScoresLast, allConfirmed: $allPlayersConfirmed ScoresReady: $scoresReadyToConfirm');
                // }

                return SingleChildScrollView(
                  primary: true,
                  child: Column(children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 10),
                        ElevatedButton(
                            onPressed:
                                (_enableScoreEntry) && (entryTimer != null)
                                    ? () {
                                        if (entryTimer != null) {
                                          entryTimer!.cancel();
                                          entryTimer = null;
                                        }
                                        setState(() {
                                          saveScore();
                                        });

                                        // forceExit = true;
                                        // Navigator.pop(context);
                                      }
                                    : null,
                            child: const Text('Save')),
                        const Spacer(),
                        ElevatedButton(
                            onPressed: (!_enableScoreEntry)
                                ? null
                                : () {
                                    setState(() {
                                      _plusMinus = !_plusMinus;
                                    });
                                  },
                            child: Text(_plusMinus
                                ? 'Count UP/down'
                                : 'Count DOWN/up')),
                        const Spacer(),
                        ElevatedButton(
                            onPressed:
                                (_enableScoreEntry) && (entryTimer != null)
                                    ? () {
                                        if (entryTimer != null) {
                                          entryTimer!.cancel();
                                          entryTimer = null;
                                        }
                                        setState(() {
                                          cancelScore();
                                        });

                                        // forceExit = true;
                                        // Navigator.pop(context);
                                      }
                                    : null,
                            child: const Text('CANCEL')),
                        const SizedBox(width: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    scoreLine(0),
                    scoreLine(1),
                    scoreLine(2),
                    scoreLine(3),
                    playerNamesOnCourt[4].isNotEmpty
                        ? scoreLine(4)
                        : const SizedBox(),
                    autoCompleteLine(),
                    Text(
                      _errorString1,
                      style: nameBoldStyle,
                    ),
                    const SizedBox(height: 15),
                    _confirmedBy.isNotEmpty
                        ? Text(
                            'Confirmed by: $_confirmedBy',
                            style: nameBoldStyle,
                          )
                        : Text(
                            'Last Score Entered By: $_lastScoreEntryBy',
                            style: nameBoldStyle,
                          ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom( backgroundColor: Colors.green,
                      foregroundColor: Colors.black),
                      onPressed: (scoresReadyToConfirm || Player.admin2Enabled)
                          ? () {
                              Player.updateConfirmScore(playersOnCourt);
                              if (entryTimer != null) {
                                entryTimer!.cancel();
                                entryTimer = null;
                                forceExit = true;
                              }
                              Navigator.pop(context);
                            }
                          : null,
                      child: (allPlayersConfirmed
                          ? const Text('Scores are CONFIRMED')
                          : (thereAreBlanksToFillIn
                              ? const Text(
                                  'Need scores for all of the games before confirming')
                              : (thisPlayerEnteredScoresLast
                                  ? const Text(
                                      'Someone else confirms that scores are correct')
                                  : (_enableScoreEntry || Player.admin1Enabled)
                                      ? const Text(
                                          'Press to confirm scores are correct')
                                      : const Text(
                                          'You did not play on this court')))),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            'REQUIRED order of play:',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(
                            'Suggested order of play:',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          ),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            '1&2 vs 3&4',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(
                            '1&4 vs 2&3',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          ),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            '1&5 vs 2&3',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(
                            '1&3 vs 2&4',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          ),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            '1&4 vs 2&5',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(
                            '1&2 vs 3&4',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          ),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            '1&3 vs 4&5',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(''),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                            '2&4 vs 3&5',
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          )
                        : const Text(''),
                    playerNamesOnCourt[4].isNotEmpty
                        ? const Text(
                      'if 1&2 did not play 3&4 first then \nrenumber the players and\nplay with those new numbers',
                      style: nameStyle,
                      textAlign: TextAlign.center,
                    )
                        : const Text(''),
                  ]),
                );
              })),
    );
  }
}
