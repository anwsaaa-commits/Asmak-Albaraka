import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cloud_config.dart';

class CloudOrdersScreen extends StatefulWidget {
  const CloudOrdersScreen({super.key});

  @override
  State<CloudOrdersScreen> createState() => _CloudOrdersScreenState();
}

class _CloudOrdersScreenState extends State<CloudOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  final _money = NumberFormat('#,##0.##', 'en');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await CloudConfig.client
          .from('customer_orders')
          .select('id,order_code,customer_name,customer_phone,pickup_at,notes,status,total,created_at,customer_order_items(fish_name,quantity_kg,line_total)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _orders = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل الطلبات. تحقق من قاعدة البيانات وصلاحية المدير.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String id, String status) async {
    try {
      await CloudConfig.client.from('customer_orders').update({'status': status}).eq('id', id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث حالة الطلب. تحقق من صلاحيات المدير.')),
        );
      }
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'غير محدد';
    return DateFormat('yyyy/MM/dd - hh:mm a').format(parsed.toLocal());
  }

  Widget _line(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text('$label:', style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value?.toString() ?? '—')),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, int index) {
    final items = List<Map<String, dynamic>>.from(order['customer_order_items'] ?? const []);
    final status = order['status'] as String? ?? 'جديد';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    const statuses = ['جديد', 'مؤكد', 'قيد التجهيز', 'جاهز للاستلام', 'تم التسليم', 'ملغي'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        title: Text(
          '${order['customer_name'] ?? ''} • ${_money.format(total)} ر.ي',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('طلب ${order['order_code'] ?? ''} • $status'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _line('الهاتف', order['customer_phone']),
          _line('موعد الاستلام', _date(order['pickup_at'])),
          _line('تاريخ الطلب', _date(order['created_at'])),
          if ((order['notes'] as String? ?? '').isNotEmpty) _line('ملاحظات', order['notes']),
          const Divider(),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...items.map((item) {
            final quantity = (item['quantity_kg'] ?? '').toString();
            final lineTotal = (item['line_total'] as num?)?.toDouble() ?? 0;
            return _line(
              '${item['fish_name'] ?? ''} • $quantity كجم',
              '${_money.format(lineTotal)} ر.ي',
            );
          }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: statuses.contains(status) ? status : 'جديد',
            decoration: const InputDecoration(
              labelText: 'تحديث حالة الطلب',
              border: OutlineInputBorder(),
            ),
            items: statuses.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) {
              if (value != null && value != status) {
                _changeStatus(order['id'].toString(), value);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات المتجر الإلكتروني'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? const Center(child: Text('لا توجد حجوزات من المتجر حتى الآن'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) => _orderCard(_orders[index], index),
                      ),
                    ),
    );
  }
}
