import '../sync_types.dart';
import '../store_interfaces.dart';

/// Build PocketBase remoteSearch parameters (filter, sort, page, perPage)
/// without requiring a PocketBase client.
(
  String filter,
  String? sort,
  int page,
  int perPage,
) buildPocketBaseRemoteSearchRequest({
  required SyncScope scope,
  required QuerySpec spec,
  required String idField,
  required String updatedAtField,
  required String? deletedAtField,
  required String scopeNameField,
}) {
  if (spec.offset != null && spec.limit == null) {
    throw ArgumentError('offset requires limit for remoteSearch (PocketBase)');
  }
  final parts = <String>["${scopeNameField}='${scope.name}'"];
  if (deletedAtField != null) {
    parts.add("${deletedAtField} = null");
  }
  String asIso(Object v) {
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is String) return v;
    throw ArgumentError('updatedAt filter value must be DateTime or ISO String');
  }
  for (final f in spec.filters) {
    switch (f.field) {
      case 'id':
        final col = idField;
        switch (f.op) {
          case FilterOperator.eq:
            if (f.value is List) {
              final list = (f.value as List)
                  .map((e) => "${col}='${e.toString()}'")
                  .join(' || ');
              parts.add('($list)');
            } else {
              if (f.value is! String) {
                throw ArgumentError('id eq expects String or List<String>');
              }
              parts.add("${col}='${f.value as String}'");
            }
            break;
          case FilterOperator.neq:
            if (f.value is! String) {
              throw ArgumentError('id neq expects String');
            }
            parts.add("${col}!='${f.value as String}'");
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError('id inList expects List<String>');
            }
            final list = (f.value as List)
                .map((e) => "${col}='${e.toString()}'")
                .join(' || ');
            parts.add('($list)');
            break;
          case FilterOperator.like:
            if (f.value is! String) {
              throw ArgumentError('id like expects String');
            }
            parts.add("${col}~'%${f.value as String}%'");
            break;
          default:
            throw ArgumentError('Unsupported operator for id: ${f.op}');
        }
        break;
      case 'updatedAt':
        final col = updatedAtField;
        switch (f.op) {
          case FilterOperator.eq:
            if (f.value == null) {
              throw ArgumentError('updatedAt eq requires value');
            }
            parts.add("${col}='${asIso(f.value!)}'");
            break;
          case FilterOperator.neq:
            if (f.value == null) {
              throw ArgumentError('updatedAt neq requires value');
            }
            parts.add("${col}!='${asIso(f.value!)}'");
            break;
          case FilterOperator.gt:
            if (f.value == null) {
              throw ArgumentError('updatedAt gt requires value');
            }
            parts.add("${col}>'${asIso(f.value!)}'");
            break;
          case FilterOperator.gte:
            if (f.value == null) {
              throw ArgumentError('updatedAt gte requires value');
            }
            parts.add("${col}>='${asIso(f.value!)}'");
            break;
          case FilterOperator.lt:
            if (f.value == null) {
              throw ArgumentError('updatedAt lt requires value');
            }
            parts.add("${col}<'${asIso(f.value!)}'");
            break;
          case FilterOperator.lte:
            if (f.value == null) {
              throw ArgumentError('updatedAt lte requires value');
            }
            parts.add("${col}<='${asIso(f.value!)}'");
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError('updatedAt inList expects List<DateTime|String>');
            }
            final list = (f.value as List)
                .map((e) => "${col}='${asIso(e)}'")
                .join(' || ');
            parts.add('($list)');
            break;
          default:
            throw ArgumentError('Unsupported operator for updatedAt: ${f.op}');
        }
        break;
      default:
        throw ArgumentError('Unsupported filter field: ${f.field}');
    }
  }
  final filter = parts.join(' && ');
  String? sort;
  if (spec.orderBy.isNotEmpty) {
    final sorts = <String>[];
    for (final o in spec.orderBy) {
      switch (o.field) {
        case 'id':
          sorts.add(o.descending ? '-$idField' : idField);
          break;
        case 'updatedAt':
          sorts.add(o.descending ? '-$updatedAtField' : updatedAtField);
          break;
        default:
          throw ArgumentError('Unsupported order field: ${o.field}');
      }
    }
    sort = sorts.join(',');
  }
  int page = 1;
  int perPage = spec.limit ?? 100;
  if (spec.limit != null && spec.offset != null) {
    final off = spec.offset!;
    final lim = spec.limit!;
    if (off % lim != 0) {
      throw ArgumentError('PocketBase supports offset as multiples of limit only (via pages)');
    }
    page = (off ~/ lim) + 1;
  }
  return (filter, sort, page, perPage);
}
