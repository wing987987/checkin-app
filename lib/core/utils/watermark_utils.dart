import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class WatermarkUtils {
  static Future<String> addClockWatermark(Uint8List bytes, List<String> lines) async {
    final original=await _decode(bytes);
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    canvas.drawImage(original,Offset.zero,Paint());
    final fontSize=(original.width/32).clamp(22,42).toDouble();
    final painters=lines.map((line){final p=TextPainter(text:TextSpan(text:line,
      style:TextStyle(color:Colors.white,fontSize:fontSize,fontWeight:FontWeight.w600,
        shadows:const [Shadow(color:Colors.black,blurRadius:3)])),textDirection:TextDirection.ltr);
      p.layout(maxWidth:original.width*.62);return p;}).toList();
    final width=painters.fold<double>(0,(v,p)=>p.width>v?p.width:v)+24;
    final height=painters.fold<double>(16,(v,p)=>v+p.height+4);
    final left=original.width-width-16, top=16.0;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left,top,width,height),const Radius.circular(8)),
      Paint()..color=Colors.black.withValues(alpha:.48));
    var y=top+8;for(final p in painters){p.paint(canvas,Offset(left+12,y));y+=p.height+4;}
    final image=await recorder.endRecording().toImage(original.width,original.height);
    final data=await image.toByteData(format:ui.ImageByteFormat.png);
    final dir=await getTemporaryDirectory();
    final file=File('${dir.path}${Platform.pathSeparator}clock_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data!.buffer.asUint8List(),flush:true);return file.path;
  }

  static Future<ui.Image> _decode(Uint8List bytes){final c=Completer<ui.Image>();
    ui.decodeImageFromList(bytes,c.complete);return c.future;}
}
