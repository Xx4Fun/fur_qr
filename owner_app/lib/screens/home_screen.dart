import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pet.dart';
import '../main.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _petCount = 0;
  int _alertCount = 0;
  String _ownerName = '';
  List<dynamic> _recentScans = [];
  bool _isLoading = true;

  final Color _primaryBlue = const Color(0xFF0047CC);
  final Color _primaryOrange = const Color(0xFFFF7A1A);

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Local pet count
      final petsCount = await isar.pets.count();
      
      // Get Owner Name
      final ownerRes = await Supabase.instance.client
          .from('owners')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      String firstName = 'Fur Parent';
      if (ownerRes != null && ownerRes['full_name'] != null) {
        String fullName = ownerRes['full_name'];
        firstName = fullName.split(' ').first;
      }
      
      // Remote alert count and recent scans
      final scansRes = await Supabase.instance.client
          .from('scans')
          .select('id, created_at, lat, lng, tags!inner(pets!inner(name, photo_url, owner_id))')
          .eq('tags.pets.owner_id', user.id)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _petCount = petsCount;
          _alertCount = scansRes.length;
          _ownerName = firstName;
          _recentScans = scansRes.take(5).toList(); // Show top 5 recent scans
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading home summary: $e');
    }
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    try {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint("Error launching map: $e");
    }
  }

  Widget _buildAlertCard(BuildContext context, dynamic scan, {bool isHorizontal = true}) {
    final pet = scan['tags']['pets'];
    final hasLocation = scan['lat'] != null && scan['lng'] != null;
    final date = DateTime.parse(scan['created_at']).toLocal();
    final timeStr = DateFormat('h:mm a, MMM d').format(date);

    if (isHorizontal) {
      return Container(
        width: 240,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    color: Colors.grey.shade200,
                    image: pet['photo_url'] != null 
                      ? DecorationImage(image: NetworkImage(pet['photo_url']), fit: BoxFit.cover)
                      : null,
                  ),
                  child: pet['photo_url'] == null 
                    ? const Icon(Icons.pets, size: 40, color: Colors.grey)
                    : null,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('SCANNED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                )
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet['name'] ?? 'Unknown Pet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(child: Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasLocation ? () => _openMap(scan['lat'], scan['lng']) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(hasLocation ? 'View Location' : 'No Location', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFFEBEBEB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                color: Colors.grey.shade200,
                image: pet['photo_url'] != null 
                  ? DecorationImage(image: NetworkImage(pet['photo_url']), fit: BoxFit.cover)
                  : null,
              ),
              child: pet['photo_url'] == null 
                ? const Icon(Icons.pets, size: 30, color: Colors.grey)
                : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pet['name'] ?? 'Unknown Pet', 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('SCANNED', style: TextStyle(color: _primaryOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(child: Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: hasLocation ? () => _openMap(scan['lat'], scan['lng']) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasLocation ? _primaryBlue.withOpacity(0.1) : Colors.grey.shade100,
                          foregroundColor: hasLocation ? _primaryBlue : Colors.grey.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                        child: Text(hasLocation ? 'View Map' : 'No Location', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isWide(context);

    // Left column content
    final List<Widget> leftContent = [
      Text(
        "Hello, $_ownerName!",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "Ready to keep your furry friends safe today?",
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 24),
      
      GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Missing Pet feature coming soon!')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: _primaryOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryOrange.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('URGENT ACTION', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Report Missing Pet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ],
          ),
        ),
      ),
      const SizedBox(height: 32),
      
      const Text("My Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _OverviewCard(
              title: "Pets Protected",
              count: _petCount.toString(),
              icon: Icons.pets,
              color: _primaryBlue,
              showBottomBar: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _OverviewCard(
              title: "Community Scans Nearby",
              count: _alertCount.toString(),
              icon: Icons.people_outline,
              color: Colors.blue.shade300,
              showBottomBar: false,
            ),
          ),
        ],
      ),
    ];

    // Right column content
    final List<Widget> rightContent = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Recent Alerts", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () {}, // Handled by bottom nav / navigation rail normally
            child: Text("See All ➔", style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      
      if (_recentScans.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(
            child: Text("No tags scanned yet. Everything looks good!", style: TextStyle(color: Colors.grey)),
          ),
        )
      else
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentScans.length,
            itemBuilder: (context, index) {
              return _buildAlertCard(context, _recentScans[index], isHorizontal: true);
            },
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              elevation: 0,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, color: _primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'PawTrace',
                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(Icons.account_circle_outlined, color: _primaryBlue),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadSummary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                bottom: 20.0,
                top: isWide ? 40.0 : 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...leftContent,
                      const SizedBox(height: 32),
                      ...rightContent,
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final bool showBottomBar;

  const _OverviewCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.showBottomBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 13)),
          if (showBottomBar) ...[
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          ]
        ],
      ),
    );
  }
}