import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/pet.dart';

class EditPetScreen extends StatefulWidget {
  final Pet pet;

  const EditPetScreen({super.key, required this.pet});

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _medicalNotesController;
  late final TextEditingController _markingsController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;

  String? _selectedType;
  String? _selectedGender;

  File? _imageFile;
  String? _existingPhotoUrl;
  bool _isLoading = false;

  final _picker = ImagePicker();
  final Color _primaryBlue = const Color(0xFF0047CC);

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;

    // Pre-populate controllers with existing pet data
    _nameController = TextEditingController(text: pet.name);
    _breedController = TextEditingController(text: pet.breed ?? '');
    _ageController = TextEditingController(text: pet.age ?? '');
    _weightController = TextEditingController(text: pet.weight ?? '');
    _medicalNotesController = TextEditingController(text: pet.medicalNotes ?? '');
    _markingsController = TextEditingController(text: pet.markings ?? '');
    _contactNameController = TextEditingController(text: pet.secondaryContactName ?? '');
    _contactPhoneController = TextEditingController(text: pet.secondaryContactPhone ?? '');

    _existingPhotoUrl = pet.photoUrl;

    // Match existing type / gender to dropdown options
    final genderOptions = ['Male', 'Female', 'Unknown'];

    // Attempt to derive type from attributes (stored in pet as string)
    // The add_pet_screen stores it in attributes['type']; it is not a top-level
    // field on the Pet Isar model, so we fall back to null gracefully.
    _selectedType = null;
    _selectedGender = genderOptions.contains(pet.gender) ? pet.gender : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _medicalNotesController.dispose();
    _markingsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pet's name is required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser!;
      final petId = widget.pet.supabaseId;

      if (petId == null) throw Exception('Pet has no Supabase ID');

      String? photoUrl = _existingPhotoUrl;

      // Upload new photo if one was selected
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

        await supabase.storage
            .from('pet_avatars')
            .upload(filePath, _imageFile!);
        photoUrl = supabase.storage
            .from('pet_avatars')
            .getPublicUrl(filePath);
      }

      // Build updated attributes map
      final attributes = <String, dynamic>{
        if (_selectedType != null) 'type': _selectedType,
        if (_breedController.text.isNotEmpty)
          'breed': _breedController.text.trim(),
        if (_ageController.text.isNotEmpty)
          'age': _ageController.text.trim(),
        if (_weightController.text.isNotEmpty)
          'weight': _weightController.text.trim(),
        if (_selectedGender != null) 'gender': _selectedGender,
        if (_medicalNotesController.text.isNotEmpty)
          'medical_notes': _medicalNotesController.text.trim(),
        if (_markingsController.text.isNotEmpty)
          'markings': _markingsController.text.trim(),
        if (_contactNameController.text.isNotEmpty)
          'secondary_contact_name': _contactNameController.text.trim(),
        if (_contactPhoneController.text.isNotEmpty)
          'secondary_contact_phone': _contactPhoneController.text.trim(),
      };

      // Rebuild public_notes from medical + markings
      String publicNotes = '';
      if (_medicalNotesController.text.isNotEmpty) {
        publicNotes += 'Medical: ${_medicalNotesController.text.trim()}\n';
      }
      if (_markingsController.text.isNotEmpty) {
        publicNotes += 'Markings: ${_markingsController.text.trim()}';
      }

      // Update Supabase
      await supabase.from('pets').update({
        'name': _nameController.text.trim(),
        'photo_url': photoUrl,
        'public_notes': publicNotes,
        'attributes': attributes,
      }).eq('id', petId);

      // Update local Isar cache
      await isar.writeTxn(() async {
        final localPet = widget.pet
          ..name = _nameController.text.trim()
          ..photoUrl = photoUrl
          ..publicNotes = publicNotes
          ..breed = _breedController.text.isNotEmpty
              ? _breedController.text.trim()
              : null
          ..age = _ageController.text.isNotEmpty
              ? _ageController.text.trim()
              : null
          ..weight = _weightController.text.isNotEmpty
              ? _weightController.text.trim()
              : null
          ..gender = _selectedGender
          ..medicalNotes = _medicalNotesController.text.isNotEmpty
              ? _medicalNotesController.text.trim()
              : null
          ..markings = _markingsController.text.isNotEmpty
              ? _markingsController.text.trim()
              : null
          ..secondaryContactName = _contactNameController.text.isNotEmpty
              ? _contactNameController.text.trim()
              : null
          ..secondaryContactPhone = _contactPhoneController.text.isNotEmpty
              ? _contactPhoneController.text.trim()
              : null
          ..lastSyncedAt = DateTime.now();
        await isar.pets.put(localPet);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully! 🐾'),
            backgroundColor: Color(0xFF0047CC),
          ),
        );
        // Return the updated pet to the detail screen
        Navigator.pop(context, widget.pet);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey.shade600)
          : null,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryBlue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which photo to show as preview
    ImageProvider? photoPreview;
    if (_imageFile != null) {
      photoPreview = FileImage(_imageFile!);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      photoPreview = NetworkImage(_existingPhotoUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: const CloseButton(color: Colors.black87),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit ${widget.pet.name}',
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header text
            const Text(
              "Update Pet Profile",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Edit your pet's details below to keep their profile up to date.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Main form card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Basic Information"),
                  const SizedBox(height: 24),

                  // Photo picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(
                                color: _primaryBlue.withOpacity(0.3),
                                width: 2,
                              ),
                              image: photoPreview != null
                                  ? DecorationImage(
                                      image: photoPreview,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: photoPreview == null
                                ? Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.grey.shade600,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Upload Photo",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                          // Edit overlay badge
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pet Name
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      "Pet's Name",
                      prefixIcon: Icons.pets,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Type dropdown
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Pet Type"),
                    value: _selectedType,
                    items: ['Dog', 'Cat', 'Bird', 'Other']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                  const SizedBox(height: 16),

                  // Breed
                  TextField(
                    controller: _breedController,
                    decoration: _inputDecoration("Breed (Optional)"),
                  ),
                  const SizedBox(height: 16),

                  // Age + Weight row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ageController,
                          decoration: _inputDecoration("Age (Years)"),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: _inputDecoration("Weight (lbs)"),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gender dropdown
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Gender"),
                    value: _selectedGender,
                    items: ['Male', 'Female', 'Unknown']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGender = v),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),

                  _buildSectionTitle("Details & Health"),
                  const SizedBox(height: 24),

                  // Medical Notes
                  TextField(
                    controller: _medicalNotesController,
                    maxLines: 3,
                    decoration:
                        _inputDecoration("Medical notes, allergies, or special needs...")
                            .copyWith(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40.0),
                        child: Icon(Icons.medical_information_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Markings / Quirks
                  TextField(
                    controller: _markingsController,
                    maxLines: 3,
                    decoration:
                        _inputDecoration("Distinctive markings or behavioral quirks...")
                            .copyWith(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40.0),
                        child: Icon(Icons.description_outlined),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),

                  _buildSectionTitle("Secondary Contact"),
                  const SizedBox(height: 8),
                  Text(
                    "In case we can't reach you, who should we call?",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _contactNameController,
                    decoration: _inputDecoration(
                      "Contact Name",
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _contactPhoneController,
                    decoration: _inputDecoration(
                      "Phone Number",
                      prefixIcon: Icons.phone_outlined,
                    ),
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                      label: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
