import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../data/app_database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override State<BackupScreen> createState()=>_BackupScreenState();
}
class _BackupScreenState extends State<BackupScreen>{
  bool busy=false;
  Future<void> exportBackup()async{
    setState(()=>busy=true);
    try{
      await AppDatabase.instance.close();
      final source=File(await AppDatabase.instance.databasePath);
      if(!await source.exists())throw StateError('لم يتم العثور على قاعدة البيانات');
      final temp=await getTemporaryDirectory();
      final stamp=DateTime.now().toIso8601String().replaceAll(':','-');
      final copy=await source.copy('${temp.path}/Asmak-Albaraka-backup-$stamp.db');
      await AppDatabase.instance.database;
      await Share.shareXFiles([XFile(copy.path)],text:'نسخة احتياطية من تطبيق أسماك البركة');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تجهيز ملف النسخة الاحتياطية للمشاركة أو الحفظ')));
    }catch(e){
      try{await AppDatabase.instance.database;}catch(_){}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إنشاء النسخة: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> restoreBackup()async{
    final choice=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('استعادة نسخة احتياطية'),content:const Text('ستُستبدل البيانات الحالية بالبيانات الموجودة في ملف النسخة الاحتياطية. تأكد من حفظ نسخة من بياناتك الحالية أولاً.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('متابعة'))]));
    if(choice!=true)return;
    setState(()=>busy=true);
    try{
      final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['db'],withData:false);
      if(picked==null||picked.files.single.path==null)return;
      final backupPath=picked.files.single.path!;
      final check=await openDatabase(backupPath,readOnly:true);
      final tables=await check.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      await check.close();
      final names=tables.map((e)=>e['name']).toSet();
      const required={'fish_types','customers','reservations','reservation_items','payments'};
      if(!required.every(names.contains))throw const FormatException('ملف النسخة لا يحتوي على قاعدة بيانات أسماك البركة الصحيحة');
      await AppDatabase.instance.close();
      final destination=File(await AppDatabase.instance.databasePath);
      if(await destination.exists())await destination.delete();
      await File(backupPath).copy(destination.path);
      await AppDatabase.instance.database;
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تمت استعادة النسخة الاحتياطية بنجاح')));
    }catch(e){
      try{await AppDatabase.instance.database;}catch(_){}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذرت الاستعادة: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('النسخ الاحتياطي')),
    body:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.backup_outlined,size:64,color:Color(0xFF087E8B)),
      const SizedBox(height:16),
      const Text('احفظ بيانات الأسماك والعملاء والحجوزات والمدفوعات في ملف مستقل. احتفظ بالنسخة في مكان آمن.',textAlign:TextAlign.center),
      const SizedBox(height:24),
      FilledButton.icon(onPressed:busy?null:exportBackup,icon:const Icon(Icons.upload_file),label:const Text('إنشاء نسخة احتياطية')),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:busy?null:restoreBackup,icon:const Icon(Icons.restore),label:const Text('استعادة نسخة احتياطية')),
      if(busy)const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator())),
      const Spacer(),
      const Text('تنبيه: استعادة نسخة قديمة تستبدل البيانات الحالية بالكامل.',style:TextStyle(color:Colors.red),textAlign:TextAlign.center),
    ])),
  );
}
