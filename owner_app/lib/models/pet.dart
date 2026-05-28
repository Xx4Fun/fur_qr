import 'package:isar/isar.dart';

part 'pet.g.dart';

@collection
class Pet {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String supabaseId; // UUID from Supabase

  late String name;
  
  String? photoUrl;
  
  String? publicNotes;
  
  String? tagId; // UUID from Supabase Tags table

  // To easily sync with Supabase
  DateTime? lastSyncedAt;
}