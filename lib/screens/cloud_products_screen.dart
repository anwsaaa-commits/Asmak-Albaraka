import 'package:flutter/material.dart';
import '../services/cloud_config.dart';

class CloudProductsScreen extends StatefulWidget {
  const CloudProductsScreen({super.key});
  @override
  State<CloudProductsScreen> createState() => _CloudProductsScreenState();
}

class _CloudProductsScreenState extends State<CloudProductsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await CloudConfig.client.from('cloud_fish_products')
          .select('id,name,description,image_url,price_per_kg,is_active,is_offer,offer_price_per_kg')
          .order('name');
      if (!mounted) return;
      setState(() => _products = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل الأصناف السحابية. تأكد من صلاحية حساب المدير وتشغيل ملف قاعدة البيانات.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _edit([Map<String, dynamic>? product]) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final description = TextEditingController(text: product?['description']?.toString() ?? '');
    final price = TextEditingController(text: product?['price_per_kg']?.toString() ?? '');
    final offerPrice = TextEditingController(text: product?['offer_price_per_kg']?.toString() ?? '');
    final image = TextEditingController(text: product?['image_url']?.toString() ?? '');
    bool isOffer = product?['is_offer'] == true;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(product == null ? 'إضافة صنف للمتجر الإلكتروني' : 'تعديل صنف المتجر'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم السمك'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'وصف مختصر')),
          TextFormField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'السعر الأساسي للكيلو'), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n < 0 ? 'أدخل سعرًا صحيحًا' : null; }),
          TextFormField(controller: image, decoration: const InputDecoration(labelText: 'رابط صورة (اختياري)')),
          SwitchListTile(title: const Text('إظهار كسعر عرض'), value: isOffer, onChanged: (v) => setDialogState(() => isOffer = v)),
          if (isOffer) TextFormField(controller: offerPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر العرض للكيلو'), validator: (v) { if (!isOffer) return null; final n = double.tryParse(v ?? ''); return n == null || n < 0 ? 'أدخل سعر عرض صحيحًا' : null; }),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: const Text('حفظ')),
        ],
      ));
    });
    if (saved == true) {
      try {
        final data = {
          'name': name.text.trim(),
          'description': description.text.trim(),
          'price_per_kg': double.parse(price.text),
          'image_url': image.text.trim().isEmpty ? null : image.text.trim(),
          'is_offer': isOffer,
          'offer_price_per_kg': isOffer ? double.parse(offerPrice.text) : null,
          'is_active': product?['is_active'] ?? true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (product == null) {
          await CloudConfig.client.from('cloud_fish_products').insert(data);
        } else {
          await CloudConfig.client.from('cloud_fish_products').update(data).eq('id', product['id']);
        }
        await _load();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الصنف. تحقق من اتصال الإنترنت وصلاحية المدير.')));
      }
    }
    name.dispose(); description.dispose(); price.dispose(); offerPrice.dispose(); image.dispose();
  }

  Future<void> _toggle(Map<String, dynamic> product) async {
    try {
      await CloudConfig.client.from('cloud_fish_products')
          .update({'is_active': !(product['is_active'] == true), 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', product['id']);
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث حالة الصنف.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أصناف المتجر الإلكتروني'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة صنف')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
      : _products.isEmpty ? const Center(child: Text('لا توجد أصناف سحابية. أضف أول صنف للمتجر.'))
      : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _products.length, itemBuilder: (context, index) {
        final p = _products[index];
        final offer = p['is_offer'] == true;
        final price = offer ? p['offer_price_per_kg'] : p['price_per_kg'];
        return Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.set_meal)),
          title: Text(p['name']?.toString() ?? ''),
          subtitle: Text((offer ? 'سعر العرض: ' : 'السعر: ') + (price?.toString() ?? '0') + ' ر.ي / كجم' + ((p['is_active'] == true) ? '' : ' • مخفي')),
          onTap: () => _edit(p),
          trailing: IconButton(icon: Icon(p['is_active'] == true ? Icons.visibility_off : Icons.visibility), onPressed: () => _toggle(p), tooltip: 'إظهار أو إخفاء'),
        ));
      })),
  );
}
