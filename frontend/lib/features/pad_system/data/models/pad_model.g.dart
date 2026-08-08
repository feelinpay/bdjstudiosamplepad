// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pad_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPadModelCollection on Isar {
  IsarCollection<PadModel> get padModels => this.collection();
}

const PadModelSchema = CollectionSchema(
  name: r'PadModel',
  id: -7987301834297399416,
  properties: {
    r'backgroundImagePath': PropertySchema(
      id: 0,
      name: r'backgroundImagePath',
      type: IsarType.string,
    ),
    r'chokeGroup': PropertySchema(
      id: 1,
      name: r'chokeGroup',
      type: IsarType.long,
    ),
    r'colorHex': PropertySchema(id: 2, name: r'colorHex', type: IsarType.long),
    r'endPointMs': PropertySchema(
      id: 3,
      name: r'endPointMs',
      type: IsarType.long,
    ),
    r'fadeInMs': PropertySchema(id: 4, name: r'fadeInMs', type: IsarType.long),
    r'fadeOutMs': PropertySchema(
      id: 5,
      name: r'fadeOutMs',
      type: IsarType.long,
    ),
    r'height': PropertySchema(id: 6, name: r'height', type: IsarType.double),
    r'isProtected': PropertySchema(
      id: 7,
      name: r'isProtected',
      type: IsarType.bool,
    ),
    r'label': PropertySchema(id: 8, name: r'label', type: IsarType.string),
    r'loopPointMs': PropertySchema(
      id: 9,
      name: r'loopPointMs',
      type: IsarType.long,
    ),
    r'padId': PropertySchema(id: 10, name: r'padId', type: IsarType.long),
    r'padTypeIndex': PropertySchema(
      id: 11,
      name: r'padTypeIndex',
      type: IsarType.long,
    ),
    r'pan': PropertySchema(id: 12, name: r'pan', type: IsarType.double),
    r'pitch': PropertySchema(id: 13, name: r'pitch', type: IsarType.double),
    r'reverse': PropertySchema(id: 14, name: r'reverse', type: IsarType.bool),
    r'samplePath': PropertySchema(
      id: 15,
      name: r'samplePath',
      type: IsarType.string,
    ),
    r'startPointMs': PropertySchema(
      id: 16,
      name: r'startPointMs',
      type: IsarType.long,
    ),
    r'targetMacroId': PropertySchema(
      id: 17,
      name: r'targetMacroId',
      type: IsarType.long,
    ),
    r'targetPageIndex': PropertySchema(
      id: 18,
      name: r'targetPageIndex',
      type: IsarType.long,
    ),
    r'triggerModeIndex': PropertySchema(
      id: 19,
      name: r'triggerModeIndex',
      type: IsarType.long,
    ),
    r'volume': PropertySchema(id: 23, name: r'volume', type: IsarType.double),
    r'width': PropertySchema(id: 20, name: r'width', type: IsarType.double),
    r'x': PropertySchema(id: 21, name: r'x', type: IsarType.double),
    r'y': PropertySchema(id: 22, name: r'y', type: IsarType.double),
  },
  estimateSize: _padModelEstimateSize,
  serialize: _padModelSerialize,
  deserialize: _padModelDeserialize,
  deserializeProp: _padModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'padId': IndexSchema(
      id: -8265528190320324444,
      name: r'padId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'padId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {
    r'sample': LinkSchema(
      id: 3456667657499294320,
      name: r'sample',
      target: r'SampleModel',
      single: true,
    ),
    r'page': LinkSchema(
      id: -8366280172691359732,
      name: r'page',
      target: r'PageModel',
      single: true,
    ),
  },
  embeddedSchemas: {},
  getId: _padModelGetId,
  getLinks: _padModelGetLinks,
  attach: _padModelAttach,
  version: '3.1.0+1',
);

int _padModelEstimateSize(
  PadModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.backgroundImagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.label.length * 3;
  {
    final value = object.samplePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _padModelSerialize(
  PadModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.backgroundImagePath);
  writer.writeLong(offsets[1], object.chokeGroup);
  writer.writeLong(offsets[2], object.colorHex);
  writer.writeLong(offsets[3], object.endPointMs);
  writer.writeLong(offsets[4], object.fadeInMs);
  writer.writeLong(offsets[5], object.fadeOutMs);
  writer.writeDouble(offsets[6], object.height);
  writer.writeBool(offsets[7], object.isProtected);
  writer.writeString(offsets[8], object.label);
  writer.writeLong(offsets[9], object.loopPointMs);
  writer.writeLong(offsets[10], object.padId);
  writer.writeLong(offsets[11], object.padTypeIndex);
  writer.writeDouble(offsets[12], object.pan);
  writer.writeDouble(offsets[13], object.pitch);
  writer.writeBool(offsets[14], object.reverse);
  writer.writeString(offsets[15], object.samplePath);
  writer.writeLong(offsets[16], object.startPointMs);
  writer.writeLong(offsets[17], object.targetMacroId);
  writer.writeLong(offsets[18], object.targetPageIndex);
  writer.writeLong(offsets[19], object.triggerModeIndex);
  writer.writeDouble(offsets[20], object.width);
  writer.writeDouble(offsets[21], object.x);
  writer.writeDouble(offsets[22], object.y);
  writer.writeDouble(offsets[23], object.volume);
}

PadModel _padModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PadModel();
  object.backgroundImagePath = reader.readStringOrNull(offsets[0]);
  object.chokeGroup = reader.readLong(offsets[1]);
  object.colorHex = reader.readLong(offsets[2]);
  object.endPointMs = reader.readLongOrNull(offsets[3]);
  object.fadeInMs = reader.readLong(offsets[4]);
  object.fadeOutMs = reader.readLong(offsets[5]);
  object.height = reader.readDouble(offsets[6]);
  object.id = id;
  object.isProtected = reader.readBool(offsets[7]);
  object.label = reader.readString(offsets[8]);
  object.loopPointMs = reader.readLong(offsets[9]);
  object.padId = reader.readLong(offsets[10]);
  object.padTypeIndex = reader.readLong(offsets[11]);
  object.pan = reader.readDouble(offsets[12]);
  object.pitch = reader.readDouble(offsets[13]);
  object.reverse = reader.readBool(offsets[14]);
  object.samplePath = reader.readStringOrNull(offsets[15]);
  object.startPointMs = reader.readLong(offsets[16]);
  object.targetMacroId = reader.readLongOrNull(offsets[17]);
  object.targetPageIndex = reader.readLongOrNull(offsets[18]);
  object.triggerModeIndex = reader.readLong(offsets[19]);
  object.width = reader.readDouble(offsets[20]);
  object.x = reader.readDouble(offsets[21]);
  object.y = reader.readDouble(offsets[22]);
  object.volume = reader.readDouble(offsets[23]);
  return object;
}

P _padModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readDouble(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    case 17:
      return (reader.readLongOrNull(offset)) as P;
    case 18:
      return (reader.readLongOrNull(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    case 20:
      return (reader.readDouble(offset)) as P;
    case 21:
      return (reader.readDouble(offset)) as P;
    case 22:
      return (reader.readDouble(offset)) as P;
    case 23:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _padModelGetId(PadModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _padModelGetLinks(PadModel object) {
  return [object.sample, object.page];
}

void _padModelAttach(IsarCollection<dynamic> col, Id id, PadModel object) {
  object.id = id;
  object.sample.attach(col, col.isar.collection<SampleModel>(), r'sample', id);
  object.page.attach(col, col.isar.collection<PageModel>(), r'page', id);
}

extension PadModelQueryWhereSort on QueryBuilder<PadModel, PadModel, QWhere> {
  QueryBuilder<PadModel, PadModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhere> anyPadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'padId'),
      );
    });
  }
}

extension PadModelQueryWhere on QueryBuilder<PadModel, PadModel, QWhereClause> {
  QueryBuilder<PadModel, PadModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> padIdEqualTo(int padId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'padId', value: [padId]),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> padIdNotEqualTo(
    int padId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'padId',
                lower: [],
                upper: [padId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'padId',
                lower: [padId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'padId',
                lower: [padId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'padId',
                lower: [],
                upper: [padId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> padIdGreaterThan(
    int padId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'padId',
          lower: [padId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> padIdLessThan(
    int padId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'padId',
          lower: [],
          upper: [padId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterWhereClause> padIdBetween(
    int lowerPadId,
    int upperPadId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'padId',
          lower: [lowerPadId],
          includeLower: includeLower,
          upper: [upperPadId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PadModelQueryFilter
    on QueryBuilder<PadModel, PadModel, QFilterCondition> {
  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'backgroundImagePath'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'backgroundImagePath'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'backgroundImagePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'backgroundImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'backgroundImagePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'backgroundImagePath', value: ''),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  backgroundImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'backgroundImagePath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> chokeGroupEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'chokeGroup', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> chokeGroupGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'chokeGroup',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> chokeGroupLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'chokeGroup',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> chokeGroupBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'chokeGroup',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> colorHexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'colorHex', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> colorHexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'colorHex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> colorHexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'colorHex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> colorHexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'colorHex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> endPointMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'endPointMs'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  endPointMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'endPointMs'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> endPointMsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endPointMs', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> endPointMsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> endPointMsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> endPointMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endPointMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeInMsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fadeInMs', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeInMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fadeInMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeInMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fadeInMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeInMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fadeInMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeOutMsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fadeOutMs', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeOutMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fadeOutMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeOutMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fadeOutMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> fadeOutMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fadeOutMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> heightEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'height',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> heightGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'height',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> heightLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'height',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> heightBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'height',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> isProtectedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isProtected', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'label',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'label',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> loopPointMsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'loopPointMs', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  loopPointMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'loopPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> loopPointMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'loopPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> loopPointMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'loopPointMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'padId', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'padId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'padId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'padId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padTypeIndexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'padTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  padTypeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'padTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padTypeIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'padTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> padTypeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'padTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> panEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pan',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> panGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pan',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> panLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pan',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> panBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pan',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> pitchEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pitch',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> pitchGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pitch',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> pitchLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pitch',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> pitchBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pitch',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> reverseEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reverse', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'samplePath'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  samplePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'samplePath'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'samplePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'samplePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'samplePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> samplePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'samplePath', value: ''),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  samplePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'samplePath', value: ''),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> startPointMsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startPointMs', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  startPointMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> startPointMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startPointMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> startPointMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startPointMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetMacroIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'targetMacroId'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetMacroIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'targetMacroId'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> targetMacroIdEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetMacroId', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetMacroIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetMacroId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> targetMacroIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetMacroId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> targetMacroIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetMacroId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'targetPageIndex'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'targetPageIndex'),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetPageIndex', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetPageIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetPageIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  targetPageIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetPageIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  triggerModeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'triggerModeIndex', value: value),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  triggerModeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'triggerModeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  triggerModeIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'triggerModeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition>
  triggerModeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'triggerModeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> widthEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'width',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> widthGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'width',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> widthLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'width',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> widthBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'width',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> xEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'x', value: value, epsilon: epsilon),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> xGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'x',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> xLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'x',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> xBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'x',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> yEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'y', value: value, epsilon: epsilon),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> yGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'y',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> yLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'y',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> yBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'y',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension PadModelQueryObject
    on QueryBuilder<PadModel, PadModel, QFilterCondition> {}

extension PadModelQueryLinks
    on QueryBuilder<PadModel, PadModel, QFilterCondition> {
  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> sample(
    FilterQuery<SampleModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'sample');
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> sampleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'sample', 0, true, 0, true);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> page(
    FilterQuery<PageModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'page');
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterFilterCondition> pageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'page', 0, true, 0, true);
    });
  }
}

extension PadModelQuerySortBy on QueryBuilder<PadModel, PadModel, QSortBy> {
  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByBackgroundImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundImagePath', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy>
  sortByBackgroundImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundImagePath', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByChokeGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chokeGroup', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByChokeGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chokeGroup', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByEndPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByEndPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByFadeInMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeInMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByFadeInMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeInMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByFadeOutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeOutMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByFadeOutMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeOutMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByIsProtected() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isProtected', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByIsProtectedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isProtected', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByLoopPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loopPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByLoopPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loopPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padId', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPadIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padId', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPadTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPadTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPan() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pan', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPanDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pan', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPitch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pitch', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByPitchDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pitch', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByReverse() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reverse', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByReverseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reverse', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortBySamplePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'samplePath', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortBySamplePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'samplePath', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByStartPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByStartPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTargetMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMacroId', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTargetMacroIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMacroId', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTargetPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPageIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTargetPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPageIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTriggerModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerModeIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByTriggerModeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerModeIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByX() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'x', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByXDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'x', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByY() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'y', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> sortByYDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'y', Sort.desc);
    });
  }
}

extension PadModelQuerySortThenBy
    on QueryBuilder<PadModel, PadModel, QSortThenBy> {
  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByBackgroundImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundImagePath', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy>
  thenByBackgroundImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundImagePath', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByChokeGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chokeGroup', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByChokeGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chokeGroup', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByEndPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByEndPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByFadeInMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeInMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByFadeInMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeInMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByFadeOutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeOutMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByFadeOutMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fadeOutMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByIsProtected() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isProtected', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByIsProtectedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isProtected', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByLoopPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loopPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByLoopPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loopPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padId', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPadIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padId', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPadTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPadTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'padTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPan() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pan', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPanDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pan', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPitch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pitch', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByPitchDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pitch', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByReverse() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reverse', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByReverseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reverse', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenBySamplePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'samplePath', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenBySamplePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'samplePath', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByStartPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startPointMs', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByStartPointMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startPointMs', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTargetMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMacroId', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTargetMacroIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMacroId', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTargetPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPageIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTargetPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPageIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTriggerModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerModeIndex', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByTriggerModeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerModeIndex', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByX() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'x', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByXDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'x', Sort.desc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByY() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'y', Sort.asc);
    });
  }

  QueryBuilder<PadModel, PadModel, QAfterSortBy> thenByYDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'y', Sort.desc);
    });
  }
}

extension PadModelQueryWhereDistinct
    on QueryBuilder<PadModel, PadModel, QDistinct> {
  QueryBuilder<PadModel, PadModel, QDistinct> distinctByBackgroundImagePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'backgroundImagePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByChokeGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chokeGroup');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'colorHex');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByEndPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endPointMs');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByFadeInMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fadeInMs');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByFadeOutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fadeOutMs');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'height');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByIsProtected() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isProtected');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByLabel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByLoopPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loopPointMs');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByPadId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'padId');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByPadTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'padTypeIndex');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByPan() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pan');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByPitch() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pitch');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByReverse() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reverse');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctBySamplePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'samplePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByStartPointMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startPointMs');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByTargetMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetMacroId');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByTargetPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetPageIndex');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByTriggerModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'triggerModeIndex');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'width');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByX() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'x');
    });
  }

  QueryBuilder<PadModel, PadModel, QDistinct> distinctByY() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'y');
    });
  }
}

extension PadModelQueryProperty
    on QueryBuilder<PadModel, PadModel, QQueryProperty> {
  QueryBuilder<PadModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PadModel, String?, QQueryOperations>
  backgroundImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backgroundImagePath');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> chokeGroupProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chokeGroup');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> colorHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'colorHex');
    });
  }

  QueryBuilder<PadModel, int?, QQueryOperations> endPointMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endPointMs');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> fadeInMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fadeInMs');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> fadeOutMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fadeOutMs');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> heightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'height');
    });
  }

  QueryBuilder<PadModel, bool, QQueryOperations> isProtectedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isProtected');
    });
  }

  QueryBuilder<PadModel, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> loopPointMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loopPointMs');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> padIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'padId');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> padTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'padTypeIndex');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> panProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pan');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> pitchProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pitch');
    });
  }

  QueryBuilder<PadModel, bool, QQueryOperations> reverseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reverse');
    });
  }

  QueryBuilder<PadModel, String?, QQueryOperations> samplePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'samplePath');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> startPointMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startPointMs');
    });
  }

  QueryBuilder<PadModel, int?, QQueryOperations> targetMacroIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetMacroId');
    });
  }

  QueryBuilder<PadModel, int?, QQueryOperations> targetPageIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetPageIndex');
    });
  }

  QueryBuilder<PadModel, int, QQueryOperations> triggerModeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'triggerModeIndex');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> widthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'width');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> xProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'x');
    });
  }

  QueryBuilder<PadModel, double, QQueryOperations> yProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'y');
    });
  }
}

