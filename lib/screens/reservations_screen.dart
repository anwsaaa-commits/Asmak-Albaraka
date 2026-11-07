import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import 'reservation_form_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override State<ReservationsScreen> createState()=>_ReservationsScreenState();
}
class _ReservationsScreenState extends State<ReservationsScreen>{
  final search=TextEditingController();
  List<Map<String,Object?>> rows=[];
  final fmt=NumberFormat('#,##0.##','en');
  @override void initState(){super.initState();search.addListener(load);load();}
  @override void dispose(){search.dispose();super.dispose();}
  Future<void> load()async{final result=await AppDatabase.instance.getReservations(search:search.text);if(mounted)setState(()=>rows=result);}
  Future<void> status(int id,String value)async{await AppDatabase.instance.updateStatus(id,value);load();}
  Future<void> payment(int id,double remaining)async{
    final ctl=TextEditingController();
    final amount=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(title:const Text('تسجيل دفعة'),content:TextField(controller:ctl,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'المتبقي ${fmt.format(remaining)} ريال')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){final n=double.tryParse(ctl.text);if(n!=null&&n>0&&n<=remaining)Navigator.pop(ctx,n);},child:const Text('حفظ'))]));
    ctl.dispose();if(amount!=null){try{await AppDatabase.instance.addPayment(id,amount);load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل الدفعة: $e')));}}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('الحجوزات')),
    floatingActionButton:FloatingActionButton.extended(onPressed:()async{final done=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const ReservationFormScreen()));if(done==true)load();},icon:const Icon(Icons.add),label:const Text('حجز جديد')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث باسم العميل أو الهاتف',border:OutlineInputBorder()))),
      Expanded(child:rows.isEmpty?const Center(child:Text('لا توجد حجوزات')):RefreshIndicator(onRefresh:load,child:ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){
        final r=rows[i];final id=r['id'] as int;final total=(r['total'] as num).toDouble();final paid=(r['paid'] as num).toDouble();final remain=total-paid;
        return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ExpansionTile(title:Text(r['customer_name'] as String),subtitle:Text('${r['customer_phone']} • ${fmt.format(total)} ريال'),childrenPadding:const EdgeInsets.all(12),children:[
          Text('موعد الاستلام: ${r['pickup_at']}'),
          Text('المدفوع: ${fmt.format(paid)} ريال | المتبقي: ${fmt.format(remain)} ريال'),
          DropdownButtonFormField<String>(value:r['status'] as String,decoration:const InputDecoration(labelText:'حالة الحجز'),items:const ['جديد','مؤكد','قيد التجهيز','تم التسليم','ملغي'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v){if(v!=null)status(id,v);}),
          if(remain>0&&r['status']!='ملغي')TextButton.icon(onPressed:()=>payment(id,remain),icon:const Icon(Icons.payments),label:const Text('تسجيل دفعة')),
        ]));
      }))),
    ]),
  );
}
