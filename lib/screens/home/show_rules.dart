import 'package:flutter/material.dart';

import '../../services/storage_image.dart';

String rulesPdfPath = "";

class ShowRules extends StatefulWidget {
  const ShowRules({Key? key}) : super(key: key);

  @override
  State<ShowRules> createState() => _ShowRulesState();
}

class _ShowRulesState extends State<ShowRules> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ladder Rules"),
      ),
      body: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 1,
          maxScale: 4,
          child: ListView(shrinkWrap: true, children: const [
            StorageImage(fullPath: 'assets/Rules0001.jpg'),
            StorageImage(fullPath: 'assets/Rules0002.jpg'),
            StorageImage(fullPath: 'assets/Rules0003.jpg'),
            StorageImage(fullPath: 'assets/Rules0004.jpg'),
            StorageImage(fullPath: 'assets/Rules0005.jpg'),
          ])),
    );
  }
}
