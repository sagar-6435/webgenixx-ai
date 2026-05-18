import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/lead_provider.dart';
import '../providers/analytics_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _urlController;
  late TextEditingController _sidController;
  late TextEditingController _tokenController;
  late TextEditingController _phoneController;
  late TextEditingController _groqController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlController = TextEditingController(text: settings.backendUrl);
    _sidController = TextEditingController(text: settings.twilioAccountSid);
    _tokenController = TextEditingController(text: settings.twilioAuthToken);
    _phoneController = TextEditingController(text: settings.twilioPhoneNumber);
    _groqController = TextEditingController(text: settings.groqApiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _sidController.dispose();
    _tokenController.dispose();
    _phoneController.dispose();
    _groqController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(settingsProvider.notifier).updateSettings(
      backendUrl: _urlController.text.trim(),
      twilioAccountSid: _sidController.text.trim(),
      twilioAuthToken: _tokenController.text.trim(),
      twilioPhoneNumber: _phoneController.text.trim(),
      groqApiKey: _groqController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API settings updated successfully!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmResetCampaign() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.errorRed),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Text('Reset CRM Campaign?'),
          ],
        ),
        content: const Text(
          'This will permanently clear all lead records, calling notes, status tags, and analytics from both the mobile app and server database. This action is irreversible.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // pop confirm
              
              // trigger clears
              await ref.read(leadProvider.notifier).clearAllLeads();
              await ref.read(analyticsProvider.notifier).fetchAnalytics();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CRM Campaign cleared! Starting fresh.'),
                    backgroundColor: AppTheme.errorRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('CLEAR ENTIRE CAMPAIGN'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CAMPAIGN SETTINGS'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // Sandbox/Simulation mode wide toggle banner
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: AppTheme.glassCardDecoration(
                      color: settings.simulated 
                          ? AppTheme.warningOrange.withOpacity(0.08) 
                          : AppTheme.successGreen.withOpacity(0.08),
                      borderColor: settings.simulated 
                          ? AppTheme.warningOrange.withOpacity(0.3) 
                          : AppTheme.successGreen.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dialing Sandbox Simulator',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: settings.simulated ? AppTheme.warningOrange : AppTheme.successGreen,
                                ),
                              ),
                              const Text(
                                'Simulates inbound-key presses and pitch voice tracks without active Twilio credits.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: settings.simulated,
                          activeColor: AppTheme.warningOrange,
                          activeTrackColor: AppTheme.warningOrange.withOpacity(0.3),
                          inactiveThumbColor: AppTheme.successGreen,
                          inactiveTrackColor: AppTheme.successGreen.withOpacity(0.3),
                          onChanged: (val) {
                            notifier.updateSettings(simulated: val);
                          },
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Outbound Voice parameters panel
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOICE CAMPAIGN SETTINGS',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 20),

                        // Language Selection
                        const Text('TTS Script & Speech Language:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderBlue),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: settings.voiceLanguage,
                              dropdownColor: AppTheme.obsidianCard,
                              isExpanded: true,
                              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                              items: ['English', 'Telugu'].map((lang) {
                                return DropdownMenuItem<String>(
                                  value: lang,
                                  child: Text(lang),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  notifier.updateSettings(voiceLanguage: val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Delay dial settings
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Auto Dial Delay Spacing:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text('${settings.callTiming} Seconds', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.secondaryNeon, fontSize: 13)),
                          ],
                        ),
                        Slider(
                          value: settings.callTiming.toDouble(),
                          min: 2,
                          max: 10,
                          divisions: 8,
                          activeColor: AppTheme.secondaryNeon,
                          inactiveColor: AppTheme.borderBlue,
                          onChanged: (val) {
                            notifier.updateSettings(callTiming: val.toInt());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Credentials parameters panel
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERVER & API CREDENTIALS',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 20),

                        // Backend Server URL
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'Node.js Backend URL',
                            hintText: 'http://10.0.2.2:5000',
                            prefixIcon: Icon(Icons.dns_outlined, color: AppTheme.textMuted),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter backend URL';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Twilio SID
                        TextFormField(
                          controller: _sidController,
                          decoration: const InputDecoration(
                            labelText: 'Twilio Account SID',
                            hintText: 'ACxxxxxxxxxxxxxxxxxxxxxxxx',
                            prefixIcon: Icon(Icons.account_box_outlined, color: AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Twilio Token
                        TextFormField(
                          controller: _tokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Twilio Auth Token',
                            hintText: 'Enter Auth Token',
                            prefixIcon: Icon(Icons.vpn_key_outlined, color: AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Twilio Phone
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Twilio Phone Number',
                            hintText: '+1xxxxxxxxxx',
                            prefixIcon: Icon(Icons.phone_iphone_outlined, color: AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Groq Key
                        TextFormField(
                          controller: _groqController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Groq API Key',
                            hintText: 'gsk_xxxxxxxxxxxxxxxxxxxxxxxx',
                            prefixIcon: Icon(Icons.insights, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNeon,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('SAVE CREDENTIALS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                // WIPE DATABASE CAMPAIGN
                OutlinedButton.icon(
                  onPressed: _confirmResetCampaign,
                  icon: const Icon(Icons.delete_sweep, color: AppTheme.errorRed),
                  label: const Text('RESET SYSTEM CAMPAIGN', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.errorRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
