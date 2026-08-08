// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'midi_mapping_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMidiMappingModelCollection on Isar {
  IsarCollection<MidiMappingModel> get midiMappingModels => this.collection();
}

const MidiMappingModelSchema = CollectionSchema(
  name: r'MidiMappingModel',
  id: 580326398779251250,
  properties: {
    r'actionType': PropertySchema(
      id: 0,
      name: r'actionType',
      type: IsarType.string,
    ),
    r'actionValue': PropertySchema(
      id: 1,
      name: r'actionValue',
      type: IsarType.string,
    ),
    r'noteOrCC': PropertySchema(id: 2, name: r'noteOrCC', type: IsarType.long),
    r'statusByte': PropertySchema(
      id: 3,
      name: r'statusByte',
      type: IsarType.long,
    ),
  },
  estimateSize: _midiMappingModelEstimateSize,
  serialize: _midiMappingModelSerialize,
  deserialize: _midiMappingModelDeserialize,
  deserializeProp: _midiMappingModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'noteOrCC': IndexSchema(
      id: -2151871883702043378,
      name: r'noteOrCC',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'noteOrCC',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _midiMappingModelGetId,
  getLinks: _midiMappingModelGetLinks,
  attach: _midiMappingModelAttach,
  version: '3.1.0+1',
);

int _midiMappingModelEstimateSize(
  MidiMappingModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.actionType.length * 3;
  bytesCount += 3 + object.actionValue.length * 3;
  return bytesCount;
}

void _midiMappingModelSerialize(
  MidiMappingModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actionType);
  writer.writeString(offsets[1], object.actionValue);
  writer.writeLong(offsets[2], object.noteOrCC);
  writer.writeLong(offsets[3], object.statusByte);
}

MidiMappingModel _midiMappingModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MidiMappingModel();
  object.actionType = reader.readString(offsets[0]);
  object.actionValue = reader.readString(offsets[1]);
  object.id = id;
  object.noteOrCC = reader.readLong(offsets[2]);
  object.statusByte = reader.readLong(offsets[3]);
  return object;
}

P _midiMappingModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _midiMappingModelGetId(MidiMappingModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _midiMappingModelGetLinks(MidiMappingModel object) {
  return [];
}

void _midiMappingModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  MidiMappingModel object,
) {
  object.id = id;
}

extension MidiMappingModelQueryWhereSort
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QWhere> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhere> anyNoteOrCC() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'noteOrCC'),
      );
    });
  }
}

extension MidiMappingModelQueryWhere
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QWhereClause> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  noteOrCCEqualTo(int noteOrCC) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'noteOrCC', value: [noteOrCC]),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  noteOrCCNotEqualTo(int noteOrCC) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteOrCC',
                lower: [],
                upper: [noteOrCC],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteOrCC',
                lower: [noteOrCC],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteOrCC',
                lower: [noteOrCC],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteOrCC',
                lower: [],
                upper: [noteOrCC],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  noteOrCCGreaterThan(int noteOrCC, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'noteOrCC',
          lower: [noteOrCC],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  noteOrCCLessThan(int noteOrCC, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'noteOrCC',
          lower: [],
          upper: [noteOrCC],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterWhereClause>
  noteOrCCBetween(
    int lowerNoteOrCC,
    int upperNoteOrCC, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'noteOrCC',
          lower: [lowerNoteOrCC],
          includeLower: includeLower,
          upper: [upperNoteOrCC],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MidiMappingModelQueryFilter
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QFilterCondition> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'actionType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'actionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'actionType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'actionType', value: ''),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'actionType', value: ''),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'actionValue',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'actionValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'actionValue',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'actionValue', value: ''),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  actionValueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'actionValue', value: ''),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  noteOrCCEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'noteOrCC', value: value),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  noteOrCCGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'noteOrCC',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  noteOrCCLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'noteOrCC',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  noteOrCCBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'noteOrCC',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  statusByteEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'statusByte', value: value),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  statusByteGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'statusByte',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  statusByteLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'statusByte',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterFilterCondition>
  statusByteBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'statusByte',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MidiMappingModelQueryObject
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QFilterCondition> {}

extension MidiMappingModelQueryLinks
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QFilterCondition> {}

extension MidiMappingModelQuerySortBy
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QSortBy> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByActionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionType', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByActionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionType', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByActionValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionValue', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByActionValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionValue', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByNoteOrCC() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteOrCC', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByNoteOrCCDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteOrCC', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByStatusByte() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusByte', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  sortByStatusByteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusByte', Sort.desc);
    });
  }
}

extension MidiMappingModelQuerySortThenBy
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QSortThenBy> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByActionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionType', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByActionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionType', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByActionValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionValue', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByActionValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionValue', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByNoteOrCC() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteOrCC', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByNoteOrCCDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteOrCC', Sort.desc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByStatusByte() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusByte', Sort.asc);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QAfterSortBy>
  thenByStatusByteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusByte', Sort.desc);
    });
  }
}

extension MidiMappingModelQueryWhereDistinct
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QDistinct> {
  QueryBuilder<MidiMappingModel, MidiMappingModel, QDistinct>
  distinctByActionType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QDistinct>
  distinctByActionValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionValue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QDistinct>
  distinctByNoteOrCC() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'noteOrCC');
    });
  }

  QueryBuilder<MidiMappingModel, MidiMappingModel, QDistinct>
  distinctByStatusByte() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusByte');
    });
  }
}

extension MidiMappingModelQueryProperty
    on QueryBuilder<MidiMappingModel, MidiMappingModel, QQueryProperty> {
  QueryBuilder<MidiMappingModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MidiMappingModel, String, QQueryOperations>
  actionTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionType');
    });
  }

  QueryBuilder<MidiMappingModel, String, QQueryOperations>
  actionValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionValue');
    });
  }

  QueryBuilder<MidiMappingModel, int, QQueryOperations> noteOrCCProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'noteOrCC');
    });
  }

  QueryBuilder<MidiMappingModel, int, QQueryOperations> statusByteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusByte');
    });
  }
}
