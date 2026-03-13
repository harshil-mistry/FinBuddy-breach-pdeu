import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUserData;
  UserModel? get currentUserData => _currentUserData;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _checkAndCreateUserInFirestore(user);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    }
  }

  Future<void> _checkAndCreateUserInFirestore(User user) async {
    final DocumentReference userDoc = _firestore.collection('users').doc(user.uid);
    final DocumentSnapshot docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // First time login - create user document
      final newUser = UserModel(
        uid: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      await userDoc.set(newUser.toMap());
      _currentUserData = newUser;
    } else {
      // Update last login
      await userDoc.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      _currentUserData = UserModel.fromMap(docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
    }
  }

  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUserData = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _currentUserData = null;
    notifyListeners();
  }
}
