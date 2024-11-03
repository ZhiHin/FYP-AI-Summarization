import 'package:flutter/material.dart';
import 'privacy_policy_page.dart'; // Import the new Privacy Policy Page

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulate user information
    String userName = "JohnDoe"; // Replace with actual user data
    String email = "john.doe@example.com"; // Replace with actual user data
    // ignore: unused_local_variable
    String phone = "+123 456 7890"; // Replace with actual user data
    // ignore: unused_local_variable
    String address = "123 Main St, City, Country"; // Replace with actual user data
    // ignore: unused_local_variable
    String encryptedPassword = "********"; // Placeholder for encrypted password

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: SingleChildScrollView( // Allow scrolling if content overflows
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50, // Size of the avatar
                  backgroundColor: Colors.grey, // Color when there is no image
                  child: Icon(Icons.person, size: 50, color: Colors.white), // Icon to represent user
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userName, // Display user's full name
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                email, // Display user's email
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "User Information",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      ListTile(
                        title: Text("Password:"),
                        subtitle: Text("********"), // Display encrypted password as asterisks
                      ),
                      ListTile(
                        title: Text("Phone:"),
                        subtitle: Text("+123 456 7890"), // Display phone number
                      ),
                      ListTile(
                        title: Text("Address:"),
                        subtitle: Text("123 Main St, City, Country"), // Display address
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Settings",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        title: const Text("Privacy Policy"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                      ),
                      const ListTile(
                        title: Text("Notifications"),
                        onTap: null, // Implement notifications settings
                      ),
                      const ListTile(
                        title: Text("Change Password"),
                        onTap: null, // Implement change password functionality
                      ),
                      const ListTile(
                        title: Text("Logout"),
                        onTap: null, // Implement logout functionality
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Implement edit profile functionality
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Full width button
                ),
                child: const Text("Edit Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
