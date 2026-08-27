import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/env_config.dart';

class WorkerLocationMapPage extends StatelessWidget {
  final LatLng current;
  final LatLng target;
  final double distanceMeters;
  final double accuracyMeters;
  final int fenceRadius;
  final String projectName;

  const WorkerLocationMapPage({
    super.key,
    required this.current,
    required this.target,
    required this.distanceMeters,
    required this.accuracyMeters,
    required this.fenceRadius,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final inside = distanceMeters <= fenceRadius;
    final center = LatLng((current.latitude + target.latitude) / 2,
        (current.longitude + target.longitude) / 2);
    return Scaffold(
      appBar: AppBar(title: const Text('打卡定位')),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
              initialCenter: center,
              initialZoom: _initialZoom(distanceMeters),
              minZoom: 3,
              maxZoom: 18),
          children: [
            TileLayer(
              urlTemplate: EnvConfig.instance.mapBaseTileUrl,
              subdomains: EnvConfig.instance.mapSubdomains,
              maxNativeZoom: 18,
              userAgentPackageName: EnvConfig.instance.mapUserAgent,
            ),
            TileLayer(
              urlTemplate: EnvConfig.instance.mapLabelTileUrl,
              subdomains: EnvConfig.instance.mapSubdomains,
              maxNativeZoom: 18,
              userAgentPackageName: EnvConfig.instance.mapUserAgent,
            ),
            CircleLayer(circles: [
              CircleMarker(
                point: target,
                radius: fenceRadius.toDouble(),
                useRadiusInMeter: true,
                color: Colors.green.withValues(alpha: .12),
                borderColor: Colors.green,
                borderStrokeWidth: 2,
              ),
              CircleMarker(
                point: current,
                radius: accuracyMeters,
                useRadiusInMeter: true,
                color: Colors.blue.withValues(alpha: .10),
                borderColor: Colors.blue.withValues(alpha: .5),
                borderStrokeWidth: 1,
              ),
            ]),
            PolylineLayer(polylines: [
              Polyline(
                  points: [current, target],
                  color: inside ? Colors.green : Colors.orange,
                  strokeWidth: 4),
            ]),
            MarkerLayer(markers: [
              Marker(
                  point: current,
                  width: 110,
                  height: 62,
                  child: const _MapPin(
                      label: '当前位置',
                      icon: Icons.my_location,
                      color: Colors.blue)),
              Marker(
                  point: target,
                  width: 120,
                  height: 62,
                  child: _MapPin(
                      label: '项目打卡点',
                      icon: Icons.location_on,
                      color: inside ? Colors.green : Colors.orange)),
            ]),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: SafeArea(
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(projectName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('距打卡点约 ${_distance(distanceMeters)}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(
                          '打卡范围 $fenceRadius 米 · 定位精度约 ±${accuracyMeters.round()} 米'),
                      const SizedBox(height: 5),
                      Text(
                        inside ? '当前在项目打卡范围内' : '当前不在打卡范围内',
                        style: TextStyle(
                            color: inside ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
              ),
            ),
          ),
        ),
        const Positioned(
          right: 6,
          top: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xAAFFFFFF)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('© 天地图', style: TextStyle(fontSize: 10)),
            ),
          ),
        ),
      ]),
    );
  }

  double _initialZoom(double meters) {
    if (meters <= 200) return 17.5;
    if (meters <= 500) return 16.5;
    if (meters <= 1000) return 15.5;
    if (meters <= 3000) return 14;
    if (meters <= 10000) return 12;
    return 10;
  }

  String _distance(double meters) => meters < 1000
      ? '${meters.round()} 米'
      : '${(meters / 1000).toStringAsFixed(2)} 公里';
}

class _MapPin extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MapPin({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3)
              ]),
          child: Text(label,
              maxLines: 1,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Icon(icon, color: color, size: 32),
      ]);
}
