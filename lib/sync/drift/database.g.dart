// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeNameMeta = const VerificationMeta(
    'scopeName',
  );
  @override
  late final GeneratedColumn<String> scopeName = GeneratedColumn<String>(
    'scope_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeKeysMeta = const VerificationMeta(
    'scopeKeys',
  );
  @override
  late final GeneratedColumn<String> scopeKeys = GeneratedColumn<String>(
    'scope_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeName,
    scopeKeys,
    id,
    payload,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_name')) {
      context.handle(
        _scopeNameMeta,
        scopeName.isAcceptableOrUnknown(data['scope_name']!, _scopeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeNameMeta);
    }
    if (data.containsKey('scope_keys')) {
      context.handle(
        _scopeKeysMeta,
        scopeKeys.isAcceptableOrUnknown(data['scope_keys']!, _scopeKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeKeysMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeName, scopeKeys, id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      scopeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_name'],
      )!,
      scopeKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_keys'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String scopeName;
  final String scopeKeys;
  final String id;
  final String payload;
  final String updatedAt;
  final String? deletedAt;
  const Item({
    required this.scopeName,
    required this.scopeKeys,
    required this.id,
    required this.payload,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_name'] = Variable<String>(scopeName);
    map['scope_keys'] = Variable<String>(scopeKeys);
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      scopeName: Value(scopeName),
      scopeKeys: Value(scopeKeys),
      id: Value(id),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      scopeName: serializer.fromJson<String>(json['scopeName']),
      scopeKeys: serializer.fromJson<String>(json['scopeKeys']),
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeName': serializer.toJson<String>(scopeName),
      'scopeKeys': serializer.toJson<String>(scopeKeys),
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Item copyWith({
    String? scopeName,
    String? scopeKeys,
    String? id,
    String? payload,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => Item(
    scopeName: scopeName ?? this.scopeName,
    scopeKeys: scopeKeys ?? this.scopeKeys,
    id: id ?? this.id,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      scopeName: data.scopeName.present ? data.scopeName.value : this.scopeName,
      scopeKeys: data.scopeKeys.present ? data.scopeKeys.value : this.scopeKeys,
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(scopeName, scopeKeys, id, payload, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.scopeName == this.scopeName &&
          other.scopeKeys == this.scopeKeys &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> scopeName;
  final Value<String> scopeKeys;
  final Value<String> id;
  final Value<String> payload;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.scopeName = const Value.absent(),
    this.scopeKeys = const Value.absent(),
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String scopeName,
    required String scopeKeys,
    required String id,
    required String payload,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeName = Value(scopeName),
       scopeKeys = Value(scopeKeys),
       id = Value(id),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<Item> custom({
    Expression<String>? scopeName,
    Expression<String>? scopeKeys,
    Expression<String>? id,
    Expression<String>? payload,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeName != null) 'scope_name': scopeName,
      if (scopeKeys != null) 'scope_keys': scopeKeys,
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? scopeName,
    Value<String>? scopeKeys,
    Value<String>? id,
    Value<String>? payload,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      scopeName: scopeName ?? this.scopeName,
      scopeKeys: scopeKeys ?? this.scopeKeys,
      id: id ?? this.id,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeName.present) {
      map['scope_name'] = Variable<String>(scopeName.value);
    }
    if (scopeKeys.present) {
      map['scope_keys'] = Variable<String>(scopeKeys.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncPointsTable extends SyncPoints
    with TableInfo<$SyncPointsTable, SyncPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeNameMeta = const VerificationMeta(
    'scopeName',
  );
  @override
  late final GeneratedColumn<String> scopeName = GeneratedColumn<String>(
    'scope_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeKeysMeta = const VerificationMeta(
    'scopeKeys',
  );
  @override
  late final GeneratedColumn<String> scopeKeys = GeneratedColumn<String>(
    'scope_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastServerTsMeta = const VerificationMeta(
    'lastServerTs',
  );
  @override
  late final GeneratedColumn<String> lastServerTs = GeneratedColumn<String>(
    'last_server_ts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scopeName, scopeKeys, lastServerTs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_name')) {
      context.handle(
        _scopeNameMeta,
        scopeName.isAcceptableOrUnknown(data['scope_name']!, _scopeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeNameMeta);
    }
    if (data.containsKey('scope_keys')) {
      context.handle(
        _scopeKeysMeta,
        scopeKeys.isAcceptableOrUnknown(data['scope_keys']!, _scopeKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeKeysMeta);
    }
    if (data.containsKey('last_server_ts')) {
      context.handle(
        _lastServerTsMeta,
        lastServerTs.isAcceptableOrUnknown(
          data['last_server_ts']!,
          _lastServerTsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastServerTsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeName, scopeKeys};
  @override
  SyncPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncPoint(
      scopeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_name'],
      )!,
      scopeKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_keys'],
      )!,
      lastServerTs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_server_ts'],
      )!,
    );
  }

  @override
  $SyncPointsTable createAlias(String alias) {
    return $SyncPointsTable(attachedDatabase, alias);
  }
}

class SyncPoint extends DataClass implements Insertable<SyncPoint> {
  final String scopeName;
  final String scopeKeys;
  final String lastServerTs;
  const SyncPoint({
    required this.scopeName,
    required this.scopeKeys,
    required this.lastServerTs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_name'] = Variable<String>(scopeName);
    map['scope_keys'] = Variable<String>(scopeKeys);
    map['last_server_ts'] = Variable<String>(lastServerTs);
    return map;
  }

  SyncPointsCompanion toCompanion(bool nullToAbsent) {
    return SyncPointsCompanion(
      scopeName: Value(scopeName),
      scopeKeys: Value(scopeKeys),
      lastServerTs: Value(lastServerTs),
    );
  }

  factory SyncPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncPoint(
      scopeName: serializer.fromJson<String>(json['scopeName']),
      scopeKeys: serializer.fromJson<String>(json['scopeKeys']),
      lastServerTs: serializer.fromJson<String>(json['lastServerTs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeName': serializer.toJson<String>(scopeName),
      'scopeKeys': serializer.toJson<String>(scopeKeys),
      'lastServerTs': serializer.toJson<String>(lastServerTs),
    };
  }

  SyncPoint copyWith({
    String? scopeName,
    String? scopeKeys,
    String? lastServerTs,
  }) => SyncPoint(
    scopeName: scopeName ?? this.scopeName,
    scopeKeys: scopeKeys ?? this.scopeKeys,
    lastServerTs: lastServerTs ?? this.lastServerTs,
  );
  SyncPoint copyWithCompanion(SyncPointsCompanion data) {
    return SyncPoint(
      scopeName: data.scopeName.present ? data.scopeName.value : this.scopeName,
      scopeKeys: data.scopeKeys.present ? data.scopeKeys.value : this.scopeKeys,
      lastServerTs: data.lastServerTs.present
          ? data.lastServerTs.value
          : this.lastServerTs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncPoint(')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('lastServerTs: $lastServerTs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scopeName, scopeKeys, lastServerTs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncPoint &&
          other.scopeName == this.scopeName &&
          other.scopeKeys == this.scopeKeys &&
          other.lastServerTs == this.lastServerTs);
}

class SyncPointsCompanion extends UpdateCompanion<SyncPoint> {
  final Value<String> scopeName;
  final Value<String> scopeKeys;
  final Value<String> lastServerTs;
  final Value<int> rowid;
  const SyncPointsCompanion({
    this.scopeName = const Value.absent(),
    this.scopeKeys = const Value.absent(),
    this.lastServerTs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncPointsCompanion.insert({
    required String scopeName,
    required String scopeKeys,
    required String lastServerTs,
    this.rowid = const Value.absent(),
  }) : scopeName = Value(scopeName),
       scopeKeys = Value(scopeKeys),
       lastServerTs = Value(lastServerTs);
  static Insertable<SyncPoint> custom({
    Expression<String>? scopeName,
    Expression<String>? scopeKeys,
    Expression<String>? lastServerTs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeName != null) 'scope_name': scopeName,
      if (scopeKeys != null) 'scope_keys': scopeKeys,
      if (lastServerTs != null) 'last_server_ts': lastServerTs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncPointsCompanion copyWith({
    Value<String>? scopeName,
    Value<String>? scopeKeys,
    Value<String>? lastServerTs,
    Value<int>? rowid,
  }) {
    return SyncPointsCompanion(
      scopeName: scopeName ?? this.scopeName,
      scopeKeys: scopeKeys ?? this.scopeKeys,
      lastServerTs: lastServerTs ?? this.lastServerTs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeName.present) {
      map['scope_name'] = Variable<String>(scopeName.value);
    }
    if (scopeKeys.present) {
      map['scope_keys'] = Variable<String>(scopeKeys.value);
    }
    if (lastServerTs.present) {
      map['last_server_ts'] = Variable<String>(lastServerTs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncPointsCompanion(')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('lastServerTs: $lastServerTs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOpsTable extends PendingOps
    with TableInfo<$PendingOpsTable, PendingOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeNameMeta = const VerificationMeta(
    'scopeName',
  );
  @override
  late final GeneratedColumn<String> scopeName = GeneratedColumn<String>(
    'scope_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeKeysMeta = const VerificationMeta(
    'scopeKeys',
  );
  @override
  late final GeneratedColumn<String> scopeKeys = GeneratedColumn<String>(
    'scope_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    opId,
    scopeName,
    scopeKeys,
    type,
    id,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('scope_name')) {
      context.handle(
        _scopeNameMeta,
        scopeName.isAcceptableOrUnknown(data['scope_name']!, _scopeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeNameMeta);
    }
    if (data.containsKey('scope_keys')) {
      context.handle(
        _scopeKeysMeta,
        scopeKeys.isAcceptableOrUnknown(data['scope_keys']!, _scopeKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeKeysMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  PendingOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOp(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      scopeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_name'],
      )!,
      scopeKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_keys'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingOpsTable createAlias(String alias) {
    return $PendingOpsTable(attachedDatabase, alias);
  }
}

class PendingOp extends DataClass implements Insertable<PendingOp> {
  final String opId;
  final String scopeName;
  final String scopeKeys;
  final String type;
  final String id;
  final String? payload;
  final String updatedAt;
  const PendingOp({
    required this.opId,
    required this.scopeName,
    required this.scopeKeys,
    required this.type,
    required this.id,
    this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['scope_name'] = Variable<String>(scopeName);
    map['scope_keys'] = Variable<String>(scopeKeys);
    map['type'] = Variable<String>(type);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PendingOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingOpsCompanion(
      opId: Value(opId),
      scopeName: Value(scopeName),
      scopeKeys: Value(scopeKeys),
      type: Value(type),
      id: Value(id),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOp(
      opId: serializer.fromJson<String>(json['opId']),
      scopeName: serializer.fromJson<String>(json['scopeName']),
      scopeKeys: serializer.fromJson<String>(json['scopeKeys']),
      type: serializer.fromJson<String>(json['type']),
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String?>(json['payload']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'scopeName': serializer.toJson<String>(scopeName),
      'scopeKeys': serializer.toJson<String>(scopeKeys),
      'type': serializer.toJson<String>(type),
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String?>(payload),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PendingOp copyWith({
    String? opId,
    String? scopeName,
    String? scopeKeys,
    String? type,
    String? id,
    Value<String?> payload = const Value.absent(),
    String? updatedAt,
  }) => PendingOp(
    opId: opId ?? this.opId,
    scopeName: scopeName ?? this.scopeName,
    scopeKeys: scopeKeys ?? this.scopeKeys,
    type: type ?? this.type,
    id: id ?? this.id,
    payload: payload.present ? payload.value : this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingOp copyWithCompanion(PendingOpsCompanion data) {
    return PendingOp(
      opId: data.opId.present ? data.opId.value : this.opId,
      scopeName: data.scopeName.present ? data.scopeName.value : this.scopeName,
      scopeKeys: data.scopeKeys.present ? data.scopeKeys.value : this.scopeKeys,
      type: data.type.present ? data.type.value : this.type,
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOp(')
          ..write('opId: $opId, ')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(opId, scopeName, scopeKeys, type, id, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOp &&
          other.opId == this.opId &&
          other.scopeName == this.scopeName &&
          other.scopeKeys == this.scopeKeys &&
          other.type == this.type &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOp> {
  final Value<String> opId;
  final Value<String> scopeName;
  final Value<String> scopeKeys;
  final Value<String> type;
  final Value<String> id;
  final Value<String?> payload;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PendingOpsCompanion({
    this.opId = const Value.absent(),
    this.scopeName = const Value.absent(),
    this.scopeKeys = const Value.absent(),
    this.type = const Value.absent(),
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    required String opId,
    required String scopeName,
    required String scopeKeys,
    required String type,
    required String id,
    this.payload = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : opId = Value(opId),
       scopeName = Value(scopeName),
       scopeKeys = Value(scopeKeys),
       type = Value(type),
       id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<PendingOp> custom({
    Expression<String>? opId,
    Expression<String>? scopeName,
    Expression<String>? scopeKeys,
    Expression<String>? type,
    Expression<String>? id,
    Expression<String>? payload,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (scopeName != null) 'scope_name': scopeName,
      if (scopeKeys != null) 'scope_keys': scopeKeys,
      if (type != null) 'type': type,
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOpsCompanion copyWith({
    Value<String>? opId,
    Value<String>? scopeName,
    Value<String>? scopeKeys,
    Value<String>? type,
    Value<String>? id,
    Value<String?>? payload,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingOpsCompanion(
      opId: opId ?? this.opId,
      scopeName: scopeName ?? this.scopeName,
      scopeKeys: scopeKeys ?? this.scopeKeys,
      type: type ?? this.type,
      id: id ?? this.id,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (scopeName.present) {
      map['scope_name'] = Variable<String>(scopeName.value);
    }
    if (scopeKeys.present) {
      map['scope_keys'] = Variable<String>(scopeKeys.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpsCompanion(')
          ..write('opId: $opId, ')
          ..write('scopeName: $scopeName, ')
          ..write('scopeKeys: $scopeKeys, ')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDriftDatabase extends GeneratedDatabase {
  _$LocalDriftDatabase(QueryExecutor e) : super(e);
  $LocalDriftDatabaseManager get managers => $LocalDriftDatabaseManager(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $SyncPointsTable syncPoints = $SyncPointsTable(this);
  late final $PendingOpsTable pendingOps = $PendingOpsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    items,
    syncPoints,
    pendingOps,
  ];
}

typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String scopeName,
      required String scopeKeys,
      required String id,
      required String payload,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> scopeName,
      Value<String> scopeKeys,
      Value<String> id,
      Value<String> payload,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer
    extends Composer<_$LocalDriftDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$LocalDriftDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$LocalDriftDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scopeName =>
      $composableBuilder(column: $table.scopeName, builder: (column) => column);

  GeneratedColumn<String> get scopeKeys =>
      $composableBuilder(column: $table.scopeKeys, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$LocalDriftDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, BaseReferences<_$LocalDriftDatabase, $ItemsTable, Item>),
          Item,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$LocalDriftDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scopeName = const Value.absent(),
                Value<String> scopeKeys = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                id: id,
                payload: payload,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scopeName,
                required String scopeKeys,
                required String id,
                required String payload,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                id: id,
                payload: payload,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDriftDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, BaseReferences<_$LocalDriftDatabase, $ItemsTable, Item>),
      Item,
      PrefetchHooks Function()
    >;
typedef $$SyncPointsTableCreateCompanionBuilder =
    SyncPointsCompanion Function({
      required String scopeName,
      required String scopeKeys,
      required String lastServerTs,
      Value<int> rowid,
    });
typedef $$SyncPointsTableUpdateCompanionBuilder =
    SyncPointsCompanion Function({
      Value<String> scopeName,
      Value<String> scopeKeys,
      Value<String> lastServerTs,
      Value<int> rowid,
    });

class $$SyncPointsTableFilterComposer
    extends Composer<_$LocalDriftDatabase, $SyncPointsTable> {
  $$SyncPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastServerTs => $composableBuilder(
    column: $table.lastServerTs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncPointsTableOrderingComposer
    extends Composer<_$LocalDriftDatabase, $SyncPointsTable> {
  $$SyncPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastServerTs => $composableBuilder(
    column: $table.lastServerTs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncPointsTableAnnotationComposer
    extends Composer<_$LocalDriftDatabase, $SyncPointsTable> {
  $$SyncPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scopeName =>
      $composableBuilder(column: $table.scopeName, builder: (column) => column);

  GeneratedColumn<String> get scopeKeys =>
      $composableBuilder(column: $table.scopeKeys, builder: (column) => column);

  GeneratedColumn<String> get lastServerTs => $composableBuilder(
    column: $table.lastServerTs,
    builder: (column) => column,
  );
}

class $$SyncPointsTableTableManager
    extends
        RootTableManager<
          _$LocalDriftDatabase,
          $SyncPointsTable,
          SyncPoint,
          $$SyncPointsTableFilterComposer,
          $$SyncPointsTableOrderingComposer,
          $$SyncPointsTableAnnotationComposer,
          $$SyncPointsTableCreateCompanionBuilder,
          $$SyncPointsTableUpdateCompanionBuilder,
          (
            SyncPoint,
            BaseReferences<_$LocalDriftDatabase, $SyncPointsTable, SyncPoint>,
          ),
          SyncPoint,
          PrefetchHooks Function()
        > {
  $$SyncPointsTableTableManager(_$LocalDriftDatabase db, $SyncPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scopeName = const Value.absent(),
                Value<String> scopeKeys = const Value.absent(),
                Value<String> lastServerTs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncPointsCompanion(
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                lastServerTs: lastServerTs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scopeName,
                required String scopeKeys,
                required String lastServerTs,
                Value<int> rowid = const Value.absent(),
              }) => SyncPointsCompanion.insert(
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                lastServerTs: lastServerTs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDriftDatabase,
      $SyncPointsTable,
      SyncPoint,
      $$SyncPointsTableFilterComposer,
      $$SyncPointsTableOrderingComposer,
      $$SyncPointsTableAnnotationComposer,
      $$SyncPointsTableCreateCompanionBuilder,
      $$SyncPointsTableUpdateCompanionBuilder,
      (
        SyncPoint,
        BaseReferences<_$LocalDriftDatabase, $SyncPointsTable, SyncPoint>,
      ),
      SyncPoint,
      PrefetchHooks Function()
    >;
typedef $$PendingOpsTableCreateCompanionBuilder =
    PendingOpsCompanion Function({
      required String opId,
      required String scopeName,
      required String scopeKeys,
      required String type,
      required String id,
      Value<String?> payload,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$PendingOpsTableUpdateCompanionBuilder =
    PendingOpsCompanion Function({
      Value<String> opId,
      Value<String> scopeName,
      Value<String> scopeKeys,
      Value<String> type,
      Value<String> id,
      Value<String?> payload,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$PendingOpsTableFilterComposer
    extends Composer<_$LocalDriftDatabase, $PendingOpsTable> {
  $$PendingOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOpsTableOrderingComposer
    extends Composer<_$LocalDriftDatabase, $PendingOpsTable> {
  $$PendingOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeName => $composableBuilder(
    column: $table.scopeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeKeys => $composableBuilder(
    column: $table.scopeKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOpsTableAnnotationComposer
    extends Composer<_$LocalDriftDatabase, $PendingOpsTable> {
  $$PendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get scopeName =>
      $composableBuilder(column: $table.scopeName, builder: (column) => column);

  GeneratedColumn<String> get scopeKeys =>
      $composableBuilder(column: $table.scopeKeys, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingOpsTableTableManager
    extends
        RootTableManager<
          _$LocalDriftDatabase,
          $PendingOpsTable,
          PendingOp,
          $$PendingOpsTableFilterComposer,
          $$PendingOpsTableOrderingComposer,
          $$PendingOpsTableAnnotationComposer,
          $$PendingOpsTableCreateCompanionBuilder,
          $$PendingOpsTableUpdateCompanionBuilder,
          (
            PendingOp,
            BaseReferences<_$LocalDriftDatabase, $PendingOpsTable, PendingOp>,
          ),
          PendingOp,
          PrefetchHooks Function()
        > {
  $$PendingOpsTableTableManager(_$LocalDriftDatabase db, $PendingOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<String> scopeName = const Value.absent(),
                Value<String> scopeKeys = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOpsCompanion(
                opId: opId,
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                type: type,
                id: id,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                required String scopeName,
                required String scopeKeys,
                required String type,
                required String id,
                Value<String?> payload = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingOpsCompanion.insert(
                opId: opId,
                scopeName: scopeName,
                scopeKeys: scopeKeys,
                type: type,
                id: id,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDriftDatabase,
      $PendingOpsTable,
      PendingOp,
      $$PendingOpsTableFilterComposer,
      $$PendingOpsTableOrderingComposer,
      $$PendingOpsTableAnnotationComposer,
      $$PendingOpsTableCreateCompanionBuilder,
      $$PendingOpsTableUpdateCompanionBuilder,
      (
        PendingOp,
        BaseReferences<_$LocalDriftDatabase, $PendingOpsTable, PendingOp>,
      ),
      PendingOp,
      PrefetchHooks Function()
    >;

class $LocalDriftDatabaseManager {
  final _$LocalDriftDatabase _db;
  $LocalDriftDatabaseManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$SyncPointsTableTableManager get syncPoints =>
      $$SyncPointsTableTableManager(_db, _db.syncPoints);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db, _db.pendingOps);
}
