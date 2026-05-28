import 'package:flutter/material.dart';
import '../widgets/pet_list_card.dart';
import '../widgets/primary_button.dart';
import 'add_new_pet_screen.dart';
import 'pet_profile_detail_screen.dart';

class MyPetsListScreen extends StatelessWidget {
  const MyPetsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock data
    final pets = [
      {'name': 'Buddy', 'breed': 'Golden Retriever'},
      {'name': 'Luna', 'breed': 'Siamese Cat'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: pets.isEmpty
                  ? Center(
                      child: Text(
                        "You haven't added any pets yet.",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: pets.length,
                      itemBuilder: (context, index) {
                        final pet = pets[index];
                        return PetListCard(
                          name: pet['name']!,
                          breed: pet['breed']!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PetProfileDetailScreen(
                                  name: pet['name']!,
                                  breed: pet['breed']!,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Add New Pet',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddNewPetScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}