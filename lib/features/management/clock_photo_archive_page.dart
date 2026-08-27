import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/zoomable_network_image.dart';
import '../../models/checkin_project.dart';
import '../../models/clock_photo.dart';
import '../../services/management_service.dart';

class ClockPhotoArchivePage extends StatefulWidget {
  final CheckinProject project;
  const ClockPhotoArchivePage({super.key, required this.project});

  @override
  State<ClockPhotoArchivePage> createState() => _ClockPhotoArchivePageState();
}

class _ClockPhotoArchivePageState extends State<ClockPhotoArchivePage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<ClockPhoto> photos = const [];
  final Set<String> expandedDays = {};
  final Map<int, Future<String?>> urls = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ManagementService.clockPhotos(
          widget.project.id, DateFormat('yyyy-MM').format(month));
      if (!mounted) return;
      setState(() {
        photos = result.data ?? const [];
        error = result.isSuccess ? null : result.message;
        urls.clear();
        expandedDays.clear();
        if (photos.isNotEmpty) expandedDays.add(photos.first.attendanceDate);
      });
    } catch (_) {
      if (mounted) setState(() => error = '照片归档加载失败');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _move(int value) {
    month = DateTime(month.year, month.month + value);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(title: const Text('打卡照片归档')),
        body: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left)),
              Text(DateFormat('yyyy年MM月').format(month),
                  style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right)),
            ]),
          ),
          Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : photos.isEmpty
                          ? const Center(child: Text('本月暂无打卡照片'))
                          : RefreshIndicator(onRefresh: _load, child: _list())),
        ]),
      );

  Widget _list() {
    final grouped = <String, List<ClockPhoto>>{};
    for (final photo in photos) {
      grouped.putIfAbsent(photo.attendanceDate, () => []).add(photo);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (_, index) {
        final date = days[index];
        final items = grouped[date]!;
        final expanded = expandedDays.contains(date);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ListTile(
              title: Text('$date（${items.length}张）',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => expanded
                  ? expandedDays.remove(date)
                  : expandedDays.add(date)),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: .82),
                  itemBuilder: (_, photoIndex) => _photoCard(items[photoIndex]),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _photoCard(ClockPhoto photo) => InkWell(
        onTap: () => _showPhoto(photo),
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE3E7EC)),
              borderRadius: BorderRadius.circular(10)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              child:
                  SizedBox(width: double.infinity, child: _networkPhoto(photo)),
            )),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${photo.workerName} · ${photo.checkpointName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${photo.teamName} ${_time(photo.clockTime)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
          ]),
        ),
      );

  Widget _networkPhoto(ClockPhoto photo) => FutureBuilder<String?>(
        future: urls.putIfAbsent(photo.recordId, () async {
          final result =
              await ManagementService.anomalyPhotoViewUrl(photo.recordId);
          return result.data;
        }),
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          }
          final url = snapshot.data;
          if (url == null) {
            return const Center(child: Icon(Icons.broken_image_outlined));
          }
          return Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)));
        },
      );

  Future<void> _showPhoto(ClockPhoto photo) async {
    final url = await urls.putIfAbsent(
        photo.recordId,
        () async =>
            (await ManagementService.anomalyPhotoViewUrl(photo.recordId)).data);
    if (!mounted || url == null) return;
    showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('${photo.workerName} · ${photo.checkpointName}'),
              content: ZoomableNetworkImage(url: url),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'))
              ],
            ));
  }

  String _time(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('HH:mm').format(parsed);
  }
}
