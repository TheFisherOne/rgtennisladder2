import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rgtennisladder/screens/authenticate/sign_in.dart';
import 'package:rgtennisladder/screens/wrapper.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import '../main.dart';
import '../screens/home/history.dart';

String fireStoreCollectionName = 'no_collection_name';

void setCollectionName(String newName) {
  if (newName == fireStoreCollectionName) {
    return;
  }
  Player.admin2Enabled = false;
  Player.admin1Enabled = false;
  Player.db = List.empty(growable: true);
  fireStoreCollectionName = newName;
  setLadder(fireStoreCollectionName);
  if (kDebugMode) {
    print(
        'setCollectionName:  fireStoreCollectionName to $fireStoreCollectionName');
  }
}

class OldSoftwareVersion implements Exception {
  String errorMessage() {
    return 'YOUR SOFTWARE NEEDS TO BE UPDATED!\nClose the window and reload please!';
  }

  @override
  String toString() {
    return 'YOUR SOFTWARE NEEDS TO BE UPDATED!\nClose the window and reload please!';
  }
}

List<FullMetadata>? playerImageFileList;
void buildPlayerImageFileList({refresh = false}) async {
  if ((playerImageFileList == null) | (refresh)) {
    playerImageFileList = List<FullMetadata>.empty(growable: true);
    // print('reading player image files');
    FirebaseStorage.instance
        .ref()
        .child(fireStoreCollectionName)
        .child('player_pictures')
        .listAll()
        .then((result) async {
      for (var element in result.items) {
        FullMetadata? metaData;
        try {
          metaData = await element.getMetadata();
          // print('Found image files: ${metaData.name} ${metaData.size} ${metaData.cacheControl}');
        } catch (e) {
          if (kDebugMode) {
            print('Error getting image meta data $e');
          }
        }
        if (metaData != null) {
          playerImageFileList!.add(metaData);
        }
      }
    });
  }
}

class Player {
  static int adNumber=0;
  static bool admin1Enabled = false;
  static bool admin2Enabled = false;
  // things there are only 1 of
  static List<Player> db = List.empty(growable: true);
  static int courtsAvailable = 4;
  static int shift5Player = 0;
  static bool freezeCheckins = false;
  static int weeksPlayed = -1;
  static String courtInfoString = '';
  static int playOnWeekday = 0;

  // stuff for location
  static double rgLatitude = 0;
  static double rgLongitude = 0;
  static double rgHowClose = 0;

  static int numPresent = 0;
  static List<int> playersPerCourt =
      List.filled(10, 0); //larger than it needs to be
  static var onUpdate = StreamController<bool>.broadcast();
  static bool topOn1 = true;
  static int numberOfAssignedCourts = 0;
  static String adLink='';

  String uid = '';
  String playerName = '';
  int currentRank = 0;
  bool present = false;
  bool skipToMakeGoodNumber = false;
  DateTime timePresent = DateTime(1999, 09, 09);
  int admin = 0;

  // things that we can build directly from reading the FireStore database
  int assignedCourt = 0;
  int score1 = -9;
  int score2 = -9;
  int score3 = -9;
  int score4 = -9;
  int score5 = -9;
  int weeksAway = 0;
  String scoreLastUpdatedBy = '';

  // things having to do with the entered scores
  int totalScore = 0;
  int movementDueToScore = 0;
  int correctedMovementDueToAway = 0;
  int movementDueToWinnerJumping = 0;
  int newRank = 0;
  String lastMovement = '';
  String? email;

  static buildPlayerDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    numPresent = 0;
    db = List.empty(growable: true);
    for (var doc in snapshot.requireData.docs) {
      // print('buildPlayerDB ${doc.id}');
      if (doc.id == '_configuration_') {
        Player.courtsAvailable = doc.get("numberOfCourts");
        Player.shift5Player = doc.get("shift5player");
        Player.rgLatitude = doc.get("latitude");
        Player.rgLongitude = doc.get("longitude");
        Player.rgHowClose = doc.get("howClose");
        Player.freezeCheckins = doc.get('FreezeCheckIns');
        Player.weeksPlayed = doc.get('WeeksPlayed');
        Player.playOnWeekday = doc.get('PlayOnWeekday');
        try {
          Player.adNumber = doc.get('adNumber');
        } catch (e) {
          Player.adNumber = 0;
        }
        try {
          Player.adLink = doc.get('adLink');
        } catch (e) {
          Player.adLink = '';
        }

        if ((Player.playOnWeekday <= 0) | (Player.playOnWeekday > 7)) {
          if (kDebugMode) {
            print(
                'Bad _configuration_ PlayOnWeekday should be between 1 and 7 inclusive');
          }
          Player.playOnWeekday = 1;
        }
        if (doc.get('RequiredSoftwareVersion') > softwareVersion) {
          db.clear();
          if (kDebugMode) {
            print('SOFTWARE NEEDS UPDATING!!!!!!!!!!');
          }
          throw OldSoftwareVersion();
        }
      } else {
        // bool createdNew = false;
        int rank = doc.get('Rank');
        if (rank > 0) {
          Player? newPlayer = Player();

          newPlayer.playerName = doc.id; // actually player name
          String? nameError = playerValidator(doc.id);
          if (nameError != null) {
            if (kDebugMode) {
              print(
                  'ERROR in database, bad player name:"${doc.id}" $nameError');
            }
          }
          String val = doc.id;
          if (val.substring(val.length - 1) == ' ') {
            if (kDebugMode) {
              print(
                  'ERROR in database, bad player name:"${doc.id}" No trailing space at the end of your name');
            }
          }
          if (val[0] == ' ') {
            if (kDebugMode) {
              print(
                  'ERROR in database, bad player name:"${doc.id}"No leading space at the beginning of your name');
            }
          }
          if (val.contains('  ')) {
            if (kDebugMode) {
              print(
                  'ERROR in database, bad player name:"${doc.id}"You can not have 2 spaces together');
            }
          }
          newPlayer.currentRank = rank;
          newPlayer.uid = doc.get('UID');
          newPlayer.present = doc.get('Present');
          newPlayer.admin = doc.get('Admin');
          newPlayer.timePresent = doc.get('TimePresent').toDate();
          newPlayer.score1 = doc.get('Score1');
          newPlayer.score2 = doc.get('Score2');
          newPlayer.score3 = doc.get('Score3');
          newPlayer.score4 = doc.get('Score4');
          newPlayer.score5 = doc.get('Score5');
          newPlayer.scoreLastUpdatedBy = doc.get('ScoreLastUpdatedBy');
          try {
            newPlayer.weeksAway = doc.get('WeeksAway');
          } catch (e) {
            newPlayer.weeksAway = 0;
          }
          try {
            newPlayer.lastMovement = doc.get('LastMovement');
          } catch (e) {
            newPlayer.lastMovement = '0:0:0:0:0';
          }
          int totalScore = 0;

          try {
            newPlayer.email = doc.get('Email');
          } catch (e) {
            newPlayer.email = null;
          }
          if (newPlayer.score1 >= 0) totalScore += newPlayer.score1;
          if (newPlayer.score2 >= 0) totalScore += newPlayer.score2;
          if (newPlayer.score3 >= 0) totalScore += newPlayer.score3;
          if (newPlayer.score4 >= 0) totalScore += newPlayer.score4;
          if (newPlayer.score5 >= 0) totalScore += newPlayer.score5;

          newPlayer.totalScore = totalScore;

          numPresent += newPlayer.present ? 1 : 0;

          // insert into the db in rank order
          int insertRank = 0;

          for (Player pl in Player.db) {
            if (pl.currentRank > newPlayer.currentRank) {
              Player.db.insert(insertRank, newPlayer);
              break;
            }
            insertRank++;
          }

          if (insertRank == Player.db.length) {
            Player.db.add(newPlayer);
          }
        } else {
          if (doc.id == loggedInPlayerName) {
            int adminLevel = doc.get('Admin');

            if (adminLevel == 1) {
              Player.admin1Enabled = true;
              Player.admin2Enabled = false;
            }
            if (adminLevel == 2) {
              Player.admin1Enabled = true;
              Player.admin2Enabled = true;
            }
          }
        }
      }
    }
    // while (numPlayersLoaded < Player.db.length) {
    //   print('$numPlayersLoaded, ${Player.db.length}: cleaning up extra Player, probably because one was deleted');
    //   Player.db.removeAt(Player.db.length - 1);
    // }

    // done building the database, now use it
    // what are the assigned courts?
    var skipPlayer = List.filled(Player.db.length, false);
    int oldestIndex;

    for (Player pl in db) {
      pl.skipToMakeGoodNumber = false;
    }
    while ((Player.numPresent > (Player.courtsAvailable * 5)) |
        ((Player.numPresent < 4) & (Player.numPresent > 0)) |
        (Player.numPresent == 6) |
        (Player.numPresent == 7) |
        (Player.numPresent == 11)) {
      var oldest = DateTime(1999, 1, 1);
      oldestIndex = -1;
      for (int ii = 0; ii < skipPlayer.length; ii++) {
        if ((db[ii].present) &
            (!Player.db[ii].skipToMakeGoodNumber) &
            Player.db[ii].timePresent.isAfter(oldest)) {
          oldestIndex = ii;
          oldest = Player.db[ii].timePresent;
        }
      }
      Player.db[oldestIndex].skipToMakeGoodNumber = true;
      Player.numPresent--;
    }

    int numCourts =
        min((Player.numPresent / 4).floor(), Player.courtsAvailable);
    int courtsOf5 = Player.numPresent - numCourts * 4;

    var choices = List.filled(numCourts, 4);
    for (var i = 0; (i < courtsOf5) & (i < numCourts); i++) {
      choices[i] = 5;
    }

    var playersPerCourt1 = choices;
    int rotateAmt = 0;
    if (playersPerCourt1.isNotEmpty) {
      rotateAmt = Player.shift5Player;
    }
    Player.topOn1 = true;
    if ((Player.shift5Player % 2) == 0) {
      Player.topOn1 = false;
    }

    for (var i = 0; i < playersPerCourt1.length; i++) {
      // if (Player.topOn1) {
        Player.playersPerCourt[i] =
            playersPerCourt1[(i + rotateAmt) % playersPerCourt1.length];
      // } else {
      //   Player.playersPerCourt[i] = playersPerCourt1[playersPerCourt1.length -
      //       1 -
      //       ((i + rotateAmt) % playersPerCourt1.length)];
      // }
    }

    int court = 1;
    int numAssigned = 0;
    for (Player pl in Player.db) {
      if ((!pl.skipToMakeGoodNumber) & (pl.present)) {
        if ((court > Player.courtsAvailable) |
            (playersPerCourt[court - 1] <= 0)) {
          pl.assignedCourt = 0;
        } else {
          pl.assignedCourt = court;
          numAssigned++;

          if (numAssigned >= Player.playersPerCourt[court - 1]) {
            numAssigned = 0;
            court++;
          }
        }
      } else {
        if (pl.skipToMakeGoodNumber) {
          pl.assignedCourt = 0;
        } else {
          pl.assignedCourt = -1;
        }
      }
    }
    numberOfAssignedCourts = court - 1;
    courtInfoString = getCourtInfoString();

    List<int> workingRank = List.filled(Player.db.length, 0);
    List<bool> moveDown = List.filled(Player.db.length, false);
    List<bool> moveDownTwice = List.filled(Player.db.length, false);
    for (Player pl in Player.db) {
      int rank = pl.currentRank;
      workingRank[rank - 1] = rank;
      if (!pl.present) {
        moveDown[rank - 1] = true;
        if (pl.weeksAway == 0) {
          moveDownTwice[rank - 1] = true;
        }
      }
    }
    // print('workingRank1: $workingRank');
    // print('moveDown: $moveDown');
    for (int i = 0; i < workingRank.length; i++) {
      if (moveDown[i]) {
        int firstNonMoveDown = -1;
        for (int j = i + 1; j < workingRank.length; j++) {
          if (!moveDown[j]) {
            firstNonMoveDown = j;
            break;
          }
        }
        // print('firstNonMoveDown: $firstNonMoveDown  i:$i');
        if (firstNonMoveDown >= 0) {
          int moveUp = workingRank[firstNonMoveDown];
          bool saveMoveDownTwice = moveDownTwice[firstNonMoveDown];
          for (int j = firstNonMoveDown; j > i; j--) {
            workingRank[j] = workingRank[j - 1];
            moveDownTwice[j] = moveDownTwice[j - 1];
          }
          workingRank[i] = moveUp;
          moveDownTwice[i] = saveMoveDownTwice;
          i = firstNonMoveDown;
        }
      }
    }
    // print('workingRank2: $workingRank');
    // print('moveDownTwice: $moveDownTwice');
    for (int i = 0; i < workingRank.length; i++) {
      if (moveDownTwice[i]) {
        int firstNonMoveDown = -1;
        for (int j = i + 1; j < workingRank.length; j++) {
          if (!moveDownTwice[j]) {
            firstNonMoveDown = j;
            break;
          }
        }
        // print('firstNonMoveDown: $firstNonMoveDown  i:$i');
        if (firstNonMoveDown >= 0) {
          int moveUp = workingRank[firstNonMoveDown];
          for (int j = firstNonMoveDown; j > i; j--) {
            workingRank[j] = workingRank[j - 1];
          }
          workingRank[i] = moveUp;
          i = firstNonMoveDown;
        }
      }
    }
    // print('workingRank3: $workingRank');

    // now update things having to do with the score
    // List<int> awayRank = List.filled(Player.db.length + 2, -1, growable: true);
    List<int> awayRank = workingRank;

    // List<int> presentRank = List.filled(Player.db.length, -1);
    List<int> movementDueToAway = List.filled(Player.db.length, 0);

    // for (Player pl in Player.db) {
    //   int rank = pl.currentRank;
    //   int courtsToDrop=2;
    //   // if (pl.weeksAway>0){
    //   //   courtsToDrop=1;
    //   // }
    //   if (pl.present) {
    //     presentRank[rank - 1] = rank;
    //   } else {
    //     awayRank[rank + courtsToDrop - 1] = rank;
    //   }
    // }
    // // print('PresentRank: $presentRank');
    // // print('awayRank1: $awayRank');
    // int presentIndex = 0;
    // for (int i = 0; i < Player.db.length; i++) {
    //   if (awayRank[i] < 0) {
    //     for (int j = presentIndex; j < presentRank.length; j++) {
    //       if (presentRank[j] >= 0) {
    //         awayRank[i] = presentRank[j];
    //         presentIndex = j + 1;
    //         break;
    //       }
    //     }
    //   }
    // }
    // // now fix up case where there was no one present to put above people who had to move down2
    // for (int j = 0; j < 2; j++) {
    //   //might have to shuffle out 2 empty slots
    //   bool doShift = false;
    //   for (int i = 0; i < Player.db.length + 1; i++) {
    //     if (awayRank[i] < 0) {
    //       doShift = true;
    //     }
    //     if (doShift) {
    //       awayRank[i] = awayRank[i + 1];
    //     }
    //   }
    // }
    // awayRank.length = awayRank.length - 2;

    // print('awayRank: $awayRank');
    for (int i = 0; i < Player.db.length; i++) {
      int index = awayRank.indexOf(i + 1);
      movementDueToAway[i] = i - index;
    }

    List<int> movementDueToScore = List.filled(Player.db.length, 0);
    List<int> winnerRanks = List.empty(growable: true);
    List<int> loserRanks = List.empty(growable: true);

    //figure out the movement within each court
    for (int court = 1; court < 9; court++) {
      List<int> rank = List.empty(growable: true);
      List<int> assignedCourt = List.empty(growable: true);
      List<int> totalScores = List.empty(growable: true);
      List<int> finishOrder = List.empty(growable: true);
      int index = 0;
      for (var pl in Player.db) {
        int thisCourt = pl.assignedCourt;

        if (thisCourt == court) {
          assignedCourt.add(thisCourt);
          int thisRank = pl.currentRank;
          rank.add(thisRank);

          int thisScore = pl.totalScore;

          int thisIndex = 0;
          for (thisIndex = 0; thisIndex < totalScores.length; thisIndex++) {
            if (thisScore > totalScores[finishOrder[thisIndex]]) {
              break;
            } else if ((thisScore == totalScores[finishOrder[thisIndex]]) &
                (thisRank < rank[thisIndex])) {
              break;
            }
          }

          totalScores.add(thisScore);
          finishOrder.insert(thisIndex, index);
          index++;
        }
      }
      if (totalScores.isEmpty) break;

      for (var i = 0; i < finishOrder.length; i++) {
        int newPos = finishOrder[i];
        movementDueToScore[rank[finishOrder[i]] - 1] = rank[newPos] - rank[i];
      }
      winnerRanks.add(rank[finishOrder[0]]);
      loserRanks.add(rank[finishOrder.last]);

      // print('$court: $movementDueToScore');
    }

    List<int> newRankAfter2 = List.filled(Player.db.length, 0);
    List<int> orderAfter2 = List.filled(Player.db.length, 0);
    for (var i = 0; i < Player.db.length; i++) {
      newRankAfter2[i] = i + 1 - movementDueToScore[i];
      orderAfter2[i - movementDueToScore[i]] = i + 1;
    }
    // print('MovementDueToScore: $movementDueToScore');
    // print('newRankAfter2: $newRankAfter2');
    // print('orderAfter2: $orderAfter2');

    List<int> correctedMovementDueToAway = List.filled(Player.db.length, 0);
    for (var i = 0; i < Player.db.length; i++) {
      correctedMovementDueToAway[orderAfter2[i] - 1] = movementDueToAway[i];
    }

    // finally figure out the extra movements for winning and losing
    List<int> movementDueToWinnerJumping = List.filled(Player.db.length, 0);
    for (int court = 0; court < loserRanks.length - 1; court++) {
      int loserRank = loserRanks[court];
      int winnerRank = winnerRanks[court + 1];
      int loserNow = loserRank -
          correctedMovementDueToAway[loserRank - 1] -
          movementDueToScore[loserRank - 1];
      int winnerNow = winnerRank -
          correctedMovementDueToAway[winnerRank - 1] -
          movementDueToScore[winnerRank - 1];
      int jumpUp = winnerNow - loserNow;
      //print(          'Court:$court, l:$loserRank, w:$winnerRank, ln:$loserNow, wn:$winnerNow, j:$jumpUp');

      movementDueToWinnerJumping[winnerRank - 1] = jumpUp;
      movementDueToWinnerJumping[loserRank - 1] = -jumpUp;
    }
    // print('movementDueToWinnerJumping: $movementDueToWinnerJumping');

    for (Player pl in Player.db) {
      int rank = pl.currentRank;
      pl.movementDueToScore = movementDueToScore[rank - 1];
      pl.correctedMovementDueToAway = correctedMovementDueToAway[rank - 1];
      pl.movementDueToWinnerJumping = movementDueToWinnerJumping[rank - 1];
      pl.newRank = rank -
          pl.movementDueToScore -
          pl.correctedMovementDueToAway -
          pl.movementDueToWinnerJumping;
    }
    onUpdate.add(true);
  }

  static bool loggedInUserIsAdmin1() {
    Player? signedInUser = findPlayerByUID(loggedInUID);
    // print('admin1 $loggedInUID $signedInUser');
    if (signedInUser == null) {
      return false;
    }
    if (signedInUser.admin >= 1) {
      return true;
    }
    return false;
  }

  static bool loggedInUserIsAdmin2() {
    Player? signedInUser = findPlayerByUID(loggedInUID);
    if (signedInUser == null) {
      return false;
    }
    if (signedInUser.admin >= 2) {
      return true;
    }
    return false;
  }

  static void updateFreezeCheckIns(bool value) {
    Player.freezeCheckins = value;
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_')
        .update({
      'FreezeCheckIns': value,
    });
    if (!value) {
      if (kDebugMode) {
        print('updateFreezeCheckIns');
      }
      // clearAllScores(clearPresentAsWell: false);
    }
  }

  void updatePresent(bool value) {
    present = value;
    timePresent = DateTime.now();
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(playerName)
        .update({
      'Present': value,
      'TimePresent': timePresent,
    });
  }

  String getLastMovement() {
    final movement = lastMovement.split(':');
    String result;
    if (movement.length < 5){
      if (kDebugMode) {
        print('LastMovement is not filled in! Can not display');
      }
      return '';
    }
    result = 'Moved From Rank: ${movement[0]} To: ${movement[1]}\n';
    if (movement[2][0] == '-') {
      result += 'Moved down due to score: ${movement[2].substring(1)}\n';
    } else if (movement[2][0] != '0') {
      result += 'Moved UP due to score: ${movement[2]}\n';
    }
    if (movement[3][0] == '-') {
      result +=
          'Moved down due to being away: ${movement[3].substring(1)}\n';
    } else if (movement[3][0] != '0') {
      result += 'Moved UP due to others being away: ${movement[3]}\n';
    }
    if (movement[4][0] == '-') {
      result += 'Moved down due to finishing last: ${movement[4].substring(1)}\n';
    } else if (movement[4][0] != '0') {
      result += 'Moved UP due to finishing first: ${movement[4]}\n';
    }

    if (movement.length < 10){
      if (kDebugMode) {
        print('LastMovement does not have scores. Probably ok');
      }
      return result;
    }
    result+='Game Scores:';
    if (movement[5][0]!='-'){
      result+=movement[5].toString();
    } else {
      result+='0';
    }
    if (movement[6][0]!='-'){
      result+=',${movement[6]}';
    } else {
      result+=',0';
    }
    if (movement[7][0]!='-'){
      result+=',${movement[7]}';
    } else {
      result+=',0';
    }
    if ((movement[8][0]=='-')&&(movement[9][0]=='-')) {
      return result; // don't display trailing zeros
    }
    if (movement[8][0]!='-'){
      result+=',${movement[8]}';
    } else {
      result+=',0';
    }
    if (movement[9][0]!='-'){
      result+=',${movement[9]}';
    } else {
      result+=',0';
    }
    return result;
  }

  static String getCourtInfoString() {
    List<int> playersPerCourt = List.filled(courtsAvailable, 0);
    int courtsOf0 = 0;
    int expectedPlayers = 0;
    for (Player pl in Player.db) {
      if (pl.weeksAway == 0) {
        expectedPlayers++;
      }
      if (pl.assignedCourt > 0) {
        playersPerCourt[pl.assignedCourt - 1] += 1;
      } else if (pl.assignedCourt == 0) {
        courtsOf0 += 1;
      }
    }
    int courtsOf4 = 0;
    int courtsOf5 = 0;
    for (int court = 0; court < playersPerCourt.length; court++) {
      if (playersPerCourt[court] == 5) {
        courtsOf5 += 1;
      } else if (playersPerCourt[court] == 4) {
        courtsOf4 += 1;
      }
    }
    String retValue = '${courtsOf4}of4  &  ${courtsOf5}of5 #$expectedPlayers';
    if (courtsOf0 > 0) {
      retValue += ', +$courtsOf0';
    }
    // print('Court Info $retValue');
    return retValue;
  }

  static void updateConfirmScore(List<int> playersOnCourt){
    // print('Entering updateConfirmScore');
    if (!freezeCheckins) {
      if (kDebugMode) {
        print("Can't updateConfirmScore after we get out of freezeCheckIns!");
      }
      return;
    }
    Player? signedInUser = findPlayerByUID(loggedInUID);
    String signedInUserName = 'Admin';
    if (signedInUser != null) {
      signedInUserName = signedInUser.playerName;
    }
    WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
    for (int pl=0;pl<playersOnCourt.length;pl++){
      // print('playersOnCourt $pl ${playersOnCourt[pl]}');
      if (playersOnCourt[pl] >=0) {
        var doc = FirebaseFirestore.instance
            .collection(fireStoreCollectionName)
            .doc(Player.db[playersOnCourt[pl]].playerName);
        Player.db[playersOnCourt[pl]].scoreLastUpdatedBy +=
        '$signedInUserName!!';
        // print('updateConfirmScore ${Player.db[playersOnCourt[pl]]
        //     .scoreLastUpdatedBy}  ${Player.db[playersOnCourt[pl]]
        //     .playerName} $signedInUserName');
        var details = {
          'ScoreLastUpdatedBy':
          Player.db[playersOnCourt[pl]].scoreLastUpdatedBy,
        };
        scoreUpdate.update(doc, details);
      }
    }
    scoreUpdate.commit();
    // print('Finished updateConfirmScore');
  }
  static void updateScore(List<int> playersOnCourt, List<int> newScore) {
    if (!freezeCheckins) {
      if (kDebugMode) {
        print("Can't save the scores after we get out of freezeCheckIns!");
      }
      return;
    }
    List<DocumentReference> docsForPlayers = List.empty(growable: true);
    for (int playerNumber = 0;
        playerNumber < playersOnCourt.length;
        playerNumber++) {
      if (playersOnCourt[playerNumber] >= 0) {
        docsForPlayers.add(FirebaseFirestore.instance
            .collection(fireStoreCollectionName)
            .doc(Player.db[playersOnCourt[playerNumber]].playerName));
        int totalScore = 0;
        for (int i = 0; i < 5; i++) {
          int thisScore = newScore[playerNumber * 6 + i];
          if (thisScore < 0) thisScore = 0;
          totalScore += thisScore;
        }
        Player.db[playersOnCourt[playerNumber]].totalScore = totalScore;
      }
    }
    Player? signedInUser = findPlayerByUID(loggedInUID);
    String signedInUserName = 'Admin';
    if (signedInUser != null) {
      signedInUserName = signedInUser.playerName;
    }
    WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
    for (int playerNumber = 0;
        playerNumber < docsForPlayers.length;
        playerNumber++) {
      int scr1 = newScore[playerNumber * 6 + 0];
      int scr2 = newScore[playerNumber * 6 + 1];
      int scr3 = newScore[playerNumber * 6 + 2];
      int scr4 = newScore[playerNumber * 6 + 3];
      int scr5 = newScore[playerNumber * 6 + 4];
      // print("updateScore1: ${Player.db[playersOnCourt[playerNumber]].score1} == $scr1");
      // print("updateScore2: ${Player.db[playersOnCourt[playerNumber]].score2} == $scr2");
      // print("updateScore3: ${Player.db[playersOnCourt[playerNumber]].score3} == $scr3");
      if ((Player.db[playersOnCourt[playerNumber]].score1 != scr1) |
          (Player.db[playersOnCourt[playerNumber]].score2 != scr2) |
          (Player.db[playersOnCourt[playerNumber]].score3 != scr3) |
          (Player.db[playersOnCourt[playerNumber]].score4 != scr4) |
          (Player.db[playersOnCourt[playerNumber]].score5 != scr5)) {
        Player.db[playersOnCourt[playerNumber]].scoreLastUpdatedBy +=
            '$signedInUserName:$scr1$scr2$scr3${(scr4 >= 0) ? scr4.toString() : ""}${(scr5 >= 0) ? scr5.toString() : ""}/';
        var details = {
          'Score1': scr1,
          'Score2': scr2,
          'Score3': scr3,
          'Score4': scr4,
          'Score5': scr5,
          'ScoreLastUpdatedBy':
              Player.db[playersOnCourt[playerNumber]].scoreLastUpdatedBy,
        };
        // print('updateScore $details');
        scoreUpdate.update(docsForPlayers[playerNumber], details);
      }
    }
    scoreUpdate.commit();
  }

  static void clearAllScores({bool clearPresentAsWell = true}) {
    List<DocumentReference> docsForPlayers = List.empty(growable: true);
    for (int playerNumber = 0;
        playerNumber < Player.db.length;
        playerNumber++) {
      docsForPlayers.add(FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(Player.db[playerNumber].playerName));
      Player.db[playerNumber].score1 = -9;
      Player.db[playerNumber].score2 = -9;
      Player.db[playerNumber].score3 = -9;
      Player.db[playerNumber].score4 = -9;
      Player.db[playerNumber].score5 = -9;
      Player.db[playerNumber].totalScore = 0;
      if (clearPresentAsWell) {
        Player.db[playerNumber].present = false;
      }
    }

    WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
    for (int playerNumber = 0;
        playerNumber < Player.db.length;
        playerNumber++) {
      var details = <String, dynamic>{};
      details['Score1'] = -9;
      details['Score2'] = -9;
      details['Score3'] = -9;
      details['Score4'] = -9;
      details['Score5'] = -9;
      details['ScoreLastUpdatedBy'] = '';

      if (clearPresentAsWell) {
        details['Present'] = false;
      }
      scoreUpdate.update(docsForPlayers[playerNumber], details);
    }
    if (clearPresentAsWell) {
      //print('adding 1 to shift5Player=$shift5Player');
      Player.shift5Player += 1;
      scoreUpdate.update(
          FirebaseFirestore.instance
              .collection(fireStoreCollectionName)
              .doc('_configuration_'),
          {'shift5player': Player.shift5Player});
    }
    scoreUpdate.commit();
  }

  static Player? findPlayerByUID(String uid) {
    for (var pl in Player.db) {
      if (pl.uid == uid) {
        return pl;
      }
    }
    return null;
  }

  static Player? findPlayerByName(String name) {
    for (var pl in Player.db) {
      if (pl.playerName == name) {
        return pl;
      }
    }
    return null;
  }

  static Player? findPlayerByRank(int rank) {
    if (rank <= 0) return null;
    if (rank <= Player.db.length) {
      return Player.db[rank - 1];
    }
    return null;
  }

  static void createUser(String newName) {
    // check for duplicate name
    Player? shouldNotBeFound = findPlayerByName(newName);
    if (shouldNotBeFound != null) {
      if (kDebugMode) {
        print('Duplicate name entered, not creating user! $newName');
      }
      return;
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(newName)
        .set({
      'Admin': 0,
      'Present': false,
      'Rank': db.length + 1,
      'Score1': -9,
      'Score2': -9,
      'Score3': -9,
      'Score4': -9,
      'Score5': -9,
      'ScoreLastUpdatedBy': '',
      'TimePresent': Timestamp(1, 0),
      'UID': '',
    });
  }

  static void updateRank(String playerName, int newRank) {
    DocumentReference<Map<String, dynamic>> doc;
    Player? pl = findPlayerByName(playerName);
    if (pl == null) return;
    int oldRank = pl.currentRank;
    // print('updateRank from $oldRank to $newRank');
    if (newRank < oldRank) {
      WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
      for (int index = newRank - 1; index < Player.db.length; index++) {
        if (db[index].playerName == playerName) {
          break;
        }
        doc = FirebaseFirestore.instance
            .collection(fireStoreCollectionName)
            .doc(Player.db[index].playerName);
        scoreUpdate.update(doc, {'Rank': db[index].currentRank + 1});
      }
      doc = FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(playerName);
      scoreUpdate.update(doc, {'Rank': newRank});
      scoreUpdate.commit();
    } else if (newRank > oldRank) {
      WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
      doc = FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(playerName);
      scoreUpdate.update(doc, {'Rank': newRank});

      for (int index = oldRank; index < newRank; index++) {
        doc = FirebaseFirestore.instance
            .collection(fireStoreCollectionName)
            .doc(Player.db[index].playerName);
        scoreUpdate.update(doc, {'Rank': db[index].currentRank - 1});
        // print('updating ${Player.db[index].playerName} to ${db[index].currentRank - 1}');
        // if (db[index].playerName == playerName) {
        //   break;
        // }
      }
      scoreUpdate.commit();
    }
  }

  static void moveToOtherLadder(String newName) async {
    if (fireStoreCollectionName.substring(0, 9) != 'rg_monday') {
      if (kDebugMode) {
        print(
            'ERROR: should not try to move $newName from ladder $fireStoreCollectionName');
      }
      return;
    }
    String otherLadder = 'rg_monday_745';
    if (fireStoreCollectionName == 'rg_monday_745') {
      otherLadder = 'rg_monday_600';
    }
    Player? shouldBeFound = findPlayerByName(newName);
    if (shouldBeFound == null) {
      if (kDebugMode) {
        print('Name not found, not moving to other ladder! $newName');
      }
      return;
    }

    int newRank = 0;
    await FirebaseFirestore.instance
        .collection(otherLadder)
        .get()
        .then((doc) => {
              doc.docs.forEach((result) {
                if (otherLadder == 'rg_monday_745') {
                  newRank = 1;
                  int rank = result.get("Rank");
                  // print('745 Found entry ${rank} ${result.id}');

                  // WriteBatch rankUpdate = FirebaseFirestore.instance.batch();
                  if ((rank > 0) && (rank < 99)) {
                    FirebaseFirestore.instance
                        .collection(otherLadder)
                        .doc(result.id)
                        .update({'Rank': rank + 1});
                  }
                } else {
                  int rank = result.get("Rank");
                  if ((rank > 0) && (rank < 99) & (rank > newRank)) {
                    newRank = rank;
                  }
                }
              })
            });
    if (otherLadder == 'rg_monday_600') {
      newRank += 1;
    }
    // print('new rank is $newRank');
    FirebaseFirestore.instance.collection(otherLadder).doc(newName).set({
      'Admin': shouldBeFound.admin,
      'Present': false,
      'Rank': newRank,
      'Score1': -9,
      'Score2': -9,
      'Score3': -9,
      'Score4': -9,
      'Score5': -9,
      'LastMovement': shouldBeFound.lastMovement,
      'WeeksAway': shouldBeFound.weeksAway,
      'ScoreLastUpdatedBy': '',
      'TimePresent': Timestamp(1, 0),
      'UID': shouldBeFound.uid,
    });

    deleteUser(newName);
    return;
  }

  static void deleteUser(String newName) {
    // must be found
    Player? shouldNotBeFound = findPlayerByName(newName);
    if (shouldNotBeFound == null) {
      if (kDebugMode) {
        print('User not found, not deleting user! $newName');
      }
      return;
    }
    if (kDebugMode) {
      print(
          '$newName player db starts ${db.length} players before del ${db[db.length - 2].playerName} ${db[db.length - 1].playerName}');
    }
    updateRank(newName, db.length);
    if (kDebugMode) {
      print(
          'player db has ${db.length} players before del ${db[db.length - 2].playerName} ${db[db.length - 1].playerName}');
    }
    db.removeAt(db.length - 1);
    if (kDebugMode) {
      print('player db has ${db.length} players after remove at');
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(newName)
        .delete();
  }

  static void setAdminLevel(String newName, int newLevel) {
    if (newLevel < 0) return;

    // check for duplicate name
    Player? shouldBeFound = findPlayerByName(newName);
    if (shouldBeFound == null) {
      if (kDebugMode) {
        print('Name not found, not setting admin level! $newName');
      }
      return;
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(newName)
        .update({
      'Admin': newLevel,
    });
  }

  static void setWeeksAway(String newName, int newVal) {
    if (newVal < 0) return;
    if (newVal > 9) return;

    // check for duplicate name
    Player? shouldBeFound = findPlayerByName(newName);
    if (shouldBeFound == null) {
      if (kDebugMode) {
        print('Name not found, not setting weeks away! $newName');
      }
      return;
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(newName)
        .update({
      'WeeksAway': newVal,
    });
  }

  static void setCourtsAvailable(int newLevel) {
    if (newLevel < 0) return;

    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_')
        .update({
      'numberOfCourts': newLevel,
    });
    //print('SETTING courtsAvailable to $newLevel');
  }

  static void clearUID(String newName) {
    // check for duplicate name
    Player? shouldBeFound = findPlayerByName(newName);
    if (shouldBeFound == null) {
      if (kDebugMode) {
        print('Name not found, not clearing UID! $newName');
      }
      return;
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(newName)
        .update({
      'UID': '',
    });
  }

  void setUID(String newUID) {
    uid = newUID;
    if (kDebugMode) {
      print('Setting UID for $playerName to $newUID');
    }
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc(playerName)
        .update({
      'UID': newUID,
    });
  }

  static Future<bool> setEmail (String playerName, String newEmail) async {
    if (kDebugMode) {
      print('Setting email for $playerName to $newEmail');
    }
    try {
      await FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(playerName)
          .update({
        'Email': newEmail,
      });
      return true;
    } catch(e) {
      return false;
    }
  }

  static void setWeeksPlayed(int val) {
    weeksPlayed = val;
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_')
        .update({
      'WeeksPlayed': val,
    });
  }

  static Future<void> uploadScore() async {
    Uint8List? sourceFile;
    await FirebaseStorage.instance
        .ref(latestCompleteHistoryFile)
        .getData(1000000)
        .then((data) {
      sourceFile = data;
    }).catchError((error) {
      if (kDebugMode) {
        print('error on loading latest history file $error');
      }
    });
    // print('original history file length ${sourceFile!.length}');

    String filename = '$fireStoreCollectionName/history/${fireStoreCollectionName}_${DateTime.now()}.csv';
    setWeeksPlayed(Player.weeksPlayed + 1);
    String outputBuf = '';
    String header =
        'Week,Court,oldR,Pres.,+-pl,+-aw,+-Wi,scr1,scr2,scr3,scr4,scr5,Total,newR,Player Name              ,Time Present,Away,ScoredBy\n';
    for (Player pl in db) {
      outputBuf += '${Player.weeksPlayed.toString().padLeft(4)},';
      outputBuf += '${pl.assignedCourt.toString().padLeft(4)},';
      outputBuf += '${pl.currentRank.toString().padLeft(4)},';
      outputBuf += '${pl.present.toString().padLeft(5)},';
      outputBuf += '${pl.movementDueToScore.toString().padLeft(4)},';
      outputBuf += '${pl.correctedMovementDueToAway.toString().padLeft(4)},';
      outputBuf += '${pl.movementDueToWinnerJumping.toString().padLeft(4)},';
      outputBuf += '${pl.score1.toString().padLeft(4)},';
      outputBuf += '${pl.score2.toString().padLeft(4)},';
      outputBuf += '${pl.score3.toString().padLeft(4)},';
      outputBuf += '${pl.score4.toString().padLeft(4)},';
      outputBuf += '${pl.score5.toString().padLeft(4)},';
      outputBuf += '${pl.totalScore.toString().padLeft(5)},';
      outputBuf += '${pl.newRank.toString().padLeft(4)},';
      outputBuf += '${pl.playerName.toString().padRight(25)},';
      // no reason to include the time, if they weren't present
      if (pl.present) {
        outputBuf += '${pl.timePresent},';
      } else {
        outputBuf += ',';
      }
      outputBuf += '${pl.weeksAway},';
      outputBuf += '${pl.scoreLastUpdatedBy.toString().padLeft(15)},\n';
    }
    try {
      await firebase_storage.FirebaseStorage.instance.ref(filename).putString(
          header + outputBuf,
          format: firebase_storage.PutStringFormat.raw);
    } catch (e) {
      if (kDebugMode) {
        print('Error on write to storage $e');
      }
    }
    try {
      filename = '$fireStoreCollectionName/history/${fireStoreCollectionName}_complete_${DateTime.now()}.csv';
      if (kDebugMode) {
        print(
            'in uploadScore: starting with file $latestCompleteHistoryFile writing to file $filename');
      }
      await firebase_storage.FirebaseStorage.instance.ref(filename).putString(
          const Utf8Decoder().convert(sourceFile!) + outputBuf,
          format: firebase_storage.PutStringFormat.raw);

      historyFileList = null;
      buildHistoryFileList();
    } catch (e) {
      if (kDebugMode) {
        print('Error on write to storage $e');
      }
    }

    //print('Finished writing csv file to storage');
  }

  static void applyMovement() async {
    if (!freezeCheckins) return;
    await uploadScore();

    //print('starting to update ranks');
    DocumentReference<Map<String, dynamic>> doc;
    WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
    for (int index = 0; index < Player.db.length; index++) {
      if (db[index].weeksAway > 0) {
        db[index].weeksAway -= 1;
      }
      doc = FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(Player.db[index].playerName);
      scoreUpdate.update(doc, {
        'Rank': db[index].newRank,
        'WeeksAway': db[index].weeksAway,
        'LastMovement': '${db[index].currentRank}:${db[index].newRank}:${db[index].movementDueToScore}:${db[index].correctedMovementDueToAway}:${db[index].movementDueToWinnerJumping}:${db[index].score1}:${db[index].score2}:${db[index].score3}:${db[index].score4}:${db[index].score5}',
      });
    }
    doc = FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_');
    scoreUpdate.update(doc, {'FreezeCheckIns': false});
    scoreUpdate.commit();
    //print('apply movement');
    clearAllScores();
  }
}
