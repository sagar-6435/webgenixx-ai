import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/analytics_provider.dart';
import '../utils/theme.dart';

class CallingEngineScreen extends ConsumerStatefulWidget {
  const CallingEngineScreen({super.key});

  @override
  ConsumerState<CallingEngineScreen> createState() => _CallingEngineScreenState();
}

class _CallingEngineScreenState extends ConsumerState<CallingEngineScreen> with TickerProviderStateMixin {
  late AnimationController _waveController;
  Timer? _campaignTimer;
  int _currentLeadIndex = 0;
  bool _isAutoCampaignRunning = false;
  String _aiModelUsed = 'Llama-3 (Groq API)';
  
  // UI Helpers
  bool _isGeneratingPitch = false;
  String? _generatedPitchText;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _campaignTimer?.cancel();
    super.dispose();
  }

  // Visual Speech Waveform Toggle
  void _toggleWaveform(bool active) {
    if (active) {
      _waveController.repeat(reverse: true);
    } else {
      _waveController.stop();
    }
  }

  // Generate Groq AI pitch first, then trigger Twilio call
  Future<void> _initiateCall(Lead lead) async {
    final leadNotifier = ref.read(leadProvider.notifier);
    final settings = ref.read(settingsProvider);

    setState(() {
      _isGeneratingPitch = true;
      _generatedPitchText = null;
    });

    // 1. Generate Llama Custom Outbound Pitch
    final pitch = await leadNotifier.generatePitch(lead.id, settings.voiceLanguage);
    
    if (!mounted) return;
    setState(() {
      _isGeneratingPitch = false;
      _generatedPitchText = pitch;
    });

    // 2. Trigger Twilio Outbound Webhook
    _toggleWaveform(true);
    final res = await leadNotifier.triggerCall(lead.id, settings.voiceLanguage, settings.simulated);

    if (!res['success'] && mounted) {
      _toggleWaveform(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Call failed'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Trigger next automated queue call
  void _runAutoCampaign(List<Lead> pendingQueue) {
    if (pendingQueue.isEmpty) {
      setState(() {
        _isAutoCampaignRunning = false;
      });
      _showCampaignCompleteNotification();
      return;
    }

    setState(() {
      _isAutoCampaignRunning = true;
      _currentLeadIndex = 0;
    });

    _executeCampaignStep(pendingQueue);
  }

  Future<void> _executeCampaignStep(List<Lead> queue) async {
    if (!_isAutoCampaignRunning || _currentLeadIndex >= queue.length) {
      setState(() {
        _isAutoCampaignRunning = false;
      });
      _showCampaignCompleteNotification();
      return;
    }

    final currentLead = queue[_currentLeadIndex];
    
    // Perform outbound dialing
    await _initiateCall(currentLead);

    // Wait until call status shifts out of In Conversation / Calling
    // In Simulator sandbox mode, this takes 8 seconds. We monitor active state.
    _monitorCallProgress(currentLead.id, queue);
  }

  void _monitorCallProgress(String leadId, List<Lead> queue) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isAutoCampaignRunning) {
        timer.cancel();
        return;
      }

      final leadState = ref.read(leadProvider);
      final currentLead = leadState.leads.firstWhere((l) => l.id == leadId);

      // Once status has shifted out of Calling/In Conversation, the call has completed!
      if (currentLead.status != 'Calling...' && currentLead.status != 'In Conversation') {
        timer.cancel();
        _toggleWaveform(false);

        // Refresh analytics dashboard in background
        ref.read(analyticsProvider.notifier).fetchAnalytics();

        // 3-5 seconds interval before dial next lead
        final settings = ref.read(settingsProvider);
        int countdown = settings.callTiming;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call completed! Next call in $countdown seconds...'),
            duration: Duration(seconds: countdown - 1),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Future.delayed(Duration(seconds: countdown), () {
          if (_isAutoCampaignRunning) {
            setState(() {
              _currentLeadIndex++;
            });
            _executeCampaignStep(queue);
          }
        });
      }
    });
  }

  void _stopAutoCampaign() {
    setState(() {
      _isAutoCampaignRunning = false;
    });
    _toggleWaveform(false);
    _campaignTimer?.cancel();
  }

  void _showCampaignCompleteNotification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderBlue),
        ),
        title: Row(
          children: const [
            Icon(Icons.campaign, color: AppTheme.secondaryNeon, size: 28),
            SizedBox(width: 10),
            Text('Campaign Finished!'),
          ],
        ),
        content: const Text(
          'All pending leads in your queue have been called. Check the Analytics panel to analyze interested business owners.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK', style: TextStyle(color: AppTheme.secondaryNeon)),
          )
        ],
      ),
    );
  }

  // Sandbox response overriding tool (super cool simulator cheat-sheet!)
  Future<void> _simulateLeadResponse(Lead lead, String status) async {
    final updated = lead.copyWith(
      status: status,
      notes: 'Manual simulation override: Marked as $status by admin.',
    );
    await ref.read(leadProvider.notifier).updateLeadManual(updated);
    _toggleWaveform(false);
    ref.read(analyticsProvider.notifier).fetchAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final leadState = ref.watch(leadProvider);
    final settings = ref.watch(settingsProvider);

    // Filter pending leads queue
    final pendingQueue = leadState.leads.where((l) => l.status == 'Pending').toList();
    final activeCallId = leadState.activeCallingLeadId;
    
    // Fetch active lead object
    Lead? activeLead;
    if (activeCallId != null) {
      activeLead = leadState.leads.firstWhere((l) => l.id == activeCallId);
    } else if (pendingQueue.isNotEmpty && !_isAutoCampaignRunning) {
      activeLead = pendingQueue.first; // Suggest first pending lead
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI CALLING COCKPIT'),
        actions: [
          if (_isAutoCampaignRunning)
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded, color: AppTheme.errorRed, size: 28),
              onPressed: _stopAutoCampaign,
            )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campaign Loop Controller
              if (pendingQueue.isNotEmpty && !_isAutoCampaignRunning && activeCallId == null)
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration(
                      color: AppTheme.primaryNeon.withOpacity(0.08),
                      borderColor: AppTheme.primaryNeon.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Outbound Queue Active',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${pendingQueue.length} leads waiting. Automate dialing loop?',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _runAutoCampaign(pendingQueue),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('RUN AUTO LOOP', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

              // Auto Campaign Progress Header
              if (_isAutoCampaignRunning)
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration(
                      color: AppTheme.secondaryNeon.withOpacity(0.08),
                      borderColor: AppTheme.secondaryNeon.withOpacity(0.3),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Automated Loop Active',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryNeon),
                              ),
                              Text(
                                'Processing lead ${_currentLeadIndex + 1} of ${pendingQueue.length + _currentLeadIndex}...',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _stopAutoCampaign,
                          child: const Text('PAUSE', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),

              if (activeLead == null) ...[
                // Queue Empty view
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.obsidianCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderBlue),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 60),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Queue Completely Clear!',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All uploaded leads have been dialed by Webgenixx AI.\nImport another CSV spreadsheet to restart.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Main Active Calling Dial Console Card
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassCardDecoration(
                      borderColor: activeCallId != null 
                          ? AppTheme.secondaryNeon.withOpacity(0.3) 
                          : AppTheme.borderBlue,
                    ),
                    child: Column(
                      children: [
                        // Lead calling details
                        _buildCallStatusBadge(activeLead.status),
                        const SizedBox(height: 16),
                        Text(
                          activeLead.name,
                          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textWhite),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeLead.phone,
                          style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activeLead.businessType} • ${activeLead.city}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),

                        // Glowing audio speech waveform during connected conversations
                        if (activeLead.status == 'Calling...' || activeLead.status == 'In Conversation')
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(10, (index) {
                                return AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, child) {
                                    final waveVal = (index % 2 == 0) 
                                        ? _waveController.value 
                                        : (1.0 - _waveController.value);
                                    return Container(
                                      width: 4,
                                      height: 15 + (waveVal * 35),
                                      decoration: BoxDecoration(
                                        color: activeLead!.status == 'In Conversation' 
                                            ? AppTheme.successGreen 
                                            : AppTheme.secondaryNeon,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),
                          )
                        else
                          const Icon(Icons.phone_paused, color: AppTheme.textMuted, size: 40),
                        
                        const SizedBox(height: 24),
                        const Divider(color: AppTheme.borderBlue),
                        const SizedBox(height: 16),

                        // Pitch Customization Frame
                        if (_isGeneratingPitch) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon)),
                              ),
                              SizedBox(width: 12),
                              Text('Synthesizing script via Llama-3 API...', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                            ],
                          )
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PERSONALIZED OUTBOUND SCRIPT (${settings.voiceLanguage})',
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.0),
                                  ),
                                  Text(
                                    _aiModelUsed,
                                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.secondaryNeon),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                                ),
                                child: Text(
                                  (_generatedPitchText ?? activeLead.pitch).replaceAll('“', '').replaceAll('”', '').trim().isNotEmpty
                                      ? (_generatedPitchText ?? activeLead.pitch)
                                      : 'No pitch generated. Click Initiate Call to customize pitch using Groq API.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                    color: activeLead.pitch.isNotEmpty || _generatedPitchText != null 
                                        ? AppTheme.textWhite 
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Dialer Command Action
                        if (activeCallId == null)
                          ElevatedButton.icon(
                            onPressed: () => _initiateCall(activeLead!),
                            icon: const Icon(Icons.call),
                            label: const Text('INITIATE OUTBOUND DIAL', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          )
                        else ...[
                          // Action panel when active dialing is running
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryNeon.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.secondaryNeon.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.speaker_phone, color: AppTheme.secondaryNeon, size: 18),
                                      SizedBox(width: 8),
                                      Text('SPEAKING TTS...', style: TextStyle(color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Sandbox Mode Manual Overrider Buttons
                          if (settings.simulated) ...[
                            const SizedBox(height: 20),
                            const Divider(color: AppTheme.borderBlue),
                            const SizedBox(height: 12),
                            const Text(
                              'SANDBOX OVERRIDE: Simulating client key press...',
                              style: TextStyle(color: AppTheme.warningOrange, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildSimulateButton(
                                  label: 'Press 1 (Interested)',
                                  color: AppTheme.successGreen,
                                  onTap: () => _simulateLeadResponse(activeLead!, 'Interested'),
                                ),
                                const SizedBox(width: 8),
                                _buildSimulateButton(
                                  label: 'Press 2 (Callback)',
                                  color: AppTheme.warningOrange,
                                  onTap: () => _simulateLeadResponse(activeLead!, 'Callback Later'),
                                ),
                                const SizedBox(width: 8),
                                _buildSimulateButton(
                                  label: 'Press 3 (Decline)',
                                  color: AppTheme.errorRed,
                                  onTap: () => _simulateLeadResponse(activeLead!, 'Rejected'),
                                ),
                              ],
                            )
                          ]
                        ]
                      ],
                    ),
                  ),
                ),
              ],

              // Queue List Preview Footer
              if (pendingQueue.length > 1) ...[
                const SizedBox(height: 32),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPCOMING OUTBOUND QUEUE (${pendingQueue.length - (activeCallId != null ? 0 : 1)})',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        decoration: AppTheme.glassCardDecoration(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.separated(
                            itemCount: pendingQueue.length,
                            separatorBuilder: (context, index) => const Divider(color: AppTheme.borderBlue, height: 1),
                            itemBuilder: (context, index) {
                              // Skip currently active lead
                              if (activeCallId == null && index == 0) return const SizedBox.shrink();
                              final lead = pendingQueue[index];
                              return ListTile(
                                title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${lead.businessType} • ${lead.city}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.borderBlue, size: 14),
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallStatusBadge(String status) {
    Color bg = AppTheme.borderBlue;
    Color text = AppTheme.textWhite;

    switch (status) {
      case 'Calling...':
        bg = AppTheme.secondaryNeon.withOpacity(0.15);
        text = AppTheme.secondaryNeon;
        break;
      case 'In Conversation':
        bg = AppTheme.successGreen.withOpacity(0.15);
        text = AppTheme.successGreen;
        break;
      case 'Interested':
        bg = AppTheme.successGreen.withOpacity(0.2);
        text = AppTheme.successGreen;
        break;
      case 'Callback Later':
        bg = AppTheme.warningOrange.withOpacity(0.2);
        text = AppTheme.warningOrange;
        break;
      case 'Rejected':
        bg = AppTheme.errorRed.withOpacity(0.2);
        text = AppTheme.errorRed;
        break;
      default:
        bg = AppTheme.borderBlue;
        text = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: text, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSimulateButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
