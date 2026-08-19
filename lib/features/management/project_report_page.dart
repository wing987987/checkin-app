import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';

class ProjectReportPage extends StatefulWidget{final CheckinProject project;const ProjectReportPage({super.key,required this.project});@override State<ProjectReportPage> createState()=>_ProjectReportPageState();}
class _ProjectReportPageState extends State<ProjectReportPage>{DateTime month=DateTime(DateTime.now().year,DateTime.now().month);ProjectMonthReport? report;bool loading=true;
  @override void initState(){super.initState();_load();}Future<void>_load()async{setState(()=>loading=true);try{final r=await ManagementService.projectMonthReport(widget.project.id,DateFormat('yyyy-MM').format(month));if(mounted)setState(()=>report=r.data);}finally{if(mounted)setState(()=>loading=false);}}
  void _move(int v){month=DateTime(month.year,month.month+v);_load();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('${widget.project.name}考勤报表')),body:Column(children:[
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(onPressed:()=>_move(-1),icon:const Icon(Icons.chevron_left)),Text(DateFormat('yyyy年MM月').format(month),style:Theme.of(context).textTheme.titleLarge),IconButton(onPressed:()=>_move(1),icon:const Icon(Icons.chevron_right))]),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):_body())]));
  Widget _body(){final r=report;if(r==null)return const Center(child:Text('报表加载失败'));return ListView(padding:const EdgeInsets.all(12),children:[
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_metric('总工数',r.totalWorkUnits),_metric('正常工时',r.totalWorkHours),_metric('加班小时',r.totalOvertimeHours)]))),
    if(r.workers.isEmpty)const Padding(padding:EdgeInsets.all(40),child:Center(child:Text('本月暂无考勤'))),
    ...r.workers.map((w)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(w.workerName),subtitle:Text('${w.teamName} · 出勤 ${w.attendanceDays} 天\n工数 ${w.workUnits}  工时 ${w.workHours}h  加班 ${w.overtimeHours}h'),isThreeLine:true,
      trailing:w.correctedDays>0?Chip(label:Text('修正 ${w.correctedDays}')):w.anomalyDays>0?Chip(label:Text('异常 ${w.anomalyDays}')):null)))]);}
  Widget _metric(String n,double v)=>Column(children:[Text(v.toStringAsFixed(2),style:Theme.of(context).textTheme.titleLarge),Text(n)]);
}
