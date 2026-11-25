import 'package:cloud_firestore/cloud_firestore.dart';

import 'document_store.dart';

class FirestoreStore implements DocumentStore {
  FirestoreStore(this._db);

  final FirebaseFirestore _db;

  @override
  Future<Json?> get(String path) async => (await _db.doc(path).get()).data();

  @override
  Future<void> set(String path, Json data) => _db.doc(path).set(data);

  @override
  Future<void> update(String path, Json data) => _db.doc(path).update(data);

  @override
  Future<void> delete(String path) => _db.doc(path).delete();

  @override
  Future<List<Document>> query(
    String collection, {
    Json where = const {},
    String? atLeastField,
    int? atLeast,
    int limit = 100,
  }) async {
    Query<Json> query = _db.collection(collection);
    for (final entry in where.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
    if (atLeastField != null) {
      query = query
          .where(atLeastField, isGreaterThanOrEqualTo: atLeast)
          .orderBy(atLeastField);
    }
    final snapshot = await query.limit(limit).get();
    return [for (final doc in snapshot.docs) Document(doc.id, doc.data())];
  }

  @override
  Future<T> transaction<T>(Future<T> Function(StoreTransaction tx) body) =>
      _db.runTransaction((tx) => body(_FirestoreTransaction(_db, tx)));
}

class _FirestoreTransaction implements StoreTransaction {
  _FirestoreTransaction(this._db, this._tx);

  final FirebaseFirestore _db;
  final Transaction _tx;

  @override
  Future<Json?> get(String path) async => (await _tx.get(_db.doc(path))).data();

  @override
  void set(String path, Json data) => _tx.set(_db.doc(path), data);

  @override
  void update(String path, Json data) => _tx.update(_db.doc(path), data);
}
