import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'storage_history.dart';

class StorageImage extends StatelessWidget {
  final String fullPath;
  const StorageImage({Key? key, required this.fullPath }) : super(key: key);
  Widget makeChildImage() {  // not sure why to include extra function here
    // print('making ImagesScreen with $fullPath');
          return ImageItem(fullPath: fullPath);
  }

  @override
  Widget build(BuildContext context) {
    return Container(  // this is probably an extra container
      child: makeChildImage(),
    );
  }
}

class ImageItem extends StatefulWidget {
  final String fullPath;
  const ImageItem({Key? key, required this.fullPath}) : super(key: key);

  @override
  State<ImageItem> createState() => _ImageItemState();
}

class _ImageItemState extends State<ImageItem> {
  Uint8List? _imageFile;

  @override
  void initState() {
    super.initState();
    // print('trying to load image file ${widget.fullPath}');
    _imageFile=inFileCache(widget.fullPath);
    if (_imageFile==null) {
      FirebaseStorage.instance
          .ref(widget.fullPath)
          .getData(1000000)
          .then((data) {
        setState(() {
          _imageFile = data;
          addToFileCache(widget.fullPath, data!);
          // print('loaded file of length ${_imageFile!.length}');
        });
      }).catchError((error) {
        if (kDebugMode) {
          print('error on loading file $error');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: _imageFile == null
            ? const Center(child: Text('Loading...'))
            : Image.memory(_imageFile!, fit: BoxFit.cover));
  }
}
