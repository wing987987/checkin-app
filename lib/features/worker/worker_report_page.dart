import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_report.dart';
import '../../services/worker_service.dart';

class WorkerReportPage extends StatefulWidget{const WorkerReportPage({super.key});@override State<WorkerReportPage> createState()=>_WorkerReportPageState();}
class _WorkerReportPageState extends State<WorkerReportPage>{DateTime month=DateTime(DateTime.now().year,DateTime.now().month);WorkerMonthReport? report;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{setState(()=>loading=true);try{final r=await WorkerService.monthReport(DateFormat('yyyy-MM').format(month));if(mounted)setState(()=>report=r.data);}finally{if(mounted)setState(()=>loading=false);}}
  void _move(int value){month=DateTime(month.year,month.month+value);_load();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('个人月度考勤')),body:Column(children:[
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(onPressed:()=>_move(-1),icon:const Icon(Icons.chevron_left)),
      Text(DateFormat('yyyy年MM月').format(month),style:Theme.of(context).textTheme.titleLarge),IconButton(onPressed:()=>_move(1),icon:const Icon(Icons.chevron_right))]),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):_body())]));
  Widget _body(){final r=report;if(r==null)return const Center(child:Text('报表加载失败'));return ListView(padding:const EdgeInsets.all(12),children:[
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:24,runSpacing:12,children:[_metric('工数',r.totalWorkUnits),_metric('正常工时',r.totalWorkHours),
      _metric('加班小时',r.totalOvertimeHours),_metric('异常天数',r.anomalyDays.toDouble()),_metric('修正天数',r.correctedDays.toDouble())]))),
    if(r.days.isEmpty)const Padding(padding:EdgeInsets.all(40),child:Center(child:Text('本月暂无考勤'))),
    ...r.days.map((d)=>Card(child:ListTile(leading:CircleAvatar(child:Text(d.date.length>=10?d.date.substring(8):'')),title:Text('${d.projectName} · ${d.shiftName}'),
      subtitle:Text('${d.teamName}\n工时 ${d.workHours}h  加班 ${d.overtimeHours}h  工数 ${d.workUnits}'),isThreeLine:true,
      trailing:d.corrected?const Chip(label:Text('修正')):d.status=='normal'?null:Chip(label:Text(d.status=='missing'?'缺卡':'异常')))))]);}
  Widget _metric(String name,double value)=>Column(mainAxisSize:MainAxisSize.min,children:[Text(value.toStringAsFixed(2),style:Theme.of(context).textTheme.titleLarge),Text(name)]);
}
