import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _ownerData;
  bool _isLoading = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('owners')
          .select('full_name, phone_number, address, avatar_url, created_at')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _ownerData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadProfilePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (image == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${user.id}/$fileName';

      await Supabase.instance.client.storage.from('pet_avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final imageUrl = Supabase.instance.client.storage.from('pet_avatars').getPublicUrl(filePath);

      await Supabase.instance.client.from('owners').update({
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      // Refresh
      await _loadProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading picture: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _ownerData?['full_name'] ?? '');
    final phoneController = TextEditingController(text: _ownerData?['phone_number'] ?? '');
    final addressController = TextEditingController(text: _ownerData?['address'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      try {
                        await Supabase.instance.client.from('owners').update({
                          'full_name': nameController.text.trim(),
                          'phone_number': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                        }).eq('id', user.id);
                        
                        if (mounted) {
                          Navigator.pop(context);
                          _loadProfile();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                        }
                      } catch (e) {
                        debugPrint('Error updating profile: $e');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setStateDialog(() => isSaving = false);
                      }
                    }
                  },
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setStateDialog(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final currentPass = currentPasswordController.text;
                    final newPass = newPasswordController.text;
                    if (currentPass.isEmpty || newPass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in both fields.')));
                      return;
                    }
                    if (newPass.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters.')));
                      return;
                    }

                    setStateDialog(() => isSaving = true);
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user?.email != null) {
                      try {
                        // Verify current password by signing in again
                        await Supabase.instance.client.auth.signInWithPassword(
                          email: user!.email!,
                          password: currentPass,
                        );
                        
                        // Update to new password
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPass),
                        );
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!')));
                        }
                      } on AuthException catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        setStateDialog(() => isSaving = false);
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setStateDialog(() => isSaving = false);
                      }
                    } else {
                       setStateDialog(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF0047CC),
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubscriptionCard() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PawTrace Pro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0047CC),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0047CC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF0047CC),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Renews on Oct 15, 2024',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription is active and managed via App Store.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0047CC),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Manage Subscription',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool pushEnabled = true;
        bool emailEnabled = true;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Notifications'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive alerts when tag is scanned'),
                    value: pushEnabled,
                    onChanged: (val) => setStateDialog(() => pushEnabled = val),
                    activeColor: const Color(0xFF0047CC),
                  ),
                  SwitchListTile(
                    title: const Text('Email Summary'),
                    subtitle: const Text('Weekly status of scanned pets'),
                    value: emailEnabled,
                    onChanged: (val) => setStateDialog(() => emailEnabled = val),
                    activeColor: const Color(0xFF0047CC),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool biometricEnabled = true;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Security & Privacy'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Biometric Login'),
                    subtitle: const Text('Unlock app with Fingerprint/Face ID'),
                    value: biometricEnabled,
                    onChanged: (val) => setStateDialog(() => biometricEnabled = val),
                    activeColor: const Color(0xFF0047CC),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                trailing: const Icon(Icons.check, color: Color(0xFF0047CC)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                title: const Text('Español'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language support coming soon!')));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SupabaseService.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isWide = ResponsiveLayout.isWide(context);
    

    // Profile summary widget (Avatar, name, email, edit button)
    final profileIdentitySection = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _uploadProfilePicture,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _ownerData?['avatar_url'] != null
                    ? NetworkImage(_ownerData!['avatar_url'])
                    : null,
                child: _ownerData?['avatar_url'] == null
                    ? const Icon(Icons.person, size: 56, color: Colors.grey)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF0047CC),
                  child: _isUploading 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _ownerData?['full_name'] ?? 'Pet Owner',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? 'Loading email...',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _showEditProfileDialog,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0047CC),
            side: const BorderSide(color: Color(0xFF0047CC), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    );

    // Account settings card
    final accountSettingsCard = Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.person_outline,
            title: 'Personal Information',
            onTap: _showEditProfileDialog,
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.lock_open_outlined,
            title: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.shield_outlined,
            title: 'Security',
            onTap: _showSecurityDialog,
          ),
        ],
      ),
    );

    // App settings card
    final appSettingsCard = Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications',
            onTap: _showNotificationsDialog,
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.verified_user_outlined,
            title: 'Privacy & Data',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy Policy details coming soon!')),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.language_outlined,
            title: 'Language',
            trailingText: 'English',
            onTap: _showLanguageDialog,
          ),
        ],
      ),
    );

    // Support and Info card
    final supportCard = Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.help_outline_outlined,
            title: 'Help Center',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help Center features coming soon!')),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.mail_outline_outlined,
            title: 'Contact Us',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support email: support@pawtrace.com')),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'About PawTrace',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'PawTrace',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.pets, color: Color(0xFF0047CC)),
                children: [
                  const Text('PawTrace is a privacy-first smart pet tag system designed to keep pets safe and owners connected.'),
                ],
              );
            },
          ),
        ],
      ),
    );

    // Logout Action Button
    final logoutButton = TextButton.icon(
      onPressed: () => _showLogoutConfirmation(context),
      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
      label: const Text(
        'Log Out',
        style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Profile',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              centerTitle: true,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: isWide ? 40.0 : 16.0,
                ),
                child: isWide
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left column
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        profileIdentitySection,
                                        const SizedBox(height: 32),
                                        _buildSectionHeader('Subscription'),
                                        _buildSubscriptionCard(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  // Right column
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader('Account Settings'),
                                        accountSettingsCard,
                                        const SizedBox(height: 16),
                                        _buildSectionHeader('App Settings'),
                                        appSettingsCard,
                                        const SizedBox(height: 16),
                                        _buildSectionHeader('Support & Info'),
                                        supportCard,
                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Center(child: profileIdentitySection),
                          const SizedBox(height: 24),
                          
                          _buildSectionHeader('Account Settings'),
                          accountSettingsCard,
                          
                          const SizedBox(height: 16),
                          _buildSectionHeader('Subscription'),
                          _buildSubscriptionCard(),
                          
                          const SizedBox(height: 16),
                          _buildSectionHeader('App Settings'),
                          appSettingsCard,
                          
                          const SizedBox(height: 16),
                          _buildSectionHeader('Support & Info'),
                          supportCard,
                          
                          const SizedBox(height: 32),
                          Center(child: logoutButton),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ),
    );
  }
}