import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/pet.dart';

class PetDetailScreen extends StatelessWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    // The live web view deployed to Firebase Hosting
    final String tagUrl = 'https://fur-qr-project.web.app/tag.html?id=${pet.tagId}';

    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (pet.photoUrl != null)
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(pet.photoUrl!),
              ),
            const SizedBox(height: 24),
            const Text(
              "Your Pet's Smart Tag",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Print this QR code and attach it to your pet's collar. Anyone who scans it can view their public profile and notify you.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (pet.tagId != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: tagUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              )
            else
              const Text("No active tag found for this pet.", style: TextStyle(color: Colors.red)),
              
            const SizedBox(height: 32),
            Text("Public Notes: ${pet.publicNotes ?? 'None'}"),
          ],
        ),
      ),
    );
  }
}