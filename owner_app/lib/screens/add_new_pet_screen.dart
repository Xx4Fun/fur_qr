import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class AddNewPetScreen extends StatelessWidget {
  const AddNewPetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Pet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pets,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.camera_alt,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        // Mock image picker
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const CustomTextField(
              labelText: 'Pet Name',
              hintText: 'e.g. Buddy',
            ),
            const CustomTextField(
              labelText: 'Breed',
              hintText: 'e.g. Golden Retriever',
            ),
            const CustomTextField(
              labelText: 'Public Notes / Medical Needs',
              hintText: 'e.g. Requires special diet...',
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Save Pet Profile',
              onPressed: () {
                // Mock save action
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}