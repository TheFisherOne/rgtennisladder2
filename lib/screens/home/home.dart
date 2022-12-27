import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rgtennisladder/screens/home/stats.dart';
import 'package:rgtennisladder/screens/wrapper.dart';
import 'package:rgtennisladder/services/location.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:rgtennisladder/services/auth.dart';
import 'package:location/location.dart';
import 'package:rgtennisladder/screens/home/history.dart';
import '../../main.dart';
import 'administration.dart';
import 'enter_scores2.dart';

_HomeState? homeStateInstance;
enum Menu { itemOne, itemTwo, itemThree, itemFour }

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _freezeCheckIns = false;
  bool _colorAdminIconRed = Player.admin1Enabled;

  AsyncSnapshot? homeSnapshot;

  final LocationService _loc = LocationService();
  bool _locInitialized = false;
  String _selectedMenu='';

  void updateAdmin1() {
    setState(() {
      _colorAdminIconRed = Player.admin1Enabled;
      // print('updateAdmin1: ${Player.admin1Enabled}');
    });
  }

  @override
  Widget build(BuildContext context) {
    homeStateInstance = this;
    buildHistoryFileList();
    buildPlayerImageFileList();
    OutlinedButton makeDoubleConfirmationButton(
        {buttonText,
        buttonColor = Colors.blue,
        dialogTitle,
        dialogQuestion,
        disabled,
        onOk}) {
      return OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: appBarColor),
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

    if (!_locInitialized) {
      _loc.init();
      _locInitialized = true;
    }

    double screenWidth = MediaQuery.of(context).size.width;
    _colorAdminIconRed = Player.admin1Enabled;
    // print('ladder: $fireStoreCollectionName');
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(fireStoreCollectionName.substring(3)),
        backgroundColor: appBarColor,
        elevation: 0.0,
        actions: <Widget>[
          PopupMenuButton<int>(
            // Callback that sets the selected popup menu item.
              onSelected: (int item) {
                setState(() {
                  _selectedMenu = ladderList[item];
                  // print('Selected $_selectedMenu');
                  setCollectionName(_selectedMenu);
                  historyFileList = null;
                  buildHistoryFileList();
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                PopupMenuItem<int>(
                  value: 0,
                  child: Text(ladderList[0]),
                ),
                PopupMenuItem<int>(
                  value: 1,
                  child: Text(ladderList[1]),
                ),
                PopupMenuItem<int>(
                  value: 2,
                  child: Text(ladderList[2]),
                ),
                PopupMenuItem<int>(
                  value: 3,
                  child: Text(ladderList[3]),
                ),
                PopupMenuItem<int>(
                  value: 4,
                  child: Text(ladderList[4]),
                ),
                PopupMenuItem<int>(
                  value: 5,
                  child: Text(ladderList[5]),
                ),
              ]),
          // ((fireStoreCollectionName.length > 9) &&
          //         (fireStoreCollectionName.substring(0, 9) == 'rg_monday'))
          //     ? IconButton(
          //         padding: EdgeInsets.zero,
          //         constraints: const BoxConstraints(),
          //         onPressed: () {
          //           if (fireStoreCollectionName == 'rg_monday_600') {
          //             setCollectionName('rg_monday_745');
          //             historyFileList = null;
          //             buildHistoryFileList();
          //           } else if (fireStoreCollectionName == 'rg_monday_745') {
          //             setCollectionName('rg_monday_600');
          //             historyFileList = null;
          //             buildHistoryFileList();
          //           }
          //           setState(() {});
          //         },
          //         icon: const Icon(Icons.toc),
          //         enableFeedback: true,
          //         // color: _colorAdminIconRed ? Colors.redAccent : Colors.white,
          //       )
          //     : const Text(''),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const Administration()));
            },
            icon: const Icon(Icons.admin_panel_settings),
            enableFeedback: true,
            color: _colorAdminIconRed ? Colors.redAccent : Colors.white,
          ),
          const SizedBox(width: 10),
          makeDoubleConfirmationButton(
              buttonText: 'LogOut',
              dialogTitle: 'You will have to enter your password again',
              dialogQuestion: 'Are you sure you want to logout?',
              disabled: false,
              onOk: () async {
                await AuthService().signOut();
              }),
          // IconButton(
          //   onPressed: () async {
          //     await AuthService().signOut();
          //   },
          //   icon: const Icon(Icons.logout),
          // )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(fireStoreCollectionName)
              .orderBy('Rank')
              // .where('Rank', isGreaterThan: 0)
              .snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data == null) return const LinearProgressIndicator();

            homeSnapshot = snapshot;
            Player.buildPlayerDB(snapshot);
            _freezeCheckIns = Player.freezeCheckins;

            var pdb = Player.db;
            int numberOfPlayers = pdb.length;

            // check if the uid has been filled in yet or not
            // print('home StreamBuilder loggedInPlayerName $loggedInPlayerName');
            for (Player pl in pdb) {
              if ((pl.playerName == loggedInPlayerName) & (pl.uid == '')) {
                pl.setUID(loggedInUID);
              }
            }
            // var orderOfCourts = orderOfCourts2;
            // if (Player.topOn1) {
            //   orderOfCourts = orderOfCourts1;
            // }
            // if (fireStoreCollectionName == 'rg_thursday_600') {
            //   orderOfCourts = orderOfCourtsThursday;
            // }
            var orderOfCourts =
                orderOfCourtsFull.sublist(0, Player.numberOfAssignedCourts);
            if ((Player.numberOfAssignedCourts >= 3) & (Player.topOn1)) {
              // move court 1 to the top and 8910 to the end
              orderOfCourts =
                  orderOfCourtsFull.sublist(3, Player.numberOfAssignedCourts);
              orderOfCourts.addAll(orderOfCourtsFull.sublist(0, 3));
            }
            // if (kDebugMode) {
            //   print('picking from courts $orderOfCourts  ${Player.numberOfAssignedCourts}');
            // }

            return Column(
              children: [
                Text(Player.courtInfoString,
                    style: const TextStyle(fontSize: 20)),
                Expanded(
                  child: ListView.separated(
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.black),
                      padding: const EdgeInsets.all(8),
                      itemCount: numberOfPlayers,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          // setting the background color of each line
                          color: pdb[index].assignedCourt > 0
                              ? courtColors[(pdb[index].assignedCourt - 1) %
                                  courtColors.length]
                              : (pdb[index].assignedCourt == 0
                                  ? Colors.red[100] //pink for not assigned
                                  : null),
                          child: Row(children: [
                            _freezeCheckIns
                                ? InkWell(
                                    onTap: () {
                                      int court = pdb[index].assignedCourt;

                                      int numPlayers = 0;
                                      if (court > 0) {
                                        numPlayers =
                                            Player.playersPerCourt[court - 1];
                                      }
                                      if ((numPlayers > 0) &
                                          (_freezeCheckIns)) {
                                        int plNum = 0;
                                        for (var i = 0; i < pdb.length; i++) {
                                          if (pdb[i].assignedCourt == court) {
                                            playersOnCourt[plNum] = i;
                                            if (i == index) {
                                              playerToEnterScore = plNum;
                                            }
                                            plNum++;
                                          }
                                        }
                                        if (plNum == 4) {
                                          playersOnCourt[plNum] = -1;
                                        }

                                        if (true |
                                            Player.admin1Enabled |
                                            (pdb[playersOnCourt[
                                                        playerToEnterScore]]
                                                    .uid ==
                                                loggedInUID)) {
                                          EnterScores2.prepareForScoreEntry(
                                              playersOnCourt,
                                              playerToEnterScore);
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      EnterScores2()));
                                        }
                                      }
                                    },
                                    child: (pdb[index].assignedCourt < 0
                                        ? Text(
                                            plusMinus.format(0) +
                                                plusMinus.format(pdb[index]
                                                    .correctedMovementDueToAways) +
                                                plusMinus.format(pdb[index]
                                                    .movementDueToWinnerJumping) +
                                                '=' +
                                                pdb[index].newRank.toString() +
                                                '  ',
                                            style: nameStyle,
                                          )
                                        : Text(
                                            plusMinus.format(pdb[index]
                                                    .movementDueToScore) +
                                                plusMinus.format(pdb[index]
                                                    .correctedMovementDueToAways) +
                                                plusMinus.format(pdb[index]
                                                    .movementDueToWinnerJumping) +
                                                '=' +
                                                pdb[index].newRank.toString() +
                                                '  ',
                                            style: nameStyle)))
                                : pdb[index].weeksAway == 0
                                    ? Checkbox(
                              activeColor: pdb[index].admin>0?Colors.green:Colors.blue,
                                        value: pdb[index].present,
                                        onChanged: (bool? value) {
                                          if (Player.admin1Enabled) {
                                            //toggle the present flag
                                            pdb[index].updatePresent(value!);
                                          } else {
                                            Future<LocationData?> loc =
                                                _loc.updateLocation();

                                            loc.then((myLocation) {
                                              if (myLocation == null) {
                                                return;
                                              }

                                              double rgLatDiff =
                                                  (myLocation.latitude! -
                                                          Player.rgLatitude)
                                                      .abs();
                                              double rgLongDiff =
                                                  (myLocation.longitude! -
                                                          Player.rgLongitude)
                                                      .abs();
                                              bool locationOK = (rgLatDiff <
                                                      Player.rgHowClose) &
                                                  (rgLongDiff <
                                                      Player.rgHowClose);

                                              if ((locationOK | !value!) &
                                                  (loggedInUID ==
                                                      pdb[index].uid)) {
                                                //toggle the present flag
                                                pdb[index].updatePresent(value);
                                              } else {
                                                if (loggedInUID !=
                                                    pdb[index].uid) {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return const AlertDialog(
                                                            title: Text(
                                                                'Who are you?'),
                                                            content: Text(
                                                                'You can only check your own name off!'));
                                                      });
                                                } else {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return AlertDialog(
                                                            title: const Text(
                                                                'Location,Location,Location'),
                                                            content: Text('You have to be at the club before you can check in!  ' +
                                                                ((myLocation.latitude! -
                                                                            Player
                                                                                .rgLatitude) /
                                                                        Player
                                                                            .rgHowClose)
                                                                    .toStringAsFixed(
                                                                        2) +
                                                                " : " +
                                                                ((myLocation.longitude! -
                                                                            Player
                                                                                .rgLongitude) /
                                                                        Player
                                                                            .rgHowClose)
                                                                    .toStringAsFixed(
                                                                        2)));
                                                      });
                                                }
                                              }
                                            }).catchError((err) {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return const AlertDialog(
                                                        title: Text(
                                                            'You have to enable location '),
                                                        content: Text('Enable location for the browser too')  );
                                                  });
                                            });
                                          }
                                        })
                                    : const Text('   ---   '),
                            Expanded(
                                child: InkWell(
                              onTap: () {
                                statsPlayerNumber = index;
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const Stats()));
                              },
                              child: Text(
                                (_freezeCheckIns & (screenWidth < 400))
                                    ? '${pdb[index].currentRank.toString()}:'
                                        '${pdb[index].playerName.substring(0, pdb[index].playerName.lastIndexOf(' ')) + pdb[index].playerName.substring(pdb[index].playerName.lastIndexOf(' ') + 1, pdb[index].playerName.lastIndexOf(' ') + 2)}'
                                    : '${pdb[index].currentRank}: ${pdb[index].playerName}',
                                style: (loggedInUID == pdb[index].uid)
                                    ? nameBoldStyle
                                    : nameStyle,
                              ),
                            )),
                            _freezeCheckIns & pdb[index].present
                                ? (Text(
                                    ((pdb[index].assignedCourt > 0)
                                            ? orderOfCourts[
                                                    pdb[index].assignedCourt -
                                                        1]
                                                .toString()
                                            : '') +
                                        ':' +
                                        pdb[index].totalScore.toString(),
                                    style: nameStyle,
                                  ))
                                : Text(
                                    ((pdb[index].assignedCourt > 0)
                                        ? orderOfCourts[
                                                pdb[index].assignedCourt - 1]
                                            .toString()
                                        : ''),
                                    style: nameStyle),
                            const SizedBox(width: 10),
                          ]),
                        );
                      }),
                )
              ],
            );
          }),
    );
  }
}
