import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/responsive_layout.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _scans = [];
  bool _isLoading = true;
  int? _selectedScanIndex;

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  Future<void> _fetchScans() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch scan history with pet name and photo URL via join
      final response = await Supabase.instance.client
          .from('scans')
          .select('id, created_at, scan_location, lat, lng, tags!inner(pets!inner(name, photo_url, owner_id))')
          .eq('tags.pets.owner_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _scans = response;
        if (_scans.isNotEmpty) {
          if (_selectedScanIndex == null || _selectedScanIndex! >= _scans.length) {
            _selectedScanIndex = 0;
          }
        } else {
          _selectedScanIndex = null;
        }
      });
    } catch (e) {
      debugPrint("Error fetching scans: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    
    try {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        debugPrint("Could not launch maps");
      }
    } catch (e) {
      debugPrint("Error launching map: $e");
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(dateTime); // e.g. Monday, 4:30 PM
    } else {
      return DateFormat('MMM d, y h:mm a').format(dateTime); // e.g. May 27, 2026 4:30 PM
    }
  }

  bool _isRecent(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    return difference.inHours < 1; // Recent if less than 1 hour old
  }

  Widget _buildScanTile(dynamic scan, int index, bool isSelected) {
    final petName = scan['tags']['pets']['name'] ?? 'Pet';
    final petPhotoUrl = scan['tags']['pets']['photo_url'];
    final date = DateTime.parse(scan['created_at']).toLocal();
    final isRecent = _isRecent(date);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedScanIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF2563EB) 
                : const Color(0xFFEBEBEB),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isRecent 
                      ? const Color(0xFFDC2626) 
                      : const Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  image: petPhotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(petPhotoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: petPhotoUrl == null
                    ? const Icon(Icons.pets, size: 18, color: Color(0xFF94A3B8))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$petName Scanned",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getRelativeTime(date),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isRecent)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDC2626),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanDetail(dynamic scan) {
    final petName = scan['tags']['pets']['name'] ?? 'Pet';
    final petPhotoUrl = scan['tags']['pets']['photo_url'];
    final date = DateTime.parse(scan['created_at']).toLocal();
    final isRecent = _isRecent(date);
    final hasLocation = scan['lat'] != null && scan['lng'] != null;
    final formattedDate = DateFormat('EEEE, MMMM d, y • h:mm a').format(date);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isRecent ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                    width: 2.5,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: petPhotoUrl != null
                        ? DecorationImage(image: NetworkImage(petPhotoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: petPhotoUrl == null
                      ? const Icon(Icons.pets, size: 28, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRecent ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRecent ? 'RECENT ALERT' : 'ARCHIVED ALERT',
                        style: TextStyle(
                          color: isRecent ? const Color(0xFF991B1B) : const Color(0xFF1E40AF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCAN TIMESTAMP',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Icon(Icons.my_location_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GEOLOCATION COORDINATES',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation ? '${scan['lat']}, ${scan['lng']}' : 'No GPS coordinates recorded',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w600,
                        color: hasLocation ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: _MapGridPainter(),
                      ),
                    ),
                  ),
                  if (hasLocation)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on, 
                          color: Color(0xFFDC2626), 
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: const Text('Pet Scanned Here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      ],
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_off, 
                          color: Color(0xFF94A3B8), 
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'The finder did not share their location when scanning this tag.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        )
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          if (hasLocation)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openMap(scan['lat'], scan['lng']),
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('Open in Google Maps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isWide(context);

    Widget mainBody;
    if (_scans.isEmpty) {
      mainBody = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No alerts yet",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "When someone scans your pet's smart QR tag, you will receive an instant location alert right here!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isWide) {
      mainBody = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _scans.length,
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemBuilder: (context, index) {
                return _buildScanTile(_scans[index], index, index == _selectedScanIndex);
              },
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEBEBEB)),
          Expanded(
            flex: 6,
            child: _selectedScanIndex == null || _selectedScanIndex! >= _scans.length
                ? Center(
                    child: Text(
                      'Select an alert to view details',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 16,
                      ),
                    ),
                  )
                : _buildScanDetail(_scans[_selectedScanIndex!]),
          ),
        ],
      );
    } else {
      mainBody = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _scans.length,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemBuilder: (context, index) {
          final scan = _scans[index];
          final petName = scan['tags']['pets']['name'] ?? 'Pet';
          final petPhotoUrl = scan['tags']['pets']['photo_url'];
          final date = DateTime.parse(scan['created_at']).toLocal();
          final isRecent = _isRecent(date);
          final hasLocation = scan['lat'] != null && scan['lng'] != null;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFEBEBEB),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isRecent 
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            image: petPhotoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(petPhotoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: petPhotoUrl == null
                              ? const Icon(Icons.pets, size: 24, color: Color(0xFF94A3B8))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "$petName's tag was scanned!",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.01,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getRelativeTime(date),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRecent 
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 18),
                    Material(
                      color: isRecent 
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () => _openMap(scan['lat'], scan['lng']),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isRecent ? Icons.location_on : Icons.location_on_outlined,
                                color: isRecent ? Colors.white : const Color(0xFF0F172A),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "View on Map",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isRecent ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'My Alerts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF1D4ED8),
                  size: 28,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)))
          : RefreshIndicator(
              color: const Color(0xFF1D4ED8),
              onRefresh: _fetchScans,
              child: mainBody,
            ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;

    const int divisions = 15;
    final double stepX = size.width / divisions;
    final double stepY = size.height / divisions;

    for (int i = 1; i < divisions; i++) {
      canvas.drawLine(Offset(stepX * i, 0), Offset(stepX * i, size.height), paint);
      canvas.drawLine(Offset(0, stepY * i), Offset(size.width, stepY * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}