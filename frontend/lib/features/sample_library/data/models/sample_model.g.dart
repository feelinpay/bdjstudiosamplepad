// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSampleModelCollection on Isar {
  IsarCollection<SampleModel> get sampleModels => this.collection();
}

const SampleModelSchema = CollectionSchema(
  name: r'SampleModel',
  id: 8082775318194892889,
  properties: {
    r'bpm': PropertySchema(id: 0, name: r'bpm', type: IsarType.double),
    r'durationInSeconds': PropertySchema(
      id: 1,
      name: r'durationInSeconds',
      type: IsarType.double,
    ),
    r'extension': PropertySchema(
      id: 2,
      name: r'extension',
      type: IsarType.string,
    ),
    r'importedAt': PropertySchema(
      id: 3,
      name: r'importedAt',
      type: IsarType.dateTime,
    ),
    r'isFavorite': PropertySchema(
      id: 4,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'lastUsedAt': PropertySchema(
      id: 5,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 6, name: r'name', type: IsarType.string),
    r'path': PropertySchema(id: 7, name: r'path', type: IsarType.string),
    r'sizeInBytes': PropertySchema(
      id: 8,
      name: r'sizeInBytes',
      type: IsarType.long,
    ),
    r'tags': PropertySchema(id: 9, name: r'tags', type: IsarType.stringList),
    r'useCount': PropertySchema(id: 10, name: r'useCount', type: IsarType.long),
    r'waveformPath': PropertySchema(
      id: 11,
      name: r'waveformPath',
      type: IsarType.string,
    ),
  },
  estimateSize: _sampleModelEstimateSize,
  serialize: _sampleModelSerialize,
  deserialize: _sampleModelDeserialize,
  deserializeProp: _sampleModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'path': IndexSchema(
      id: 8756705481922369689,
      name: r'path',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'path',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'isFavorite': IndexSchema(
      id: 5742774614603939776,
      name: r'isFavorite',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isFavorite',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'bpm': IndexSchema(
      id: -467211772103288797,
      name: r'bpm',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'bpm',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'tags': IndexSchema(
      id: 4029205728550669204,
      name: r'tags',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'tags',
          type: IndexType.hashElements,
          caseSensitive: true,
        ),
      ],
    ),
    r'lastUsedAt': IndexSchema(
      id: 458483797936957613,
      name: r'lastUsedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastUsedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'useCount': IndexSchema(
      id: 7410387838542085084,
      name: r'useCount',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'useCount',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {
    r'genre': LinkSchema(
      id: -5299532555810961420,
      name: r'genre',
      target: r'GenreModel',
      single: true,
    ),
    r'folder': LinkSchema(
      id: -3973125127570686016,
      name: r'folder',
      target: r'FolderModel',
      single: true,
    ),
  },
  embeddedSchemas: {},
  getId: _sampleModelGetId,
  getLinks: _sampleModelGetLinks,
  attach: _sampleModelAttach,
  version: '3.1.0+1',
);

int _sampleModelEstimateSize(
  SampleModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.extension.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.path.length * 3;
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.waveformPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _sampleModelSerialize(
  SampleModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.bpm);
  writer.writeDouble(offsets[1], object.durationInSeconds);
  writer.writeString(offsets[2], object.extension);
  writer.writeDateTime(offsets[3], object.importedAt);
  writer.writeBool(offsets[4], object.isFavorite);
  writer.writeDateTime(offsets[5], object.lastUsedAt);
  writer.writeString(offsets[6], object.name);
  writer.writeString(offsets[7], object.path);
  writer.writeLong(offsets[8], object.sizeInBytes);
  writer.writeStringList(offsets[9], object.tags);
  writer.writeLong(offsets[10], object.useCount);
  writer.writeString(offsets[11], object.waveformPath);
}

SampleModel _sampleModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SampleModel();
  object.bpm = reader.readDoubleOrNull(offsets[0]);
  object.durationInSeconds = reader.readDoubleOrNull(offsets[1]);
  object.extension = reader.readString(offsets[2]);
  object.id = id;
  object.importedAt = reader.readDateTime(offsets[3]);
  object.isFavorite = reader.readBool(offsets[4]);
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[5]);
  object.name = reader.readString(offsets[6]);
  object.path = reader.readString(offsets[7]);
  object.sizeInBytes = reader.readLong(offsets[8]);
  object.tags = reader.readStringList(offsets[9]) ?? [];
  object.useCount = reader.readLong(offsets[10]);
  object.waveformPath = reader.readStringOrNull(offsets[11]);
  return object;
}

P _sampleModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readStringList(offset) ?? []) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sampleModelGetId(SampleModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sampleModelGetLinks(SampleModel object) {
  return [object.genre, object.folder];
}

void _sampleModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  SampleModel object,
) {
  object.id = id;
  object.genre.attach(col, col.isar.collection<GenreModel>(), r'genre', id);
  object.folder.attach(col, col.isar.collection<FolderModel>(), r'folder', id);
}

extension SampleModelByIndex on IsarCollection<SampleModel> {
  Future<SampleModel?> getByPath(String path) {
    return getByIndex(r'path', [path]);
  }

  SampleModel? getByPathSync(String path) {
    return getByIndexSync(r'path', [path]);
  }

  Future<bool> deleteByPath(String path) {
    return deleteByIndex(r'path', [path]);
  }

  bool deleteByPathSync(String path) {
    return deleteByIndexSync(r'path', [path]);
  }

  Future<List<SampleModel?>> getAllByPath(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return getAllByIndex(r'path', values);
  }

  List<SampleModel?> getAllByPathSync(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'path', values);
  }

  Future<int> deleteAllByPath(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'path', values);
  }

  int deleteAllByPathSync(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'path', values);
  }

  Future<Id> putByPath(SampleModel object) {
    return putByIndex(r'path', object);
  }

  Id putByPathSync(SampleModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'path', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPath(List<SampleModel> objects) {
    return putAllByIndex(r'path', objects);
  }

  List<Id> putAllByPathSync(
    List<SampleModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'path', objects, saveLinks: saveLinks);
  }
}

extension SampleModelQueryWhereSort
    on QueryBuilder<SampleModel, SampleModel, QWhere> {
  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'name'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isFavorite'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyBpm() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bpm'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhere> anyUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'useCount'),
      );
    });
  }
}

extension SampleModelQueryWhere
    on QueryBuilder<SampleModel, SampleModel, QWhereClause> {
  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> pathEqualTo(
    String path,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'path', value: [path]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> pathNotEqualTo(
    String path,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [],
                upper: [path],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [path],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [path],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [],
                upper: [path],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: [name]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameNotEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameGreaterThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [name],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameLessThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [],
          upper: [name],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameBetween(
    String lowerName,
    String upperName, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [lowerName],
          includeLower: includeLower,
          upper: [upperName],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameStartsWith(
    String NamePrefix,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [NamePrefix],
          upper: ['$NamePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: ['']),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'name', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'name', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'name', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'name', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> isFavoriteEqualTo(
    bool isFavorite,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isFavorite', value: [isFavorite]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause>
  isFavoriteNotEqualTo(bool isFavorite) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [],
                upper: [isFavorite],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [isFavorite],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [isFavorite],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [],
                upper: [isFavorite],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'bpm', value: [null]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'bpm',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmEqualTo(
    double? bpm,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'bpm', value: [bpm]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmNotEqualTo(
    double? bpm,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bpm',
                lower: [],
                upper: [bpm],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bpm',
                lower: [bpm],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bpm',
                lower: [bpm],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bpm',
                lower: [],
                upper: [bpm],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmGreaterThan(
    double? bpm, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'bpm',
          lower: [bpm],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmLessThan(
    double? bpm, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'bpm',
          lower: [],
          upper: [bpm],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> bpmBetween(
    double? lowerBpm,
    double? upperBpm, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'bpm',
          lower: [lowerBpm],
          includeLower: includeLower,
          upper: [upperBpm],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> tagsElementEqualTo(
    String tagsElement,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'tags', value: [tagsElement]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause>
  tagsElementNotEqualTo(String tagsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'tags',
                lower: [],
                upper: [tagsElement],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'tags',
                lower: [tagsElement],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'tags',
                lower: [tagsElement],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'tags',
                lower: [],
                upper: [tagsElement],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'lastUsedAt', value: [null]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause>
  lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastUsedAt',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> lastUsedAtEqualTo(
    DateTime? lastUsedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'lastUsedAt', value: [lastUsedAt]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause>
  lastUsedAtNotEqualTo(DateTime? lastUsedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastUsedAt',
                lower: [],
                upper: [lastUsedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastUsedAt',
                lower: [lastUsedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastUsedAt',
                lower: [lastUsedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastUsedAt',
                lower: [],
                upper: [lastUsedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause>
  lastUsedAtGreaterThan(DateTime? lastUsedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastUsedAt',
          lower: [lastUsedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> lastUsedAtLessThan(
    DateTime? lastUsedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastUsedAt',
          lower: [],
          upper: [lastUsedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> lastUsedAtBetween(
    DateTime? lowerLastUsedAt,
    DateTime? upperLastUsedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastUsedAt',
          lower: [lowerLastUsedAt],
          includeLower: includeLower,
          upper: [upperLastUsedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> useCountEqualTo(
    int useCount,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'useCount', value: [useCount]),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> useCountNotEqualTo(
    int useCount,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'useCount',
                lower: [],
                upper: [useCount],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'useCount',
                lower: [useCount],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'useCount',
                lower: [useCount],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'useCount',
                lower: [],
                upper: [useCount],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> useCountGreaterThan(
    int useCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'useCount',
          lower: [useCount],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> useCountLessThan(
    int useCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'useCount',
          lower: [],
          upper: [useCount],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterWhereClause> useCountBetween(
    int lowerUseCount,
    int upperUseCount, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'useCount',
          lower: [lowerUseCount],
          includeLower: includeLower,
          upper: [upperUseCount],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SampleModelQueryFilter
    on QueryBuilder<SampleModel, SampleModel, QFilterCondition> {
  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bpm'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bpm'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bpm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bpm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bpm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> bpmBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bpm',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'durationInSeconds'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'durationInSeconds'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'durationInSeconds',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'durationInSeconds',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'durationInSeconds',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  durationInSecondsBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'durationInSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'extension',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'extension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'extension',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'extension', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  extensionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'extension', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  importedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'importedAt', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  importedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'importedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  importedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'importedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  importedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'importedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  isFavoriteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFavorite', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUsedAt', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUsedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'path',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'path',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> pathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  pathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  sizeInBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sizeInBytes', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  sizeInBytesGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sizeInBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  sizeInBytesLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sizeInBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  sizeInBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sizeInBytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tags',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tags',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, true, length, true);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, 0, true);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, false, 999999, true);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, length, include);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, include, 999999, true);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> useCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'useCount', value: value),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  useCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  useCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> useCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'useCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'waveformPath'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'waveformPath'),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'waveformPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'waveformPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'waveformPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'waveformPath', value: ''),
      );
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition>
  waveformPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'waveformPath', value: ''),
      );
    });
  }
}

extension SampleModelQueryObject
    on QueryBuilder<SampleModel, SampleModel, QFilterCondition> {}

extension SampleModelQueryLinks
    on QueryBuilder<SampleModel, SampleModel, QFilterCondition> {
  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> genre(
    FilterQuery<GenreModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'genre');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> genreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'genre', 0, true, 0, true);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> folder(
    FilterQuery<FolderModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'folder');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterFilterCondition> folderIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'folder', 0, true, 0, true);
    });
  }
}

extension SampleModelQuerySortBy
    on QueryBuilder<SampleModel, SampleModel, QSortBy> {
  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByBpm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bpm', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByBpmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bpm', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  sortByDurationInSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationInSeconds', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  sortByDurationInSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationInSeconds', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByExtension() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extension', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByExtensionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extension', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByImportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importedAt', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByImportedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importedAt', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortBySizeInBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeInBytes', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortBySizeInBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeInBytes', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> sortByWaveformPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveformPath', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  sortByWaveformPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveformPath', Sort.desc);
    });
  }
}

extension SampleModelQuerySortThenBy
    on QueryBuilder<SampleModel, SampleModel, QSortThenBy> {
  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByBpm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bpm', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByBpmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bpm', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  thenByDurationInSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationInSeconds', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  thenByDurationInSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationInSeconds', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByExtension() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extension', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByExtensionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'extension', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByImportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importedAt', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByImportedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importedAt', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenBySizeInBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeInBytes', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenBySizeInBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeInBytes', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy> thenByWaveformPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveformPath', Sort.asc);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QAfterSortBy>
  thenByWaveformPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveformPath', Sort.desc);
    });
  }
}

extension SampleModelQueryWhereDistinct
    on QueryBuilder<SampleModel, SampleModel, QDistinct> {
  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByBpm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bpm');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct>
  distinctByDurationInSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationInSeconds');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByExtension({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'extension', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByImportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'importedAt');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'path', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctBySizeInBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sizeInBytes');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useCount');
    });
  }

  QueryBuilder<SampleModel, SampleModel, QDistinct> distinctByWaveformPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'waveformPath', caseSensitive: caseSensitive);
    });
  }
}

extension SampleModelQueryProperty
    on QueryBuilder<SampleModel, SampleModel, QQueryProperty> {
  QueryBuilder<SampleModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SampleModel, double?, QQueryOperations> bpmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bpm');
    });
  }

  QueryBuilder<SampleModel, double?, QQueryOperations>
  durationInSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationInSeconds');
    });
  }

  QueryBuilder<SampleModel, String, QQueryOperations> extensionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'extension');
    });
  }

  QueryBuilder<SampleModel, DateTime, QQueryOperations> importedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'importedAt');
    });
  }

  QueryBuilder<SampleModel, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<SampleModel, DateTime?, QQueryOperations> lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<SampleModel, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<SampleModel, String, QQueryOperations> pathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'path');
    });
  }

  QueryBuilder<SampleModel, int, QQueryOperations> sizeInBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sizeInBytes');
    });
  }

  QueryBuilder<SampleModel, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<SampleModel, int, QQueryOperations> useCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useCount');
    });
  }

  QueryBuilder<SampleModel, String?, QQueryOperations> waveformPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'waveformPath');
    });
  }
}
