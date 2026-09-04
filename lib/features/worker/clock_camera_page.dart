import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ClockCameraPage extends StatefulWidget {
  const ClockCameraPage({super.key});

  @override
  State<ClockCameraPage> createState() => _ClockCameraPageState();
}

class _ClockCameraPageState extends State<ClockCameraPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize([CameraLensDirection? preferred]) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('手机未检测到可用摄像头');
      if (preferred != null) {
        final index = _cameras.indexWhere((c) => c.lensDirection == preferred);
        if (index >= 0) _cameraIndex = index;
      } else {
        final back = _cameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        if (back >= 0) _cameraIndex = back;
      }
      await _startCamera(_cameraIndex);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.toString().replaceFirst('CameraException: ', ''));
      }
    }
  }

  Future<void> _startCamera(int index) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    final currentDirection = _cameras[_cameraIndex].lensDirection;
    final wanted = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final next = _cameras.indexWhere((c) => c.lensDirection == wanted);
    if (next < 0) return;
    setState(() => _cameraIndex = next);
    await _startCamera(next);
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.pop(context, photo.path);
    } catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = '拍照失败，请重试';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final direction =
        _cameras.isEmpty ? null : _cameras[_cameraIndex].lensDirection;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && direction != null) {
      _initialize(direction);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        title: const Text('现场拍照'),
        actions: [
          IconButton(
            tooltip: '翻转摄像头',
            onPressed: _cameras.length > 1 ? _flipCamera : null,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
            )
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : OrientationBuilder(
                  builder: (context, orientation) {
                    final cameraAspectRatio = controller.value.aspectRatio;
                    final previewAspectRatio =
                        orientation == Orientation.portrait
                            ? 1 / cameraAspectRatio
                            : cameraAspectRatio;
                    return Center(
                      child: AspectRatio(
                        aspectRatio: previewAspectRatio,
                        child: CameraPreview(controller),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 104,
          child: Center(
            child: IconButton.filled(
              tooltip: '拍照',
              onPressed: _capturing ? null : _takePhoto,
              iconSize: 42,
              padding: const EdgeInsets.all(18),
              icon: _capturing
                  ? const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.camera_alt),
            ),
          ),
        ),
      ),
    );
  }
}
