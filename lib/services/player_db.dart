import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quiver/collection.dart';
import 'package:rgtennisladder/screens/authenticate/sign_in.dart';
import 'package:rgtennisladder/screens/home/administration.dart';
import 'package:rgtennisladder/screens/wrapper.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import '../main.dart';
import '../screens/home/history.dart';

String fireStoreCollectionName = 'no_collection_name';
List<int> absentOnCourt = List.empty(growable: true);
final random = Random();

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
        // .child(fireStoreCollectionName)
        .child('PlayerPictures')
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
  static int adNumber = 0;
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
  static String lastScoreConfirm = '';

  // stuff for location
  static double rgLatitude = 0;
  static double rgLongitude = 0;
  static double rgHowClose = 0;

  static int numPresent = 0;
  static List<int> playersPerCourt =
      List.filled(10, 0); //larger than it needs to be
  static var onUpdate = StreamController<bool>.broadcast();
  static int numberOfAssignedCourts = 0;
  static String adLink = '';
  static bool weJustConfirmed = false;
  static bool nonPlayingGuest = true;
  static bool nonPlayingAdmin = false;

  static int debugRotateAmount = 0;
  // static List<int>? orderOfCourts;
  static List<String> orderOfCourts = ['', '', '', ''];
  static List<String> finalOrderOfCourts = ['', '', '', ''];
  static int orderOfCourtsUsed = 0;
  static List<String> workingOrderOfCourtsStr = [];
  static String courtsNotAvailable = '';
  static List<String> courtsNotAvailableArray = [];
  static String courtsForFives = '';
  static List<String> courtsForFivesArray = [];
  static String priorityOfCourts = '';
  static bool atLeast1ScoreEntered = false;

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
  int placeOnCourt = 0;
  int origPlaceOnCourt = 0;
  int correctedMovementDueToAway = 0;
  int movementDueToWinnerJumping = 0;
  int newRank = 0;
  String lastMovement = '';
  String? email;

  static bool buildPlayerDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    numPresent = 0;
    Player.nonPlayingAdmin = false;
    Player.nonPlayingGuest = true;
    atLeast1ScoreEntered = false;

    // print('snapshot len: ${snapshot.requireData.docs.length}');
    db = List.empty(growable: true);
    for (var doc in snapshot.requireData.docs) {
      // print('buildPlayerDB ${doc.id}');
      if (doc.id == '_configuration_') {
        // Player.courtsAvailable = doc.get("numberOfCourts");
        Player.shift5Player = doc.get("shift5player");
        Player.rgLatitude = doc.get("latitude");
        Player.rgLongitude = doc.get("longitude");
        Player.rgHowClose = doc.get("howClose");
        Player.freezeCheckins = doc.get('FreezeCheckIns');
        Player.weeksPlayed = doc.get('WeeksPlayed');
        Player.playOnWeekday = doc.get('PlayOnWeekday');
        Player.lastScoreConfirm = doc.get('LastScoreConfirm');
        try {
          Player.orderOfCourts[0] = doc.get('OrderOfCourts1');
          Player.orderOfCourts[1] = doc.get('OrderOfCourts2');
          Player.orderOfCourts[2] = doc.get('OrderOfCourts3');
          Player.orderOfCourts[3] = doc.get('OrderOfCourts4');
          Player.orderOfCourtsUsed = doc.get('OrderOfCourtsUsed');
          Player.courtsNotAvailable = doc.get('CourtsNotAvailable');
          Player.courtsForFives = doc.get('CourtsForFives');
          Player.priorityOfCourts = doc.get('PriorityOfCourts');
        } catch (e) {
          if (kDebugMode) {
            print('ERROR!!!!!!! court order info not all in _configuration_');
          }
        }
        for (int i = 0; i < 4; i++) {
          if (orderOfCourts[orderOfCourtsUsed - 1].isNotEmpty) {
            break;
          }
          orderOfCourtsUsed += 1;
          if (orderOfCourtsUsed > 4) {
            orderOfCourtsUsed = 1;
          }
        }
        finalOrderOfCourts = orderOfCourts[orderOfCourtsUsed - 1].split(',');
        courtsNotAvailableArray = courtsNotAvailable.split(',');
        courtsForFivesArray = courtsForFives.split(',');

        for (int i = 0; i < courtsNotAvailableArray.length; i++) {
          finalOrderOfCourts.remove(courtsNotAvailableArray[i]);
          courtsForFivesArray.remove(courtsNotAvailableArray[i]);
        }
        Player.courtsAvailable = finalOrderOfCourts.length;

        // print('Using OrderOfCourts[$OrderOfCourtsUsed]  ${OrderOfCourts[OrderOfCourtsUsed-1]}');

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
        // print("needs version: ${doc.get('RequiredSoftwareVersion')} running version $softwareVersion");
        if (doc.get('RequiredSoftwareVersion') > softwareVersion) {
          db.clear();
          if (kDebugMode) {
            print('SOFTWARE NEEDS UPDATING!!!!!!!!!!');
          }
          return false;
        }
      } else {
        String? nameError = playerValidator(doc.id);
        if (nameError != null) {
          if (kDebugMode) {
            print('ERROR in database, bad player name:"${doc.id}" $nameError');
          }
        }
        int rank = doc.get('Rank');
        if (rank > 0) {
          Player? newPlayer = Player();
          newPlayer.playerName = doc.id; // actually player name

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
            newPlayer.placeOnCourt = doc.get('PlaceOnCourt');
          } catch (e) {
            newPlayer.placeOnCourt = 0;
          }
          try {
            newPlayer.lastMovement = doc.get('LastMovement');
          } catch (e) {
            newPlayer.lastMovement = '0:0:0:0:0:0:0:0:0:0:0:0';
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

          if (totalScore > 0 ){
            atLeast1ScoreEntered = true;
          }

          numPresent += newPlayer.present ? 1 : 0;

          // insert into the db in rank order
          int insertRank = 0;
          // print('CHECKING: ${doc.id}/$loggedInPlayerName');
          if (doc.id == loggedInPlayerName) {
            Player.nonPlayingGuest = false;
            // print('found logged in player ${doc.id}');
          }

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
            if (adminLevel > 1) {
              Player.nonPlayingAdmin = true;
            }

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
    // print('results: ${Player.nonPlayingGuest } ${Player.nonPlayingAdmin}');
    // done building the database, now use it
    // what are the assigned courts?
    var skipPlayer = List.filled(Player.db.length, false);
    int oldestIndex;

    bool skippedAtLeastOne = false;
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
      skippedAtLeastOne = true;
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

    // print("playersPerCourt1-1: $playersPerCourt1");
    // playersPerCourt1 is of length total number of courts needed
    // with the first n marked as 5 and the last ones marked as 4
    // keep the first choice as a court of 5
    // print('playersPerCourt1 before: $playersPerCourt1');
    if (playersPerCourt1.length == 3) {
      int tmp = playersPerCourt1[2];
      playersPerCourt1[2] = playersPerCourt1[1];
      playersPerCourt1[1] = tmp;
    } else if (playersPerCourt1.length == 4) {
      int tmp = playersPerCourt1[2];
      playersPerCourt1[2] = playersPerCourt1[1];
      playersPerCourt1[1] = tmp;
    } else if (playersPerCourt1.length > 4) {
      int tmp = playersPerCourt1[4];
      playersPerCourt1[4] = playersPerCourt1[2];
      playersPerCourt1[2] = tmp;
      tmp = playersPerCourt1[2];
      playersPerCourt1[2] = playersPerCourt1[1];
      playersPerCourt1[1] = tmp;
    }
    // print('playersPerCourt1 after: $playersPerCourt1');
    List<int> prevPlayersPerCourt = Player.playersPerCourt;
    debugRotateAmount = rotateAmt % playersPerCourt1.length;
    // print("playersPerCourt1a: $playersPerCourt1 $rotateAmt ${playersPerCourt1.length} ${debugRotateAmount}");

    if (overrideCourt4to5 >= 0) {
      prevPlayersPerCourt[overrideCourt4to5 - 1] = 5;
    } else {
      for (var i = 0; i < playersPerCourt1.length; i++) {
        // print('court5 shuffle: $i, $rotateAmt, ${playersPerCourt1.length}, ${(i + rotateAmt) % playersPerCourt1.length}');
        Player.playersPerCourt[i] =
            playersPerCourt1[(i + rotateAmt) % playersPerCourt1.length];
      }
    }

    // print("playersPerCourt1b: $playersPerCourt");
    int court = 1;
    int numAssigned = 0;
    List<int> onACourtOf = List.filled(Player.db.length, 0);
    absentOnCourt = List.filled(Player.db.length, 0);
    int playerIndex = 0;
    int playersOnLastCourt = 0;
    int lastCourt = -1;
    for (Player pl in Player.db) {
      if ((!pl.skipToMakeGoodNumber) & (pl.present)) {
        if ((court > Player.courtsAvailable) |
            (playersPerCourt[court - 1] <= 0)) {
          // we ran out of available courts
          pl.assignedCourt = 0;
          onACourtOf[playerIndex] = playersPerCourt[court - 1];
          // print('playerIndex $playerIndex');
        } else {
          // normal case
          pl.assignedCourt = court;
          numAssigned++;
          onACourtOf[playerIndex] = playersPerCourt[court - 1];

          if (numAssigned >= Player.playersPerCourt[court - 1]) {
            // last person on the court move to next court
            playersOnLastCourt = Player.playersPerCourt[court - 1];
            lastCourt = court;
            numAssigned = 0;
            court++;
          } else {
            playersOnLastCourt = Player.playersPerCourt[court - 1];
            lastCourt = court;
          }
        }
      } else {
        // special case of skipping players that are present
        // AND the players that are not present
        if (playersPerCourt[court - 1] == 0) {
          // at end of list
          if (court >= 2) {
            // handle special case when very few people here
            onACourtOf[playerIndex] = playersPerCourt[court - 2];
          }
          if (!pl.present &&
              !skippedAtLeastOne &&
              (onACourtOf[playerIndex] != 5)) {
            absentOnCourt[playerIndex] = lastCourt;
          }
        } else {
          if ((playersOnLastCourt == 4) || (playersPerCourt[court - 1] == 4)) {
            if ((!pl.present) &&
                (playersPerCourt[court - 1] == 4) &&
                !skippedAtLeastOne) {
              absentOnCourt[playerIndex] = court;
            } else if ((!pl.present) &&
                (playersOnLastCourt == 4) &&
                !skippedAtLeastOne) {
              absentOnCourt[playerIndex] = court - 1;
            }
            onACourtOf[playerIndex] = 4;
          } else {
            onACourtOf[playerIndex] = 5;
          }
        }
        if (pl.skipToMakeGoodNumber) {
          pl.assignedCourt = 0;
        } else {
          pl.assignedCourt = -1;
        }
      }
      playerIndex += 1;
    }
    // print('onACourtOf    $onACourtOf');
    // print('absentOnCourt $absentOnCourt ${absentOnCourt.length}');
    numberOfAssignedCourts = court - 1;
    courtInfoString = getCourtInfoString();

    List<int> workingRank = List.filled(Player.db.length, 0);
    List<bool> moveDown = List.filled(Player.db.length, false);
    List<bool> moveDownTwice = List.filled(Player.db.length, false);
    // print('workingRank: $workingRank');
    for (Player pl in Player.db) {
      int rank = pl.currentRank;
      workingRank[rank - 1] = rank;
      if (fireStoreCollectionName.substring(3, 5) == 'PB') {
        if (!pl.present) {
          moveDown[rank - 1] = true;
        }
      } else if (!pl.present) {
        moveDown[rank - 1] = true;
        if ((pl.weeksAway == 0)) {
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

    // print('awayRank: $awayRank');
    for (int i = 0; i < Player.db.length; i++) {
      int index = awayRank.indexOf(i + 1);
      movementDueToAway[i] = i - index;
    }

    List<int> movementDueToScore = List.filled(Player.db.length, 0);
    List<int> placeOnCourt = List.filled(Player.db.length, 0);
    List<int> origPlaceOnCourt = List.filled(Player.db.length, 0);
    List<int> winnerRanks = List.empty(growable: true);
    List<int> loserRanks = List.empty(growable: true);

    //figure out the movement within each court
    for (int court = 1; court < 9; court++) {
      List<int> rank = List.empty(growable: true);
      List<int> totalScores = List.empty(growable: true);
      List<int> finishOrder = List.empty(growable: true);
      int index = 0;
      for (var pl in Player.db) {
        int thisCourt = pl.assignedCourt;

        if (thisCourt == court) {
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
        placeOnCourt[rank[finishOrder[i]] - 1] = i + 1;
        origPlaceOnCourt[rank[i] - 1] = i + 1;
        // print('finish: $i, ${finishOrder[i]} ${rank[finishOrder[i]]}');
      }
      // print('finishOrder: $court $finishOrder $rank $origPlaceOnCourt');
      winnerRanks.add(rank[finishOrder[0]]);
      loserRanks.add(rank[finishOrder.last]);

      // print('$court: $movementDueToScore');
      // print('$court: finishOrder $finishOrder');
    }

    List<int> newRankAfter2 = List.filled(Player.db.length, 0);
    List<int> orderAfter2 = List.filled(Player.db.length, 0);
    for (var i = 0; i < Player.db.length; i++) {
      newRankAfter2[i] = i + 1 - movementDueToScore[i];
      orderAfter2[i - movementDueToScore[i]] = i + 1;
    }
    // print('MovementDueToScore: $movementDueToScore');
    // print('placeOnCourt: $placeOnCourt');

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
      pl.placeOnCourt = placeOnCourt[rank - 1];
      pl.origPlaceOnCourt = origPlaceOnCourt[rank - 1];
      pl.correctedMovementDueToAway = correctedMovementDueToAway[rank - 1];
      pl.movementDueToWinnerJumping = movementDueToWinnerJumping[rank - 1];
      pl.newRank = rank -
          pl.movementDueToScore -
          pl.correctedMovementDueToAway -
          pl.movementDueToWinnerJumping;
    }
    onUpdate.add(true);
    return true;
  }

  static List<bool> isOrderOfCourtsValid() {
    List<bool> result = [true, true, true, true];
    var sortedPriority = Player.priorityOfCourts.split(',');
    sortedPriority.sort();

    for (int i = 0; i < Player.orderOfCourts.length; i++) {
      var list1 = Player.orderOfCourts[i].split(',');
      // print('orderOfCourts $i $list1 ${list1.length}');
      if (list1[0].isEmpty) {
        result[i] = true;
      } else {
        list1.sort();
        result[i] = listsEqual(sortedPriority, list1);
      }
    }
    return result;
  }

  static bool isCourtsForFivesValid() {
    var sortedPriority = Player.priorityOfCourts.split(',');
    sortedPriority.sort();
    var list1 = Player.courtsForFives.split(',');
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].isNotEmpty && !sortedPriority.contains(list1[i])) {
        // print('isCourtsForFivesValid $i $list1 , ${list1[i]} from $sortedPriority');
        return false;
      }
      sortedPriority.remove(list1[0]);
    }
    return true;
  }

  static bool isCourtsNotAvailableValid() {
    var sortedPriority = Player.priorityOfCourts.split(',');
    sortedPriority.sort();
    var list1 = Player.courtsNotAvailable.split(',');
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].isNotEmpty && !sortedPriority.contains(list1[i])) {
        // print('isCourtsNotAvailable $i $list1 , ${list1[i]} from $sortedPriority');
        return false;
      }
      sortedPriority.remove(list1[0]);
    }
    return true;
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

  String getLastWeeksInfo() {
    final movement = lastMovement.split(':');

    if (movement.length < 15) {
      return '';
    }
    if (movement[12] == '0') {
      if (movement[3] != '0') {
        return '${movement[0]}${movement[3]}';
      } else {
        return '${movement[0]}-0';
      }
    }
    return '${movement[0]}:${movement[12]}:${movement[13]}:${movement[14]}';
  }

  String getLastMovement() {
    final movement = lastMovement.split(':');
    String result;
    if (movement.length < 5) {
      if (kDebugMode) {
        print('LastMovement is not filled in! Can not display');
      }
      return '';
    }
    result = 'Moved From Rank: ${movement[0]} To: ${movement[1]}\n';
    result +=
        'You moved from place ${(movement.length > 11) ? movement[11] : '-'} to ${movement[10]}\n';

    if (movement[2][0] == '-') {
      result += 'Moved down due to score: ${movement[2].substring(1)}\n';
    } else if (movement[2][0] != '0') {
      result += 'Moved UP due to score: ${movement[2]}\n';
    }
    if (movement[3][0] == '-') {
      result += 'Moved down due to being away: ${movement[3].substring(1)}\n';
    } else if (movement[3][0] != '0') {
      result += 'Moved UP due to others being away: ${movement[3]}\n';
    }
    if (movement[4][0] == '-') {
      result +=
          'Moved down due to finishing last: ${movement[4].substring(1)}\n';
    } else if (movement[4][0] != '0') {
      result += 'Moved UP due to finishing first: ${movement[4]}\n';
    }

    if (movement.length < 10) {
      if (kDebugMode) {
        print('LastMovement does not have scores. Probably ok');
      }
      return result;
    }
    result += 'Game Scores:';
    if (movement[5][0] != '-') {
      result += movement[5].toString();
    } else {
      result += '0';
    }
    if (movement[6][0] != '-') {
      result += ',${movement[6]}';
    } else {
      result += ',0';
    }
    if (movement[7][0] != '-') {
      result += ',${movement[7]}';
    } else {
      result += ',0';
    }
    if ((movement[8][0] == '-') && (movement[9][0] == '-')) {
      return result; // don't display trailing zeros
    }
    if (movement[8][0] != '-') {
      result += ',${movement[8]}';
    } else {
      result += ',0';
    }
    if (movement[9][0] != '-') {
      result += ',${movement[9]}';
    } else {
      result += ',0';
    }
    return result;
  }

  static String getCourtInfoString() {
    List<int> playersPerCourt = List.filled(courtsAvailable, 0);
    int courtsOf0 = 0;
    int expectedPlayers = 0;
    int presentPlayers = 0;
    for (Player pl in Player.db) {
      if (pl.weeksAway == 0) {
        expectedPlayers++;
      }
      if (pl.assignedCourt > 0) {
        playersPerCourt[pl.assignedCourt - 1] += 1;
        presentPlayers += 1;
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
    String retValue =
        '${courtsOf4}of4  &  ${courtsOf5}of5 =$presentPlayers/$expectedPlayers';
    if (courtsOf0 > 0) {
      retValue += ', +$courtsOf0';
    }

    // retValue += ' >$debugRotateAmount';
    // print('Court Info $retValue');
    return retValue;
  }

  static void updateConfirmScore(List<int> playersOnCourt) {
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
    for (int pl = 0; pl < playersOnCourt.length; pl++) {
      // print('playersOnCourt $pl ${playersOnCourt[pl]}');
      if (playersOnCourt[pl] >= 0) {
        var doc = FirebaseFirestore.instance
            .collection(fireStoreCollectionName)
            .doc(Player.db[playersOnCourt[pl]].playerName);
        Player.db[playersOnCourt[pl]].scoreLastUpdatedBy +=
            '$signedInUserName!!/';

        // print('updateConfirmScore ${Player.db[playersOnCourt[pl]]
        //     .scoreLastUpdatedBy}  ${Player.db[playersOnCourt[pl]]
        //     .playerName} $signedInUserName');
        var details = {
          'ScoreLastUpdatedBy':
              Player.db[playersOnCourt[pl]].scoreLastUpdatedBy,
        };
        scoreUpdate.update(doc, details);
      }
      // print('ConfirmScore $loggedInPlayerName');
      var doc = FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc('_configuration_');
      scoreUpdate.update(doc, {'LastScoreConfirm': loggedInPlayerName});
    }

    scoreUpdate.commit();
    // print('Finished updateConfirmScore');
    weJustConfirmed = true;
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
      Player.shift5Player = random.nextInt(1000);
      Player.orderOfCourtsUsed += 1;
      if ((Player.orderOfCourtsUsed > 4) || (Player.orderOfCourtsUsed < 1)) {
        Player.orderOfCourtsUsed = 1;
      }
      for (int i = 0; i < 4; i++) {
        if (orderOfCourts[orderOfCourtsUsed - 1].isNotEmpty) {
          break;
        }
        orderOfCourtsUsed += 1;
        if (orderOfCourtsUsed > 4) {
          orderOfCourtsUsed = 1;
        }
      }
      // print('shift5Player: $shift5Player  OrderOfCourtsUsed $OrderOfCourtsUsed');
      scoreUpdate.update(
          FirebaseFirestore.instance
              .collection(fireStoreCollectionName)
              .doc('_configuration_'),
          {
            'shift5player': Player.shift5Player,
            'OrderOfCourtsUsed': Player.orderOfCourtsUsed
          });
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
    if ((fireStoreCollectionName.substring(0, 9) != 'rg_monday') &&
        (fireStoreCollectionName.substring(0, 13) != 'rg_sunday_700')) {
      if (kDebugMode) {
        print(
            'ERROR: should not try to move $newName from ladder $fireStoreCollectionName');
      }
      return;
    }
    String otherLadder = 'rg_monday_745';
    if (fireStoreCollectionName == 'rg_monday_745') {
      otherLadder = 'rg_monday_600';
    } else if (fireStoreCollectionName == 'rg_sunday_700') {
      otherLadder = 'rg_sunday_700b';
    } else if (fireStoreCollectionName == 'rg_sunday_700b') {
      otherLadder = 'rg_sunday_700';
    }
    Player? shouldBeFound = findPlayerByName(newName);
    if (shouldBeFound == null) {
      if (kDebugMode) {
        print('Name not found, not moving to other ladder! $newName');
      }
      return;
    }
    // print('Moving player $newName from $fireStoreCollectionName to $otherLadder');
    int newRank = 0;
    // await FirebaseFirestore.instance
    //     .collection(otherLadder)
    //     .get()
    //     .then((doc) => {
    //           doc.docs.forEach((result) {
    //             if ((otherLadder == 'rg_monday_745') || (otherLadder == 'rg_sunday_700b')) {
    //               newRank = 1;
    //               int rank = result.get("Rank");
    //
    //               //shuffle everyone down
    //               if ((rank > 0) && (rank < 900)) {
    //                 FirebaseFirestore.instance
    //                     .collection(otherLadder)
    //                     .doc(result.id)
    //                     .update({'Rank': rank + 1});
    //               }
    //             } else {
    //               int rank = result.get("Rank");
    //               if ((rank > 0) && (rank < 99) & (rank > newRank)) {
    //                 newRank = rank;
    //               }
    //             }
    //           })
    //         });
    WriteBatch rankUpdate = FirebaseFirestore.instance.batch();
    await FirebaseFirestore.instance
        .collection(otherLadder)
        .get()
        .then((result) {
      for (var doc in result.docs) {
        // print('shuffling: ${doc.id}');
        if ((otherLadder == 'rg_monday_745') ||
            (otherLadder == 'rg_sunday_700b')) {
          newRank = 1;
          int rank = doc.get("Rank");

          //shuffle everyone down
          if ((rank > 0) && (rank < 900)) {
            // print('shuffling down $otherLadder, ${doc.id} Rank: ${rank+1}');
            rankUpdate.update(doc.reference, {'Rank': rank + 1});
            // FirebaseFirestore.instance
            //     .collection(otherLadder)
            //     .doc(result.id)
            //     .update({'Rank': rank + 1});
          }
        } else {
          int rank = doc.get("Rank");
          if ((rank > 0) && (rank < 99) & (rank > newRank)) {
            newRank = rank;
          }
        }
      }
    });
    await rankUpdate.commit();
    // this is actually setting the rank to be 1 more than the highest found
    if ((otherLadder == 'rg_monday_600') || (otherLadder == 'rg_sunday_700')) {
      newRank += 1;
    }
    // print('new rank is $newRank for $newName in ladder $otherLadder');
    await FirebaseFirestore.instance.collection(otherLadder).doc(newName).set({
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
    // print('moved $newName');
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
    //need to prevent someone clicking "Present" then WeeksAway
    // but also want to allow them to set WeeksAway at 22:00 even if the ladder is still frozen
    // clearing "Present" when the ladder is frozen results in a serious corruption of the scoring
    // the Present flag will be cleared when the scores are finalized
    if (Player.freezeCheckins) {
      FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(newName)
          .update({
        'WeeksAway': newVal,
        // 'Present': false,
      });
    } else {
      FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(newName)
          .update({
        'WeeksAway': newVal,
        'Present': false,
      });
    }
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

  static void incrementShift5Player() {
    FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_')
        .update({'shift5player': FieldValue.increment(1)});
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

  static Future<bool> setEmail(String playerName, String newEmail) async {
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
    } catch (e) {
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

    String filename =
        '$fireStoreCollectionName/history/${fireStoreCollectionName}_${DateTime.now()}.csv';
    setWeeksPlayed(Player.weeksPlayed + 1);
    String outputBuf = '';
    String header =
        'Week,Court,oldR,Pres.,+-pl,+-aw,+-Wi,scr1,scr2,scr3,scr4,scr5,Total,newR,Player Name              ,Time Present,Away,ScoredBy,Court,Players,TotalScore\n';
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
      outputBuf += '${pl.scoreLastUpdatedBy.toString().padLeft(15)},';
      outputBuf +=
          '${(pl.assignedCourt > 0) ? workingOrderOfCourtsStr[pl.assignedCourt - 1] : 0},';
      outputBuf +=
          '${(pl.assignedCourt > 0) ? playersPerCourt[pl.assignedCourt - 1] : 0},';
      outputBuf += '${pl.totalScore.toString().padLeft(3)},\n';
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
      filename =
          '$fireStoreCollectionName/history/${fireStoreCollectionName}_complete_${DateTime.now()}.csv';
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

  static void applyMovement({bool clearPresentAsWell = true}) async {
    if (!freezeCheckins) return;
    await uploadScore();

    //print('starting to update ranks');
    DocumentReference<Map<String, dynamic>> doc;
    WriteBatch scoreUpdate = FirebaseFirestore.instance.batch();
    // print('playersPerCourt: $playersPerCourt');
    for (int index = 0; index < Player.db.length; index++) {
      if (db[index].weeksAway > 0) {
        db[index].weeksAway -= 1;
      }
      doc = FirebaseFirestore.instance
          .collection(fireStoreCollectionName)
          .doc(Player.db[index].playerName);
      // print('index: $index, assignedCourt: ${db[index].assignedCourt}');
      scoreUpdate.update(doc, {
        'Rank': db[index].newRank,
        'WeeksAway': db[index].weeksAway,
        'LastMovement':
            '${db[index].currentRank}:${db[index].newRank}:${db[index].movementDueToScore}:${db[index].correctedMovementDueToAway}:${db[index].movementDueToWinnerJumping}:${db[index].score1}:${db[index].score2}:${db[index].score3}:${db[index].score4}:${db[index].score5}:${db[index].placeOnCourt}:${db[index].origPlaceOnCourt}:${(db[index].assignedCourt > 0) ? workingOrderOfCourtsStr[db[index].assignedCourt - 1] : 0}:${(db[index].assignedCourt > 0) ? playersPerCourt[db[index].assignedCourt - 1] : 0}:${db[index].totalScore}',
      });
    }
    doc = FirebaseFirestore.instance
        .collection(fireStoreCollectionName)
        .doc('_configuration_');
    scoreUpdate.update(doc, {'FreezeCheckIns': false});
    scoreUpdate.commit();
    //print('apply movement');
    clearAllScores(clearPresentAsWell: clearPresentAsWell);
  }
}
