import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/theme.dart';
import 'csv_upload_screen.dart';
import 'calling_engine_screen.dart';
import 'lead_management_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'recordings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh leads and analytics when dashboard loads
    Future.microtask(() {
      ref.read(leadProvider.notifier).fetchLeads();
      ref.read(analyticsProvider.notifier).fetchAnalytics();
    });
  }

  Future<void> _handleRefresh() async {
    await ref.read(leadProvider.notifier).fetchLeads();
    await ref.read(analyticsProvider.notifier).fetchAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final leadState = ref.watch(leadProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final settingsState = ref.watch(settingsProvider);

    // Calculate dynamic dashboard numbers
    final totalLeads = leadState.leads.length;
    final completed = leadState.leads.where((l) => l.status != 'Pending' && l.status != 'Calling...').length;
    final interested = leadState.leads.where((l) => l.status == 'Interested').length;
    final callback = leadState.leads.where((l) => l.status == 'Callback Later').length;
    
    final conversion = totalLeads > 0 ? (interested / totalLeads) * 100 : 0.0;
    final progressVal = totalLeads > 0 ? completed / totalLeads : 0.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.secondaryNeon,
            backgroundColor: AppTheme.obsidianCard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Profile Welcome Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${authState.user?['name'] ?? 'Founder'}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Webgenixx outbound campaign active',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Action buttons
                      Row(
                        children: [
                          // Sandbox status dot
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: settingsState.simulated 
                                  ? AppTheme.warningOrange.withOpacity(0.1) 
                                  : AppTheme.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: settingsState.simulated 
                                    ? AppTheme.warningOrange.withOpacity(0.4) 
                                    : AppTheme.successGreen.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: settingsState.simulated ? AppTheme.warningOrange : AppTheme.successGreen,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  settingsState.simulated ? 'SIMULATOR' : 'LIVE API',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: settingsState.simulated ? AppTheme.warningOrange : AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: AppTheme.textWhite),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                                );
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Campaign Call Progress Bar Panel
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassCardDecoration(
                        color: AppTheme.obsidianCard.withOpacity(0.9),
                        borderColor: AppTheme.primaryNeon.withOpacity(0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Call Progress',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                              ),
                              Text(
                                '$completed / $totalLeads Calls',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryNeon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressVal.isNaN ? 0.0 : progressVal,
                              minHeight: 10,
                              backgroundColor: AppTheme.borderBlue,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryNeon),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Campaign Status: ${progressVal >= 1.0 && totalLeads > 0 ? "Completed" : totalLeads > 0 ? "In Progress" : "No Leads Uploaded"}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              Text(
                                '${(progressVal * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grid of Premium CRM Metrics
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildMetricCard(
                        title: 'Total Leads',
                        value: totalLeads.toString(),
                        subtitle: 'Upload Spreadsheet',
                        icon: Icons.people_outline,
                        color: AppTheme.primaryNeon,
                        delay: 100,
                      ),
                      _buildMetricCard(
                        title: 'Completed',
                        value: completed.toString(),
                        subtitle: 'Outbound Dialed',
                        icon: Icons.phone_callback_outlined,
                        color: AppTheme.secondaryNeon,
                        delay: 200,
                      ),
                      _buildMetricCard(
                        title: 'Interested',
                        value: interested.toString(),
                        subtitle: 'Pitched Mockup',
                        icon: Icons.thumb_up_alt_outlined,
                        color: AppTheme.successGreen,
                        delay: 300,
                      ),
                      _buildMetricCard(
                        title: 'Callback Later',
                        value: callback.toString(),
                        subtitle: 'Scheduled Follow-up',
                        icon: Icons.calendar_today_outlined,
                        color: AppTheme.warningOrange,
                        delay: 400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Conversion Rate Wide Banner
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: AppTheme.glassCardDecoration(
                        borderColor: AppTheme.successGreen.withOpacity(0.15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.insights, color: AppTheme.successGreen, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Conversion Success Rate',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textWhite,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Interested clients pitched by Llama-3',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${conversion.toStringAsFixed(1)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Navigation Portal Header
                  Text(
                    'CAMPAIGN CONTROL ROOM',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Large functional control grid buttons
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildNavigationButton(
                        label: 'Upload CSV',
                        desc: 'Import Contacts',
                        icon: Icons.file_upload_outlined,
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const CsvUploadScreen()),
                          );
                        },
                      ),
                      _buildNavigationButton(
                        label: 'Start Calling',
                        desc: 'AI Voice Cockpit',
                        icon: Icons.record_voice_over_outlined,
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const CallingEngineScreen()),
                          );
                        },
                      ),
                      _buildNavigationButton(
                        label: 'View Leads',
                        desc: 'CRM Contact Board',
                        icon: Icons.view_headline_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const LeadManagementScreen()),
                          );
                        },
                      ),
                      _buildNavigationButton(
                        label: 'Analytics',
                        desc: 'Performance Curves',
                        icon: Icons.bar_chart_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF43F5E)]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                          );
                        },
                      ),
                      _buildNavigationButton(
                        label: 'Recordings',
                        desc: 'Voice Call Archive',
                        icon: Icons.mic_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const RecordingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      
      // Floating Action Quick Call Dialing Cockpit
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CallingEngineScreen()),
          );
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
          ),
          child: const Icon(Icons.phone_in_talk, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCardDecoration(
          borderColor: color.withOpacity(0.15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required String label,
    required String desc,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return ZoomIn(
      duration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
