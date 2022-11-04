
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';



int lastWeekRecorded=-1;
var fileCache=[];
Uint8List? inFileCache(String fullPath){
  int indexFound=-1;
  int indexToDelete=-1;
  for (int index=0; index<fileCache.length; index++){
    if (DateTime.now().difference(fileCache[index]['date']).inMinutes<60) {
      if (fileCache[index]['path'] == fullPath) {
        indexFound=index;
        // fileCache[index]['date'] = DateTime.now();
      }
    } else {
      indexToDelete=index;  // only deletes 1 file each time
    }
  }
  if (indexToDelete>=0) {
    fileCache.removeAt(indexToDelete);
  }
  if (indexFound>=0){
    // print('found file in cache!!! $fullPath  length: ${fileCache[indexFound]['data'].length}');
    return fileCache[indexFound]['data'];
  }
  return null;
}
void addToFileCache(String fullPath, Uint8List data){
  var record = {};
  record['date'] = DateTime.now();
  record['path'] = fullPath;
  record['data'] = data;
  fileCache.add(record);
  // TODO add code to restrict the length of the cache
}

class StorageHistory extends StatelessWidget {
  final String fullPath;
  final String loggedInPlayerName;
  final String comparisonPlayerName;
  const StorageHistory(
      {Key? key,
      required this.fullPath,
      required this.loggedInPlayerName,
      required this.comparisonPlayerName})
      : super(key: key);
  Widget makeChildImage() {
    // not sure why to include extra function here
    // print('making history storage with $fullPath $loggedInPlayerName $comparisonPlayerName');
    return HistoryItem(
        fullPath: fullPath,
        loggedInPlayerName: loggedInPlayerName,
        comparisonPlayerName: comparisonPlayerName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // this is probably an extra container
      child: makeChildImage(),
    );
  }
}

class HistoryItem extends StatefulWidget {
  final String fullPath;
  final String loggedInPlayerName;
  final String comparisonPlayerName;
  const HistoryItem(
      {Key? key,
      required this.fullPath,
      required this.loggedInPlayerName,
      required this.comparisonPlayerName})
      : super(key: key);

  @override
  State<HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<HistoryItem> {
  Uint8List? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile=inFileCache(widget.fullPath);
    if (_imageFile!=null){
      setState(() {
        //_imageFile already set
      });
    } else {
      // print('HistoryStorage fullPath ${widget.fullPath}');
      FirebaseStorage.instance.ref(widget.fullPath).getData(1000000).then((
          data) {
        setState(() {
          _imageFile = data;
          addToFileCache(widget.fullPath, data!);
        });
      }).catchError((error) {
        if (kDebugMode) {
          print('error on loading history file $error');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('in HistoryItem build');
    var result = [];
    int maxWeek=0;
    if (_imageFile != null) {
      String x = utf8.decode(_imageFile!);
      // print('after decode');
      final resultCsv = const CsvToListConverter(allowInvalid: true, eol: '\n').convert(x);
      // print('CSV ${resultCsv.length}');
      int weekNumCol = 0;
      int courtNumCol = 1;
      int presentCol=3;
      int nameCol = 14;
      int scoreCol = 12;
      int numRows = resultCsv.length;
      // print('HistoryItem build $numRows');
      for (int row = 0; row < numRows; row++) {
        String name = resultCsv[row][nameCol].trim();
        // if (row==1){
        //   print('${widget.loggedInPlayerName} $name,${resultCsv[row][presentCol].trim()},${resultCsv[row][presentCol].trim()=='true'}  ');
        // }
        if ((name == widget.loggedInPlayerName)&(resultCsv[row][presentCol].trim()=='true')) {
          // print('row length ${resultCsv[row].length}');
          int weekNum = resultCsv[row][weekNumCol];
          if (weekNum>maxWeek)maxWeek=weekNum;
          int courtNum = resultCsv[row][courtNumCol];
          int loggedInScore = resultCsv[row][scoreCol];
          for (int row2 = 0; row2 < numRows; row2++) {
            String name2 = resultCsv[row2][nameCol].trim();
            //print('$row $row2 $name $name2 $courtNum ${resultCsv[row2][weekNumCol]} ${resultCsv[row2][presentCol].trim()}');
            if ((name2 == widget.comparisonPlayerName) &
                (resultCsv[row2][weekNumCol] == weekNum) &
                (resultCsv[row2][courtNumCol] == courtNum)&
                (resultCsv[row2][presentCol].trim()=='true')) {
              result.add({
                'week': weekNum,
                'score': loggedInScore - resultCsv[row2][scoreCol]
              });
            }
          }
        }
      }
      if (maxWeek>lastWeekRecorded)lastWeekRecorded=maxWeek;
      // print(result.length);
    }
    if (result.isEmpty){
      // print('HistoryItem null return');
      return const Center( child: Text('No history for this player'));
    }
    // print('HistoryItem Container: ${result.length} $maxWeek ');
    return Container(
        child: _imageFile == null
            ? const Center(child: Text('Loading...'))
            : Expanded(
              child: ListView.builder(
                  // physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  reverse: true,
                  itemCount: result.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Text(
                        '${(maxWeek+1-result[index]['week']).toString().padLeft(4,'0')} Weeks ago: ${result[index]['score'].toString().padLeft(5)}',
                        style: const TextStyle(fontSize: 20));
                  }),
            ));
  }
}
