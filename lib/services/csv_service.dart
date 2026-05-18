import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/lead_model.dart';

class CsvService {
  // Picks a file from phone storage and returns parsed, validated Lead list
  static Future<Map<String, dynamic>> pickAndParseCsv() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'error': 'No file selected'};
      }

      final String? filePath = result.files.first.path;
      if (filePath == null) {
        return {'success': false, 'error': 'Failed to retrieve file path'};
      }

      final File file = File(filePath);
      final String csvContent = await file.readAsString(encoding: utf8);
      
      return parseCsvContent(csvContent, result.files.first.name);
    } catch (e) {
      print('CSV Picker Error: $e');
      return {'success': false, 'error': 'Failed to read CSV file: ${e.toString()}'};
    }
  }

  // Parse raw CSV string content
  static Map<String, dynamic> parseCsvContent(String csvContent, String fileName) {
    try {
      // Parse CSV into lists of values
      final List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ',',
        shouldParseNumbers: false,
      ).convert(csvContent);

      if (rows.isEmpty) {
        return {'success': false, 'error': 'The CSV file is empty'};
      }

      final List<Lead> validLeads = [];
      final List<Map<String, dynamic>> invalidRows = [];
      int duplicatesCount = 0;
      final Set<String> processedPhones = {};

      // Analyze headers to identify key columns (case-insensitive search)
      final List<dynamic> headers = rows.first;
      int nameIdx = 0;
      int phoneIdx = 1;
      int businessIdx = 2;
      int cityIdx = 3;
      int statusIdx = -1;

      for (int i = 0; i < headers.length; i++) {
        final String col = headers[i].toString().toLowerCase().trim();
        if (col.contains('name') || col.contains('owner') || col.contains('business name')) {
          nameIdx = i;
        } else if (col.contains('phone') || col.contains('number') || col.contains('mobile') || col.contains('contact')) {
          phoneIdx = i;
        } else if (col.contains('type') || col.contains('niche') || col.contains('category') || col.contains('industry') || col.contains('business type')) {
          businessIdx = i;
        } else if (col.contains('city') || col.contains('town') || col.contains('location') || col.contains('address')) {
          cityIdx = i;
        } else if (col.contains('status')) {
          statusIdx = i;
        }
      }

      // Check if CSV has only 1 row (just headers)
      if (rows.length <= 1) {
        return {'success': false, 'error': 'No lead rows found below the header'};
      }

      // Parse data rows
      for (int i = 1; i < rows.length; i++) {
        final List<dynamic> row = rows[i];
        if (row.length <= nameIdx || row.length <= phoneIdx) {
          invalidRows.add({'row': i + 1, 'reason': 'Missing columns'});
          continue;
        }

        final String name = row[nameIdx].toString().trim();
        final String rawPhone = row[phoneIdx].toString().trim();
        
        // Dynamic fallback fields
        final String businessType = row.length > businessIdx 
            ? row[businessIdx].toString().trim() 
            : 'General Business';
        final String city = row.length > cityIdx 
            ? row[cityIdx].toString().trim() 
            : 'Unknown';

        // Extract and normalize raw status if present
        String leadStatus = 'Pending';
        if (statusIdx != -1 && row.length > statusIdx) {
          final String rawStatus = row[statusIdx].toString().trim();
          if (rawStatus.isNotEmpty) {
            final String norm = rawStatus.toLowerCase();
            if (norm.contains('interested')) {
              leadStatus = 'Interested';
            } else if (norm.contains('callback') || norm.contains('later')) {
              leadStatus = 'Callback Later';
            } else if (norm.contains('reject') || norm.contains('decline') || norm.contains('no')) {
              leadStatus = 'Rejected';
            } else if (norm.contains('call')) {
              leadStatus = 'Calling...';
            } else if (norm.contains('conversation') || norm.contains('talk')) {
              leadStatus = 'In Conversation';
            }
          }
        }

        // Validation checks
        if (name.isEmpty) {
          invalidRows.add({'row': i + 1, 'reason': 'Empty name'});
          continue;
        }

        // Clean phone number (remove spaces, dashes, brackets, etc.)
        final String cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        
        if (cleanPhone.isEmpty || cleanPhone.length < 10) {
          invalidRows.add({'row': i + 1, 'reason': 'Invalid phone number ($rawPhone)'});
          continue;
        }

        // Duplicate detection inside file
        if (processedPhones.contains(cleanPhone)) {
          duplicatesCount++;
          continue;
        }

        processedPhones.add(cleanPhone);

        // Format to standard phone output (add +91 if 10 digits and not already added)
        String formattedPhone = cleanPhone;
        if (cleanPhone.length == 10 && !cleanPhone.startsWith('+')) {
          formattedPhone = '+91$cleanPhone'; // Default Indian dial code since user has +91 examples
        } else if (cleanPhone.length == 12 && cleanPhone.startsWith('91')) {
          formattedPhone = '+$cleanPhone';
        } else if (!cleanPhone.startsWith('+')) {
          formattedPhone = '+$cleanPhone';
        }

        validLeads.add(Lead(
          id: 'temp_${i}_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          phone: formattedPhone,
          businessType: businessType.isEmpty ? 'General Business' : businessType,
          city: city.isEmpty ? 'Unknown' : city,
          status: leadStatus,
        ));
      }

      return {
        'success': true,
        'fileName': fileName,
        'leads': validLeads,
        'invalidRows': invalidRows,
        'duplicatesCount': duplicatesCount,
        'totalRowsProcessed': rows.length - 1,
      };
    } catch (e) {
      print('CSV Parse Error: $e');
      return {'success': false, 'error': 'CSV format error: Make sure details are comma-separated.'};
    }
  }
}
