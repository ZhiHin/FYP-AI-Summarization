import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromptModel {
  Future<void> savePromptToFirebase(List<String> imageUrls,
      List<String> promptTexts, String promptName, String type) async {
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
        'fileUrls': imageUrls,
        'promptTexts': promptTexts,
        'type': type,
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

  Future<Map<String, dynamic>> fetchText(String promptId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return {};
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc(promptId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['promptId'] = doc.id;
        return data;
      } else {
        print('Prompt not found');
        return {};
      }
    } catch (e) {
      print('Error fetching prompt: $e');
      return {};
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
        data['promptId'] = promptId;
        return data;
      }).toList();
    } catch (e) {
      print('Error retrieving prompts: $e');
      return [];
    }
  }

  Future<void> deletePrompt(String promptId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc(promptId)
          .delete();

      QuerySnapshot historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('promptHistory')
          .where('promptId', isEqualTo: promptId)
          .get();
      for (DocumentSnapshot doc in historySnapshot.docs) {
        await doc.reference.delete();
      }
      print('Prompt deleted successfully');
    } catch (e) {
      print('Error deleting prompt: $e');
    }
  }

  Future<void> restorePrompt(
      String promptId, List<String> promptTexts, Timestamp date) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }
    try {
      print(promptId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc(promptId)
          .update({'promptTexts': promptTexts});

      QuerySnapshot historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('promptHistory')
          .where('promptId', isEqualTo: promptId)
          .where('timestamp', isGreaterThan: date)
          .get();

      for (DocumentSnapshot doc in historySnapshot.docs) {
        await doc.reference.delete();
      }
      print('Prompt deleted successfully');
    } catch (e) {
      print('Error deleting prompt: $e');
    }
  }

  Future<void> renamePrompt(String promptId, String newName) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('prompts')
        .doc(promptId)
        .update({'promptName': newName});
  }
}
