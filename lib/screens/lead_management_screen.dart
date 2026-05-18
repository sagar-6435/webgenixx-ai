import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/theme.dart';
import 'calling_engine_screen.dart';

class LeadManagementScreen extends ConsumerStatefulWidget {
  const LeadManagementScreen({super.key});

  @override
  ConsumerState<LeadManagementScreen> createState() => _LeadManagementScreenState();
}

class _LeadManagementScreenState extends ConsumerState<LeadManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Fetch latest leads from remote
    Future.microtask(() {
      ref.read(leadProvider.notifier).fetchLeads();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Edit notes pop up dialog
  void _showEditNotesDialog(Lead lead) {
    final notesController = TextEditingController(text: lead.notes);
    String selectedStatus = lead.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.obsidianCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderBlue),
            ),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.secondaryNeon, size: 28),
                const SizedBox(width: 8),
                Text('Update CRM Status', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(lead.phone, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 20),
                
                // Status Selector dropdown
                const Text('Campaign Response Status:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderBlue),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      dropdownColor: AppTheme.obsidianCard,
                      isExpanded: true,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                      items: ['Pending', 'Interested', 'Callback Later', 'Rejected'].map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedStatus = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Note input text area
                const Text('Conversation Notes:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add summary of pitch call, specific client requirements, callback time...',
                    fillColor: Colors.black.withOpacity(0.3),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updatedLead = lead.copyWith(
                    status: selectedStatus,
                    notes: notesController.text.trim(),
                  );
                  await ref.read(leadProvider.notifier).updateLeadManual(updatedLead);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CRM record updated!'),
                        backgroundColor: AppTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryNeon),
                child: const Text('SAVE CHANGES'),
              )
            ],
          );
        },
      ),
    );
  }

  // Redial shortcut caller trigger
  Future<void> _redialLead(Lead lead) async {
    final settings = ref.read(settingsProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CallingEngineScreen(),
      ),
    );
    // Small delay to let screen transition, then trigger call!
    Future.delayed(const Duration(milliseconds: 500), () {
      ref.read(leadProvider.notifier).triggerCall(lead.id, settings.voiceLanguage, settings.simulated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadState = ref.watch(leadProvider);
    final notifier = ref.read(leadProvider.notifier);

    // Apply search filter and split lists by CRM outcome
    List<Lead> filteredLeads = leadState.leads.where((l) {
      final query = _searchQuery.toLowerCase();
      return l.name.toLowerCase().contains(query) ||
          l.phone.contains(query) ||
          l.city.toLowerCase().contains(query) ||
          l.businessType.toLowerCase().contains(query);
    }).toList();

    List<Lead> interested = filteredLeads.where((l) => l.status == 'Interested').toList();
    List<Lead> callbacks = filteredLeads.where((l) => l.status == 'Callback Later').toList();
    List<Lead> rejected = filteredLeads.where((l) => l.status == 'Rejected').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM LEAD MANAGER'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondaryNeon,
          labelColor: AppTheme.secondaryNeon,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'All (${filteredLeads.length})'),
            Tab(text: 'Interested (${interested.length})'),
            Tab(text: 'Callback (${callbacks.length})'),
            Tab(text: 'Decline (${rejected.length})'),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: Column(
          children: [
            // Interactive Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by business name, city, category...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Main Tab list panel
            Expanded(
              child: leadState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon)),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLeadsList(filteredLeads),
                        _buildLeadsList(interested),
                        _buildLeadsList(callbacks),
                        _buildLeadsList(rejected),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsList(List<Lead> leads) {
    if (leads.isEmpty) {
      return Center(
        child: FadeIn(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.obsidianCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderBlue),
                ),
                child: const Icon(Icons.contact_phone_outlined, color: AppTheme.textMuted, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'No leads match filters',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return FadeInRight(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 50 > 300 ? 300 : index * 50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Name & Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lead.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ),
                    _buildLeadStatusMiniBadge(lead.status),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Details row: Phone
                Text(
                  lead.phone,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.secondaryNeon, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),

                // Details: Business type and city
                Text(
                  '${lead.businessType} • ${lead.city}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),

                // Note panel
                if (lead.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.3)),
                    ),
                    child: Text(
                      lead.notes,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textWhite, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: AppTheme.borderBlue, height: 1),
                const SizedBox(height: 8),

                // Interactive command bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditNotesDialog(lead),
                      icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.textMuted),
                      label: const Text('CRM LOG', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: () => _redialLead(lead),
                      icon: const Icon(Icons.phone_in_talk, size: 14),
                      label: const Text('DIAL AGENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNeon,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeadStatusMiniBadge(String status) {
    Color color = AppTheme.textMuted;
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
      case 'Calling...':
      case 'In Conversation':
        color = AppTheme.secondaryNeon;
        break;
      default:
        color = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
      ),
    );
  }
}
