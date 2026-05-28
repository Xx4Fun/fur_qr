import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';
import '../widgets/responsive_layout.dart';
import 'edit_pet_screen.dart';

class PetDetailScreen extends StatefulWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  final Color _primaryBlue = const Color(0xFF0047CC);
  
  Map<String, dynamic>? _ownerData;
  String? _userEmail;
  late Pet _pet;

  // Key used to capture QR widget as PNG for download
  final GlobalKey _qrKey = GlobalKey();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _fetchOwnerInfo();
  }

  Future<void> _fetchOwnerInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _userEmail = user.email;
        final data = await Supabase.instance.client
            .from('owners')
            .select('full_name, phone_number')
            .eq('id', user.id)
            .single();
            
        if (mounted) {
          setState(() {
            _ownerData = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner info: $e');
    }
  }

  /// Renders the QR code to PNG bytes using QrPainter and saves to gallery.
  Future<void> _downloadQr() async {
    if (_pet.tagId == null) return;

    setState(() => _isDownloading = true);

    try {
      final String tagUrl =
          'https://fur-qr-project.web.app/tag.html?id=${_pet.tagId}';

      // Use QrPainter to render a 1024×1024 QR image off-screen
      final painter = QrPainter(
        data: tagUrl,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black87,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.circle,
          color: Colors.black54,
        ),
        gapless: false,
      );

      const double size = 1024.0;
      const double padding = 64.0; // Quiet zone for scanners
      final double qrSize = size - (padding * 2);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // White background for the entire image
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );

      // Shift the canvas to create the quiet zone and paint the QR code
      canvas.translate(padding, padding);
      painter.paint(canvas, Size(qrSize, qrSize));

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image =
          await picture.toImage(size.toInt(), size.toInt());
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to device gallery
      await Gal.putImageBytes(pngBytes,
          name: '${_pet.name}_QR_Tag');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code saved to gallery! 📲'),
            backgroundColor: _primaryBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildDetailItem(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value == null || value.isEmpty ? 'Not specified' : value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final String tagUrl = 'https://fur-qr-project.web.app/tag.html?id=${pet.tagId}';
    final isWide = ResponsiveLayout.isWide(context);

    // 1. Hero Image Card
    final heroImageCard = Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.shade300,
        image: pet.photoUrl != null 
          ? DecorationImage(image: NetworkImage(pet.photoUrl!), fit: BoxFit.cover)
          : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Stack(
        children: [
          if (pet.photoUrl == null)
            const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
          
          // Gradient overlay at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
          ),
          
          // Text overlay
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pet.homeBase ?? 'Unknown Location',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          
          // Badge
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('Safe at Home', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );

    // 2. Details Grid Card
    final detailsGridCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('Breed', pet.breed)),
              Expanded(child: _buildDetailItem('Age', pet.age != null ? '${pet.age} Years' : null)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Weight', pet.weight != null ? '${pet.weight} lbs' : null)),
              Expanded(child: _buildDetailItem('Gender', pet.gender)),
            ],
          ),
        ],
      ),
    );

    // 3. Digital Tag Card
    final digitalTagCard = pet.tagId != null
        ? Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text("${pet.name}'s Digital Tag", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "Scan this QR code with any smartphone camera to instantly view ${pet.name}'s contact info.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: QrImageView(
                      data: tagUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadQr,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    label: Text(
                      _isDownloading ? 'Saving...' : 'Download QR for Tag',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                )
              ],
            ),
          )
        : const SizedBox.shrink();

    // 4. Owner Contact Card
    final ownerContactCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text("OWNER CONTACT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFF7A1A),
                radius: 20,
                child: Text(
                  _ownerData?['full_name']?.substring(0, 1).toUpperCase() ?? 'O',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ownerData?['full_name'] ?? 'Loading...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text('Primary Owner', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, color: Color(0xFF0047CC), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ownerData?['phone_number'] ?? 'Not provided',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: Color(0xFF0047CC), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _userEmail ?? 'Loading...',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0047CC)),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "${pet.name}'s Profile",
            style: const TextStyle(color: Color(0xFF0047CC), fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Edit Pet',
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0047CC)),
            onPressed: () async {
              final updatedPet = await Navigator.push<Pet>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPetScreen(pet: _pet),
                ),
              );
              if (updatedPet != null && mounted) {
                setState(() => _pet = updatedPet);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        heroImageCard,
                        if (pet.tagId != null) const SizedBox(height: 24),
                        digitalTagCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        detailsGridCard,
                        const SizedBox(height: 24),
                        ownerContactCard,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  heroImageCard,
                  const SizedBox(height: 24),
                  detailsGridCard,
                  if (pet.tagId != null) const SizedBox(height: 24),
                  digitalTagCard,
                  const SizedBox(height: 24),
                  ownerContactCard,
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}