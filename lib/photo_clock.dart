import 'package:flutter/material.dart';
import 'package:final_countdown/countdown_stream.dart';
import 'package:final_countdown/utils.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

class PhotoClock extends StatelessWidget {
  PhotoClock(this.countdown);
  final FinalCountdown countdown;
  @override
  Widget build(BuildContext context) {
    return GridPhotoView(countdown);
  }
}

class GridPhotoView extends StatelessWidget {
  GridPhotoView(this.countdown) : photos = List<Picture>.generate(16, (i) => Picture(countdown, i));
  // TODO(efortuna): Make accessible via inherited widget?
  final FinalCountdown countdown; 
  final List<Picture> photos;
  final photosPerRow = 4;

  @override
  Widget build(BuildContext context) {
    var rows = List<TableRow>.generate(
        photosPerRow,
        (int i) => TableRow(
            children: photos.sublist(i * photosPerRow, i * photosPerRow + photosPerRow)));
    return Center(child: Table(children: rows));
  }
}

class Picture extends StatefulWidget {
  Picture(this.countdown, this.index);
  final FinalCountdown countdown;
  /// Indicator of what number this picture is, important 
  /// to know when it should take a picture.
  final index;
  @override
  _PictureState createState() => _PictureState();
}

class _PictureState extends State<Picture> {
  Widget _image;
  Color _color;
  StreamSubscription _colorUpdates;
  CameraController _controller;
  bool _setPicture;
  // TODO(efortuna): add a TIME's UP for the last square.

  @override
  initState() {
    super.initState();
    _setPicture = false;
    _image = makeClock();
    _color = Colors.yellow;
    // TODO(efortuna): I feel like there should be a better way to do this.
    _colorUpdates = widget.countdown.time.listen((Duration newDuration) async {
      // Normalize rating to (0,1) and interpolate color from yellow to red as we run out of time
      setState(() {
        _color = Color.lerp(Colors.red, Colors.yellow,
            newDuration.inMinutes / widget.countdown.duration.inMinutes);
      });
      int nthImage = widget.countdown.duration.inMinutes - widget.index;
      if (newDuration.inSeconds % 60 == 0 && newDuration.inMinutes == nthImage) {
        var filename = await takePicture();
        setState(() => _image = Image.file(File(filename), fit: BoxFit.cover));
        _setPicture = true;
      }
      if (!_setPicture && newDuration.inMinutes < nthImage) {
        setState(() => _image = Image.asset('assets/beaker_by_david_goehring.jpg', fit: BoxFit.cover));
        _setPicture = true;
      }
    });
  }

  initializeCamera() async {
    List<CameraDescription> cameraOptions = await availableCameras();
    try {
      var frontCamera = cameraOptions.firstWhere((description) =>
          description.lensDirection == CameraLensDirection.front);
      _controller = CameraController(frontCamera, ResolutionPreset.low);
      /*_controller.addListener(() {
      if (mounted) setState(() {});
      if (_controller.value.hasError) {
        print('Camera error ${_controller.value.errorDescription}');
      }
    });*/
      await _controller.initialize();
      /*if (mounted) {
      setState(() {});
    }*/
    } on StateError catch (e) {
      print('No front-facing camera found: $e');
    }
  }

  Future<String> takePicture() async {
    await initializeCamera();
    Directory extDir = await getApplicationDocumentsDirectory();
    var dirPath = '${extDir.path}/Pictures/clock_app';
    await Directory(dirPath).create(recursive: true);
    var filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _controller.takePicture(filePath);
    } on CameraException catch (e) {
      print('There was a problem taking the picture. $e');
      return null;
    }
    return filePath;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: AnimatedContainer(
          height: 100.0,
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

  makeClock() => StreamBuilder(
        stream: widget.countdown.time,
        builder: (context, AsyncSnapshot<Duration> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Text('Waiting ...');
            case ConnectionState.active:
              return Text('Time ${prettyPrintDuration(snapshot.data)}');
            case ConnectionState.done:
              return Text('Time\s up!');
            case ConnectionState.none:
              return Text('Entered oblivion; this should never have happened');
          }
        },
      );
}
