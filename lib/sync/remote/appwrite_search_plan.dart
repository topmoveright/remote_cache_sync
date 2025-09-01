import 'package:appwrite/appwrite.dart' as aw;

import '../store_interfaces.dart';
import '../sync_types.dart';

/// Top-level helper to build Appwrite remoteSearch queries without requiring a Client/Databases.
List<String> buildAppwriteRemoteSearchQueries({
  required SyncScope scope,
  required QuerySpec spec,
  required String idField,
  required String updatedAtField,
  required String? deletedAtField,
  required String scopeNameField,
}) {
  if (spec.offset != null && spec.limit == null) {
    throw ArgumentError('offset requires limit for remoteSearch (Appwrite)');
  }
  final queries = <String>[
    aw.Query.equal(scopeNameField, scope.name),
  ];
  if (deletedAtField != null) {
    queries.add(aw.Query.isNull(deletedAtField));
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
              queries.add(
                aw.Query.equal(
                  col,
                  (f.value as List).map((e) => e.toString()).toList(),
                ),
              );
            } else {
              if (f.value is! String) {
                throw ArgumentError('id eq expects String or List<String>');
              }
              queries.add(aw.Query.equal(col, f.value as String));
            }
            break;
          case FilterOperator.neq:
            if (f.value is! String) {
              throw ArgumentError('id neq expects String');
            }
            queries.add(aw.Query.notEqual(col, f.value as String));
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError('id inList expects List<String>');
            }
            queries.add(
              aw.Query.equal(
                col,
                (f.value as List).map((e) => e.toString()).toList(),
              ),
            );
            break;
          case FilterOperator.like:
            if (f.value is! String) {
              throw ArgumentError('id like expects String');
            }
            queries.add(aw.Query.search(col, f.value as String));
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
            queries.add(aw.Query.equal(col, asIso(f.value!)));
            break;
          case FilterOperator.neq:
            if (f.value == null) {
              throw ArgumentError('updatedAt neq requires value');
            }
            queries.add(aw.Query.notEqual(col, asIso(f.value!)));
            break;
          case FilterOperator.gt:
            if (f.value == null) {
              throw ArgumentError('updatedAt gt requires value');
            }
            queries.add(aw.Query.greaterThan(col, asIso(f.value!)));
            break;
          case FilterOperator.gte:
            if (f.value == null) {
              throw ArgumentError('updatedAt gte requires value');
            }
            queries.add(aw.Query.greaterThanEqual(col, asIso(f.value!)));
            break;
          case FilterOperator.lt:
            if (f.value == null) {
              throw ArgumentError('updatedAt lt requires value');
            }
            queries.add(aw.Query.lessThan(col, asIso(f.value!)));
            break;
          case FilterOperator.lte:
            if (f.value == null) {
              throw ArgumentError('updatedAt lte requires value');
            }
            queries.add(aw.Query.lessThanEqual(col, asIso(f.value!)));
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError('updatedAt inList expects List<DateTime|String>');
            }
            queries.add(
              aw.Query.equal(
                col,
                (f.value as List).map((e) => asIso(e)).toList(),
              ),
            );
            break;
          default:
            throw ArgumentError('Unsupported operator for updatedAt: ${f.op}');
        }
        break;
      default:
        throw ArgumentError('Unsupported filter field: ${f.field}');
    }
  }
  for (final o in spec.orderBy) {
    switch (o.field) {
      case 'id':
        queries.add(
          o.descending ? aw.Query.orderDesc(idField) : aw.Query.orderAsc(idField),
        );
        break;
      case 'updatedAt':
        queries.add(
          o.descending
              ? aw.Query.orderDesc(updatedAtField)
              : aw.Query.orderAsc(updatedAtField),
        );
        break;
      default:
        throw ArgumentError('Unsupported order field: ${o.field}');
    }
  }
  if (spec.limit != null) {
    queries.add(aw.Query.limit(spec.limit!));
    if (spec.offset != null) {
      queries.add(aw.Query.offset(spec.offset!));
    }
  }
  return queries;
}
