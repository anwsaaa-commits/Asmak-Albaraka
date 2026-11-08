import 'package:supabase_flutter/supabase_flutter.dart';

class CloudConfig {
  static const projectUrl = 'https://qrvphvimsjhnuqcvnfaw.supabase.co';
  static const publishableKey = 'sb_publishable_1mVWr0OIelzIPW4iAdwLEQ_gCSfpB8X';
  static Future<void> initialize() => Supabase.initialize(url: projectUrl, publishableKey: publishableKey);
  static SupabaseClient get client => Supabase.instance.client;
}
