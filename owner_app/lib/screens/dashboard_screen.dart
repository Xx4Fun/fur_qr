import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/pet.dart';
import '../services/fcm_service.dart';
import 'add_pet_screen.dart';
import 'pet_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Pet> _pets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize FCM when the user reaches the dashboard (logged in)
    FCMService.instance.init();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch from Supabase
      final ownerId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('pets')
          .select('id, name, photo_url, public_notes, tags!inner(id)')
          .eq('owner_id', ownerId);

      // 2. Sync to Isar
      await isar.writeTxn(() async {
        await isar.pets.clear(); // Simple sync for this prototype: clear and rewrite
        
        for (var row in response) {
          final pet = Pet()
            ..supabaseId = row['id']
            ..name = row['name']
            ..photoUrl = row['photo_url']
            ..publicNotes = row['public_notes']
            ..tagId = (row['tags'] as List).isNotEmpty ? row['tags'][0]['id'] : null
            ..lastSyncedAt = DateTime.now();
            
          await isar.pets.put(pet);
        }
      });

      // 3. Load from Isar to UI
      _pets = await isar.pets.where().findAll();
    } catch (e) {
      debugPrint("Error loading pets: $e");
      // Fallback: Load local data if offline
      _pets = await isar.pets.where().findAll();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
              ? const Center(child: Text("No pets added yet. Click + to add one!"))
              : ListView.builder(
                  itemCount: _pets.length,
                  itemBuilder: (context, index) {
                    final pet = _pets[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: pet.photoUrl != null 
                          ? NetworkImage(pet.photoUrl!) 
                          : null,
                        child: pet.photoUrl == null ? const Icon(Icons.pets) : null,
                      ),
                      title: Text(pet.name),
                      subtitle: Text(pet.tagId != null ? 'Tag Active' : 'No Tag'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PetDetailScreen(pet: pet)),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPetScreen()),
          );
          _loadPets(); // Refresh after adding
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}