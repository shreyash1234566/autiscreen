import 'package:json_annotation/json_annotation.dart';

part 'child.g.dart';

enum ChildGender {
  @JsonValue('male')
  male,
  @JsonValue('female')
  female,
  @JsonValue('other')
  other
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Child {
  final String id;
  final String name;
  final int ageMonths; // stored in months for precision
  final ChildGender gender;
  final String language; // 'en' or 'hi'
  final String? doctorId;
  final DateTime createdAt;

  const Child({
    required this.id,
    required this.name,
    required this.ageMonths,
    required this.gender,
    required this.language,
    this.doctorId,
    required this.createdAt,
  });

  factory Child.fromJson(Map<String, dynamic> json) => _$ChildFromJson(json);
  Map<String, dynamic> toJson() => _$ChildToJson(this);

  // M-CHAT-R is used for 16-30 months; INDT-ASD for older children
  bool get useMchatR => ageMonths >= 16 && ageMonths <= 30;
  bool get useIndtAsd => ageMonths > 30;
}
