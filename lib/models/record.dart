import 'dart:convert';

class RtoRecord {
  String id;
  String name;
  String fatherName;
  DateTime registrationDate;
  DateTime dob;
  String mobile;
  String rcNumber;
  double paidAmount;
  DateTime createdAt;
  String comments;

  RtoRecord({
    required this.id,
    required this.name,
    required this.fatherName,
    required this.registrationDate,
    required this.dob,
    required this.mobile,
    required this.rcNumber,
    required this.paidAmount,
    required this.createdAt,
    required this.comments,
  });

  factory RtoRecord.fromJson(Map<String, dynamic> json) => RtoRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    fatherName: json['fatherName'] as String,
    // registrationDate is optional in older backups; fall back to createdAt if missing
    registrationDate: json.containsKey('registrationDate')
        ? DateTime.parse(json['registrationDate'] as String)
        : DateTime.parse(json['createdAt'] as String),
    dob: DateTime.parse(json['dob'] as String),
    mobile: json['mobile'] as String,
    rcNumber: json['rcNumber'] as String,
    paidAmount: (json['paidAmount'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    comments: json['comments'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fatherName': fatherName,
    'registrationDate': registrationDate.toIso8601String(),
    'dob': dob.toIso8601String(),
    'mobile': mobile,
    'rcNumber': rcNumber,
    'paidAmount': paidAmount,
    'createdAt': createdAt.toIso8601String(),
    'comments': comments,
  };

  static List<RtoRecord> listFromJson(String jsonStr) {
    final data = json.decode(jsonStr) as List<dynamic>;
    return data
        .map((e) => RtoRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<RtoRecord> records) {
    final data = records.map((r) => r.toJson()).toList();
    return json.encode(data);
  }
}
