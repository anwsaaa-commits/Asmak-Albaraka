import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState()=>_ReportsScreenState();
}
class _ReportsScreenState extends State<ReportsScreen>{
  Map<String,Object?> today={},month={};
  final fmt=NumberFormat('#,##0.##','en');
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final db=await AppDatabase.instance.database;
    final now=DateTime.now();final d=DateFormat('yyyy-MM-dd').format(now);final m=DateFormat('yyyy-MM').format(now);
    final a=await db.rawQuery("SELECT COUNT(*) AS count,COALESCE(SUM(total),0) AS total,COALESCE(SUM(paid),0) AS paid,COALESCE(SUM(total-paid),0) AS debt FROM reservations WHERE substr(created_at,1,10)=? AND status!='ملغي'",[d]);
    final b=await db.rawQuery("SELECT COUNT(*) AS count,COALESCE(SUM(total),0) AS total,COALESCE(SUM(paid),0) AS paid,COALESCE(SUM(total-paid),0) AS debt FROM reservations WHERE substr(created_at,1,7)=? AND status!='ملغي'",[m]);
    if(mounted)setState(()=>{today=a.first,month=b.first});
  }
  Widget card(String title,Map<String,Object?> data)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Divider(),
    _line('عدد الحجوزات','${data['count']??0}'),
    _line('إجمالي المبيعات','${fmt.format(data['total']??0)} ريال'),
    _line('المبالغ المدفوعة','${fmt.format(data['paid']??0)} ريال'),
    _line('المبالغ المتبقية','${fmt.format(data['debt']??0)} ريال'),
  ])));
  Widget _line(String k,String v)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(k),Text(v,style:const TextStyle(fontWeight:FontWeight.bold))]));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('التقارير')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(12),children:[card('تقرير اليوم',today),card('تقرير الشهر',month),const Padding(padding:EdgeInsets.all(12),child:Text('التقارير تعتمد على الحجوزات المسجلة، ولا تشمل الحجوزات الملغاة.',style:TextStyle(color:Colors.black54)))])));
}
