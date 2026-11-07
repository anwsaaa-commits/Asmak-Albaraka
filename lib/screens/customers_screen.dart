import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override State<CustomersScreen> createState()=>_CustomersScreenState();
}
class _CustomersScreenState extends State<CustomersScreen>{
  List<Map<String,Object?>> rows=[];
  final fmt=NumberFormat('#,##0.##','en');
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final db=await AppDatabase.instance.database;
    final data=await db.rawQuery("SELECT c.id,c.name,c.phone,COUNT(r.id) AS count,COALESCE(SUM(r.total),0) AS total,COALESCE(SUM(r.total-r.paid),0) AS debt FROM customers c LEFT JOIN reservations r ON r.customer_id=c.id AND r.status!='ملغي' GROUP BY c.id ORDER BY c.name");
    if(mounted)setState(()=>rows=data);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('العملاء')),
    body:rows.isEmpty?const Center(child:Text('سيظهر العملاء هنا بعد تسجيل أول حجز')):RefreshIndicator(onRefresh:load,child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(ctx,i){
      final c=rows[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(c['name'] as String),subtitle:Text('الهاتف: ${c['phone']}\nعدد الحجوزات: ${c['count']}\nإجمالي التعامل: ${fmt.format(c['total'])} ريال • المتبقي: ${fmt.format(c['debt'])} ريال'),isThreeLine:true));
    })),
  );
}
