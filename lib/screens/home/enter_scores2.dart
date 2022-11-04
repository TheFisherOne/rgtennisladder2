import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<int> playersOnCourt = List.filled(5, 0);
int playerToEnterScore = 0;
List<int> scores = List.filled(30, -9);
List<int> originalScores = List.filled(30, -9);

class EnterScores2 extends StatefulWidget {
  const EnterScores2({Key? key}) : super(key: key);

  @override
  _EnterScores2State createState() => _EnterScores2State();

  static void prepareForScoreEntry(newPlayersOnCourt, newPlayerToEnterScore) {
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
  @override
  Widget build(BuildContext context) {
    int numPlayers = 4;

    if (playersOnCourt[4] >= 0) numPlayers = 5;

    int numberOfGames = 3;
    if (numPlayers > 4) {
      numberOfGames = 5;
    }
    int lineScore=0;
    for (int row=0;row<numPlayers;row++) {
      lineScore=0;
      for (int c = 0; c < numberOfGames; c++) {
        int score = scores[row * 6 + c];
        if (score >= 0) {
          lineScore += score;
        }
      }

      scores[row * 6 + 5 ] = lineScore;
    }
    List<Widget> _getGrid(int numPlayers) {
      List<Widget> listings = List<Widget>.empty(growable: true);
      for (int row = 0; row < numPlayers; row++) {
        if (row < numPlayers) {
          for (int col = 0; col < numPlayers + 2; col++) {
            if (col == 0) {
              String separator = ':';
              TextStyle thisStyle = nameStyle;

              listings.add(Text(
                (row + 1).toString() + separator,
                style: thisStyle,
                textAlign: TextAlign.center,
              ));
            } else if (col <= numberOfGames) {
              int scoreIndex = row * 6 + col - 1;

              bool enabled = true;

              int limit = (numPlayers == 5) ? 6 : 8;

              InputDecoration decoration = scoreBackgroundDecoration;

              bool scoreOk=true;
              int colScore=0;
              int numEnteredScores=0;
              List colScores=[];
              if (numPlayers==4) {
                for (int j = 0;j<4;j++){
                  int score=scores[j * 6 + col - 1];

                  if (score>=0) {
                    colScores.add(score);
                    colScore+=score;
                    numEnteredScores+=1;
                  }
                }

                if (numEnteredScores==4) {
                  if (colScore != 16) {
                    scoreOk = false;
                  }
                  int score=scores[row * 6 + col - 1];
                  if (score==4){
                    if ((colScores[0]!=4)| (colScores[1]!=4)| (colScores[2]!=4)| (colScores[3]!=4)) {
                      scoreOk=false;
                    }
                  } else {
                    int numMatch=0;
                    int numOpp=0;
                    for (int j = 0;j<4;j++){
                      if ((colScores[j]==score)){
                        numMatch+=1;
                      } else if (colScores[j]==(8-score)){
                        numOpp+=1;
                      }
                    }
                    if ((numMatch!=2)|(numOpp!=2)){
                      scoreOk=false;
                    }
                  }
                }
              } else{
                for (int j = 0;j<5;j++){
                  int score=scores[j * 6 + col - 1];

                  if (score>=0) {
                    colScores.add(score);
                    colScore+=score;
                    numEnteredScores+=1;
                  }
                }

                if (numEnteredScores>=4) {
                  if (colScore != 12) {
                    scoreOk = false;
                  }
                  int score=scores[row * 6 + col - 1];
                  if (score<0){

                  }else if (score==3){
                    int num3=0;
                    for (int j = 0;j<colScores.length;j++){
                      if (colScores[j]==3) num3+=1;
                    }

                    if (num3!=4) {
                      scoreOk=false;
                    }
                  } else {
                    int numMatch=0;
                    int numOpp=0;
                    for (int j = 0;j<colScores.length;j++){
                      if ((colScores[j]==score)){
                        numMatch+=1;
                      } else if (colScores[j]==(6-score)){
                        numOpp+=1;
                      }
                    }

                    if (score==0){

                    } else if (score==6){
                      if ((numOpp<2)|(numMatch!=2)) scoreOk=false;
                    } else if ((numMatch!=2)|(numOpp!=2)){
                      scoreOk=false;
                    }
                    //print('$col $scoreOk score: $score match: $numMatch opp: $numOpp');
                  }
                }
              }



              if ((scores[scoreIndex] > limit)|(!scoreOk)) {
                decoration = scoreBadDecoration;
              }

                listings.add(Container(
                  color: (numPlayers==5)&((5 - col) == row)
                      ? appBackgroundColor
                      : appBarColor,
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: TextFormField(
                      initialValue: (scores[scoreIndex] >= 0)
                          ? scores[scoreIndex].toString()
                          : '',
                      enabled: enabled,
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
      }
      return listings;
    }

    return WillPopScope(
      onWillPop: () async {
        //check if the score changed
        bool changed = false;
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
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.brown[50],
        appBar: AppBar(
          title: const Text('Enter Scores:'),
          backgroundColor: Colors.brown[400],
          elevation: 0.0,
          actions: const [

          ],
        ),
        body: ListView(shrinkWrap: true, padding: const EdgeInsets.all(10),
            children: [
              const Text(
                'You must leave this page to save scores',
                style: nameStyle,
              ),
              const Divider(
                color: Colors.black,
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '1: ' + Player.db[playersOnCourt[0]].playerName,
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
                      '2: ' + Player.db[playersOnCourt[1]].playerName,
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
                      '3: ' + Player.db[playersOnCourt[2]].playerName,
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
                      '4: ' + Player.db[playersOnCourt[3]].playerName,
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
                            '5: ' + Player.db[playersOnCourt[4]].playerName,
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
            ]),
      ),
    );
  }
}
