import 'package:flutter/material.dart';
import '../data/app_database.dart';

class FishScreen extends StatefulWidget {
  const FishScreen({super.key});
  @override State<FishScreen> createState() => _FishScreenState();
}
class _FishScreenState extends State<FishScreen> {
  List<Map<String,Object?>> rows=[];
  @override void initState(){super.initState();load();}
  Future<void> load() async {final r=await AppDatabase.instance.getFish();if(mounted)setState(()=>rows=r);}
  Future<void> edit([Map<String,Object?>? fish]) async {
    final name=TextEditingController(text:fish?['name'] as String? ?? '');
    final price=TextEditingController(text:fish?['price_per_kg']?.toString() ?? '');
    final key=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(fish==null?'إضافة نوع سمك':'تعديل الصنف'),
      content:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'اسم السمك'),validator:(v)=>v==null||v.trim().isEmpty?'الاسم مطلوب':null),
        TextFormField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'سعر الكيلو بالريال'),validator:(v){final n=double.tryParse(v??'');return n==null||n<0?'أدخل سعرًا صحيحًا':null;})
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:(){if(key.currentState!.validate())Navigator.pop(ctx,true);},child:const Text('حفظ'))],
    ));
    if(ok==true){try{await AppDatabase.instance.saveFish(id:fish?['id'] as int?,name:name.text,price:double.parse(price.text));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: $e')));}}
    name.dispose();price.dispose();load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('الأسماك والأسعار')),
    floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('إضافة صنف')),
    body:rows.isEmpty?const Center(child:Text('لا توجد أصناف. أضف نوع السمك وسعر الكيلو.')):ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(ctx,i){
      final f=rows[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.set_meal)),title:Text(f['name'] as String),subtitle:Text('سعر الكيلو: ${(f['price_per_kg'] as num).toStringAsFixed(0)} ريال'),onTap:()=>edit(f),trailing:IconButton(icon:const Icon(Icons.archive_outlined),onPressed:()async{await AppDatabase.instance.archiveFish(f['id'] as int);load();})));
    }),
  );
}
