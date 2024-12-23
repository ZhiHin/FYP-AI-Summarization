import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromptModel {
  Future<void> savePromptToFirebase(List<String> imageUrls,
      List<String> promptTexts, String promptName) async {
    // Save the prompt to Firebase
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }
    try {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc();
      await docRef.set({
        'promptName': promptName,
        'imageUrls': imageUrls,
        'promptTexts': promptTexts,
        'timestamp': FieldValue.serverTimestamp(),
      });
      DocumentReference promptHistoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('promptHistory')
          .doc();

      await promptHistoryRef.set({
        'promptId': docRef.id,
        'updatedTexts': promptTexts,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Prompt and initial edit history saved successfully');
    } catch (e) {
      print('Error saving prompt: $e');
    }
  }

  Future<void> updatePromptInFirebase(
      String promptId, List<String> promptTexts) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }
    try {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc(promptId);

      await docRef.update({'promptTexts': promptTexts});
      DocumentReference promptHistoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('promptHistory')
          .doc();

      await promptHistoryRef.set({
        'promptId': promptId,
        'updatedTexts': promptTexts,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Prompt updated successfully');
    } catch (e) {
      print('Error updating prompt: $e');
    }
  }

  Future<void> updatePromptNameInFirebase(
      String promptId, String promptName) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPrompts() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return [];
    }

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['promptId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching prompt history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPromptHistory(String promptId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return [];
    }
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('promptHistory')
          .where('promptId', isEqualTo: promptId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['promptId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error retrieving prompts: $e');
      return [];
    }
  }
}
