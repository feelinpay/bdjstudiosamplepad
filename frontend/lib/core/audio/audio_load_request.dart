class AudioLoadRequest {
  final String id;
  final String path;
  final bool needsRandomAccess;

  const AudioLoadRequest({
    required this.id,
    required this.path,
    this.needsRandomAccess = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioLoadRequest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path &&
          needsRandomAccess == other.needsRandomAccess;

  @override
  int get hashCode => Object.hash(id, path, needsRandomAccess);

  @override
  String toString() =>
      'AudioLoadRequest(id: $id, path: $path, needsRandomAccess: $needsRandomAccess)';
}
