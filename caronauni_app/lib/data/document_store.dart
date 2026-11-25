typedef Json = Map<String, dynamic>;

class Document {
  const Document(this.id, this.data);

  final String id;
  final Json data;
}

/// Leituras primeiro, depois escritas, como o Firestore exige.
abstract class StoreTransaction {
  Future<Json?> get(String path);

  void set(String path, Json data);

  void update(String path, Json data);
}

/// Banco de documentos. As regras de negócio dependem só deste contrato, e
/// por isso valem igual no Firestore e na demonstração em memória.
abstract class DocumentStore {
  Future<Json?> get(String path);

  Future<void> set(String path, Json data);

  Future<void> update(String path, Json data);

  Future<void> delete(String path);

  Future<List<Document>> query(
    String collection, {
    Json where = const {},
    String? atLeastField,
    int? atLeast,
    int limit = 100,
  });

  Future<T> transaction<T>(Future<T> Function(StoreTransaction tx) body);
}

class MemoryStore implements DocumentStore {
  final Map<String, Json> _docs = {};

  @override
  Future<Json?> get(String path) async {
    final data = _docs[path];
    return data == null ? null : Json.of(data);
  }

  @override
  Future<void> set(String path, Json data) async => _docs[path] = Json.of(data);

  @override
  Future<void> update(String path, Json data) async {
    final current = _docs[path];
    if (current == null) throw StateError('Documento inexistente: $path');
    _docs[path] = {...current, ...data};
  }

  @override
  Future<void> delete(String path) async => _docs.remove(path);

  @override
  Future<List<Document>> query(
    String collection, {
    Json where = const {},
    String? atLeastField,
    int? atLeast,
    int limit = 100,
  }) async {
    final prefix = '$collection/';
    final result = [
      for (final entry in _docs.entries)
        if (entry.key.startsWith(prefix) &&
            !entry.key.substring(prefix.length).contains('/') &&
            where.entries.every((w) => entry.value[w.key] == w.value) &&
            (atLeastField == null ||
                (entry.value[atLeastField] as int) >= atLeast!))
          Document(entry.key.substring(prefix.length), Json.of(entry.value)),
    ];
    if (atLeastField != null) {
      result.sort(
        (a, b) =>
            (a.data[atLeastField] as int).compareTo(b.data[atLeastField] as int),
      );
    }
    return result.take(limit).toList();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(StoreTransaction tx) body,
  ) async {
    final tx = _MemoryTransaction(this);
    final result = await body(tx);
    for (final write in tx.writes) {
      await write();
    }
    return result;
  }
}

class _MemoryTransaction implements StoreTransaction {
  _MemoryTransaction(this._store);

  final MemoryStore _store;
  final List<Future<void> Function()> writes = [];

  @override
  Future<Json?> get(String path) => _store.get(path);

  @override
  void set(String path, Json data) => writes.add(() => _store.set(path, data));

  @override
  void update(String path, Json data) =>
      writes.add(() => _store.update(path, data));
}
