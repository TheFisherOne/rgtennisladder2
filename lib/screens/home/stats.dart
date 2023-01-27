import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:rgtennisladder/main.dart';
import 'package:rgtennisladder/services/storage_image.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:rgtennisladder/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_history.dart';
import 'package:rgtennisladder/screens/home/history.dart';

int statsPlayerNumber = -1;
Future<void> uploadPicture(XFile file) async {
  String filename =
      '$fireStoreCollectionName/player_pictures/${loggedInPlayerName!}';
  Uint8List fileData;
  img.Image? image;
  try {
    fileData = await file.readAsBytes();
  } catch (e) {
    if (kDebugMode) {
      print('error on readAsBytes $e');
    }
    return;
  }

  try {
    image = img.decodeImage(fileData);
  } catch (e) {
    if (kDebugMode) {
      print('error on decode $e');
    }
    return;
  }
  if (image == null) return;

  img.Image resized = img.copyResize(image, width: 200);
  try {
    await firebase_storage.FirebaseStorage.instance
        .ref(filename)
        .putData(img.encodePng(resized) as Uint8List);
  } catch (e) {
    if (kDebugMode) {
      print('Error on write to storage $e');
    }
  }
}

class Stats extends StatefulWidget {
  const Stats({Key? key}) : super(key: key);

  @override
  StatsState createState() => StatsState();
}

Future<Image> getPlayerImage(playerNumber) async {
  Uint8List blankBytes = const Base64Codec().decode(
      "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7");
  if (playerImageFileList == null) {
    return Image.memory(
      blankBytes,
      height: 1,
    ) as Future<Image>;
  }
  String name = Player.db[playerNumber].playerName;

  for (int i = 0; i < playerImageFileList!.length; i++) {
    FullMetadata element = playerImageFileList![i];
    if (element.name == name) {
      // print('found $name in imageList');
      var data = await firebase_storage.FirebaseStorage.instance
          .ref(element.fullPath)
          .getData();
      if (data == null) {
        return Image.memory(
          blankBytes,
          height: 1,
        ) as Future<Image>;
      }
      return Image.memory(data) as Future<Image>;
    }
  }
  return Image.memory(
    blankBytes,
    height: 1,
  ) as Future<Image>;
}

class StatsState extends State<Stats> {
  String? _imagePath;
  parentSetState(playerNumber) {
    setState(() {
      statsPlayerNumber = playerNumber;
      _imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // String playerName = '';
    // for (int index = 0; index < Player.db.length; index++) {
    //   if (Player.db[index].uid == loggedInUID) {
    //     playerName = Player.db[index].playerName;
    //   }
    // }
    String selectedName = '';
    String? selectedEmail;
    if (statsPlayerNumber >= 0) {
      selectedName = Player.db[statsPlayerNumber].playerName;
      selectedEmail=Player.db[statsPlayerNumber].email;
    }

    // print('stats build names: $selectedName, $loggedInPlayerName ');
    if ((playerImageFileList != null) & (statsPlayerNumber >= 0)) {
      for (int index = 0; index < playerImageFileList!.length; index++) {
        if (selectedName == playerImageFileList![index].name) {
          _imagePath = playerImageFileList![index].fullPath;
          // if (kDebugMode) {
          //   print('found matching path $_imagePath at $index for $selectedName');
          // }
        }
      }
    }

    return WillPopScope(
      onWillPop: () async {
        //check if the score changed
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.brown[50],
        appBar: AppBar(
          title: Text('$loggedInPlayerName vs \n$selectedName'),
          backgroundColor: Colors.brown[400],
          elevation: 0.0,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const History()));
              },
              icon: const Icon(Icons.history),
              enableFeedback: true,
              color: Colors.white,
            ),
          ],
        ),
        body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(10),
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black, backgroundColor: Colors.blue),
                onPressed: () async {
                  await launchUrl(Uri(path: 'assets/assets/DoublesLadderRules.pdf'));
                  // Navigator.push(context, MaterialPageRoute(builder:(context)=>const ShowRules()));
                },
                child: const Text('Open PDF of rules'),
              ),
              loggedInPlayerName != selectedName
                  ? (selectedName == ''
                      ? const Text('Please wait for picture to be processed')
                      : const Text('Here are the stats'))
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.green),
                      onPressed: () async {
                        // print('Select Picture');
                        XFile? pickedFile;
                        try {
                          pickedFile = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                        } catch (e) {
                          if (kDebugMode) {
                            print('Exception while picking image $e');
                          }
                        }
                        if (pickedFile == null) {
                          // print('No file picked');
                          return;
                        } else {
                          int savePlayerNumber = statsPlayerNumber;
                          parentSetState(-1);
                          await uploadPicture(pickedFile);
                          buildPlayerImageFileList(refresh: true);
                          parentSetState(savePlayerNumber);

                          // print(pickedFile.path);
                        }
                      },
                      child: const Text('Select new picture')),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    selectedName,
                    style: nameStyle,
                  ),
                ]),
                Row(children: [
                  _imagePath != null
                      ?
                      // const Text('Image available!!')
                      Center(child: StorageImage(fullPath: _imagePath!))
                      : const Text(
                          'Please upload an image so others can recognize you'),
                ]),
                Text(
                  'Admin Level: ${(statsPlayerNumber >= 0)
                          ? Player.db[statsPlayerNumber].admin.toString()
                          : 'XX'}',
                  style: nameStyle,
                  textAlign: TextAlign.end,
                ),
                ((selectedEmail!=null)&&((Player.admin2Enabled )|| (loggedInPlayerName == selectedName)))?OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.blue),
                    onPressed: () {
                      if (kDebugMode) {
                        print('password reset to $selectedEmail');
                      }
                      FirebaseAuth.instance.sendPasswordResetEmail(email: selectedEmail!);
                    },
                    child: const Text('Send Password Reset Email'))
                :const Text('Please log out and log in again\nWe have not recorded your email address yet'),
                Row(children: [
                  const Expanded(
                      child: Text(
                    'Weeks away:',
                    style: nameStyle,
                  )),
                  Expanded(
                      child: Player.admin2Enabled | (((Player.admin1Enabled) |
                                  (Player.db[statsPlayerNumber].playerName ==
                                      loggedInPlayerName)) &
                              ((DateTime.now().weekday !=
                                      Player.playOnWeekday) |
                                  (DateTime.now().hour < 8) |
                                  (DateTime.now().hour >= 22)))
                          ? TextFormField(
                              initialValue: Player
                                  .db[statsPlayerNumber].weeksAway
                                  .toString(),
                              style: nameStyle,
                              textAlign: TextAlign.center,
                              // decoration: decoration,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1)
                              ],
                              onChanged: (String value) {
                                if (value.length == 1) {
                                  setState(() {
                                    int newVal = 0;
                                    try {
                                      newVal = int.parse(value);
                                    } catch (e) {
                                      if (kDebugMode) {
                                        print('invalid entry to weeks away');
                                      }
                                      newVal = 0;
                                    }
                                    Player.setWeeksAway(selectedName, newVal);
                                  });
                                }
                              })
                          : ((Player.db[statsPlayerNumber].playerName ==
                                  loggedInPlayerName)
                              ? Text('${Player.db[statsPlayerNumber].weeksAway} :FROZEN 8am to 10pm\n   on day of ladder!')
                              : Text(
                                  Player.db[statsPlayerNumber].weeksAway
                                      .toString(),
                                  style: nameStyle)))
                ]),
                Text(
                  Player.db[statsPlayerNumber].getLastMovement(),
                  style: nameStyle,
                ),
                // (playerImage!=null)?Container( child: playerImage):const Text('No image'),
              ]),
              const Divider(
                color: Colors.black,
              ),
              loggedInPlayerName != selectedName
                  ? Row(children: [
                      StorageHistory(
                        fullPath: latestCompleteHistoryFile,
                        //fireStoreCollectionName+'_complete.csv',
                        loggedInPlayerName: loggedInPlayerName!,
                        comparisonPlayerName: selectedName,
                      )
                    ])
                  : const Text(''),
              const SizedBox(height: 20),
            ]),
      ),
    );
  }
}
