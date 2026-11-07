import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({super.key});
  @override State<ReservationFormScreen> createState()=>_ReservationFormScreenState();
}
class _ReservationFormScreenState extends State<ReservationFormScreen>{
  final form=GlobalKey<FormState>();
  final customer=TextEditingController(),phone=TextEditingController(),paid=TextEditingController(text:'0'),notes=TextEditingController();
  List<Map<String,Object?>> fish=[];
  final List<_Line> lines=[];
  DateTime pickup=DateTime.now().add(const Duration(hours:2));
  bool saving=false;
  final fmt=NumberFormat('#,##0.##','en');
  @override void initState(){super.initState();loadFish();}
  @override void dispose(){customer.dispose();phone.dispose();paid.dispose();notes.dispose();for(final l in lines){l.qty.dispose();}super.dispose();}
  Future<void> loadFish()async{final f=await AppDatabase.instance.getFish();if(mounted)setState((){fish=f;if(f.isNotEmpty&&lines.isEmpty)lines.add(_Line(f.first));});}
  double get total=>lines.fold(0,(s,l)=>s+l.quantity*l.price);
  double get paidValue=>double.tryParse(paid.text)??0;
  Future<void> choosePickup()async{
    final d=await showDatePicker(context:context,initialDate:pickup,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:365)));
    if(d==null||!mounted)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(pickup));if(t!=null)setState(()=>pickup=DateTime(d.year,d.month,d.day,t.hour,t.minute));
  }
  Future<void> save()async{
    if(!form.currentState!.validate())return;
    if(lines.isEmpty||lines.any((l)=>l.fish==null||l.quantity<=0)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أضف نوع السمك والكمية')));return;}
    if(paidValue>total){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الدفعة أكبر من الإجمالي')));return;}
    setState(()=>saving=true);
    try{
      await AppDatabase.instance.createReservation(customerName:customer.text,phone:phone.text,pickupAt:pickup,paid:paidValue,notes:notes.text,items:lines.map((l)=>{'fish_type_id':l.fish!['id'],'fish_name':l.fish!['name'],'quantity_kg':l.quantity,'unit_price':l.price}).toList());
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الحجز: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('حجز جديد')),
    body:fish.isEmpty?const Center(child:Text('أضف أنواع الأسماك وأسعارها أولاً')):Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('بيانات العميل',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      TextFormField(controller:customer,decoration:const InputDecoration(labelText:'اسم العميل'),validator:(v)=>v==null||v.trim().isEmpty?'اسم العميل مطلوب':null),
      TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم الهاتف')),
      const SizedBox(height:18),const Text('تفاصيل الطلب',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      ...lines.asMap().entries.map((e){final i=e.key;final l=e.value;return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
        Row(children:[Expanded(child:DropdownButtonFormField<int>(value:l.fish?['id'] as int?,decoration:const InputDecoration(labelText:'نوع السمك'),items:fish.map((f)=>DropdownMenuItem(value:f['id'] as int,child:Text(f['name'] as String))).toList(),onChanged:(id){if(id!=null)setState(()=>l.fish=fish.firstWhere((f)=>f['id']==id));})),IconButton(onPressed:(){setState((){lines.removeAt(i);l.qty.dispose();});},icon:const Icon(Icons.delete_outline,color:Colors.red))]),
        TextFormField(controller:l.qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية بالكيلو'),onChanged:(_)=>setState((){}),validator:(v){final n=double.tryParse(v??'');return n==null||n<=0?'أدخل كمية صحيحة':null;}),
        Align(alignment:Alignment.centerRight,child:Text('سعر الكيلو ${fmt.format(l.price)} ريال • الإجمالي ${fmt.format(l.quantity*l.price)} ريال')),
      ])));}),
      TextButton.icon(onPressed:()async{final selected=await showModalBottomSheet<Map<String,Object?>>(context:context,builder:(ctx)=>ListView(children:fish.map((f)=>ListTile(title:Text(f['name'] as String),subtitle:Text('${fmt.format((f['price_per_kg'] as num).toDouble())} ريال/كجم'),onTap:()=>Navigator.pop(ctx,f))).toList()));if(selected!=null)setState(()=>lines.add(_Line(selected)));},icon:const Icon(Icons.add),label:const Text('إضافة نوع سمك آخر')),
      ListTile(title:const Text('موعد الاستلام'),subtitle:Text(DateFormat('yyyy/MM/dd - hh:mm a').format(pickup)),trailing:const Icon(Icons.calendar_month),onTap:choosePickup),
      Text('الإجمالي: ${fmt.format(total)} ريال',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      TextFormField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المدفوع الآن بالريال'),onChanged:(_)=>setState((){}),validator:(v){final n=double.tryParse(v??'');return n==null||n<0?'أدخل مبلغًا صحيحًا':null;}),
      Text('المتبقي: ${fmt.format((total-paidValue).clamp(0,double.infinity))} ريال',style:const TextStyle(fontWeight:FontWeight.bold)),
      TextFormField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'ملاحظات')),
      const SizedBox(height:20),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'جارٍ الحفظ':'حفظ الحجز')),
    ])),
  );
}
class _Line{
  _Line(this.fish);
  Map<String,Object?>? fish;
  final qty=TextEditingController(text:'1');
  double get quantity=>double.tryParse(qty.text.trim())??0;
  double get price=>(fish?['price_per_kg'] as num?)?.toDouble()??0;
}
