import 'package:isar/isar.dart';

part 'pet.g.dart';

@collection
class Pet {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? supabaseId;

  String? ownerId;
  String name = '';
  
  String? photoUrl;
  
  String? publicNotes;
  
  String? tagId; // UUID from Supabase Tags table

  // New fields from JSONB attributes
  String? breed;
  String? age;
  String? gender;
  String? weight;
  String? homeBase;
  String? medicalNotes;
  String? markings;
  String? secondaryContactName;
  String? secondaryContactPhone;

  // To easily sync with Supabase
  DateTime? lastSyncedAt;
}