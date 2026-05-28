import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/pet.dart';
import '../services/fcm_service.dart';
import 'add_pet_screen.dart';
import 'pet_detail_screen.dart';
import '../widgets/responsive_layout.dart';

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
          .select('id, name, photo_url, public_notes, attributes, tags!inner(id)')
          .eq('owner_id', ownerId);

      // 2. Sync to Isar
      await isar.writeTxn(() async {
        await isar.pets.clear(); // Simple sync for this prototype: clear and rewrite
        
        for (var row in response) {
          final attrs = row['attributes'] as Map<String, dynamic>? ?? {};
          final pet = Pet()
            ..supabaseId = row['id']
            ..ownerId = ownerId
            ..name = row['name']
            ..photoUrl = row['photo_url']
            ..publicNotes = row['public_notes']
            ..tagId = (row['tags'] as List).isNotEmpty ? row['tags'][0]['id'] : null
            ..breed = attrs['breed']
            ..age = attrs['age']
            ..gender = attrs['gender']
            ..weight = attrs['weight']
            ..homeBase = attrs['home_base']
            ..medicalNotes = attrs['medical_notes']
            ..markings = attrs['markings']
            ..secondaryContactName = attrs['secondary_contact_name']
            ..secondaryContactPhone = attrs['secondary_contact_phone']
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

  Widget _buildPetCard(BuildContext context, Pet pet, {bool isGrid = false}) {
    final isProtected = pet.tagId != null;
    
    return Container(
      margin: isGrid 
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: const Color(0xFFEBEBEB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Section
          Stack(
            children: [
              Container(
                height: isGrid ? 140 : 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  color: Colors.grey.shade200,
                  image: pet.photoUrl != null 
                    ? DecorationImage(image: NetworkImage(pet.photoUrl!), fit: BoxFit.cover)
                    : null,
                ),
                child: pet.photoUrl == null 
                  ? const Icon(Icons.pets, size: 60, color: Colors.grey)
                  : null,
              ),
              if (isProtected)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Color(0xFF0047CC), size: 16),
                        const SizedBox(width: 4),
                        const Text('Protected', style: TextStyle(color: Color(0xFF0047CC), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
            ],
          ),
          
          // Details Section
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        pet.name, 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                        maxLines: 1,
                      ),
                    ),
                    if (pet.breed != null && pet.breed!.isNotEmpty)
                      const SizedBox(width: 8),
                    if (pet.breed != null && pet.breed!.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            pet.breed!, 
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 11, overflow: TextOverflow.ellipsis),
                            maxLines: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pet.homeBase ?? 'Unknown Location',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, overflow: TextOverflow.ellipsis),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PetDetailScreen(pet: pet)),
                      ).then((_) => _loadPets());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isWide(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF0047CC)),
                    const SizedBox(width: 8),
                    const Text(
                      'FindMyPaws', // Or PawTrace based on branding
                      style: TextStyle(color: Color(0xFF0047CC), fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPets,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        top: isWide ? 40.0 : 24.0,
                        bottom: 16.0,
                      ),
                      child: const Text(
                        "Your Companions",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ),
                  ),
                  if (_pets.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text("No pets added yet. Click + to add one!", style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    )
                  else if (ResponsiveLayout.isWide(context))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            final columns = ResponsiveLayout.isDesktop(context) ? 3 : 2;
                            final cardWidth = (totalWidth - (columns - 1) * 16) / columns;
                            
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _pets.map((pet) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: _buildPetCard(context, pet, isGrid: true),
                                );
                              }).toList(),
                            );
                          }
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pet = _pets[index];
                          return _buildPetCard(context, pet, isGrid: false);
                        },
                        childCount: _pets.length,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0047CC),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPetScreen()),
          );
          _loadPets(); // Refresh after adding
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}