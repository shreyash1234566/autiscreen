// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'child.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Child _$ChildFromJson(Map<String, dynamic> json) => Child(
      id: json['id'] as String,
      name: json['name'] as String,
      ageMonths: (json['age_months'] as num).toInt(),
      gender: $enumDecode(_$ChildGenderEnumMap, json['gender']),
      language: json['language'] as String,
      doctorId: json['doctor_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ChildToJson(Child instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'age_months': instance.ageMonths,
      'gender': _$ChildGenderEnumMap[instance.gender]!,
      'language': instance.language,
      'doctor_id': instance.doctorId,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$ChildGenderEnumMap = {
  ChildGender.male: 'male',
  ChildGender.female: 'female',
  ChildGender.other: 'other',
};
