import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../utils/constants.dart';

/// Manages real-time user presence (online / offline / last seen) using the
/// Firebase Realtime Database.
///
/// The Realtime Database is preferred over Firestore for presence because it
/// provides the [onDisconnect] hook, which fires server-side even when the
/// client loses connectivity unexpectedly.
class PresenceService {
  PresenceService({
    FirebaseDatabase? database,
    FirebaseFirestore? firestore,
  })  : _db = database ?? FirebaseDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseDatabase _db;
  final FirebaseFirestore _firestore;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Marks [userId] as online in the Realtime Database and registers an
  /// [onDisconnect] handler that automatically marks them offline.
  ///
  /// Call this when the user opens the app / chat.
  Future<void> goOnline(String userId) async {
    final ref = _userRef(userId);
    final now = ServerValue.timestamp;

    // Register what happens when the connection drops.
    await ref.onDisconnect().update({
      'isOnline': false,
      'lastSeen': now,
    });

    // Mark as online now.
    await ref.update({
      'isOnline': true,
      'lastSeen': now,
    });

    // Mirror to Firestore so other services can read it without RTDB access.
    await _mirrorToFirestore(userId, isOnline: true);
  }

  /// Cancels the [onDisconnect] handler and immediately marks [userId] as
  /// offline.
  ///
  /// Call this on app lifecycle pause / logout.
  Future<void> goOffline(String userId) async {
    final ref = _userRef(userId);
    await ref.onDisconnect().cancel();
    await ref.update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
    await _mirrorToFirestore(userId, isOnline: false);
  }

  /// Configures automatic online → offline transition using [onDisconnect].
  ///
  /// This is the primary method to call on app start for a user session. It
  /// combines [goOnline] with the disconnect listener and also wires up a
  /// `.info/connected` listener so the online state is restored after
  /// reconnects.
  Future<void> setupPresenceListener(String userId) async {
    final connectedRef = _db.ref('.info/connected');

    connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      // (Re)establish online state and onDisconnect on every reconnect.
      await goOnline(userId);
    });
  }

  /// Stream that emits `true` when [userId] is online and `false` otherwise.
  Stream<bool> getUserPresenceStream(String userId) {
    return _userRef(userId).child('isOnline').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Updates the [lastSeen] timestamp for [userId] without changing the
  /// online status. Useful for periodic activity heartbeats.
  Future<void> updateLastSeen(String userId) async {
    await _userRef(userId).update({'lastSeen': ServerValue.timestamp});

    await _firestore
        .collection(ChatCollections.users)
        .doc(userId)
        .update({ChatFields.lastSeen: FieldValue.serverTimestamp()});
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  DatabaseReference _userRef(String userId) =>
      _db.ref(PresencePaths.forUser(userId));

  /// Mirrors the online/offline state to the Firestore [ChatCollections.users]
  /// document so the rest of the app can use Firestore listeners instead of
  /// RTDB listeners.
  Future<void> _mirrorToFirestore(String userId, {required bool isOnline}) {
    return _firestore
        .collection(ChatCollections.users)
        .doc(userId)
        .set(
          {
            ChatFields.isOnline: isOnline,
            ChatFields.lastSeen: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }
}
