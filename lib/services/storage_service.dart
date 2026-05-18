import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/lead_model.dart';

class StorageService {
  static const String _leadsBoxName = 'webgenixx_leads_box';
  static const String _leadsKey = 'cached_leads';

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_leadsBoxName);
  }

  // Get active leads box
  static Box get _box => Hive.box(_leadsBoxName);

  // Save leads list locally
  static Future<void> saveLeads(List<Lead> leads) async {
    final List<Map<String, dynamic>> leadMaps = leads.map((l) => l.toMap()).toList();
    final String serialized = json.encode(leadMaps);
    await _box.put(_leadsKey, serialized);
  }

  // Fetch leads list locally
  static List<Lead> getLeads() {
    final String? serialized = _box.get(_leadsKey) as String?;
    if (serialized == null) return [];

    try {
      final List<dynamic> decoded = json.decode(serialized) as List<dynamic>;
      return decoded.map((item) => Lead.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error parsing cached leads: $e');
      return [];
    }
  }

  // Clear local cache
  static Future<void> clearCache() async {
    await _box.delete(_leadsKey);
  }
}
