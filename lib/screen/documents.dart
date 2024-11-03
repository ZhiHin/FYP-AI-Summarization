import 'package:flutter/material.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0), // Adjust the top padding
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                // Implement document upload functionality
              },
              child: const Text("Upload Document"),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your Documents",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10), // Optional spacing between title and list
            Expanded(
              child: ListView.builder(
                itemCount: 10, // Replace with actual document count
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text("Document ${index + 1}"),
                    subtitle: Text("Last modified: ${DateTime.now()}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        // Implement delete functionality
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
