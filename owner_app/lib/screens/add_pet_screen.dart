import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _markingsController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  
  String? _selectedType;
  String? _selectedGender;
  
  File? _imageFile;
  bool _isLoading = false;

  final _picker = ImagePicker();
  final Color _primaryBlue = const Color(0xFF0047CC);

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _savePet() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pet's Name is required")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser!;
      
      String? photoUrl;

      // 1. Upload Image (if selected)
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

        await supabase.storage.from('pet_avatars').upload(filePath, _imageFile!);
        photoUrl = supabase.storage.from('pet_avatars').getPublicUrl(filePath);
      }

      // Prepare attributes JSON
      final attributes = {
        if (_selectedType != null) 'type': _selectedType,
        if (_breedController.text.isNotEmpty) 'breed': _breedController.text.trim(),
        if (_ageController.text.isNotEmpty) 'age': _ageController.text.trim(),
        if (_selectedGender != null) 'gender': _selectedGender,
        if (_medicalNotesController.text.isNotEmpty) 'medical_notes': _medicalNotesController.text.trim(),
        if (_markingsController.text.isNotEmpty) 'markings': _markingsController.text.trim(),
        if (_contactNameController.text.isNotEmpty) 'secondary_contact_name': _contactNameController.text.trim(),
        if (_contactPhoneController.text.isNotEmpty) 'secondary_contact_phone': _contactPhoneController.text.trim(),
      };

      // Combine notes for public_notes
      String publicNotes = '';
      if (_medicalNotesController.text.isNotEmpty) {
        publicNotes += 'Medical: ${_medicalNotesController.text.trim()}\n';
      }
      if (_markingsController.text.isNotEmpty) {
        publicNotes += 'Markings: ${_markingsController.text.trim()}';
      }

      // 2. Insert Pet into DB
      final petResponse = await supabase.from('pets').insert({
        'owner_id': user.id,
        'name': _nameController.text.trim(),
        'photo_url': photoUrl,
        'public_notes': publicNotes,
        'attributes': attributes,
      }).select('id').single();

      final petId = petResponse['id'];

      // 3. Generate a Tag for the Pet
      await supabase.from('tags').insert({
        'pet_id': petId,
        'is_active': true,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade600) : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.pets, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'FindMyPaws',
                style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
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
            const Text(
              "Register a New Pet",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Add their details below to keep them safe in our community network.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Basic Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // Photo Upload
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                          image: _imageFile != null 
                            ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                            : null,
                        ),
                        child: _imageFile == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600, size: 32),
                                const SizedBox(height: 4),
                                Text("Upload Photo", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            )
                          : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration("Pet's Name", prefixIcon: Icons.pets),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Pet Type"),
                    value: _selectedType,
                    items: ['Dog', 'Cat', 'Bird', 'Other'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedType = newValue),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _breedController,
                    decoration: _inputDecoration("Breed (Optional)"),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _ageController,
                    decoration: _inputDecoration("Age (Years)"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Gender"),
                    value: _selectedGender,
                    items: ['Male', 'Female', 'Unknown'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedGender = newValue),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),
                  
                  const Text("Details & Health", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _medicalNotesController,
                    maxLines: 3,
                    decoration: _inputDecoration("Medical notes, allergies, or special needs...").copyWith(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40.0),
                        child: Icon(Icons.medical_information_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _markingsController,
                    maxLines: 3,
                    decoration: _inputDecoration("Distinctive markings or behavioral quirks...").copyWith(
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
                  
                  const Text("Secondary Contact", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("In case we can't reach you, who should we call?", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _contactNameController,
                    decoration: _inputDecoration("Contact Name", prefixIcon: Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _contactPhoneController,
                    decoration: _inputDecoration("Phone Number", prefixIcon: Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _savePet,
                      icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Complete Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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