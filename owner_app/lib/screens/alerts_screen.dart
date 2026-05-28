import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _scans = [];
  bool _isLoading = true;

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

      // Join scans -> tags -> pets to get the pet name and scan time
      final response = await Supabase.instance.client
          .from('scans')
          .select('id, created_at, scan_location, lat, lng, tags!inner(pets!inner(name, owner_id))')
          .eq('tags.pets.owner_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _scans = response;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchScans,
          )
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _scans.isEmpty
            ? const Center(child: Text("No scans recorded yet."))
            : ListView.builder(
                itemCount: _scans.length,
                itemBuilder: (context, index) {
                  final scan = _scans[index];
                  final petName = scan['tags']['pets']['name'];
                  final date = DateTime.parse(scan['created_at']).toLocal();
                  final formattedDate = DateFormat('MMM d, y h:mm a').format(date);
                  final hasLocation = scan['lat'] != null && scan['lng'] != null;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                      ),
                      title: Text("$petName was scanned!"),
                      subtitle: Text(formattedDate),
                      trailing: hasLocation 
                        ? IconButton(
                            icon: const Icon(Icons.map, color: Colors.indigo),
                            onPressed: () => _openMap(scan['lat'], scan['lng']),
                          )
                        : const Icon(Icons.location_off, color: Colors.grey),
                    ),
                  );
                },
              ),
    );
  }
}