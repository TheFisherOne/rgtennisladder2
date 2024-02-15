import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rgtennisladder/screens/authenticate/sign_in.dart';
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
  bool _waitingForLocationForCheckIn = false;
  DateTime _startOfWaitForCheckIn = DateTime.now();

  AsyncSnapshot? homeSnapshot;

  final LocationService _loc = LocationService();
  bool _locInitialized = false;
  String _selectedMenu = '';
  final List<int> _playerOverrides = List.empty(growable: true);

  void updateAdmin1() {
    setState(() {
      _colorAdminIconRed = Player.admin1Enabled;
      // print('updateAdmin1: ${Player.admin1Enabled}');
    });
  }

  List<String> getOrderOfCourts(int numCourts) {
    List<String> orderOfCourtsStr = Player.finalOrderOfCourts;

    // print('Start $orderOfCourtsStr Number of Courts assigned: ${Player.numberOfAssignedCourts}');
    List<String> priorityCourts = Player.priorityOfCourts.split(',');

    for (int i = priorityCourts.length - 1; i >= 0; i--) {
      if (!orderOfCourtsStr.contains(priorityCourts[i])) {
        priorityCourts.removeAt(i);
      }
    }
    // print('PriorityCourts: $priorityCourts  $numCourts');
    if (numCourts <= 0) {
      return orderOfCourtsStr;
    }

    int courtToRemove = priorityCourts.length - 1;
    int fullLen = orderOfCourtsStr.length;
    for (int removeCourt = Player.numberOfAssignedCourts;
        removeCourt < fullLen;
        removeCourt++) {
      // print('Removing $removeCourt, ${priorityCourts[courtToRemove]}');
      orderOfCourtsStr.remove(priorityCourts[courtToRemove]);
      courtToRemove -= 1;
    }
    // print('after priorityassignment: $orderOfCourtsStr ');

    // String courtsForFivesStrings=Player.courtsForFives;
    // List<String> courtsForFivesArray=courtsForFivesStrings.split(',');

    List<int> needToMove = List.filled(0, 0, growable: true);
    var tmpCourtsForFives = Player.courtsForFivesArray;
    for (int court = 0; court < numCourts; court++) {
      if (Player.playersPerCourt[court] == 5) {
        if (tmpCourtsForFives.contains(orderOfCourtsStr[court])) {
          tmpCourtsForFives.remove(orderOfCourtsStr[court]);
        } else {
          // print('added court $court to list needToMove');
          needToMove.add(court);
        }
      }
    }
    // print('needToMove $needToMove $tmpCourtsForFives');

    while ((needToMove.isNotEmpty) & (tmpCourtsForFives.isNotEmpty)) {
      int courtToMove = -1;
      for (int court1 = 0; court1 < orderOfCourtsStr.length; court1++) {
        if (orderOfCourtsStr[court1] == tmpCourtsForFives[0]) {
          courtToMove = court1;
        }
      }
      if (courtToMove < 0) {
        if (kDebugMode) {
          print(
              'Config error: ${orderOfCourtsStr[needToMove[0]]} not in CourtsForFives: $tmpCourtsForFives');
        }
        break; //error handling
      }
      String tmp = orderOfCourtsStr[needToMove[0]]; //current assigned court
      orderOfCourtsStr[needToMove[0]] = tmpCourtsForFives[0];
      // print('exchanging $tmp with ${orderOfCourtsStr[courtToMove]}');
      orderOfCourtsStr[courtToMove] = tmp;

      needToMove.removeAt(0);
      tmpCourtsForFives.removeAt(0);
    }
    // print('After move would be $orderOfCourtsStr');
    Player.workingOrderOfCourtsStr = orderOfCourtsStr;
    return orderOfCourtsStr;
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
      // print('home.dart build ${FirebaseAuth.instance.currentUser?.email}');
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

            // not sure why this is needed but sometimes only a single record is returned.
            // this causes major problems in buildPlayerDB
            // seems to occur after refresh, admin mode is selected
            // and first person is marked present by admin
            // print('StreamBuilder: ${snapshot.hasError}, ${snapshot.connectionState}, ${snapshot.requireData.docs.length}');
            if (snapshot.requireData.docs.length <= 1) {
              return const LinearProgressIndicator();
            }
            homeSnapshot = snapshot;
            if (!Player.buildPlayerDB(snapshot)) {
              //this forces a reload of the web page
              Navigator.pushReplacementNamed(context, '/');
              // ModalRoute.of(context)!.settings.name!);
              return const Text(
                  'You must force a reload to get a new software version');
            }
            _freezeCheckIns = Player.freezeCheckins;

            var pdb = Player.db;
            int numberOfPlayers = pdb.length;

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

              if (!pl.present && pl.scoreLastUpdatedBy.isNotEmpty) {
                if (kDebugMode) {
                  print(
                      "ERROR! player ${pl.playerName} is marked not present after scores were entered!!!! fixing this");
                }
                pl.updatePresent(true);
              }
            }
            // print('allScoresConfirmed: Done?:$allScoresConfirmed  Us last?:'
            // '${Player.weJustConfirmed} Who did: ${Player.lastScoreConfirm}');
            // if (allScoresConfirmed && Player.weJustConfirmed &&
            // (Player.lastScoreConfirm == loggedInPlayerName ) ){
            //   Player.applyMovement();
            // }
            // Player.weJustConfirmed = false;
            // var orderOfCourts =
            //     orderOfCourtsFull.sublist(0, Player.numberOfAssignedCourts);
            // if ((Player.numberOfAssignedCourts >= 3) &&
            //     (Player.topOn1) &&
            //     ((fireStoreCollectionName != 'rg_thursday_600') &&
            //         (fireStoreCollectionName != 'rg_wednesday_100'))) {
            //   // move court 1 to the top and 8910 to the end
            //   orderOfCourts =
            //       orderOfCourtsFull.sublist(3, Player.numberOfAssignedCourts);
            //   orderOfCourts.addAll(orderOfCourtsFull.sublist(0, 3));
            // }
            // print('playersPerCourt ${Player.numberOfAssignedCourts}');
            List<String> orderOfCourtsStr =
                getOrderOfCourts(Player.numberOfAssignedCourts);

            String adName = '';
            if (Player.adNumber > 0) {
              adName =
                  'assets/TennisAd${Player.adNumber.toString().padLeft(3, '0')}.jpg';
              print('adName: $adName');
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
                              // print('adLink.isNotEmpty');
                              return InkWell(
                                  child: StorageImage(fullPath: adName),
                                  onTap: () async {
                                    await launchUrl(Uri.parse(Player.adLink));
                                  }
                                  // onTap: () => launchUrl(Uri(path: Player.adLink)),
                                  );
                            } else {
                              // print('adLink is empty');
                              return StorageImage(fullPath: adName);
                            }
                          } else {
                            return const Text('');
                          }
                        }
                        return Container(
                          // setting the background color of each line
                          color: _freezeCheckIns
                              ? (pdb[index].assignedCourt > 0
                                  ? courtColors[(pdb[index].assignedCourt - 1) %
                                      courtColors.length]
                                  : (pdb[index].assignedCourt == 0
                                      ? Colors.red[100] //pink for not assigned
                                      : null))
                              : null,
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
                                    child: (pdb[index].assignedCourt < 0)
                                        ? const Text(
                                            '           ',
                                            style: nameStyle,
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.black,
                                                  width: 3),
                                            ),
                                            child: Text(
                                              'Sc:${'${pdb[index].totalScore}'.padLeft(2)} ',
                                              style: nameStyle,
                                            ),
                                          ),
                                  )
                                : (pdb[index].weeksAway == 0)
                                    ? Checkbox(
                                        activeColor:
                                            (_playerOverrides.contains(index))
                                                ? Colors.red
                                                : Colors.blue,
                                        value: pdb[index].present,
                                        onChanged: (bool? value) {
                                          _startOfWaitForCheckIn =
                                              DateTime.now();
                                          if ((value == null) ||
                                              (_waitingForLocationForCheckIn)) {
                                            if (kDebugMode) {
                                              print(
                                                  'still waiting for location to come back, but pressing button again');
                                            }
                                            showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return const AlertDialog(
                                                      title: Text(
                                                          'Waiting for Location update'),
                                                      content: Text(
                                                          'Please do not press the checkbox twice.'));
                                                });
                                            return;
                                          }

                                          if (!value) {
                                            // uncheck
                                            showDialog<String>(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                          title: const Text(
                                                              "You are no longer going to Play?"),
                                                          content: Text(
                                                            pdb[index]
                                                                .playerName,
                                                            textScaler:
                                                                const TextScaler
                                                                    .linear(2),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                                child: const Text(
                                                                    'Cancel:Yes  I am')),
                                                            TextButton(
                                                                onPressed: () {
                                                                  // print('${DateTime.now()} / $_startOfWaitForCheckIn / ${DateTime.now().difference(_startOfWaitForCheckIn ).inMinutes}');
                                                                  if (DateTime.now()
                                                                          .difference(
                                                                              _startOfWaitForCheckIn)
                                                                          .inMinutes >=
                                                                      2) {
                                                                    if (kDebugMode) {
                                                                      print(
                                                                          'Timing out uncheck of present');
                                                                    }
                                                                    Navigator.pop(
                                                                        context);
                                                                    return;
                                                                  }
                                                                  setState(() {
                                                                    int alreadyThere =
                                                                        _playerOverrides
                                                                            .indexOf(index);
                                                                    if (alreadyThere >=
                                                                        0) {
                                                                      _playerOverrides
                                                                          .removeAt(
                                                                              alreadyThere);
                                                                    }
                                                                    pdb[index]
                                                                        .updatePresent(
                                                                            false);
                                                                  });

                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                                child: const Text(
                                                                    'Confirm:Not Playing')),
                                                          ],
                                                        ));
                                            return;
                                          }
                                          if (!Player.admin2Enabled) {
                                            if ((DateTime.now().weekday !=
                                                    Player.playOnWeekday) |
                                                (DateTime.now().hour <
                                                    (ladderHour - 3)) |
                                                (DateTime.now().hour >
                                                    (ladderHour))) {
                                              // print('wrong day');
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return const AlertDialog(
                                                        title: Text(
                                                            'What day is it?'),
                                                        content: Text(
                                                            'You can only check present on the day of the ladder! (and only 3 hours before ladder start)'));
                                                  });
                                              return;
                                            }
                                          }
                                          if (Player.admin1Enabled) {
                                            showDialog<String>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                      title: const Text(
                                                          "Helper Check In"),
                                                      content: Text(
                                                        pdb[index].playerName,
                                                        textScaler:
                                                            const TextScaler
                                                                .linear(2),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: const Text(
                                                                'cancel check in')),
                                                        TextButton(
                                                            onPressed: () {
                                                              setState(() {
                                                                pdb[index]
                                                                    .updatePresent(
                                                                        true);
                                                                _playerOverrides
                                                                    .add(index);
                                                              });

                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: const Text(
                                                                'OK')),
                                                      ],
                                                    ));
                                            _waitingForLocationForCheckIn = false;
                                            return;
                                          } else {
                                            _waitingForLocationForCheckIn =
                                                true;
                                            Future<LocationData?> loc =
                                                _loc.updateLocation();

                                            loc.then((myLocation) {
                                              if (myLocation == null) {
                                                _waitingForLocationForCheckIn =
                                                    false;
                                                showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return const AlertDialog(
                                                          title: Text(
                                                              'Get Location Error'),
                                                          content: Text(
                                                              'Your phone did not return your location'));
                                                    });
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
                                              if ((locationOK) &
                                                  (loggedInUID ==
                                                      pdb[index].uid)) {
                                                // print('toggle present');
                                                //toggle the present flag
                                                pdb[index].updatePresent(true);
                                              } else {
                                                if (loggedInUID !=
                                                    pdb[index].uid) {
                                                  if (Player
                                                      .loggedInUserIsAdmin1()) {
                                                    showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          return const AlertDialog(
                                                              title: Text(
                                                                  'Who are you?'),
                                                              content: Text(
                                                                  'you must click on the shield in the top right\n'
                                                                  'and enable Helper 1 mode to check in someone else'));
                                                        });
                                                  } else {
                                                    showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                              title: const Text(
                                                                  'Who are you?'),
                                                              content: Text(
                                                                  '$loggedInPlayerName is who you logged in as\n'
                                                                  '${pdb[index].playerName} is who you clicked\n'
                                                                  'Names must match exactly or\n'
                                                                  'you must be admin to check someone else'));
                                                        });
                                                  }
                                                } else {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return AlertDialog(
                                                            title: const Text(
                                                                'Location,Location,Location'),
                                                            content: Text(
                                                                'You have to be at the club before you can check in! \n'
                                                                '${((myLocation.latitude! - Player.rgLatitude) / Player.rgHowClose).toStringAsFixed(2)} :'
                                                                '${((myLocation.longitude! - Player.rgLongitude) / Player.rgHowClose).toStringAsFixed(2)}'));
                                                      });
                                                }
                                              }
                                              _waitingForLocationForCheckIn =
                                                  false;
                                            }).catchError((err) {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    _waitingForLocationForCheckIn =
                                                        false;
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
                                // (_freezeCheckIns & (screenWidth < 400))
                                //     ? '${pdb[index].currentRank.toString()}:'
                                //      '${pdb[index].playerName.substring(0, pdb[index].playerName.lastIndexOf(' ')) + pdb[index].playerName.substring(pdb[index].playerName.lastIndexOf(' ') + 1, pdb[index].playerName.lastIndexOf(' ') + 2)}'
                                //     :
                                ' ${pdb[index].currentRank}: ${pdb[index].playerName}',
                                style: (loggedInPlayerName ==
                                        pdb[index].playerName)
                                    ? nameBoldStyle
                                    : pdb[index].admin > 0
                                        ? italicNameStyle
                                        : nameStyle,
                              ),
                            )),
                            InkWell(
                              onTap: () => showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: _freezeCheckIns
                                            ? const Text('Current Info')
                                            : const Text(
                                                'Last Ladder Completed'),
                                        content: _freezeCheckIns
                                            ? const Text(
                                                'Assigned Court\nCurrent Score')
                                            : const Text(
                                                'Rank Before\nCourt Number\nPlayers on Court\n'
                                                'Score\nOR\nRank Before\nYou were Away'),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Clear')),
                                        ],
                                      )),
                              child: (_freezeCheckIns &
                                      pdb[index].present &
                                      (orderOfCourtsStr.length >
                                          (pdb[index].assignedCourt - 1)))
                                  ? (Text(
                                      '${pdb[index].scoreLastUpdatedBy.endsWith('!!/') ? 'To:${pdb[index].newRank} ' : ''}'
                                      ' Ct:${(pdb[index].assignedCourt > 0) ? orderOfCourtsStr[pdb[index].assignedCourt - 1] : ''}',
                                      style: nameStyle,
                                    ))
                                  : Text(
                                      (_freezeCheckIns & !pdb[index].present)
                                          ? 'To:${pdb[index].newRank}         '
                                          : ' ',
                                      style: nameStyle),
                            ),
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
