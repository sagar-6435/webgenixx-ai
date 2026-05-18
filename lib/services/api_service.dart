import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class ApiService {
  static String _baseUrl = 'http://10.45.146.96:5005'; // PC local IP for physical device
  static String? _token;

  static const String _defaultUrl = 'http://10.45.146.96:5005';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Always reset to current default IP — clears any stale cached URL
    await prefs.setString('backend_url', _defaultUrl);
    _baseUrl = _defaultUrl;
    _token = prefs.getString('auth_token');
  }

  static String get baseUrl => _baseUrl;

  static Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', newUrl);
  }

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ================= AUTHENTICATION =================

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({'email': email, 'password': password}),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        _token = decoded['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        return {'success': true, 'user': decoded['user']};
      } else {
        return {'success': false, 'error': decoded['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server. Check server URL and network.'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: _headers,
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 201) {
        _token = decoded['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        return {'success': true, 'user': decoded['user']};
      } else {
        return {'success': false, 'error': decoded['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed.'};
    }
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ================= LEADS MANAGEMENT =================

  static Future<List<Lead>> fetchLeads() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/leads'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        return decoded.map((item) => Lead.fromMap(item)).toList();
      } else {
        throw Exception('Failed to load leads from server');
      }
    } catch (e) {
      print('API Error fetchLeads: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> syncBulkLeads(List<Lead> leads) async {
    try {
      final leadMaps = leads.map((l) => {
        'name': l.name,
        'phone': l.phone,
        'businessType': l.businessType,
        'city': l.city,
      }).toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/leads/bulk'),
        headers: _headers,
        body: json.encode({'leads': leadMaps}),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': decoded['message'], 'addedCount': decoded['addedCount']};
      } else {
        return {'success': false, 'error': decoded['error'] ?? 'Bulk sync failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed during lead sync'};
    }
  }

  static Future<Lead> updateLead(Lead lead) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/leads/${lead.id}'),
        headers: _headers,
        body: json.encode(lead.toMap()),
      );

      if (response != null && response.statusCode == 200) {
        return Lead.fromMap(json.decode(response.body));
      } else {
        throw Exception('Failed to update lead status');
      }
    } catch (e) {
      print('API Error updateLead: $e');
      rethrow;
    }
  }

  static Future<void> clearAllLeadsOnServer() async {
    try {
      await http.delete(Uri.parse('$_baseUrl/api/leads'), headers: _headers);
    } catch (e) {
      print('API Error clearAllLeads: $e');
    }
  }

  // ================= AI SCRIPT GENERATION =================

  static Future<String> generateAiScript(Lead lead, String language) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/generate-pitch'),
        headers: _headers,
        body: json.encode({
          'name': lead.name,
          'businessType': lead.businessType,
          'city': lead.city,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['pitch'] ?? '';
      } else {
        throw Exception('Failed to generate AI pitch');
      }
    } catch (e) {
      print('API Error generateAiScript: $e');
      // Offline fallback pitch
      return language == 'Telugu'
          ? "Namaskaram ${lead.name} garu! Memu Webgenixx web agency nunchi contact chesthunnam. Mee ${lead.businessType} ki beautiful custom website design chestham. Online search and dynamic bookings automate cheyyadaniki, 1 press cheyyandi details kosam. Dhanyavadalu!"
          : "Hello ${lead.name}! This is the Webgenixx web development team. We noticed your premium ${lead.businessType} in ${lead.city} and want to design a modern booking website to double your customers. To see a custom mockup layout, press 1 now. Thank you!";
    }
  }

  // ================= CALL TRIGGERING =================

  static Future<Map<String, dynamic>> triggerTwilioCall(String leadId, String language, bool simulated) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/calls/trigger'),
        headers: _headers,
        body: json.encode({
          'leadId': leadId,
          'language': language,
          'simulated': simulated,
        }),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'],
          'status': decoded['status'],
          'simulated': decoded['simulated'] ?? false
        };
      } else {
        return {'success': false, 'error': decoded['error'] ?? 'Call placement failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to calling API server.'};
    }
  }

  // ================= ANALYTICS =================

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/analytics'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch analytics from backend');
      }
    } catch (e) {
      print('API Error fetchAnalytics: $e');
      // offline fallback structure to prevent app crashes
      return {
        'totalLeads': 0,
        'callsCompleted': 0,
        'interestedLeads': 0,
        'callbackRequests': 0,
        'rejectedLeads': 0,
        'conversionRate': 0.0,
        'nichePerformance': [],
        'callingHistory': []
      };
    }
  }
}
