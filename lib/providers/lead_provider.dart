import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class LeadState {
  final List<Lead> leads;
  final bool isLoading;
  final String? error;
  final String? activeCallingLeadId; // ID of lead currently being dialed/called

  LeadState({
    required this.leads,
    required this.isLoading,
    this.error,
    this.activeCallingLeadId,
  });

  LeadState copyWith({
    List<Lead>? leads,
    bool? isLoading,
    String? error,
    String? activeCallingLeadId,
  }) {
    return LeadState(
      leads: leads ?? this.leads,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      activeCallingLeadId: activeCallingLeadId ?? this.activeCallingLeadId,
    );
  }
}

class LeadNotifier extends StateNotifier<LeadState> {
  LeadNotifier()
      : super(LeadState(
          leads: [],
          isLoading: false,
        )) {
    loadLocalCachedLeads();
  }

  // Load from local Hive cache instantly on app startup
  void loadLocalCachedLeads() {
    final cached = StorageService.getLeads();
    if (cached.isNotEmpty) {
      state = state.copyWith(leads: cached);
    }
  }

  // Synchronize leads from backend cloud database
  Future<void> fetchLeads() async {
    state = state.copyWith(isLoading: state.leads.isEmpty); // Only show loader if cache is empty
    try {
      final remoteLeads = await ApiService.fetchLeads();
      state = LeadState(leads: remoteLeads, isLoading: false);
      
      // Save locally to cache box
      await StorageService.saveLeads(remoteLeads);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sync with cloud. Displaying offline cached leads.',
      );
      // Ensure cache remains active
      loadLocalCachedLeads();
    }
  }

  // Bulk import leads parsed from CSV
  Future<Map<String, dynamic>> importLeads(List<Lead> importedLeads) async {
    state = state.copyWith(isLoading: true);
    
    final res = await ApiService.syncBulkLeads(importedLeads);
    if (res['success']) {
      // Sync cloud data back down
      await fetchLeads();
      return {'success': true, 'addedCount': res['addedCount']};
    } else {
      state = state.copyWith(isLoading: false);
      
      // If server is offline, store in local cache directly for offline simulation!
      final mergedLeads = List<Lead>.from(state.leads);
      int offlineAdded = 0;
      
      for (var l in importedLeads) {
        final isDuplicate = mergedLeads.any((existing) => 
          existing.phone.replaceAll(RegExp(r'\s+'), '') == l.phone.replaceAll(RegExp(r'\s+'), '')
        );
        if (!isDuplicate) {
          mergedLeads.add(l.copyWith(id: 'offline_${DateTime.now().microsecondsSinceEpoch}_${offlineAdded++}'));
        }
      }
      
      state = LeadState(leads: mergedLeads, isLoading: false);
      await StorageService.saveLeads(mergedLeads);
      
      return {
        'success': true,
        'addedCount': offlineAdded,
        'offline': true,
        'error': 'Cloud unreachable. Saved to offline simulator cache!'
      };
    }
  }

  // Generate Groq AI pitch script for a single lead
  Future<String> generatePitch(String leadId, String language) async {
    final leadIndex = state.leads.indexWhere((l) => l.id == leadId);
    if (leadIndex == -1) return '';

    final lead = state.leads[leadIndex];
    try {
      final pitchText = await ApiService.generateAiScript(lead, language);
      
      final updatedLead = lead.copyWith(pitch: pitchText);
      final updatedLeads = List<Lead>.from(state.leads);
      updatedLeads[leadIndex] = updatedLead;
      
      state = state.copyWith(leads: updatedLeads);
      await StorageService.saveLeads(updatedLeads);

      // Attempt to save to cloud server
      try {
        await ApiService.updateLead(updatedLead);
      } catch (_) {}

      return pitchText;
    } catch (e) {
      print('AI generation provider failure: $e');
      return '';
    }
  }

  // Trigger Outbound Call via Twilio
  Future<Map<String, dynamic>> triggerCall(String leadId, String language, bool simulated) async {
    // 1. Shift UI state to calling
    final leadIndex = state.leads.indexWhere((l) => l.id == leadId);
    if (leadIndex == -1) return {'success': false, 'error': 'Lead not found'};

    state = state.copyWith(activeCallingLeadId: leadId);
    
    final originalLead = state.leads[leadIndex];
    
    // Update local UI state to 'Calling...'
    final dialLead = originalLead.copyWith(
      status: 'Calling...',
      lastCalled: DateTime.now(),
    );
    _updateLocalLead(dialLead);

    // 2. Trigger API Call
    final res = await ApiService.triggerTwilioCall(leadId, language, simulated);
    
    if (res['success']) {
      // Monitor status in real-time or update after response
      if (res['simulated'] == true) {
        // Start an offline simulation polling sequence to mimic phone conversation!
        _startOfflineSimulationSequence(leadId);
      } else {
        // Real Twilio call triggered
        final activeCall = dialLead.copyWith(status: 'Calling...');
        _updateLocalLead(activeCall);
      }
      return {'success': true, 'simulated': res['simulated']};
    } else {
      // Revert status to Pending on failure
      final resetLead = originalLead.copyWith(status: 'Pending');
      _updateLocalLead(resetLead);
      state = state.copyWith(activeCallingLeadId: null);
      return {'success': false, 'error': res['error']};
    }
  }

  // Helper: Offline call simulation timing matching the backend
  void _startOfflineSimulationSequence(String leadId) {
    // Simulate Connect (In Conversation) after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      final leadIndex = state.leads.indexWhere((l) => l.id == leadId);
      if (leadIndex == -1) return;
      
      final currentLead = state.leads[leadIndex];
      if (currentLead.status != 'Calling...') return;

      final connectLead = currentLead.copyWith(status: 'In Conversation');
      _updateLocalLead(connectLead);

      // Simulate completed response (Interested, Callback, Rejected) after 5 seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await fetchLeads(); // Fetch fresh updates from server analytics
        state = state.copyWith(activeCallingLeadId: null);
      });
    });
  }

  // Manually update notes or status
  Future<void> updateLeadManual(Lead updatedLead) async {
    _updateLocalLead(updatedLead);
    try {
      await ApiService.updateLead(updatedLead);
    } catch (_) {}
  }

  // Clear all leads from app and cloud
  Future<void> clearAllLeads() async {
    state = state.copyWith(isLoading: true);
    await ApiService.clearAllLeadsOnServer();
    await StorageService.clearCache();
    state = LeadState(leads: [], isLoading: false);
  }

  // Helper to update a lead inside our memory list and Hive cache
  void _updateLocalLead(Lead updatedLead) {
    final index = state.leads.indexWhere((l) => l.id == updatedLead.id);
    if (index != -1) {
      final newLeads = List<Lead>.from(state.leads);
      newLeads[index] = updatedLead;
      state = state.copyWith(leads: newLeads);
      StorageService.saveLeads(newLeads);
    }
  }

  // ================= GETTERS FOR FILTERING =================

  List<Lead> get pendingLeads => state.leads.where((l) => l.status == 'Pending').toList();
  List<Lead> get interestedLeads => state.leads.where((l) => l.status == 'Interested').toList();
  List<Lead> get callbackLeads => state.leads.where((l) => l.status == 'Callback Later').toList();
  List<Lead> get rejectedLeads => state.leads.where((l) => l.status == 'Rejected').toList();
  
  List<Lead> get completedCalls => state.leads.where((l) => 
    l.status == 'Interested' || l.status == 'Callback Later' || l.status == 'Rejected'
  ).toList();
}

// Global Provider declaration
final leadProvider = StateNotifierProvider<LeadNotifier, LeadState>((ref) {
  return LeadNotifier();
});
