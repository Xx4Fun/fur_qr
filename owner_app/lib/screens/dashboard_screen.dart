import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/pet.dart';
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
  bool _isDeleteMode = false;
  bool _isMenuOpen = false;
  final Set<String> _selectedPetIds = {};

  @override
  void initState() {
    super.initState();
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

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedPetIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove $count Pet(s)?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the $count selected pet(s)? This will permanently remove their details, active QR code tags, and scans history.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Delete selected pets from Supabase
        await Supabase.instance.client
            .from('pets')
            .delete()
            .inFilter('id', _selectedPetIds.toList());

        // Refresh list
        await _loadPets();

        setState(() {
          _isDeleteMode = false;
          _selectedPetIds.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully removed $count pet(s)!')),
          );
        }
      } catch (e) {
        debugPrint("Error deleting pets: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove pets: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPetCard(BuildContext context, Pet pet, {bool isGrid = false}) {
    final isProtected = pet.tagId != null;
    final isSelected = _selectedPetIds.contains(pet.supabaseId);
    
    return GestureDetector(
      onTap: _isDeleteMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedPetIds.remove(pet.supabaseId);
                } else {
                  _selectedPetIds.add(pet.supabaseId!);
                }
              });
            }
          : null,
      child: Container(
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
                  ),
                if (_isDeleteMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.redAccent : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.redAccent : Colors.grey.shade400, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isSelected ? Icons.check : null,
                          size: 14,
                          color: Colors.white,
                        ),
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
                    onPressed: _isDeleteMode
                        ? () {
                            setState(() {
                              if (isSelected) {
                                _selectedPetIds.remove(pet.supabaseId);
                              } else {
                                _selectedPetIds.add(pet.supabaseId!);
                              }
                            });
                          }
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PetDetailScreen(pet: pet)),
                            ).then((_) => _loadPets());
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDeleteMode
                          ? (isSelected ? Colors.redAccent.withOpacity(0.1) : Colors.grey.shade100)
                          : Colors.grey.shade100,
                      foregroundColor: _isDeleteMode
                          ? (isSelected ? Colors.redAccent : Colors.black87)
                          : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _isDeleteMode
                          ? (isSelected ? 'Selected' : 'Select')
                          : 'View Profile',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSpeedDialItem({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: const CircleBorder(),
          onPressed: onTap,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isDeleteMode) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isMenuOpen) ...[
          _buildSpeedDialItem(
            label: 'Add Pet',
            icon: Icons.add,
            backgroundColor: const Color(0xFF0047CC),
            onTap: () async {
              setState(() => _isMenuOpen = false);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPetScreen()),
              );
              _loadPets();
            },
          ),
          const SizedBox(height: 12),
          _buildSpeedDialItem(
            label: 'Remove Pet',
            icon: Icons.delete_outline,
            backgroundColor: Colors.redAccent,
            onTap: () {
              setState(() {
                _isMenuOpen = false;
                _isDeleteMode = true;
                _selectedPetIds.clear();
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          backgroundColor: _isMenuOpen ? Colors.grey.shade800 : const Color(0xFF0047CC),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          onPressed: () {
            setState(() {
              _isMenuOpen = !_isMenuOpen;
            });
          },
          child: Icon(_isMenuOpen ? Icons.close : Icons.edit, size: 24),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _isDeleteMode
          ? AppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _isDeleteMode = false;
                    _selectedPetIds.clear();
                  });
                },
              ),
              title: Text(
                'Remove Companions (${_selectedPetIds.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedPetIds.length == _pets.length) {
                        _selectedPetIds.clear();
                      } else {
                        _selectedPetIds.addAll(_pets.map((p) => p.supabaseId!));
                      }
                    });
                  },
                  child: Text(
                    _selectedPetIds.length == _pets.length ? 'Deselect All' : 'Select All',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFF9FAFB),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Companions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: GestureDetector(
        onTap: _isMenuOpen
            ? () {
                setState(() {
                  _isMenuOpen = false;
                });
              }
            : null,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPets,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 16),
                    ),
                    if (_pets.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text("No pets added yet.", style: TextStyle(color: Colors.grey.shade600)),
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
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _isDeleteMode
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isDeleteMode = false;
                            _selectedPetIds.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedPetIds.isEmpty ? null : _confirmDeleteSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.redAccent.withOpacity(0.4),
                          disabledForegroundColor: Colors.white.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Remove Selected (${_selectedPetIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}