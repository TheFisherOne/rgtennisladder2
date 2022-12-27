import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<int> playersOnCourt = List.filled(5, 0);
int playerToEnterScore = 0;
List<int> scores = List.filled(30, -9);
List<int> originalScores = List.filled(30, -9);
bool _enableScoreEntry = false;
Timer? entryTimer;
bool forceExit = false;

class EnterScores2 extends StatefulWidget {
  EnterScores2({Key? key}) : super(key: key);

  @override
  _EnterScores2State createState() => _EnterScores2State();

  static void prepareForScoreEntry(newPlayersOnCourt, newPlayerToEnterScore) {
    _enableScoreEntry = false;
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
        scores[pl * 6 + 0] = pdb[playersOnCourt[pl]].score1;
        scores[pl * 6 + 1] = pdb[playersOnCourt[pl]].score2;
        scores[pl * 6 + 2] = pdb[playersOnCourt[pl]].score3;
        scores[pl * 6 + 3] = pdb[playersOnCourt[pl]].score4;
        scores[pl * 6 + 4] = pdb[playersOnCourt[pl]].score5;
        scores[pl * 6 + 5] = pdb[playersOnCourt[pl]].totalScore;

        originalScores[pl * 6 + 0] = pdb[playersOnCourt[pl]].score1;
        originalScores[pl * 6 + 1] = pdb[playersOnCourt[pl]].score2;
        originalScores[pl * 6 + 2] = pdb[playersOnCourt[pl]].score3;
        originalScores[pl * 6 + 3] = pdb[playersOnCourt[pl]].score4;
        originalScores[pl * 6 + 4] = pdb[playersOnCourt[pl]].score5;
        originalScores[pl * 6 + 5] = pdb[playersOnCourt[pl]].totalScore;
      }
    }
  }
}

class _EnterScores2State extends State<EnterScores2> {
  int _exitCountdown = scoreEntryTimeout;
  Timer? _timer;

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

  @override
  Widget build(BuildContext context) {
    if (_timer == null) {
      startTimer();
    }
    int numPlayers = 4;

    if (playersOnCourt[4] >= 0) numPlayers = 5;

    int numberOfGames = 3;
    if (numPlayers > 4) {
      numberOfGames = 5;
    }
    int lineScore = 0;
    for (int row = 0; row < numPlayers; row++) {
      lineScore = 0;
      for (int c = 0; c < numberOfGames; c++) {
        int score = scores[row * 6 + c];
        if (score >= 0) {
          lineScore += score;
        }
      }

      scores[row * 6 + 5] = lineScore;
    }
    List<Widget> _getGrid(int numPlayers) {
      List<Widget> listings = List<Widget>.empty(growable: true);
      for (int row = 0; row < numPlayers; row++) {
          for (int col = 0; col < numPlayers + 2; col++) {
          if (col == 0) {
            String separator = ':';
            TextStyle thisStyle = nameStyle;

            listings.add(Text(
              'P' + (row + 1).toString() + separator,
              style: thisStyle,
              textAlign: TextAlign.center,
            ));
          } else if (col <= numberOfGames) {
            int scoreIndex = row * 6 + col - 1;
            int limit = (numPlayers == 5) ? 6 : 8;

            InputDecoration decoration = scoreBackgroundDecoration;

            bool scoreOk = true;
            int colScore = 0;
            int numEnteredScores = 0;
            List colScores = [];
            if (numPlayers == 4) {
              for (int j = 0; j < 4; j++) {
                int score = scores[j * 6 + col - 1];

                if (score >= 0) {
                  colScores.add(score);
                  colScore += score;
                  numEnteredScores += 1;
                }
              }

              if (numEnteredScores == 4) {
                if (colScore != 16) {
                  scoreOk = false;
                }
                int score = scores[row * 6 + col - 1];
                if (score == 4) {
                  if ((colScores[0] != 4) |
                      (colScores[1] != 4) |
                      (colScores[2] != 4) |
                      (colScores[3] != 4)) {
                    scoreOk = false;
                  }
                } else {
                  int numMatch = 0;
                  int numOpp = 0;
                  for (int j = 0; j < 4; j++) {
                    if ((colScores[j] == score)) {
                      numMatch += 1;
                    } else if (colScores[j] == (8 - score)) {
                      numOpp += 1;
                    }
                  }
                  if ((numMatch != 2) | (numOpp != 2)) {
                    scoreOk = false;
                  }
                }
              }
            } else {
              for (int j = 0; j < 5; j++) {
                int score = scores[j * 6 + col - 1];

                if (score >= 0) {
                  colScores.add(score);
                  colScore += score;
                  numEnteredScores += 1;
                }
              }

              if (numEnteredScores >= 4) {
                if (colScore != 12) {
                  scoreOk = false;
                }
                int score = scores[row * 6 + col - 1];
                if (score < 0) {
                } else if (score == 3) {
                  int num3 = 0;
                  for (int j = 0; j < colScores.length; j++) {
                    if (colScores[j] == 3) num3 += 1;
                  }

                  if (num3 != 4) {
                    scoreOk = false;
                  }
                } else {
                  int numMatch = 0;
                  int numOpp = 0;
                  for (int j = 0; j < colScores.length; j++) {
                    if ((colScores[j] == score)) {
                      numMatch += 1;
                    } else if (colScores[j] == (6 - score)) {
                      numOpp += 1;
                    }
                  }

                  if (score == 0) {
                  } else if (score == 6) {
                    if ((numOpp < 2) | (numMatch != 2)) scoreOk = false;
                  } else if ((numMatch != 2) | (numOpp != 2)) {
                    scoreOk = false;
                  }
                  //print('$col $scoreOk score: $score match: $numMatch opp: $numOpp');
                }
              }
            }

            if ((scores[scoreIndex] > limit) | (!scoreOk)) {
              decoration = scoreBadDecoration;
            }

            listings.add(Container(
              color: (numPlayers == 5) & ((5 - col) == row)
                  ? appBackgroundColor
                  : appBarColor,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: TextFormField(
                  initialValue: (scores[scoreIndex] >= 0)
                      ? scores[scoreIndex].toString()
                      : '',
                  enabled: _enableScoreEntry,
                  style: nameStyle,
                  textAlign: TextAlign.center,
                  decoration: decoration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1)
                  ],
                  textInputAction: TextInputAction.next,
                  onChanged: (String value) {
                    setState(() {
                      try {
                        scores[scoreIndex] = int.parse(value);
                        FocusScope.of(context).nextFocus();
                      } catch (e) {
                        scores[scoreIndex] = 0;
                      }
                    });
                  },
                ),
              ),
            ));
          }
        }
      }
      return listings;
    }

    void saveScore() {
      bool changed = false;
      //check if the score changed
      for (int pl = 0; pl < 5; pl++) {
        if (playersOnCourt[pl] >= 0) {
          if (scores[pl * 6 + 0] != originalScores[pl * 6 + 0]) {
            changed = true;
          }
          if (scores[pl * 6 + 1] != originalScores[pl * 6 + 1]) {
            changed = true;
          }
          if (scores[pl * 6 + 2] != originalScores[pl * 6 + 2]) {
            changed = true;
          }
          if (scores[pl * 6 + 3] != originalScores[pl * 6 + 3]) {
            changed = true;
          }
          if (scores[pl * 6 + 4] != originalScores[pl * 6 + 4]) {
            changed = true;
          }
        }
      }
      // print('WillPopScope (enter_scores2) $changed');
      if (changed) {
        Player.updateScore(playersOnCourt, scores);
      }
    }

    if (forceExit) {
      // if (kDebugMode) {
      //   print('forceExit of enter_scores2');
      // }
      return const Text('dummy');
    }
    if (entryTimer == null) {
      // print('creating entryTimer');
      entryTimer = Timer(const Duration(seconds: scoreEntryTimeout), () {
        _enableScoreEntry = false;
        entryTimer = null;
        forceExit = true;
        // if (kDebugMode) {
        //   print('entryTimer expires!!!');
        // }
        Navigator.pop(context);
      });
    }
    return WillPopScope(
      onWillPop: () async {
        if (_enableScoreEntry) {
          return false;
        }
        if (entryTimer != null) {
          entryTimer!.cancel();
          entryTimer = null;
          forceExit = true;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.brown[50],
        appBar: AppBar(
          title: const Text('Enter Scores:'),
          backgroundColor: Colors.brown[400],
          elevation: 0.0,
          actions: const [],
        ),
        body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(10),
            children: [
              ElevatedButton(
                  onPressed: (!_enableScoreEntry)
                      ? null
                      : () {
                          if (entryTimer != null) {
                            entryTimer!.cancel();
                            entryTimer = null;
                          }
                          saveScore();
                          forceExit = true;
                          Navigator.pop(context);
                        },
                  child: const Text('Save&Exit')),
              ElevatedButton(
                  onPressed: (_enableScoreEntry)
                      ? null
                      : () {
                          setState(() {
                            _enableScoreEntry = true;
                          });
                        },
                  child: const Text('Change')),
              ElevatedButton(
                  onPressed: (!_enableScoreEntry)
                      ? null
                      : () {
                          if (entryTimer != null) {
                            entryTimer!.cancel();
                            entryTimer = null;
                            forceExit = true;
                          }
                          Navigator.pop(context);
                        },
                  child: Text(
                      'QUIT discard changes ${_exitCountdown.toString()}')),

              const Divider(
                color: Colors.black,
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      'P1: ' + Player.db[playersOnCourt[0]].playerName,
                      style: nameStyle,
                    ),
                  ),
                  Text(
                    '${scores[0 * 6 + 5]}',
                    style: nameStyle,
                    textAlign: TextAlign.end,
                  ),
                ]),
                const Divider(
                  color: Colors.black,
                ),
                Row(children: [
                  Expanded(
                    child: Text(
                      'P2: ' + Player.db[playersOnCourt[1]].playerName,
                      style: nameStyle,
                    ),
                  ),
                  Text('${scores[1 * 6 + 5]}',
                      style: nameStyle, textAlign: TextAlign.end),
                ]),
                const Divider(
                  color: Colors.black,
                ),
                Row(children: [
                  Expanded(
                    child: Text(
                      'P3: ' + Player.db[playersOnCourt[2]].playerName,
                      style: nameStyle,
                    ),
                  ),
                  Text('${scores[2 * 6 + 5]}',
                      style: nameStyle, textAlign: TextAlign.end),
                ]),
                const Divider(
                  color: Colors.black,
                ),
                Row(children: [
                  Expanded(
                    child: Text(
                      'P4: ' + Player.db[playersOnCourt[3]].playerName,
                      style: nameStyle,
                    ),
                  ),
                  Text('${scores[3 * 6 + 5]}',
                      style: nameStyle, textAlign: TextAlign.end),
                ]),
                const Divider(
                  color: Colors.black,
                ),
                (playersOnCourt[4] >= 0)
                    ? Row(children: [
                        Expanded(
                          child: Text(
                            'P5: ' + Player.db[playersOnCourt[4]].playerName,
                            style: nameStyle,
                          ),
                        ),
                        Text('${scores[4 * 6 + 5]}',
                            style: nameStyle, textAlign: TextAlign.end),
                      ])
                    : const Text(''),
                const SizedBox(height: 20),
              ]),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: numPlayers > 4 ? 6 : 4,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
                shrinkWrap: true,
                childAspectRatio: 1.5,
                children: _getGrid(numPlayers),
              ),
              const Text(
                'Once you start changing scores you must save or quit',
                style: nameStyle,
              ),
              Text(
                'this window will timeout and quit after ' +
                    scoreEntryTimeout.toString() +
                    ' seconds',
                style: nameStyle,
              ),
            ]),
      ),
    );
  }
}
