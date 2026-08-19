import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/my_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../services/worker_service.dart';
import '../../core/utils/watermark_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'worker_report_page.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});
  @override State<WorkerHomePage> createState()=>_WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage>{
  MySchedule? schedule; String? error; bool loading=true;
  bool clocking=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async{
    setState((){loading=true;error=null;});
    try{final result=await WorkerService.schedule();if(!mounted)return;
      setState((){schedule=result.data;error=result.isSuccess?null:result.message;});
    }catch(_){if(mounted)setState(()=>error='无法加载当前排班，请检查网络');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('今日打卡'),actions:[IconButton(tooltip:'月度考勤',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WorkerReportPage())),icon:const Icon(Icons.assessment)),IconButton(onPressed:_load,icon:const Icon(Icons.refresh)),
      IconButton(onPressed:()=>context.read<AuthProvider>().logout(),icon:const Icon(Icons.logout))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Padding(
      padding:const EdgeInsets.all(24),child:Text(error!,textAlign:TextAlign.center))):_content(),
  );
  Widget _content(){final value=schedule!;return RefreshIndicator(onRefresh:_load,child:ListView(
    padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value.projectName,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:8),
        Text('${value.teamName} · ${value.shiftName}'),Text('考勤日期 ${value.attendanceDate} · 围栏 ${value.fenceRadius} 米'),
      ]))),
      const SizedBox(height:16),Text('打卡进度',style:Theme.of(context).textTheme.titleMedium),
      ...value.checkpoints.map((point){final matches=value.records.where((r)=>r.checkpointId==point.id);
        final record=matches.isEmpty?null:matches.first;return Card(child:ListTile(
          leading:Icon(record==null?Icons.radio_button_unchecked:record.countable?Icons.check_circle:Icons.warning,
            color:record==null?null:record.countable?Colors.green:Colors.orange),
          title:Text(point.name),subtitle:Text('标准时间 ${point.expectedTime}${point.dayOffset==1?'（次日）':''}'),
          trailing:Text(record==null?'未打卡':record.anomalyType==null?'已完成':'异常'),));}),
      const SizedBox(height:20),FilledButton.icon(onPressed:clocking?null:_clock,icon:clocking
        ?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.camera_alt),
        label:Text(clocking?'正在提交…':'定位并拍照打卡')),
    ]));}

  Future<void> _clock() async{
    final value=schedule!;
    final user=context.read<AuthProvider>().currentUser;
    try{
      setState(()=>clocking=true);
      if(!await Geolocator.isLocationServiceEnabled())throw Exception('请先打开手机定位服务');
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
      if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('需要定位权限才能打卡');
      final position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high));
      final distance=Geolocator.distanceBetween(position.latitude,position.longitude,value.gpsLat,value.gpsLng);
      if(!mounted)return;
      if(distance>value.fenceRadius){final proceed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        icon:const Icon(Icons.warning_amber,color:Colors.orange,size:42),title:const Text('当前在项目围栏外'),
        content:Text('距离项目约 ${distance.round()} 米，允许范围 ${value.fenceRadius} 米。\n\n继续打卡会标记为异常，不计入工时，需要项目主管确认或修正。'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('仍要打卡'))]));
        if(proceed!=true)return;
      }
      final photo=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:88,maxWidth:1920);
      if(photo==null)return;
      final now=DateTime.now();
      final path=await WatermarkUtils.addClockWatermark(await photo.readAsBytes(),[
        value.projectName,user?.realName??user?.username??'',DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        'GPS ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'Distance ${distance.round()}m',
      ]);
      final uploaded=await WorkerService.uploadPhoto(path);
      if(!uploaded.isSuccess||uploaded.data==null)throw Exception(uploaded.message);
      final result=await WorkerService.clock({'requestId':'${now.microsecondsSinceEpoch}-${user?.id??0}',
        'gpsLat':position.latitude,'gpsLng':position.longitude,'gpsAccuracy':position.accuracy,
        'clientTime':now.toIso8601String(),'photoUrl':uploaded.data});
      if(!result.isSuccess)throw Exception(result.message);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.data?['anomalyType']==null?'打卡成功':'打卡已记录，存在异常，等待主管处理')));await _load();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ','')),backgroundColor:Colors.red));}
    finally{if(mounted)setState(()=>clocking=false);}
  }
}
