import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/lead_provider.dart';
import '../models/lead_model.dart';
import '../utils/theme.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(leadProvider.notifier).fetchLeads());
  }

  Future<void> _openRecording(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open recording URL'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadState = ref.watch(leadProvider);

    // Filter only leads that have a recording
    final recordedLeads = leadState.leads
        .where((l) => l.recordingUrl.isNotEmpty)
        .toList()
      ..sort((a, b) => (b.lastCalled ?? DateTime(0))
          .compareTo(a.lastCalled ?? DateTime(0)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOICE RECORDINGS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(leadProvider.notifier).fetchLeads(),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: leadState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon),
                ),
              )
            : recordedLeads.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => ref.read(leadProvider.notifier).fetchLeads(),
                    color: AppTheme.secondaryNeon,
                    backgroundColor: AppTheme.obsidianCard,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: recordedLeads.length,
                      itemBuilder: (context, index) {
                        return FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: Duration(milliseconds: index * 60),
                          child: _buildRecordingCard(recordedLeads[index]),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.obsidianCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderBlue),
            ),
            child: const Icon(Icons.mic_off_rounded, color: AppTheme.textMuted, size: 52),
          ),
          const SizedBox(height: 24),
          Text(
            'No Recordings Yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Voice recordings will appear here\nafter calls are completed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(Lead lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.glassCardDecoration(
        borderColor: AppTheme.secondaryNeon.withOpacity(0.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — name + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryNeon.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_rounded,
                            color: AppTheme.secondaryNeon, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              lead.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryNeon,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(lead.status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderBlue, height: 1),
            const SizedBox(height: 12),

            // Business info
            Row(
              children: [
                const Icon(Icons.business_outlined,
                    color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${lead.businessType} • ${lead.city}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lead.lastCalled != null) ...[
                  const Icon(Icons.access_time,
                      color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(lead.lastCalled!),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Play recording button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openRecording(lead.recordingUrl),
                icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
                label: const Text(
                  'PLAY VOICE RECORDING',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryNeon.withOpacity(0.15),
                  foregroundColor: AppTheme.secondaryNeon,
                  side: BorderSide(
                      color: AppTheme.secondaryNeon.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Interested':
        color = AppTheme.successGreen;
        break;
      case 'Callback Later':
        color = AppTheme.warningOrange;
        break;
      case 'Rejected':
        color = AppTheme.errorRed;
        break;
      default:
        color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
