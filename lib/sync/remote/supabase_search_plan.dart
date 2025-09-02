import '../sync_types.dart';
import '../store_interfaces.dart';

/// Data class describing a single filter operation in Supabase PostgREST.
class SupabaseQueryOp {
  final String method; // eq, neq, gt, gte, lt, lte, in, like, contains, isNull
  final String column;
  final dynamic value; // scalar, List, or Map for jsonb contains
  const SupabaseQueryOp(this.method, this.column, this.value);
}

/// Data class describing an order clause.
class SupabaseOrderSpecDto {
  final String column;
  final bool ascending;
  const SupabaseOrderSpecDto(this.column, {required this.ascending});
}

/// Data class holding a full remoteSearch request plan for Supabase.
class SupabaseSearchRequest {
  final List<SupabaseQueryOp> filters;
  final List<SupabaseOrderSpecDto> orders;
  final int? limit;
  final int? rangeFrom;
  final int? rangeTo;
  const SupabaseSearchRequest({
    required this.filters,
    required this.orders,
    this.limit,
    this.rangeFrom,
    this.rangeTo,
  });
}

/// Build a testable Supabase remoteSearch request plan from QuerySpec.
SupabaseSearchRequest buildSupabaseRemoteSearchRequest({
  required SyncScope scope,
  required QuerySpec spec,
  required String idColumn,
  required String updatedAtColumn,
  required String? deletedAtColumn,
  required String scopeNameColumn,
  required String scopeKeysColumn,
}) {
  if (spec.offset != null && spec.limit == null) {
    throw ArgumentError('offset requires limit for remoteSearch (Supabase)');
  }
  final filters = <SupabaseQueryOp>[
    SupabaseQueryOp('eq', scopeNameColumn, scope.name),
    SupabaseQueryOp('contains', scopeKeysColumn, scope.keys),
  ];
  if (deletedAtColumn != null) {
    filters.add(SupabaseQueryOp('isNull', deletedAtColumn, null));
  }
  String asIso(Object v) {
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is String) return v;
    throw ArgumentError(
      'updatedAt filter value must be DateTime or ISO String',
    );
  }

  for (final f in spec.filters) {
    switch (f.field) {
      case 'id':
        final col = idColumn;
        switch (f.op) {
          case FilterOperator.eq:
            if (f.value is! String) {
              throw ArgumentError('id eq expects String value');
            }
            filters.add(SupabaseQueryOp('eq', col, f.value as String));
            break;
          case FilterOperator.neq:
            if (f.value is! String) {
              throw ArgumentError('id neq expects String value');
            }
            filters.add(SupabaseQueryOp('neq', col, f.value as String));
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError('id inList expects List<String>');
            }
            filters.add(
              SupabaseQueryOp(
                'in',
                col,
                (f.value as List).map((e) => e.toString()).toList(),
              ),
            );
            break;
          case FilterOperator.like:
            if (f.value is! String) {
              throw ArgumentError('id like expects String value');
            }
            filters.add(SupabaseQueryOp('like', col, '%${f.value}%'));
            break;
          default:
            throw ArgumentError('Unsupported operator for id: ${f.op}');
        }
        break;
      case 'updatedAt':
        final col = updatedAtColumn;
        switch (f.op) {
          case FilterOperator.eq:
            if (f.value == null)
              throw ArgumentError('updatedAt eq requires value');
            filters.add(SupabaseQueryOp('eq', col, asIso(f.value!)));
            break;
          case FilterOperator.neq:
            if (f.value == null)
              throw ArgumentError('updatedAt neq requires value');
            filters.add(SupabaseQueryOp('neq', col, asIso(f.value!)));
            break;
          case FilterOperator.gt:
            if (f.value == null)
              throw ArgumentError('updatedAt gt requires value');
            filters.add(SupabaseQueryOp('gt', col, asIso(f.value!)));
            break;
          case FilterOperator.gte:
            if (f.value == null)
              throw ArgumentError('updatedAt gte requires value');
            filters.add(SupabaseQueryOp('gte', col, asIso(f.value!)));
            break;
          case FilterOperator.lt:
            if (f.value == null)
              throw ArgumentError('updatedAt lt requires value');
            filters.add(SupabaseQueryOp('lt', col, asIso(f.value!)));
            break;
          case FilterOperator.lte:
            if (f.value == null)
              throw ArgumentError('updatedAt lte requires value');
            filters.add(SupabaseQueryOp('lte', col, asIso(f.value!)));
            break;
          case FilterOperator.inList:
            if (f.value is! List) {
              throw ArgumentError(
                'updatedAt inList expects List<DateTime|String>',
              );
            }
            filters.add(
              SupabaseQueryOp(
                'in',
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
  final orders = <SupabaseOrderSpecDto>[];
  for (final o in spec.orderBy) {
    switch (o.field) {
      case 'id':
        orders.add(SupabaseOrderSpecDto(idColumn, ascending: !o.descending));
        break;
      case 'updatedAt':
        orders.add(
          SupabaseOrderSpecDto(updatedAtColumn, ascending: !o.descending),
        );
        break;
      default:
        throw ArgumentError('Unsupported order field: ${o.field}');
    }
  }
  int? limit;
  int? rangeFrom;
  int? rangeTo;
  if (spec.limit != null) {
    final l = spec.limit!;
    final off = spec.offset ?? 0;
    if (off == 0) {
      limit = l;
    } else {
      rangeFrom = off;
      rangeTo = off + l - 1;
    }
  }
  return SupabaseSearchRequest(
    filters: filters,
    orders: orders,
    limit: limit,
    rangeFrom: rangeFrom,
    rangeTo: rangeTo,
  );
}
