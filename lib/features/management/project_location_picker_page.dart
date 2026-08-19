import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/management_service.dart';

class ProjectLocationPickerPage extends StatefulWidget {
  const ProjectLocationPickerPage({super.key});

  @override
  State<ProjectLocationPickerPage> createState() =>
      _ProjectLocationPickerPageState();
}

class _ProjectLocationPickerPageState extends State<ProjectLocationPickerPage> {
  final _nameController = TextEditingController();
  final _mapController = MapController();

  LatLng? _center;
  int _radius = 100;
  bool _locating = true;
  bool _saving = false;
  bool _permissionPermanentlyDenied = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
      _permissionPermanentlyDenied = false;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('请先开启手机定位服务');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _permissionPermanentlyDenied = true;
        throw Exception('定位权限已被永久拒绝，请到系统设置中开启');
      }
      if (permission == LocationPermission.denied) {
        throw Exception('需要定位权限才能创建项目');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      setState(() => _center = point);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(point, 17);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('TimeoutException: ', '定位超时，请到开阔位置重试：');
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final center = _center;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入项目名称')));
      return;
    }
    if (center == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先获取项目位置')));
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ManagementService.createProject({
        'name': name,
        'gpsLat': center.latitude,
        'gpsLng': center.longitude,
        'fenceRadius': _radius,
        'status': 'active',
      });
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('项目创建失败，请检查网络后重试'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建项目')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '项目名称',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('项目位置', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildLocationArea(),
                  if (_center != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_center!.latitude.toStringAsFixed(6)}, '
                            '${_center!.longitude.toStringAsFixed(6)}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _locating ? null : _locate,
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('重新定位'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _radius,
                      decoration: const InputDecoration(
                        labelText: '打卡范围',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.radar),
                      ),
                      items: const [100, 200, 300, 500]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value 米'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _radius = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _center == null ? null : _create,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_location_alt),
                  label: Text(_saving ? '正在创建…' : '创建项目'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationArea() {
    if (_center == null) {
      return Container(
        height: 330,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: _locating
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取手机位置…'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 48),
                  const SizedBox(height: 12),
                  Text(_locationError ?? '暂时无法获取位置',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _permissionPermanentlyDenied
                        ? Geolocator.openAppSettings
                        : _locate,
                    icon: Icon(_permissionPermanentlyDenied
                        ? Icons.settings
                        : Icons.refresh),
                    label: Text(_permissionPermanentlyDenied ? '打开设置' : '重新定位'),
                  ),
                ],
              ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 330,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && mounted) {
                    setState(() => _center = camera.center);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zhaochen.checkin',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _center!,
                      radius: _radius.toDouble(),
                      useRadiusInMeter: true,
                      color: Colors.green.withValues(alpha: 0.14),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 34),
                  child:
                      Icon(Icons.location_pin, size: 44, color: Colors.green),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        '拖动地图调整项目中心',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 5,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white70),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black87)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
