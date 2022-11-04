import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rgtennisladder/services/player_db.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<String>? historyFileList;
String latestCompleteHistoryFile = '';

void buildHistoryFileList() async {
  if (historyFileList != null) return;
  historyFileList = [];
  // print('reading history files $fireStoreCollectionName');
  FirebaseStorage.instance
      .ref()
      .child(fireStoreCollectionName)
      .child('history')
      .listAll()
      .then((result) {
    for (var element in result.items) {
      historyFileList!.add(element.fullPath);
      if (element.fullPath.contains('_complete_')) {
        // print('buildHistoryFileList $latestCompleteHistoryFile  ${element.fullPath} ${element.fullPath.compareTo(latestCompleteHistoryFile)}');
        if (element.fullPath.compareTo(latestCompleteHistoryFile) > 0) {
          latestCompleteHistoryFile = element.fullPath;
        }
      }
    }
    if (kDebugMode) {
      print('Latest complete history file $latestCompleteHistoryFile');
    }
  });
}

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  String? _downloadURL;
  final _storage = FirebaseStorage.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.brown[50],
        appBar: AppBar(
          title: const Text('History'),
          backgroundColor: Colors.brown[400],
          elevation: 0.0,
          actions: const [],
        ),
        body: Column(
          children: <Widget>[
            InkWell(
                child: Text(_downloadURL == null
                    ? 'Files Available for ' + fireStoreCollectionName
                    : _downloadURL!),
                onTap: _downloadURL == null
                    ? null
                    : () {
                        // launch(_downloadURL!);
                        launchUrlString(_downloadURL!);
                      }),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: historyFileList == null ? 0 : historyFileList!.length,
                itemBuilder: (context, index) {
                  return ElevatedButton(
                      onPressed: () async {
                        String downloadURL = await _storage
                            .ref(historyFileList![historyFileList!.length - 1 - index])
                            .getDownloadURL();
                        setState(() {
                          _downloadURL = downloadURL;
                        });
                      },
                      child: Text(historyFileList == null
                          ? ''
                          : historyFileList![historyFileList!.length - 1 - index]
                              .toString()
                              .substring(
                                  fireStoreCollectionName.length * 2 + 10)));
                },
              ),
            )
          ],
        ));
  }
}
