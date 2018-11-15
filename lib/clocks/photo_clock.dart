import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';

import 'package:final_countdown/data/countdown_provider.dart';
import 'package:final_countdown/data/storage_provider.dart';
import 'package:final_countdown/clocks/simple_clock.dart';

class PhotoClock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridPhotoView();
  }
}

class GridPhotoView extends StatelessWidget {
  static final photosPerRow = 4;
  static final totalPhotos = photosPerRow * photosPerRow;

  @override
  Widget build(BuildContext context) {
    final countdown = CountdownProvider.of(context);
    final storage = PhotoStorageProvider.of(context);
    final photos = List<Picture>.generate(
        totalPhotos, (i) => Picture(countdown, storage, i, totalPhotos));

    var rows = List<TableRow>.generate(
        photosPerRow,
        (int i) => TableRow(
            children: photos.sublist(
                i * photosPerRow, i * photosPerRow + photosPerRow)));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Image.asset('assets/camera_top.png'),
        Container(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Table(children: rows),
          ),
        ),
        Image.asset('assets/camera_bottom.png'),
      ],
    );
  }
}

class Picture extends StatefulWidget {
  Picture(this.countdown, this.storage, this.index, this.totalTiles);
  final CountdownProvider countdown;
  final PhotoDirectory storage;
  final totalTiles;

  /// Indicator of what number this picture is, important
  /// to know when it should take a picture.
  final index;
  @override
  createState() => _PictureState();
}

class _PictureState extends State<Picture> {
  Widget _image;
  Color _color;
  StreamSubscription _colorUpdates;
  CameraController _controller;
  CameraLensDirection _cameraDirection;
  bool _flipRed;
  String _filePath;
  // Reversing the index so that we start at the top left instead of the bottom right.
  int _reverseIndex;

  @override
  initState() {
    super.initState();
    // Search for existing picture.
    _filePath = '${widget.storage.path}/picture${widget.index}.jpg';
    _flipRed = true;
    _reverseIndex = widget.countdown.duration.inMinutes - widget.index;
    _cameraDirection = _reverseIndex % 2 == 0 ? CameraLensDirection.front : CameraLensDirection.back;
    _color = Colors.yellow;

    if (widget.countdown.mostRecentTime.inMinutes < _reverseIndex) {
      _image = makeTintedImage(calculateColor());
    } else {
      _image = SimpleClock(
        TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      );
    }

    // TODO(efortuna): I feel like there should be a better way to do this.
    _colorUpdates =
        widget.countdown.stream.listen((Duration newDuration) async {
      var calculatedColor = calculateColor(duration: newDuration);
      setState(() {
        _color = calculatedColor;
      });
      if (newDuration.inMinutes == _reverseIndex &&
          newDuration.inSeconds % 60 == 0) {
        await takePicture();
        setState(() => _image = makeTintedImage(calculatedColor));
      }
    });
  }

  Widget makeTintedImage(Color tint) {
    var image;
    var file = File(_filePath);
    if (file.existsSync()) {
      image = Image.file(File(_filePath), fit: BoxFit.cover);
    } else {
      image = Container(decoration: FlutterLogoDecoration());
    }
    return Stack(
        fit: StackFit.expand,
        children: [image, Opacity(opacity: .4, child: Container(color: tint))]);
  }

  Color calculateColor({Duration duration}) {
    if (duration == null) {
      return Color.lerp(
          Colors.red, Colors.yellow, _reverseIndex / widget.totalTiles);
    }
    if (duration.inMinutes == _reverseIndex &&
        duration.inSeconds % 60 < 10 &&
        duration.inSeconds % 60 != 0) {
      // Create "flashing" effect in the last 10 seconds before taking a picture.
      _flipRed = !_flipRed;
      return _flipRed ? Colors.red : Colors.yellow;
    }
    return Color.lerp(Colors.red, Colors.yellow,
        duration.inMinutes / widget.countdown.duration.inMinutes);
  }

  initializeCamera() async {
    List<CameraDescription> cameraOptions = await availableCameras();
    try {
      var frontCamera = cameraOptions.firstWhere(
          (description) => description.lensDirection == _cameraDirection);
      _controller = CameraController(frontCamera, ResolutionPreset.low);
      await _controller.initialize();
    } on StateError catch (e) {
      print('No front-facing camera found: $e');
    }
  }

  Future<bool> takePicture() async {
    await initializeCamera();
    try {
      await _controller.takePicture(_filePath);
    } on CameraException catch (e) {
      print('There was a problem taking the picture. $e');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
          height: 100,
          color: _color,
          child: _image,
          duration: const Duration(milliseconds: 500)),
    );
  }

  @override
  deactivate() {
    _colorUpdates.cancel();
    super.deactivate();
  }
}
