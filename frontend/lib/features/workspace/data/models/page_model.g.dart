// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPageModelCollection on Isar {
  IsarCollection<PageModel> get pageModels => this.collection();
}

const PageModelSchema = CollectionSchema(
  name: r'PageModel',
  id: -5125267323554502652,
  properties: {
    r'columns': PropertySchema(id: 0, name: r'columns', type: IsarType.long),
    r'name': PropertySchema(id: 1, name: r'name', type: IsarType.string),
    r'pageIndex': PropertySchema(
      id: 2,
      name: r'pageIndex',
      type: IsarType.long,
    ),
    r'rows': PropertySchema(id: 3, name: r'rows', type: IsarType.long),
    r'parentPageId': PropertySchema(
      id: 4,
      name: r'parentPageId',
      type: IsarType.long,
    ),
    r'sortOrder': PropertySchema(
      id: 5,
      name: r'sortOrder',
      type: IsarType.long,
    ),
  },
  estimateSize: _pageModelEstimateSize,
  serialize: _pageModelSerialize,
  deserialize: _pageModelDeserialize,
  deserializeProp: _pageModelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'workspace': LinkSchema(
      id: -3716474612212213775,
      name: r'workspace',
      target: r'WorkspaceModel',
      single: true,
    ),
    r'pads': LinkSchema(
      id: -429904951807238531,
      name: r'pads',
      target: r'PadModel',
      single: false,
      linkName: r'page',
    ),
  },
  embeddedSchemas: {},
  getId: _pageModelGetId,
  getLinks: _pageModelGetLinks,
  attach: _pageModelAttach,
  version: '3.1.0+1',
);

int _pageModelEstimateSize(
  PageModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.parentPageId;
    if (value != null) {
      bytesCount += 3;
    }
  }
  return bytesCount;
}

void _pageModelSerialize(
  PageModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.columns);
  writer.writeString(offsets[1], object.name);
  writer.writeLong(offsets[2], object.pageIndex);
  writer.writeLong(offsets[3], object.rows);
  writer.writeLong(offsets[4], object.parentPageId);
  writer.writeLong(offsets[5], object.sortOrder);
}

PageModel _pageModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PageModel();
  object.columns = reader.readLong(offsets[0]);
  object.id = id;
  object.name = reader.readStringOrNull(offsets[1]);
  object.pageIndex = reader.readLong(offsets[2]);
  object.rows = reader.readLong(offsets[3]);
  object.parentPageId = reader.readLongOrNull(offsets[4]);
  object.sortOrder = reader.readLong(offsets[5]);
  return object;
}

P _pageModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pageModelGetId(PageModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pageModelGetLinks(PageModel object) {
  return [object.workspace, object.pads];
}

void _pageModelAttach(IsarCollection<dynamic> col, Id id, PageModel object) {
  object.id = id;
  object.workspace.attach(
    col,
    col.isar.collection<WorkspaceModel>(),
    r'workspace',
    id,
  );
  object.pads.attach(col, col.isar.collection<PadModel>(), r'pads', id);
}

extension PageModelQueryWhereSort
    on QueryBuilder<PageModel, PageModel, QWhere> {
  QueryBuilder<PageModel, PageModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PageModelQueryWhere
    on QueryBuilder<PageModel, PageModel, QWhereClause> {
  QueryBuilder<PageModel, PageModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<PageModel, PageModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterWhereClause> idBetween(
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
}

extension PageModelQueryFilter
    on QueryBuilder<PageModel, PageModel, QFilterCondition> {
  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> columnsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'columns', value: value),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> columnsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'columns',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> columnsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'columns',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> columnsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'columns',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'name'),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'name'),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameEqualTo(
    String? value, {
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameGreaterThan(
    String? value, {
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameLessThan(
    String? value, {
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameContains(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> pageIndexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pageIndex', value: value),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  pageIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pageIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> pageIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pageIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> pageIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pageIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> rowsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rows', value: value),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> rowsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rows',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> rowsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rows',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> rowsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rows',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  parentPageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parentPageId'),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  parentPageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parentPageId'),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> parentPageIdEqualTo(
    int? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'parentPageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  parentPageIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parentPageId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  parentPageIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parentPageId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> parentPageIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parentPageId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> sortOrderEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sortOrder', value: value),
      );
    });
  }
}

extension PageModelQueryObject
    on QueryBuilder<PageModel, PageModel, QFilterCondition> {}

extension PageModelQueryLinks
    on QueryBuilder<PageModel, PageModel, QFilterCondition> {
  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> workspace(
    FilterQuery<WorkspaceModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'workspace');
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> workspaceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'workspace', 0, true, 0, true);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> pads(
    FilterQuery<PadModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'pads');
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> padsLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'pads', length, true, length, true);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> padsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'pads', 0, true, 0, true);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> padsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'pads', 0, false, 999999, true);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> padsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'pads', 0, true, length, include);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition>
  padsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'pads', length, include, 999999, true);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterFilterCondition> padsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'pads',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension PageModelQuerySortBy on QueryBuilder<PageModel, PageModel, QSortBy> {
  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByColumns() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'columns', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByColumnsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'columns', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByRows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rows', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> sortByRowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rows', Sort.desc);
    });
  }
}

extension PageModelQuerySortThenBy
    on QueryBuilder<PageModel, PageModel, QSortThenBy> {
  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByColumns() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'columns', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByColumnsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'columns', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByRows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rows', Sort.asc);
    });
  }

  QueryBuilder<PageModel, PageModel, QAfterSortBy> thenByRowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rows', Sort.desc);
    });
  }
}

extension PageModelQueryWhereDistinct
    on QueryBuilder<PageModel, PageModel, QDistinct> {
  QueryBuilder<PageModel, PageModel, QDistinct> distinctByColumns() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'columns');
    });
  }

  QueryBuilder<PageModel, PageModel, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PageModel, PageModel, QDistinct> distinctByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageIndex');
    });
  }

  QueryBuilder<PageModel, PageModel, QDistinct> distinctByParentPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentPageId');
    });
  }

  QueryBuilder<PageModel, PageModel, QDistinct> distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }

  QueryBuilder<PageModel, PageModel, QDistinct> distinctByRows() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rows');
    });
  }
}

extension PageModelQueryProperty
    on QueryBuilder<PageModel, PageModel, QQueryProperty> {
  QueryBuilder<PageModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PageModel, int, QQueryOperations> columnsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'columns');
    });
  }

  QueryBuilder<PageModel, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<PageModel, int, QQueryOperations> pageIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageIndex');
    });
  }

  QueryBuilder<PageModel, int?, QQueryOperations> parentPageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentPageId');
    });
  }

  QueryBuilder<PageModel, int, QQueryOperations> rowsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rows');
    });
  }

  QueryBuilder<PageModel, int, QQueryOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }
}
