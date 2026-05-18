import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsState {
  final String backendUrl;
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioPhoneNumber;
  final String groqApiKey;
  final String voiceLanguage; // English or Telugu
  final bool simulated; // Sandbox/Simulation Mode
  final int callTiming; // Interval in seconds

  SettingsState({
    required this.backendUrl,
    required this.twilioAccountSid,
    required this.twilioAuthToken,
    required this.twilioPhoneNumber,
    required this.groqApiKey,
    required this.voiceLanguage,
    required this.simulated,
    required this.callTiming,
  });

  SettingsState copyWith({
    String? backendUrl,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? twilioPhoneNumber,
    String? groqApiKey,
    String? voiceLanguage,
    bool? simulated,
    int? callTiming,
  }) {
    return SettingsState(
      backendUrl: backendUrl ?? this.backendUrl,
      twilioAccountSid: twilioAccountSid ?? this.twilioAccountSid,
      twilioAuthToken: twilioAuthToken ?? this.twilioAuthToken,
      twilioPhoneNumber: twilioPhoneNumber ?? this.twilioPhoneNumber,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      simulated: simulated ?? this.simulated,
      callTiming: callTiming ?? this.callTiming,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(
          backendUrl: 'http://10.45.146.96:5005',
          twilioAccountSid: '',
          twilioAuthToken: '',
          twilioPhoneNumber: '',
          groqApiKey: '',
          voiceLanguage: 'English',
          simulated: false,
          callTiming: 3,
        )) {
    loadSettings();
  }

  // Load persistent configurations from device storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Always use the hardcoded IP — never load stale cached URL
    const backend = 'http://10.45.146.96:5005';
    await prefs.setString('backend_url', backend);

    final sid = prefs.getString('twilio_account_sid') ?? '';
    final token = prefs.getString('twilio_auth_token') ?? '';
    final phone = prefs.getString('twilio_phone_number') ?? '';
    final groq = prefs.getString('groq_api_key') ?? '';
    final lang = prefs.getString('voice_language') ?? 'English';
    final sim = prefs.getBool('simulated_calling') ?? false;
    final timing = prefs.getInt('call_timing') ?? 3;

    state = SettingsState(
      backendUrl: backend,
      twilioAccountSid: sid,
      twilioAuthToken: token,
      twilioPhoneNumber: phone,
      groqApiKey: groq,
      voiceLanguage: lang,
      simulated: sim,
      callTiming: timing,
    );

    // Sync base URL with the API service
    await ApiService.updateBaseUrl(backend);
  }

  // Save configurations to storage and state
  Future<void> updateSettings({
    String? backendUrl,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? twilioPhoneNumber,
    String? groqApiKey,
    String? voiceLanguage,
    bool? simulated,
    int? callTiming,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (backendUrl != null) {
      await prefs.setString('backend_url', backendUrl);
      await ApiService.updateBaseUrl(backendUrl);
    }
    if (twilioAccountSid != null) {
      await prefs.setString('twilio_account_sid', twilioAccountSid);
    }
    if (twilioAuthToken != null) {
      await prefs.setString('twilio_auth_token', twilioAuthToken);
    }
    if (twilioPhoneNumber != null) {
      await prefs.setString('twilio_phone_number', twilioPhoneNumber);
    }
    if (groqApiKey != null) {
      await prefs.setString('groq_api_key', groqApiKey);
    }
    if (voiceLanguage != null) {
      await prefs.setString('voice_language', voiceLanguage);
    }
    if (simulated != null) {
      await prefs.setBool('simulated_calling', simulated);
    }
    if (callTiming != null) {
      await prefs.setInt('call_timing', callTiming);
    }

    state = state.copyWith(
      backendUrl: backendUrl,
      twilioAccountSid: twilioAccountSid,
      twilioAuthToken: twilioAuthToken,
      twilioPhoneNumber: twilioPhoneNumber,
      groqApiKey: groqApiKey,
      voiceLanguage: voiceLanguage,
      simulated: simulated,
      callTiming: callTiming,
    );
  }
}

// Global Provider declaration
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
