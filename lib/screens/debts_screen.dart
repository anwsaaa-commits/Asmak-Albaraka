import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override State<DebtsScreen> createState()=>_DebtsScreenState();
}
class _DebtsScreenState extends State<DebtsScreen>{
  List<Map<String,Object?>> rows=[];
  final fmt=NumberFormat('#,##0.##','en');
  @override void initState(){super.initState();load();}
  Future<void> load()async{final r=await AppDatabase.instance.getDebts();if(mounted)setState(()=>rows=r);}
  Future<void> collect(Map<String,Object?> row)async{
    final id=row['id'] as int;
    final total=(row['total'] as num).toDouble();
    final paid=(row['paid'] as num).toDouble();
    final remaining=total-paid;
    final ctl=TextEditingController(text:remaining.toStringAsFixed(0));
    final amount=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('تحصيل من ${row['customer_name']}'),
      content:TextField(controller:ctl,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'المبلغ المتبقي ${fmt.format(remaining)} ريال')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){final n=double.tryParse(ctl.text);if(n!=null&&n>0&&n<=remaining)Navigator.pop(ctx,n);},child:const Text('تسجيل الدفعة'))],
    ));
    ctl.dispose();
    if(amount!=null){try{await AppDatabase.instance.addPayment(id,amount);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر التحصيل: $e')));}}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('المدفوعات والديون')),
    body:rows.isEmpty?const Center(child:Text('لا توجد مبالغ مستحقة حاليًا')):RefreshIndicator(onRefresh:load,child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(ctx,i){
      final r=rows[i];final remaining=(r['total'] as num).toDouble()-(r['paid'] as num).toDouble();
      return Card(child:ListTile(
        leading:const CircleAvatar(child:Icon(Icons.account_balance_wallet_outlined)),
        title:Text(r['customer_name'] as String),
        subtitle:Text('الهاتف: ${r['customer_phone']}\nالإجمالي: ${fmt.format(r['total'])} • المدفوع: ${fmt.format(r['paid'])}\nالمتبقي: ${fmt.format(remaining)} ريال'),
        isThreeLine:true,
        trailing:IconButton(tooltip:'تسجيل دفعة',icon:const Icon(Icons.add_card,color:Color(0xFF087E8B)),onPressed:()=>collect(r)),
      ));
    })),
  );
}
