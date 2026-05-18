import 'dart:convert';

class Lead {
  final String id;
  final String name;
  final String phone;
  final String businessType;
  final String city;
  final String status; // Pending, Calling..., In Conversation, Interested, Callback Later, Rejected
  final String pitch;
  final DateTime? lastCalled;
  final String notes;

  Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.businessType,
    required this.city,
    required this.status,
    this.pitch = '',
    this.lastCalled,
    this.notes = '',
  });

  Lead copyWith({
    String? id,
    String? name,
    String? phone,
    String? businessType,
    String? city,
    String? status,
    String? pitch,
    DateTime? lastCalled,
    String? notes,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      businessType: businessType ?? this.businessType,
      city: city ?? this.city,
      status: status ?? this.status,
      pitch: pitch ?? this.pitch,
      lastCalled: lastCalled ?? this.lastCalled,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'businessType': businessType,
      'city': city,
      'status': status,
      'pitch': pitch,
      'lastCalled': lastCalled?.toIso8601String(),
      'notes': notes,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      businessType: map['businessType'] ?? 'General Business',
      city: map['city'] ?? 'Unknown',
      status: map['status'] ?? 'Pending',
      pitch: map['pitch'] ?? '',
      lastCalled: map['lastCalled'] != null ? DateTime.tryParse(map['lastCalled']) : null,
      notes: map['notes'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Lead.fromJson(String source) => Lead.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Lead(id: $id, name: $name, phone: $phone, businessType: $businessType, city: $city, status: $status)';
  }
}
