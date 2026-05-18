import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lead_model.dart';
import '../services/csv_service.dart';
import '../providers/lead_provider.dart';
import '../utils/theme.dart';

class CsvUploadScreen extends ConsumerStatefulWidget {
  const CsvUploadScreen({super.key});

  @override
  ConsumerState<CsvUploadScreen> createState() => _CsvUploadScreenState();
}

class _CsvUploadScreenState extends ConsumerState<CsvUploadScreen> {
  bool _isProcessing = false;
  String? _fileName;
  List<Lead> _parsedLeads = [];
  List<Map<String, dynamic>> _invalidRows = [];
  int _duplicatesCount = 0;
  int _totalProcessed = 0;

  Future<void> _pickFile() async {
    setState(() {
      _isProcessing = true;
      _parsedLeads.clear();
      _invalidRows.clear();
      _duplicatesCount = 0;
      _totalProcessed = 0;
    });

    final res = await CsvService.pickAndParseCsv();

    setState(() {
      _isProcessing = false;
    });

    if (res['success'] == true) {
      setState(() {
        _fileName = res['fileName'];
        _parsedLeads = List<Lead>.from(res['leads']);
        _invalidRows = List<Map<String, dynamic>>.from(res['invalidRows']);
        _duplicatesCount = res['duplicatesCount'];
        _totalProcessed = res['totalRowsProcessed'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully parsed ${_parsedLeads.length} leads!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (res['error'] != 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Parsing failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadLeads() async {
    if (_parsedLeads.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    final leadNotifier = ref.read(leadProvider.notifier);
    final res = await leadNotifier.importLeads(_parsedLeads);

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      if (res['success']) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: ZoomIn(
              duration: const Duration(milliseconds: 500),
              child: AlertDialog(
                backgroundColor: AppTheme.obsidianCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppTheme.borderBlue),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 60),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Campaign Sync Complete',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Added: ${res['addedCount']} new leads to outbound queue.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    if (res['offline'] == true) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cloud offline. Cached in local agent!',
                          style: TextStyle(color: AppTheme.warningOrange, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // pop dialog
                        Navigator.of(context).pop(); // pop csv screen back to dashboard
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        minimumSize: const Size(140, 45),
                      ),
                      child: const Text('GO TO DASHBOARD'),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Upload failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV LEAD UPLOADER'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryNeon)),
                    SizedBox(height: 16),
                    Text('Processing contacts & formats...', style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Core Upload Panel
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        decoration: AppTheme.glassCardDecoration(
                          borderColor: AppTheme.primaryNeon.withOpacity(0.2),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNeon.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_copy_rounded, color: AppTheme.primaryNeon, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _fileName ?? 'Select Business CSV File',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Required: Name, Phone, Business Type, City',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('BROWSE STORAGE'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_parsedLeads.isNotEmpty) ...[
                      // File Parsing Summary Card
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: AppTheme.glassCardDecoration(
                            borderColor: AppTheme.secondaryNeon.withOpacity(0.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spreadsheet Analysis',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryStat('Total rows', _totalProcessed.toString(), Colors.blue),
                                  _buildSummaryStat('Valid Leads', _parsedLeads.length.toString(), AppTheme.successGreen),
                                  _buildSummaryStat('Duplicates', _duplicatesCount.toString(), AppTheme.warningOrange),
                                  _buildSummaryStat('Bad rows', _invalidRows.length.toString(), AppTheme.errorRed),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Lead List Table Preview
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PREVIEW DATA BEFORE CAMPAIGN',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 240,
                              decoration: AppTheme.glassCardDecoration(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ListView.separated(
                                  itemCount: _parsedLeads.length,
                                  separatorBuilder: (context, index) => const Divider(color: AppTheme.borderBlue, height: 1),
                                  itemBuilder: (context, index) {
                                    final lead = _parsedLeads[index];
                                    return ListTile(
                                      title: Text(
                                        lead.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${lead.businessType} • ${lead.city}',
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                      trailing: Text(
                                        lead.phone,
                                        style: GoogleFonts.outfit(color: AppTheme.secondaryNeon, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Confirm campaign import
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _uploadLeads,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            minimumSize: const Size(double.infinity, 54),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rocket_launch),
                              const SizedBox(width: 10),
                              Text(
                                'START AI CALL CAMPAIGN (${_parsedLeads.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        )
      ],
    );
  }
}
