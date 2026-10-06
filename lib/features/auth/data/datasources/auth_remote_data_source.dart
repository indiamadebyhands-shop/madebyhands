import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:madebyhands/features/auth/data/models/user_model.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';

abstract interface class AuthRemoteDataSource {
  Future<UserModel?> signInWithGoogle();

  /// Signs in as a fresh guest buyer without Google or role selection. Only
  /// offered while `kTestBuyerLoginEnabled` is on.
  Future<UserModel> signInAsTestBuyer();
  Future<UserModel> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  });

  /// The signed-in user's profile, or null when nobody is signed in.
  Future<UserModel?> getCurrentUserData();
  Future<UserModel> updateProfile({
    required String uid,
    required String name,
    required String phone,
  });
  Future<void> deleteAccount(String uid, String reason);
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;
  final GoogleSignIn googleSignIn;
  final FirebaseStorage storage;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
    required this.googleSignIn,
    required this.storage,
  });

  UserModel _userFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final storedUid = data['uid'] as String?;
    return UserModel.fromJson({
      ...data,
      'uid': storedUid == null || storedUid.isEmpty ? doc.id : storedUid,
    });
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          'Google did not return sign-in credentials. Please try again.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) return null;

      final email = user.email ?? '';
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return _userFromDocument(userDoc);
      }
      if (UserEntity.presetSuperAdminEmails.contains(email.toLowerCase())) {
        // Preset administrators get their profile created on first sign-in.
        return await signUpWithRole(
          uid: user.uid,
          email: email,
          name: user.displayName ?? 'Admin',
          phone: '',
          role: 'admin',
        );
      }
      // An empty role sends the user to role selection.
      return UserModel(
        uid: user.uid,
        email: email,
        name: user.displayName ?? '',
        role: '',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Google sign-in failed. Please try again.');
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel> signInAsTestBuyer() async {
    final UserCredential credential;
    try {
      credential = await firebaseAuth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed' ||
          e.code == 'admin-restricted-operation') {
        throw Exception(
          'Test sign-in is not switched on for this project yet.',
        );
      }
      throw Exception(e.message ?? 'Test sign-in failed. Please try again.');
    }
    final user = credential.user;
    if (user == null) {
      throw Exception('Test sign-in failed. Please try again.');
    }

    // A returning guest (same browser, still signed in) keeps their profile.
    final reference = firestore.collection('users').doc(user.uid);
    final existing = await reference.get();
    if (existing.exists && existing.data() != null) {
      return _userFromDocument(existing);
    }
    final profile = UserModel(
      uid: user.uid,
      email: '',
      name: 'Test Buyer',
      role: 'buyer',
    );
    // isTestAccount marks the document so guests are easy to find and
    // delete once the review is over.
    await reference.set({...profile.toJson(), 'isTestAccount': true});
    return profile;
  }

  @override
  Future<UserModel> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    final reference = firestore.collection('users').doc(uid);
    final existing = await reference.get();
    if (existing.exists && existing.data() != null) {
      await reference.update({'name': name, 'email': email, 'phone': phone});
      return UserModel.fromJson({
        ..._userFromDocument(existing).toJson(),
        'name': name,
        'email': email,
        'phone': phone,
      });
    }
    final userModel = UserModel(
      uid: uid,
      email: email,
      name: name,
      phone: phone,
      role: role,
    );
    await reference.set(userModel.toJson());
    return userModel;
  }

  @override
  Future<UserModel?> getCurrentUserData() async {
    // On web the persisted session is restored asynchronously, so
    // currentUser can be null for a moment after start-up.
    final user =
        firebaseAuth.currentUser ??
        await firebaseAuth
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
    if (user == null) return null;

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      return _userFromDocument(userDoc);
    }
    // Signed in with Firebase but no profile yet: ask for a role.
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
      role: '',
    );
  }

  @override
  Future<UserModel> updateProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final reference = firestore.collection('users').doc(uid);
    await reference.update({'name': name.trim(), 'phone': phone.trim()});
    if (firebaseAuth.currentUser?.uid == uid) {
      await firebaseAuth.currentUser?.updateDisplayName(name.trim());
    }
    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('User profile not found.');
    }
    return _userFromDocument(snapshot);
  }

  @override
  Future<void> deleteAccount(String uid, String reason) async {
    final currentUser = firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      throw Exception('Please sign in again before deleting your account.');
    }
    // Firebase only deletes accounts that signed in recently. Checking first
    // avoids wiping the user's data and then failing to delete the login.
    final lastSignIn = currentUser.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > const Duration(minutes: 4)) {
      throw Exception(
        'For your security, sign out and sign in again, then delete your account.',
      );
    }

    final userDoc = await firestore.collection('users').doc(uid).get();
    final role = (userDoc.data()?['role'] as String? ?? '').toLowerCase();

    // Record why they left before wiping their data. This is a one-way,
    // write-only log for the platform's own records; the account itself is
    // still deleted immediately rather than waiting on any review.
    try {
      await firestore.collection('account_deletions').add({
        'uid': uid,
        'email': userDoc.data()?['email'] ?? currentUser.email ?? '',
        'role': role,
        'reason': reason.trim(),
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Could not record account-deletion reason: $error');
    }

    if (role == 'creator' || role == 'seller') {
      await _deleteQuietly(firestore.collection('creator_profiles').doc(uid));
      await _deleteQuietly(firestore.collection('creator_verifications').doc(uid));
      await _deleteQuietly(firestore.collection('creator_bank_accounts').doc(uid));
      await _deleteQuery(
        firestore.collection('products').where('creatorUid', isEqualTo: uid),
      );
      await _deleteQuery(
        firestore.collection('notifications').where('creatorUid', isEqualTo: uid),
      );
      await _deleteStorageFolder(storage.ref('creator_profiles/$uid'));
      await _deleteStorageFolder(storage.ref('products/$uid'));
    }
    await _deleteQuery(
      firestore.collection('users').doc(uid).collection('favorites'),
    );
    await _deleteQuery(
      firestore.collection('users').doc(uid).collection('addresses'),
    );
    await firestore.collection('users').doc(uid).delete();

    try {
      await currentUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For your security, sign out and sign in again, then delete your account.',
        );
      }
      throw Exception(e.message ?? 'Your account could not be deleted.');
    }
    try {
      await googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> _deleteQuietly(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (error) {
      debugPrint('Account cleanup skipped ${ref.path}: $error');
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        await _deleteQuietly(doc.reference);
      }
    } catch (error) {
      debugPrint('Account cleanup query failed: $error');
    }
  }

  Future<void> _deleteStorageFolder(Reference folder) async {
    try {
      final listing = await folder.listAll();
      for (final item in listing.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
      for (final prefix in listing.prefixes) {
        await _deleteStorageFolder(prefix);
      }
    } catch (error) {
      debugPrint('Storage cleanup skipped ${folder.fullPath}: $error');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
    } catch (_) {
      // Google may already be signed out; Firebase sign-out still matters.
    }
    await firebaseAuth.signOut();
  }
}
