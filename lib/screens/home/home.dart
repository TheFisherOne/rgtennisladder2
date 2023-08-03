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
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../services/storage_image.dart';
import 'administration.dart';
// import 'enter_scores2.dart';
import 'enter_scores3.dart';

HomeState? homeStateInstance;

enum Menu { itemOne, itemTwo, itemThree, itemFour }

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  bool _freezeCheckIns = false;
  bool _colorAdminIconRed = Player.admin1Enabled;

  AsyncSnapshot? homeSnapshot;

  final LocationService _loc = LocationService();
  bool _locInitialized = false;
  String _selectedMenu = '';

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

    // print('home build ladder: $fireStoreCollectionName user: $loggedInPlayerName');
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
              if ((item >= ladderList.length) ||
                  ((!Player.admin2Enabled) &&
                      (item == (ladderList.length - 1)))) {
                item = 0;
              }
              _selectedMenu = ladderList[item];
              setCollectionName(_selectedMenu);
              historyFileList = null;
              buildHistoryFileList();
            });
          }, itemBuilder: (BuildContext context) {
            var list = <PopupMenuEntry<int>>[];
            var numChoices = ladderList.length;
            if (!Player.admin2Enabled) {
              numChoices--;
            }
            for (int ladderNum = 0; ladderNum < numChoices; ladderNum++) {
              list.add(PopupMenuItem<int>(
                value: ladderNum,
                child: Text(ladderList[ladderNum]),
              ));
            }
            return list;
          }),
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
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(fireStoreCollectionName)
              .orderBy('Rank')
              .snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data == null) return const LinearProgressIndicator();

            homeSnapshot = snapshot;
            if (!Player.buildPlayerDB(snapshot)) {
              return const Text(
                  'You must force a reload to get a new software version');
            }
            _freezeCheckIns = Player.freezeCheckins;

            var pdb = Player.db;
            int numberOfPlayers = pdb.length;
            bool allScoresConfirmed = true;

            // check if the uid has been filled in yet or not
            // print('home StreamBuilder loggedInPlayerName $loggedInPlayerName');
            for (Player pl in pdb) {
              if (pl.playerName == loggedInPlayerName) {
                if (pl.uid == '') {
                  pl.setUID(loggedInUID);
                }
                if (pl.uid != loggedInUID) {
                  loggedInPlayerName = 'NEW email? $loggedInPlayerName';
                }
              }

              if (pl.present && !pl.scoreLastUpdatedBy.endsWith('!!')) {
                allScoresConfirmed = false;
              }
            }
            // print('allScoresConfirmed: $allScoresConfirmed');
            if (allScoresConfirmed && Player.weJustConfirmed) {
              Player.applyMovement();
            }
            Player.weJustConfirmed = false;
            var orderOfCourts =
                orderOfCourtsFull.sublist(0, Player.numberOfAssignedCourts);
            if ((Player.numberOfAssignedCourts >= 3) && (Player.topOn1) &&
                ((fireStoreCollectionName != 'rg_thursday_600') &&
                    (fireStoreCollectionName != 'rg_wednesday_100'))) {
              // move court 1 to the top and 8910 to the end
              orderOfCourts =
                  orderOfCourtsFull.sublist(3, Player.numberOfAssignedCourts);
              orderOfCourts.addAll(orderOfCourtsFull.sublist(0, 3));
            }
            // orderOfCourts is either 89T1x or 1x89T
            if ((fireStoreCollectionName == 'rg_thursday_600') ||
                (fireStoreCollectionName == 'rg_wednesday_100')){
              int numCourtsOf5 = 0;
              for (int court = 0; court < orderOfCourts.length; court++) {
                if (Player.playersPerCourt[court] == 5) {
                  numCourtsOf5 += 1;
                  if (numCourtsOf5 == 1) {
                    if (court > 0) {
                      int tmp = orderOfCourts[court];
                      orderOfCourts[court] = orderOfCourts[0];
                      orderOfCourts[0] = tmp;
                    }
                  } else if ((numCourtsOf5 == 2) &&
                      (orderOfCourts.length >= 3)) {
                    int tmp = orderOfCourts[court];
                    orderOfCourts[court] = orderOfCourts[2];
                    orderOfCourts[2] = tmp;
                  } else if ((numCourtsOf5 == 3) &&
                      (orderOfCourts.length >= 4)) {
                    int tmp = orderOfCourts[court];
                    orderOfCourts[court] = orderOfCourts[3];
                    orderOfCourts[3] = tmp;
                  }
                }
              }
            }

            // if (kDebugMode) {
            //   print('picking from courts $orderOfCourts  ${Player.numberOfAssignedCourts}');
            // }
            String adName = '';
            if (Player.adNumber > 0) {
              adName =
                  'assets/TennisAd${Player.adNumber.toString().padLeft(3, '0')}.jpg';
            }
            return Column(
              children: [
                Text(Player.courtInfoString,
                    style: const TextStyle(fontSize: 20)),
                Expanded(
                  child: ListView.separated(
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.black),
                      padding: const EdgeInsets.all(8),
                      itemCount: numberOfPlayers + 1,
                      itemBuilder: (BuildContext context, int row) {
                        int index = row - 1;
                        if (row == 0) {
                          if (Player.nonPlayingGuest) {
                            return Text(
                                'NOT Playing ${Player.nonPlayingAdmin ? ' Admin' : 'Guest'}:$loggedInPlayerName',
                                style: nameStyle);
                          }
                          if (adName != '') {
                            if (Player.adLink.isNotEmpty) {
                              return InkWell(
                                  child: StorageImage(fullPath: adName),
                                  onTap: () async {
                                    await launchUrl(Uri.parse(Player.adLink));
                                  }
                                  // onTap: () => launchUrl(Uri(path: Player.adLink)),
                                  );
                            } else {
                              return StorageImage(fullPath: adName);
                            }
                          } else {
                            return const Text('');
                          }
                        }
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
                                            if (pdb[i].uid == loggedInUID) {
                                              playerToEnterScore = i;
                                            }
                                            plNum++;
                                          }
                                        }
                                        if (plNum == 4) {
                                          playersOnCourt[plNum] = -1;
                                        }
                                        EnterScores3.prepareForScoreEntry(
                                            playersOnCourt, playerToEnterScore);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const EnterScores3()));
                                      }
                                    },
                                    child: (pdb[index].assignedCourt < 0
                                        ? Text(
                                            '${plusMinus.format(0)}${plusMinus.format(pdb[index].correctedMovementDueToAway)}${plusMinus.format(pdb[index].movementDueToWinnerJumping)}=${pdb[index].newRank}  ',
                                            style: nameStyle,
                                          )
                                        : Text(
                                            '${plusMinus.format(pdb[index].movementDueToScore)}${plusMinus.format(pdb[index].correctedMovementDueToAway)}${plusMinus.format(pdb[index].movementDueToWinnerJumping)}=${pdb[index].newRank}  ',
                                            style: nameStyle)))
                                : (pdb[index].weeksAway == 0)
                                    ? Checkbox(
                                        activeColor: pdb[index].admin > 0
                                            ? Colors.green
                                            : Colors.blue,
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
                                              // print('checking location $value');
                                              if ((locationOK | !value!) &
                                                  (loggedInUID ==
                                                      pdb[index].uid)) {
                                                if (((DateTime.now().weekday !=
                                                            Player
                                                                .playOnWeekday) |
                                                        (DateTime.now().hour <
                                                            8) |
                                                        (DateTime.now().hour >=
                                                            22)) &&
                                                    value) {
                                                  // print('wrong day');
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return const AlertDialog(
                                                            title: Text(
                                                                'What day is it?'),
                                                            content: Text(
                                                                'You can only check present on the day of the ladder!'));
                                                      });
                                                } else {
                                                  print('toggle present');
                                                  //toggle the present flag
                                                  pdb[index]
                                                      .updatePresent(value);
                                                }
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
                                                            content: Text(
                                                                'You have to be at the club before you can check in! \n${((myLocation.latitude! - Player.rgLatitude) / Player.rgHowClose).toStringAsFixed(2)} : ${((myLocation.longitude! - Player.rgLongitude) / Player.rgHowClose).toStringAsFixed(2)}'));
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
                                                        content: Text(
                                                            'Enable location for the browser too'));
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
                                style: (loggedInPlayerName ==
                                        pdb[index].playerName)
                                    ? nameBoldStyle
                                    : pdb[index].admin > 0
                                        ? italicNameStyle
                                        : nameStyle,
                              ),
                            )),
                            _freezeCheckIns & pdb[index].present
                                ? (Text(
                                    '${(pdb[index].assignedCourt > 0) ? orderOfCourts[pdb[index].assignedCourt - 1].toString() : ''}${pdb[index].scoreLastUpdatedBy.endsWith('!!') ? '!' : ':'}${pdb[index].totalScore}',
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
