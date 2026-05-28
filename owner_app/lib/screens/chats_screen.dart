import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Query conversations -> tags -> pets to get conversations for pets owned by current user
      // Also fetch messages to show the last message snippet
      final response = await Supabase.instance.client
          .from('conversations')
          .select('id, tag_id, is_active, created_at, tags!inner(id, pets!inner(name, photo_url, owner_id)), messages(content, created_at)')
          .eq('tags.pets.owner_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _conversations = response;
      });
    } catch (e) {
      debugPrint("Error fetching conversations: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveConversation(String conversationId, String petName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mark Pet as Found?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete the conversation and message history regarding $petName to protect the finder\'s privacy.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Yes, Found!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Cascade delete the conversation (will delete all messages)
        await Supabase.instance.client
            .from('conversations')
            .delete()
            .eq('id', conversationId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Conversation resolved! Glad $petName is safe.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        _fetchConversations();
      } catch (e) {
        debugPrint("Error resolving conversation: $e");
      }
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours h ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Messages',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF1D4ED8),
                  size: 28,
                ),
                onPressed: _fetchConversations,
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)))
          : RefreshIndicator(
              color: const Color(0xFF1D4ED8),
              onRefresh: _fetchConversations,
              child: _conversations.isEmpty
                  ? ListView(
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
                                  Icons.chat_bubble_outline_rounded,
                                  color: Color(0xFF1D4ED8),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "No messages yet",
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
                                  "Active chats with finders of your lost pets will appear here.",
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
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _conversations.length,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final pet = conv['tags']['pets'];
                        final petName = pet['name'] ?? 'Pet';
                        final petPhotoUrl = pet['photo_url'];
                        final messages = conv['messages'] as List? ?? [];
                        
                        // Sort messages locally by creation time to get the last message
                        if (messages.isNotEmpty) {
                          messages.sort((a, b) => a['created_at'].compareTo(b['created_at']));
                        }
                        
                        final lastMessageContent = messages.isNotEmpty 
                            ? messages.last['content'] 
                            : 'Conversation started...';
                        
                        final lastMessageTimeStr = messages.isNotEmpty 
                            ? messages.last['created_at'] 
                            : conv['created_at'];
                            
                        final relativeTime = _getRelativeTime(DateTime.parse(lastMessageTimeStr).toLocal());

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEBEBEB),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    conversationId: conv['id'],
                                    petName: petName,
                                  ),
                                ),
                              );
                              _fetchConversations();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Pet Avatar
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: petPhotoUrl != null
                                          ? Image.network(petPhotoUrl, fit: BoxFit.cover)
                                          : const Icon(Icons.pets, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Text details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Finder of $petName",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              relativeTime,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          lastMessageContent,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Action dropdown / menu
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    onSelected: (value) {
                                      if (value == 'resolve') {
                                        _resolveConversation(conv['id'], petName);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'resolve',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Mark as Found',
                                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
