// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _handleMeta = const VerificationMeta('handle');
  @override
  late final GeneratedColumn<String> handle = GeneratedColumn<String>(
      'handle', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
      'vendor', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productTypeMeta =
      const VerificationMeta('productType');
  @override
  late final GeneratedColumn<String> productType = GeneratedColumn<String>(
      'product_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
      'images', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _descriptionHtmlMeta =
      const VerificationMeta('descriptionHtml');
  @override
  late final GeneratedColumn<String> descriptionHtml = GeneratedColumn<String>(
      'description_html', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _collectionHandlesMeta =
      const VerificationMeta('collectionHandles');
  @override
  late final GeneratedColumn<String> collectionHandles =
      GeneratedColumn<String>('collection_handles', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _brandOverrideMeta =
      const VerificationMeta('brandOverride');
  @override
  late final GeneratedColumn<String> brandOverride = GeneratedColumn<String>(
      'brand_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryOverrideMeta =
      const VerificationMeta('categoryOverride');
  @override
  late final GeneratedColumn<String> categoryOverride = GeneratedColumn<String>(
      'category_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        handle,
        title,
        vendor,
        productType,
        tags,
        images,
        descriptionHtml,
        collectionHandles,
        brandOverride,
        categoryOverride,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(Insertable<CachedProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('handle')) {
      context.handle(_handleMeta,
          handle.isAcceptableOrUnknown(data['handle']!, _handleMeta));
    } else if (isInserting) {
      context.missing(_handleMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('vendor')) {
      context.handle(_vendorMeta,
          vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta));
    } else if (isInserting) {
      context.missing(_vendorMeta);
    }
    if (data.containsKey('product_type')) {
      context.handle(
          _productTypeMeta,
          productType.isAcceptableOrUnknown(
              data['product_type']!, _productTypeMeta));
    } else if (isInserting) {
      context.missing(_productTypeMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('images')) {
      context.handle(_imagesMeta,
          images.isAcceptableOrUnknown(data['images']!, _imagesMeta));
    }
    if (data.containsKey('description_html')) {
      context.handle(
          _descriptionHtmlMeta,
          descriptionHtml.isAcceptableOrUnknown(
              data['description_html']!, _descriptionHtmlMeta));
    }
    if (data.containsKey('collection_handles')) {
      context.handle(
          _collectionHandlesMeta,
          collectionHandles.isAcceptableOrUnknown(
              data['collection_handles']!, _collectionHandlesMeta));
    }
    if (data.containsKey('brand_override')) {
      context.handle(
          _brandOverrideMeta,
          brandOverride.isAcceptableOrUnknown(
              data['brand_override']!, _brandOverrideMeta));
    }
    if (data.containsKey('category_override')) {
      context.handle(
          _categoryOverrideMeta,
          categoryOverride.isAcceptableOrUnknown(
              data['category_override']!, _categoryOverrideMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      handle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}handle'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      vendor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vendor'])!,
      productType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_type'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      images: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}images'])!,
      descriptionHtml: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}description_html'])!,
      collectionHandles: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}collection_handles'])!,
      brandOverride: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand_override']),
      categoryOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}category_override']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String id;
  final String handle;
  final String title;
  final String vendor;
  final String productType;

  /// JSON-encoded `List<String>`.
  final String tags;

  /// JSON-encoded `List<String>`.
  final String images;
  final String descriptionHtml;

  /// JSON-encoded `List<String>`.
  final String collectionHandles;
  final String? brandOverride;
  final String? categoryOverride;
  final DateTime createdAt;

  /// Drives delta sync — see `SyncCursors` and
  /// `lib/data/shopify/catalog_sync.dart`.
  final DateTime updatedAt;
  const CachedProduct(
      {required this.id,
      required this.handle,
      required this.title,
      required this.vendor,
      required this.productType,
      required this.tags,
      required this.images,
      required this.descriptionHtml,
      required this.collectionHandles,
      this.brandOverride,
      this.categoryOverride,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['handle'] = Variable<String>(handle);
    map['title'] = Variable<String>(title);
    map['vendor'] = Variable<String>(vendor);
    map['product_type'] = Variable<String>(productType);
    map['tags'] = Variable<String>(tags);
    map['images'] = Variable<String>(images);
    map['description_html'] = Variable<String>(descriptionHtml);
    map['collection_handles'] = Variable<String>(collectionHandles);
    if (!nullToAbsent || brandOverride != null) {
      map['brand_override'] = Variable<String>(brandOverride);
    }
    if (!nullToAbsent || categoryOverride != null) {
      map['category_override'] = Variable<String>(categoryOverride);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      id: Value(id),
      handle: Value(handle),
      title: Value(title),
      vendor: Value(vendor),
      productType: Value(productType),
      tags: Value(tags),
      images: Value(images),
      descriptionHtml: Value(descriptionHtml),
      collectionHandles: Value(collectionHandles),
      brandOverride: brandOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(brandOverride),
      categoryOverride: categoryOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryOverride),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      id: serializer.fromJson<String>(json['id']),
      handle: serializer.fromJson<String>(json['handle']),
      title: serializer.fromJson<String>(json['title']),
      vendor: serializer.fromJson<String>(json['vendor']),
      productType: serializer.fromJson<String>(json['productType']),
      tags: serializer.fromJson<String>(json['tags']),
      images: serializer.fromJson<String>(json['images']),
      descriptionHtml: serializer.fromJson<String>(json['descriptionHtml']),
      collectionHandles: serializer.fromJson<String>(json['collectionHandles']),
      brandOverride: serializer.fromJson<String?>(json['brandOverride']),
      categoryOverride: serializer.fromJson<String?>(json['categoryOverride']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'handle': serializer.toJson<String>(handle),
      'title': serializer.toJson<String>(title),
      'vendor': serializer.toJson<String>(vendor),
      'productType': serializer.toJson<String>(productType),
      'tags': serializer.toJson<String>(tags),
      'images': serializer.toJson<String>(images),
      'descriptionHtml': serializer.toJson<String>(descriptionHtml),
      'collectionHandles': serializer.toJson<String>(collectionHandles),
      'brandOverride': serializer.toJson<String?>(brandOverride),
      'categoryOverride': serializer.toJson<String?>(categoryOverride),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedProduct copyWith(
          {String? id,
          String? handle,
          String? title,
          String? vendor,
          String? productType,
          String? tags,
          String? images,
          String? descriptionHtml,
          String? collectionHandles,
          Value<String?> brandOverride = const Value.absent(),
          Value<String?> categoryOverride = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      CachedProduct(
        id: id ?? this.id,
        handle: handle ?? this.handle,
        title: title ?? this.title,
        vendor: vendor ?? this.vendor,
        productType: productType ?? this.productType,
        tags: tags ?? this.tags,
        images: images ?? this.images,
        descriptionHtml: descriptionHtml ?? this.descriptionHtml,
        collectionHandles: collectionHandles ?? this.collectionHandles,
        brandOverride:
            brandOverride.present ? brandOverride.value : this.brandOverride,
        categoryOverride: categoryOverride.present
            ? categoryOverride.value
            : this.categoryOverride,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      id: data.id.present ? data.id.value : this.id,
      handle: data.handle.present ? data.handle.value : this.handle,
      title: data.title.present ? data.title.value : this.title,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      productType:
          data.productType.present ? data.productType.value : this.productType,
      tags: data.tags.present ? data.tags.value : this.tags,
      images: data.images.present ? data.images.value : this.images,
      descriptionHtml: data.descriptionHtml.present
          ? data.descriptionHtml.value
          : this.descriptionHtml,
      collectionHandles: data.collectionHandles.present
          ? data.collectionHandles.value
          : this.collectionHandles,
      brandOverride: data.brandOverride.present
          ? data.brandOverride.value
          : this.brandOverride,
      categoryOverride: data.categoryOverride.present
          ? data.categoryOverride.value
          : this.categoryOverride,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('id: $id, ')
          ..write('handle: $handle, ')
          ..write('title: $title, ')
          ..write('vendor: $vendor, ')
          ..write('productType: $productType, ')
          ..write('tags: $tags, ')
          ..write('images: $images, ')
          ..write('descriptionHtml: $descriptionHtml, ')
          ..write('collectionHandles: $collectionHandles, ')
          ..write('brandOverride: $brandOverride, ')
          ..write('categoryOverride: $categoryOverride, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      handle,
      title,
      vendor,
      productType,
      tags,
      images,
      descriptionHtml,
      collectionHandles,
      brandOverride,
      categoryOverride,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.id == this.id &&
          other.handle == this.handle &&
          other.title == this.title &&
          other.vendor == this.vendor &&
          other.productType == this.productType &&
          other.tags == this.tags &&
          other.images == this.images &&
          other.descriptionHtml == this.descriptionHtml &&
          other.collectionHandles == this.collectionHandles &&
          other.brandOverride == this.brandOverride &&
          other.categoryOverride == this.categoryOverride &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> id;
  final Value<String> handle;
  final Value<String> title;
  final Value<String> vendor;
  final Value<String> productType;
  final Value<String> tags;
  final Value<String> images;
  final Value<String> descriptionHtml;
  final Value<String> collectionHandles;
  final Value<String?> brandOverride;
  final Value<String?> categoryOverride;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.id = const Value.absent(),
    this.handle = const Value.absent(),
    this.title = const Value.absent(),
    this.vendor = const Value.absent(),
    this.productType = const Value.absent(),
    this.tags = const Value.absent(),
    this.images = const Value.absent(),
    this.descriptionHtml = const Value.absent(),
    this.collectionHandles = const Value.absent(),
    this.brandOverride = const Value.absent(),
    this.categoryOverride = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String id,
    required String handle,
    required String title,
    required String vendor,
    required String productType,
    this.tags = const Value.absent(),
    this.images = const Value.absent(),
    this.descriptionHtml = const Value.absent(),
    this.collectionHandles = const Value.absent(),
    this.brandOverride = const Value.absent(),
    this.categoryOverride = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        handle = Value(handle),
        title = Value(title),
        vendor = Value(vendor),
        productType = Value(productType),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CachedProduct> custom({
    Expression<String>? id,
    Expression<String>? handle,
    Expression<String>? title,
    Expression<String>? vendor,
    Expression<String>? productType,
    Expression<String>? tags,
    Expression<String>? images,
    Expression<String>? descriptionHtml,
    Expression<String>? collectionHandles,
    Expression<String>? brandOverride,
    Expression<String>? categoryOverride,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (handle != null) 'handle': handle,
      if (title != null) 'title': title,
      if (vendor != null) 'vendor': vendor,
      if (productType != null) 'product_type': productType,
      if (tags != null) 'tags': tags,
      if (images != null) 'images': images,
      if (descriptionHtml != null) 'description_html': descriptionHtml,
      if (collectionHandles != null) 'collection_handles': collectionHandles,
      if (brandOverride != null) 'brand_override': brandOverride,
      if (categoryOverride != null) 'category_override': categoryOverride,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? handle,
      Value<String>? title,
      Value<String>? vendor,
      Value<String>? productType,
      Value<String>? tags,
      Value<String>? images,
      Value<String>? descriptionHtml,
      Value<String>? collectionHandles,
      Value<String?>? brandOverride,
      Value<String?>? categoryOverride,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CachedProductsCompanion(
      id: id ?? this.id,
      handle: handle ?? this.handle,
      title: title ?? this.title,
      vendor: vendor ?? this.vendor,
      productType: productType ?? this.productType,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      descriptionHtml: descriptionHtml ?? this.descriptionHtml,
      collectionHandles: collectionHandles ?? this.collectionHandles,
      brandOverride: brandOverride ?? this.brandOverride,
      categoryOverride: categoryOverride ?? this.categoryOverride,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (handle.present) {
      map['handle'] = Variable<String>(handle.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (productType.present) {
      map['product_type'] = Variable<String>(productType.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (descriptionHtml.present) {
      map['description_html'] = Variable<String>(descriptionHtml.value);
    }
    if (collectionHandles.present) {
      map['collection_handles'] = Variable<String>(collectionHandles.value);
    }
    if (brandOverride.present) {
      map['brand_override'] = Variable<String>(brandOverride.value);
    }
    if (categoryOverride.present) {
      map['category_override'] = Variable<String>(categoryOverride.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('id: $id, ')
          ..write('handle: $handle, ')
          ..write('title: $title, ')
          ..write('vendor: $vendor, ')
          ..write('productType: $productType, ')
          ..write('tags: $tags, ')
          ..write('images: $images, ')
          ..write('descriptionHtml: $descriptionHtml, ')
          ..write('collectionHandles: $collectionHandles, ')
          ..write('brandOverride: $brandOverride, ')
          ..write('categoryOverride: $categoryOverride, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedVariantsTable extends CachedVariants
    with TableInfo<$CachedVariantsTable, CachedVariant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES cached_products (id) ON DELETE CASCADE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _compareAtPriceMeta =
      const VerificationMeta('compareAtPrice');
  @override
  late final GeneratedColumn<double> compareAtPrice = GeneratedColumn<double>(
      'compare_at_price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _availableMeta =
      const VerificationMeta('available');
  @override
  late final GeneratedColumn<bool> available = GeneratedColumn<bool>(
      'available', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("available" IN (0, 1))'));
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, productId, title, price, compareAtPrice, available, sku];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_variants';
  @override
  VerificationContext validateIntegrity(Insertable<CachedVariant> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('compare_at_price')) {
      context.handle(
          _compareAtPriceMeta,
          compareAtPrice.isAcceptableOrUnknown(
              data['compare_at_price']!, _compareAtPriceMeta));
    }
    if (data.containsKey('available')) {
      context.handle(_availableMeta,
          available.isAcceptableOrUnknown(data['available']!, _availableMeta));
    } else if (isInserting) {
      context.missing(_availableMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedVariant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVariant(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price'])!,
      compareAtPrice: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}compare_at_price']),
      available: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}available'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku']),
    );
  }

  @override
  $CachedVariantsTable createAlias(String alias) {
    return $CachedVariantsTable(attachedDatabase, alias);
  }
}

class CachedVariant extends DataClass implements Insertable<CachedVariant> {
  final String id;
  final String productId;
  final String title;
  final double price;
  final double? compareAtPrice;
  final bool available;
  final String? sku;
  const CachedVariant(
      {required this.id,
      required this.productId,
      required this.title,
      required this.price,
      this.compareAtPrice,
      required this.available,
      this.sku});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['title'] = Variable<String>(title);
    map['price'] = Variable<double>(price);
    if (!nullToAbsent || compareAtPrice != null) {
      map['compare_at_price'] = Variable<double>(compareAtPrice);
    }
    map['available'] = Variable<bool>(available);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    return map;
  }

  CachedVariantsCompanion toCompanion(bool nullToAbsent) {
    return CachedVariantsCompanion(
      id: Value(id),
      productId: Value(productId),
      title: Value(title),
      price: Value(price),
      compareAtPrice: compareAtPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(compareAtPrice),
      available: Value(available),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
    );
  }

  factory CachedVariant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVariant(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      title: serializer.fromJson<String>(json['title']),
      price: serializer.fromJson<double>(json['price']),
      compareAtPrice: serializer.fromJson<double?>(json['compareAtPrice']),
      available: serializer.fromJson<bool>(json['available']),
      sku: serializer.fromJson<String?>(json['sku']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'title': serializer.toJson<String>(title),
      'price': serializer.toJson<double>(price),
      'compareAtPrice': serializer.toJson<double?>(compareAtPrice),
      'available': serializer.toJson<bool>(available),
      'sku': serializer.toJson<String?>(sku),
    };
  }

  CachedVariant copyWith(
          {String? id,
          String? productId,
          String? title,
          double? price,
          Value<double?> compareAtPrice = const Value.absent(),
          bool? available,
          Value<String?> sku = const Value.absent()}) =>
      CachedVariant(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        title: title ?? this.title,
        price: price ?? this.price,
        compareAtPrice:
            compareAtPrice.present ? compareAtPrice.value : this.compareAtPrice,
        available: available ?? this.available,
        sku: sku.present ? sku.value : this.sku,
      );
  CachedVariant copyWithCompanion(CachedVariantsCompanion data) {
    return CachedVariant(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      title: data.title.present ? data.title.value : this.title,
      price: data.price.present ? data.price.value : this.price,
      compareAtPrice: data.compareAtPrice.present
          ? data.compareAtPrice.value
          : this.compareAtPrice,
      available: data.available.present ? data.available.value : this.available,
      sku: data.sku.present ? data.sku.value : this.sku,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVariant(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('title: $title, ')
          ..write('price: $price, ')
          ..write('compareAtPrice: $compareAtPrice, ')
          ..write('available: $available, ')
          ..write('sku: $sku')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, productId, title, price, compareAtPrice, available, sku);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVariant &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.title == this.title &&
          other.price == this.price &&
          other.compareAtPrice == this.compareAtPrice &&
          other.available == this.available &&
          other.sku == this.sku);
}

class CachedVariantsCompanion extends UpdateCompanion<CachedVariant> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> title;
  final Value<double> price;
  final Value<double?> compareAtPrice;
  final Value<bool> available;
  final Value<String?> sku;
  final Value<int> rowid;
  const CachedVariantsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.title = const Value.absent(),
    this.price = const Value.absent(),
    this.compareAtPrice = const Value.absent(),
    this.available = const Value.absent(),
    this.sku = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVariantsCompanion.insert({
    required String id,
    required String productId,
    required String title,
    required double price,
    this.compareAtPrice = const Value.absent(),
    required bool available,
    this.sku = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        title = Value(title),
        price = Value(price),
        available = Value(available);
  static Insertable<CachedVariant> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? title,
    Expression<double>? price,
    Expression<double>? compareAtPrice,
    Expression<bool>? available,
    Expression<String>? sku,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (title != null) 'title': title,
      if (price != null) 'price': price,
      if (compareAtPrice != null) 'compare_at_price': compareAtPrice,
      if (available != null) 'available': available,
      if (sku != null) 'sku': sku,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVariantsCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<String>? title,
      Value<double>? price,
      Value<double?>? compareAtPrice,
      Value<bool>? available,
      Value<String?>? sku,
      Value<int>? rowid}) {
    return CachedVariantsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      available: available ?? this.available,
      sku: sku ?? this.sku,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (compareAtPrice.present) {
      map['compare_at_price'] = Variable<double>(compareAtPrice.value);
    }
    if (available.present) {
      map['available'] = Variable<bool>(available.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVariantsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('title: $title, ')
          ..write('price: $price, ')
          ..write('compareAtPrice: $compareAtPrice, ')
          ..write('available: $available, ')
          ..write('sku: $sku, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCollectionsTable extends CachedCollections
    with TableInfo<$CachedCollectionsTable, CachedCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _handleMeta = const VerificationMeta('handle');
  @override
  late final GeneratedColumn<String> handle = GeneratedColumn<String>(
      'handle', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _productCountMeta =
      const VerificationMeta('productCount');
  @override
  late final GeneratedColumn<int> productCount = GeneratedColumn<int>(
      'product_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, handle, title, description, imageUrl, productCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_collections';
  @override
  VerificationContext validateIntegrity(Insertable<CachedCollection> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('handle')) {
      context.handle(_handleMeta,
          handle.isAcceptableOrUnknown(data['handle']!, _handleMeta));
    } else if (isInserting) {
      context.missing(_handleMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('product_count')) {
      context.handle(
          _productCountMeta,
          productCount.isAcceptableOrUnknown(
              data['product_count']!, _productCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCollection(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      handle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}handle'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      productCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_count']),
    );
  }

  @override
  $CachedCollectionsTable createAlias(String alias) {
    return $CachedCollectionsTable(attachedDatabase, alias);
  }
}

class CachedCollection extends DataClass
    implements Insertable<CachedCollection> {
  final String id;
  final String handle;
  final String title;
  final String description;
  final String? imageUrl;
  final int? productCount;
  const CachedCollection(
      {required this.id,
      required this.handle,
      required this.title,
      required this.description,
      this.imageUrl,
      this.productCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['handle'] = Variable<String>(handle);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || productCount != null) {
      map['product_count'] = Variable<int>(productCount);
    }
    return map;
  }

  CachedCollectionsCompanion toCompanion(bool nullToAbsent) {
    return CachedCollectionsCompanion(
      id: Value(id),
      handle: Value(handle),
      title: Value(title),
      description: Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      productCount: productCount == null && nullToAbsent
          ? const Value.absent()
          : Value(productCount),
    );
  }

  factory CachedCollection.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCollection(
      id: serializer.fromJson<String>(json['id']),
      handle: serializer.fromJson<String>(json['handle']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      productCount: serializer.fromJson<int?>(json['productCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'handle': serializer.toJson<String>(handle),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'productCount': serializer.toJson<int?>(productCount),
    };
  }

  CachedCollection copyWith(
          {String? id,
          String? handle,
          String? title,
          String? description,
          Value<String?> imageUrl = const Value.absent(),
          Value<int?> productCount = const Value.absent()}) =>
      CachedCollection(
        id: id ?? this.id,
        handle: handle ?? this.handle,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        productCount:
            productCount.present ? productCount.value : this.productCount,
      );
  CachedCollection copyWithCompanion(CachedCollectionsCompanion data) {
    return CachedCollection(
      id: data.id.present ? data.id.value : this.id,
      handle: data.handle.present ? data.handle.value : this.handle,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      productCount: data.productCount.present
          ? data.productCount.value
          : this.productCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollection(')
          ..write('id: $id, ')
          ..write('handle: $handle, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('productCount: $productCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, handle, title, description, imageUrl, productCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCollection &&
          other.id == this.id &&
          other.handle == this.handle &&
          other.title == this.title &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.productCount == this.productCount);
}

class CachedCollectionsCompanion extends UpdateCompanion<CachedCollection> {
  final Value<String> id;
  final Value<String> handle;
  final Value<String> title;
  final Value<String> description;
  final Value<String?> imageUrl;
  final Value<int?> productCount;
  final Value<int> rowid;
  const CachedCollectionsCompanion({
    this.id = const Value.absent(),
    this.handle = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.productCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCollectionsCompanion.insert({
    required String id,
    required String handle,
    required String title,
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.productCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        handle = Value(handle),
        title = Value(title);
  static Insertable<CachedCollection> custom({
    Expression<String>? id,
    Expression<String>? handle,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<int>? productCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (handle != null) 'handle': handle,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (productCount != null) 'product_count': productCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCollectionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? handle,
      Value<String>? title,
      Value<String>? description,
      Value<String?>? imageUrl,
      Value<int?>? productCount,
      Value<int>? rowid}) {
    return CachedCollectionsCompanion(
      id: id ?? this.id,
      handle: handle ?? this.handle,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      productCount: productCount ?? this.productCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (handle.present) {
      map['handle'] = Variable<String>(handle.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (productCount.present) {
      map['product_count'] = Variable<int>(productCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('handle: $handle, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('productCount: $productCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastUpdatedAtMeta =
      const VerificationMeta('lastUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> lastUpdatedAt =
      GeneratedColumn<DateTime>('last_updated_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastFullSyncAtMeta =
      const VerificationMeta('lastFullSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastFullSyncAt =
      GeneratedColumn<DateTime>('last_full_sync_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, lastUpdatedAt, lastFullSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursor> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_updated_at')) {
      context.handle(
          _lastUpdatedAtMeta,
          lastUpdatedAt.isAcceptableOrUnknown(
              data['last_updated_at']!, _lastUpdatedAtMeta));
    }
    if (data.containsKey('last_full_sync_at')) {
      context.handle(
          _lastFullSyncAtMeta,
          lastFullSyncAt.isAcceptableOrUnknown(
              data['last_full_sync_at']!, _lastFullSyncAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      lastUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_updated_at']),
      lastFullSyncAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_full_sync_at']),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final int id;
  final DateTime? lastUpdatedAt;
  final DateTime? lastFullSyncAt;
  const SyncCursor({required this.id, this.lastUpdatedAt, this.lastFullSyncAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastUpdatedAt != null) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt);
    }
    if (!nullToAbsent || lastFullSyncAt != null) {
      map['last_full_sync_at'] = Variable<DateTime>(lastFullSyncAt);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      id: Value(id),
      lastUpdatedAt: lastUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdatedAt),
      lastFullSyncAt: lastFullSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFullSyncAt),
    );
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      id: serializer.fromJson<int>(json['id']),
      lastUpdatedAt: serializer.fromJson<DateTime?>(json['lastUpdatedAt']),
      lastFullSyncAt: serializer.fromJson<DateTime?>(json['lastFullSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastUpdatedAt': serializer.toJson<DateTime?>(lastUpdatedAt),
      'lastFullSyncAt': serializer.toJson<DateTime?>(lastFullSyncAt),
    };
  }

  SyncCursor copyWith(
          {int? id,
          Value<DateTime?> lastUpdatedAt = const Value.absent(),
          Value<DateTime?> lastFullSyncAt = const Value.absent()}) =>
      SyncCursor(
        id: id ?? this.id,
        lastUpdatedAt:
            lastUpdatedAt.present ? lastUpdatedAt.value : this.lastUpdatedAt,
        lastFullSyncAt:
            lastFullSyncAt.present ? lastFullSyncAt.value : this.lastFullSyncAt,
      );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      id: data.id.present ? data.id.value : this.id,
      lastUpdatedAt: data.lastUpdatedAt.present
          ? data.lastUpdatedAt.value
          : this.lastUpdatedAt,
      lastFullSyncAt: data.lastFullSyncAt.present
          ? data.lastFullSyncAt.value
          : this.lastFullSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('id: $id, ')
          ..write('lastUpdatedAt: $lastUpdatedAt, ')
          ..write('lastFullSyncAt: $lastFullSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastUpdatedAt, lastFullSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.id == this.id &&
          other.lastUpdatedAt == this.lastUpdatedAt &&
          other.lastFullSyncAt == this.lastFullSyncAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<int> id;
  final Value<DateTime?> lastUpdatedAt;
  final Value<DateTime?> lastFullSyncAt;
  const SyncCursorsCompanion({
    this.id = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    this.id = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
  });
  static Insertable<SyncCursor> custom({
    Expression<int>? id,
    Expression<DateTime>? lastUpdatedAt,
    Expression<DateTime>? lastFullSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastUpdatedAt != null) 'last_updated_at': lastUpdatedAt,
      if (lastFullSyncAt != null) 'last_full_sync_at': lastFullSyncAt,
    });
  }

  SyncCursorsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime?>? lastUpdatedAt,
      Value<DateTime?>? lastFullSyncAt}) {
    return SyncCursorsCompanion(
      id: id ?? this.id,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastUpdatedAt.present) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt.value);
    }
    if (lastFullSyncAt.present) {
      map['last_full_sync_at'] = Variable<DateTime>(lastFullSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('id: $id, ')
          ..write('lastUpdatedAt: $lastUpdatedAt, ')
          ..write('lastFullSyncAt: $lastFullSyncAt')
          ..write(')'))
        .toString();
  }
}

class $CatalogStatesTable extends CatalogStates
    with TableInfo<$CatalogStatesTable, CatalogState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _productCountMeta =
      const VerificationMeta('productCount');
  @override
  late final GeneratedColumn<int> productCount = GeneratedColumn<int>(
      'product_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fingerprintMeta =
      const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
      'fingerprint', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
      'detail', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, source, syncedAt, productCount, fingerprint, status, detail];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_states';
  @override
  VerificationContext validateIntegrity(Insertable<CatalogState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('product_count')) {
      context.handle(
          _productCountMeta,
          productCount.isAcceptableOrUnknown(
              data['product_count']!, _productCountMeta));
    } else if (isInserting) {
      context.missing(_productCountMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
          _fingerprintMeta,
          fingerprint.isAcceptableOrUnknown(
              data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(_detailMeta,
          detail.isAcceptableOrUnknown(data['detail']!, _detailMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogState(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      productCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_count'])!,
      fingerprint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      detail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}detail']),
    );
  }

  @override
  $CatalogStatesTable createAlias(String alias) {
    return $CatalogStatesTable(attachedDatabase, alias);
  }
}

class CatalogState extends DataClass implements Insertable<CatalogState> {
  final int id;
  final String source;
  final DateTime? syncedAt;
  final int productCount;
  final String fingerprint;
  final String status;
  final String? detail;
  const CatalogState(
      {required this.id,
      required this.source,
      this.syncedAt,
      required this.productCount,
      required this.fingerprint,
      required this.status,
      this.detail});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['product_count'] = Variable<int>(productCount);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  CatalogStatesCompanion toCompanion(bool nullToAbsent) {
    return CatalogStatesCompanion(
      id: Value(id),
      source: Value(source),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      productCount: Value(productCount),
      fingerprint: Value(fingerprint),
      status: Value(status),
      detail:
          detail == null && nullToAbsent ? const Value.absent() : Value(detail),
    );
  }

  factory CatalogState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogState(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      productCount: serializer.fromJson<int>(json['productCount']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      status: serializer.fromJson<String>(json['status']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'productCount': serializer.toJson<int>(productCount),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'status': serializer.toJson<String>(status),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  CatalogState copyWith(
          {int? id,
          String? source,
          Value<DateTime?> syncedAt = const Value.absent(),
          int? productCount,
          String? fingerprint,
          String? status,
          Value<String?> detail = const Value.absent()}) =>
      CatalogState(
        id: id ?? this.id,
        source: source ?? this.source,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        productCount: productCount ?? this.productCount,
        fingerprint: fingerprint ?? this.fingerprint,
        status: status ?? this.status,
        detail: detail.present ? detail.value : this.detail,
      );
  CatalogState copyWithCompanion(CatalogStatesCompanion data) {
    return CatalogState(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      productCount: data.productCount.present
          ? data.productCount.value
          : this.productCount,
      fingerprint:
          data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      status: data.status.present ? data.status.value : this.status,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogState(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('productCount: $productCount, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('status: $status, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, source, syncedAt, productCount, fingerprint, status, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogState &&
          other.id == this.id &&
          other.source == this.source &&
          other.syncedAt == this.syncedAt &&
          other.productCount == this.productCount &&
          other.fingerprint == this.fingerprint &&
          other.status == this.status &&
          other.detail == this.detail);
}

class CatalogStatesCompanion extends UpdateCompanion<CatalogState> {
  final Value<int> id;
  final Value<String> source;
  final Value<DateTime?> syncedAt;
  final Value<int> productCount;
  final Value<String> fingerprint;
  final Value<String> status;
  final Value<String?> detail;
  const CatalogStatesCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.productCount = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.status = const Value.absent(),
    this.detail = const Value.absent(),
  });
  CatalogStatesCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    this.syncedAt = const Value.absent(),
    required int productCount,
    required String fingerprint,
    required String status,
    this.detail = const Value.absent(),
  })  : source = Value(source),
        productCount = Value(productCount),
        fingerprint = Value(fingerprint),
        status = Value(status);
  static Insertable<CatalogState> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<DateTime>? syncedAt,
    Expression<int>? productCount,
    Expression<String>? fingerprint,
    Expression<String>? status,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (productCount != null) 'product_count': productCount,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (status != null) 'status': status,
      if (detail != null) 'detail': detail,
    });
  }

  CatalogStatesCompanion copyWith(
      {Value<int>? id,
      Value<String>? source,
      Value<DateTime?>? syncedAt,
      Value<int>? productCount,
      Value<String>? fingerprint,
      Value<String>? status,
      Value<String?>? detail}) {
    return CatalogStatesCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      syncedAt: syncedAt ?? this.syncedAt,
      productCount: productCount ?? this.productCount,
      fingerprint: fingerprint ?? this.fingerprint,
      status: status ?? this.status,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (productCount.present) {
      map['product_count'] = Variable<int>(productCount.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogStatesCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('productCount: $productCount, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('status: $status, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _themeModeMeta =
      const VerificationMeta('themeMode');
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
      'theme_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('system'));
  static const VerificationMeta _onboardingStateMeta =
      const VerificationMeta('onboardingState');
  @override
  late final GeneratedColumn<String> onboardingState = GeneratedColumn<String>(
      'onboarding_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns => [id, themeMode, onboardingState];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<AppPreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(_themeModeMeta,
          themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta));
    }
    if (data.containsKey('onboarding_state')) {
      context.handle(
          _onboardingStateMeta,
          onboardingState.isAcceptableOrUnknown(
              data['onboarding_state']!, _onboardingStateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      themeMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme_mode'])!,
      onboardingState: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}onboarding_state'])!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final int id;
  final String themeMode;
  final String onboardingState;
  const AppPreference(
      {required this.id,
      required this.themeMode,
      required this.onboardingState});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode'] = Variable<String>(themeMode);
    map['onboarding_state'] = Variable<String>(onboardingState);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      onboardingState: Value(onboardingState),
    );
  }

  factory AppPreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      id: serializer.fromJson<int>(json['id']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      onboardingState: serializer.fromJson<String>(json['onboardingState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<String>(themeMode),
      'onboardingState': serializer.toJson<String>(onboardingState),
    };
  }

  AppPreference copyWith(
          {int? id, String? themeMode, String? onboardingState}) =>
      AppPreference(
        id: id ?? this.id,
        themeMode: themeMode ?? this.themeMode,
        onboardingState: onboardingState ?? this.onboardingState,
      );
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      onboardingState: data.onboardingState.present
          ? data.onboardingState.value
          : this.onboardingState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('onboardingState: $onboardingState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, themeMode, onboardingState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.onboardingState == this.onboardingState);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<int> id;
  final Value<String> themeMode;
  final Value<String> onboardingState;
  const AppPreferencesCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.onboardingState = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.onboardingState = const Value.absent(),
  });
  static Insertable<AppPreference> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
    Expression<String>? onboardingState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (onboardingState != null) 'onboarding_state': onboardingState,
    });
  }

  AppPreferencesCompanion copyWith(
      {Value<int>? id,
      Value<String>? themeMode,
      Value<String>? onboardingState}) {
    return AppPreferencesCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      onboardingState: onboardingState ?? this.onboardingState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (onboardingState.present) {
      map['onboarding_state'] = Variable<String>(onboardingState.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('onboardingState: $onboardingState')
          ..write(')'))
        .toString();
  }
}

class $WishlistItemsTable extends WishlistItems
    with TableInfo<$WishlistItemsTable, WishlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [productId, accountId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist_items';
  @override
  VerificationContext validateIntegrity(Insertable<WishlistItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  WishlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishlistItem(
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $WishlistItemsTable createAlias(String alias) {
    return $WishlistItemsTable(attachedDatabase, alias);
  }
}

class WishlistItem extends DataClass implements Insertable<WishlistItem> {
  final String productId;
  final String? accountId;
  final DateTime addedAt;
  const WishlistItem(
      {required this.productId, this.accountId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WishlistItemsCompanion toCompanion(bool nullToAbsent) {
    return WishlistItemsCompanion(
      productId: Value(productId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      addedAt: Value(addedAt),
    );
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishlistItem(
      productId: serializer.fromJson<String>(json['productId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'accountId': serializer.toJson<String?>(accountId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WishlistItem copyWith(
          {String? productId,
          Value<String?> accountId = const Value.absent(),
          DateTime? addedAt}) =>
      WishlistItem(
        productId: productId ?? this.productId,
        accountId: accountId.present ? accountId.value : this.accountId,
        addedAt: addedAt ?? this.addedAt,
      );
  WishlistItem copyWithCompanion(WishlistItemsCompanion data) {
    return WishlistItem(
      productId: data.productId.present ? data.productId.value : this.productId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItem(')
          ..write('productId: $productId, ')
          ..write('accountId: $accountId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(productId, accountId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistItem &&
          other.productId == this.productId &&
          other.accountId == this.accountId &&
          other.addedAt == this.addedAt);
}

class WishlistItemsCompanion extends UpdateCompanion<WishlistItem> {
  final Value<String> productId;
  final Value<String?> accountId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const WishlistItemsCompanion({
    this.productId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishlistItemsCompanion.insert({
    required String productId,
    this.accountId = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : productId = Value(productId),
        addedAt = Value(addedAt);
  static Insertable<WishlistItem> custom({
    Expression<String>? productId,
    Expression<String>? accountId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (accountId != null) 'account_id': accountId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishlistItemsCompanion copyWith(
      {Value<String>? productId,
      Value<String?>? accountId,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return WishlistItemsCompanion(
      productId: productId ?? this.productId,
      accountId: accountId ?? this.accountId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItemsCompanion(')
          ..write('productId: $productId, ')
          ..write('accountId: $accountId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BagLinesTable extends BagLines with TableInfo<$BagLinesTable, BagLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BagLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _variantIdMeta =
      const VerificationMeta('variantId');
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
      'variant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [productId, variantId, accountId, quantity];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bag_lines';
  @override
  VerificationContext validateIntegrity(Insertable<BagLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(_variantIdMeta,
          variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta));
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  BagLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BagLine(
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      variantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}variant_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
    );
  }

  @override
  $BagLinesTable createAlias(String alias) {
    return $BagLinesTable(attachedDatabase, alias);
  }
}

class BagLine extends DataClass implements Insertable<BagLine> {
  final String productId;
  final String variantId;
  final String? accountId;
  final int quantity;
  const BagLine(
      {required this.productId,
      required this.variantId,
      this.accountId,
      required this.quantity});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['variant_id'] = Variable<String>(variantId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['quantity'] = Variable<int>(quantity);
    return map;
  }

  BagLinesCompanion toCompanion(bool nullToAbsent) {
    return BagLinesCompanion(
      productId: Value(productId),
      variantId: Value(variantId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      quantity: Value(quantity),
    );
  }

  factory BagLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BagLine(
      productId: serializer.fromJson<String>(json['productId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      quantity: serializer.fromJson<int>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'variantId': serializer.toJson<String>(variantId),
      'accountId': serializer.toJson<String?>(accountId),
      'quantity': serializer.toJson<int>(quantity),
    };
  }

  BagLine copyWith(
          {String? productId,
          String? variantId,
          Value<String?> accountId = const Value.absent(),
          int? quantity}) =>
      BagLine(
        productId: productId ?? this.productId,
        variantId: variantId ?? this.variantId,
        accountId: accountId.present ? accountId.value : this.accountId,
        quantity: quantity ?? this.quantity,
      );
  BagLine copyWithCompanion(BagLinesCompanion data) {
    return BagLine(
      productId: data.productId.present ? data.productId.value : this.productId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BagLine(')
          ..write('productId: $productId, ')
          ..write('variantId: $variantId, ')
          ..write('accountId: $accountId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(productId, variantId, accountId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BagLine &&
          other.productId == this.productId &&
          other.variantId == this.variantId &&
          other.accountId == this.accountId &&
          other.quantity == this.quantity);
}

class BagLinesCompanion extends UpdateCompanion<BagLine> {
  final Value<String> productId;
  final Value<String> variantId;
  final Value<String?> accountId;
  final Value<int> quantity;
  final Value<int> rowid;
  const BagLinesCompanion({
    this.productId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BagLinesCompanion.insert({
    required String productId,
    required String variantId,
    this.accountId = const Value.absent(),
    required int quantity,
    this.rowid = const Value.absent(),
  })  : productId = Value(productId),
        variantId = Value(variantId),
        quantity = Value(quantity);
  static Insertable<BagLine> custom({
    Expression<String>? productId,
    Expression<String>? variantId,
    Expression<String>? accountId,
    Expression<int>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      if (accountId != null) 'account_id': accountId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BagLinesCompanion copyWith(
      {Value<String>? productId,
      Value<String>? variantId,
      Value<String?>? accountId,
      Value<int>? quantity,
      Value<int>? rowid}) {
    return BagLinesCompanion(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      accountId: accountId ?? this.accountId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BagLinesCompanion(')
          ..write('productId: $productId, ')
          ..write('variantId: $variantId, ')
          ..write('accountId: $accountId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InteractionEventsTable extends InteractionEvents
    with TableInfo<$InteractionEventsTable, InteractionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InteractionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dwellMsMeta =
      const VerificationMeta('dwellMs');
  @override
  late final GeneratedColumn<int> dwellMs = GeneratedColumn<int>(
      'dwell_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _facetHintMeta =
      const VerificationMeta('facetHint');
  @override
  late final GeneratedColumn<String> facetHint = GeneratedColumn<String>(
      'facet_hint', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, type, timestamp, productId, dwellMs, facetHint];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interaction_events';
  @override
  VerificationContext validateIntegrity(Insertable<InteractionEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    }
    if (data.containsKey('dwell_ms')) {
      context.handle(_dwellMsMeta,
          dwellMs.isAcceptableOrUnknown(data['dwell_ms']!, _dwellMsMeta));
    }
    if (data.containsKey('facet_hint')) {
      context.handle(_facetHintMeta,
          facetHint.isAcceptableOrUnknown(data['facet_hint']!, _facetHintMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InteractionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InteractionEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id']),
      dwellMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}dwell_ms']),
      facetHint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}facet_hint']),
    );
  }

  @override
  $InteractionEventsTable createAlias(String alias) {
    return $InteractionEventsTable(attachedDatabase, alias);
  }
}

class InteractionEvent extends DataClass
    implements Insertable<InteractionEvent> {
  final int id;
  final String type;
  final DateTime timestamp;
  final String? productId;
  final int? dwellMs;
  final String? facetHint;
  const InteractionEvent(
      {required this.id,
      required this.type,
      required this.timestamp,
      this.productId,
      this.dwellMs,
      this.facetHint});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    if (!nullToAbsent || dwellMs != null) {
      map['dwell_ms'] = Variable<int>(dwellMs);
    }
    if (!nullToAbsent || facetHint != null) {
      map['facet_hint'] = Variable<String>(facetHint);
    }
    return map;
  }

  InteractionEventsCompanion toCompanion(bool nullToAbsent) {
    return InteractionEventsCompanion(
      id: Value(id),
      type: Value(type),
      timestamp: Value(timestamp),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      dwellMs: dwellMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dwellMs),
      facetHint: facetHint == null && nullToAbsent
          ? const Value.absent()
          : Value(facetHint),
    );
  }

  factory InteractionEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InteractionEvent(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      productId: serializer.fromJson<String?>(json['productId']),
      dwellMs: serializer.fromJson<int?>(json['dwellMs']),
      facetHint: serializer.fromJson<String?>(json['facetHint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'productId': serializer.toJson<String?>(productId),
      'dwellMs': serializer.toJson<int?>(dwellMs),
      'facetHint': serializer.toJson<String?>(facetHint),
    };
  }

  InteractionEvent copyWith(
          {int? id,
          String? type,
          DateTime? timestamp,
          Value<String?> productId = const Value.absent(),
          Value<int?> dwellMs = const Value.absent(),
          Value<String?> facetHint = const Value.absent()}) =>
      InteractionEvent(
        id: id ?? this.id,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
        productId: productId.present ? productId.value : this.productId,
        dwellMs: dwellMs.present ? dwellMs.value : this.dwellMs,
        facetHint: facetHint.present ? facetHint.value : this.facetHint,
      );
  InteractionEvent copyWithCompanion(InteractionEventsCompanion data) {
    return InteractionEvent(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      productId: data.productId.present ? data.productId.value : this.productId,
      dwellMs: data.dwellMs.present ? data.dwellMs.value : this.dwellMs,
      facetHint: data.facetHint.present ? data.facetHint.value : this.facetHint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InteractionEvent(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('productId: $productId, ')
          ..write('dwellMs: $dwellMs, ')
          ..write('facetHint: $facetHint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, timestamp, productId, dwellMs, facetHint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InteractionEvent &&
          other.id == this.id &&
          other.type == this.type &&
          other.timestamp == this.timestamp &&
          other.productId == this.productId &&
          other.dwellMs == this.dwellMs &&
          other.facetHint == this.facetHint);
}

class InteractionEventsCompanion extends UpdateCompanion<InteractionEvent> {
  final Value<int> id;
  final Value<String> type;
  final Value<DateTime> timestamp;
  final Value<String?> productId;
  final Value<int?> dwellMs;
  final Value<String?> facetHint;
  const InteractionEventsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.productId = const Value.absent(),
    this.dwellMs = const Value.absent(),
    this.facetHint = const Value.absent(),
  });
  InteractionEventsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required DateTime timestamp,
    this.productId = const Value.absent(),
    this.dwellMs = const Value.absent(),
    this.facetHint = const Value.absent(),
  })  : type = Value(type),
        timestamp = Value(timestamp);
  static Insertable<InteractionEvent> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<DateTime>? timestamp,
    Expression<String>? productId,
    Expression<int>? dwellMs,
    Expression<String>? facetHint,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (timestamp != null) 'timestamp': timestamp,
      if (productId != null) 'product_id': productId,
      if (dwellMs != null) 'dwell_ms': dwellMs,
      if (facetHint != null) 'facet_hint': facetHint,
    });
  }

  InteractionEventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? type,
      Value<DateTime>? timestamp,
      Value<String?>? productId,
      Value<int?>? dwellMs,
      Value<String?>? facetHint}) {
    return InteractionEventsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      productId: productId ?? this.productId,
      dwellMs: dwellMs ?? this.dwellMs,
      facetHint: facetHint ?? this.facetHint,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (dwellMs.present) {
      map['dwell_ms'] = Variable<int>(dwellMs.value);
    }
    if (facetHint.present) {
      map['facet_hint'] = Variable<String>(facetHint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InteractionEventsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('productId: $productId, ')
          ..write('dwellMs: $dwellMs, ')
          ..write('facetHint: $facetHint')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _platformMeta =
      const VerificationMeta('platform');
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
      'platform', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _appVersionMeta =
      const VerificationMeta('appVersion');
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
      'app_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pushTokenMeta =
      const VerificationMeta('pushToken');
  @override
  late final GeneratedColumn<String> pushToken = GeneratedColumn<String>(
      'push_token', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _installedAtMeta =
      const VerificationMeta('installedAt');
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
      'installed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        deviceId,
        accountId,
        platform,
        appVersion,
        pushToken,
        installedAt,
        lastSeenAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(Insertable<Device> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(_platformMeta,
          platform.isAcceptableOrUnknown(data['platform']!, _platformMeta));
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
          _appVersionMeta,
          appVersion.isAcceptableOrUnknown(
              data['app_version']!, _appVersionMeta));
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    if (data.containsKey('push_token')) {
      context.handle(_pushTokenMeta,
          pushToken.isAcceptableOrUnknown(data['push_token']!, _pushTokenMeta));
    }
    if (data.containsKey('installed_at')) {
      context.handle(
          _installedAtMeta,
          installedAt.isAcceptableOrUnknown(
              data['installed_at']!, _installedAtMeta));
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      platform: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}platform'])!,
      appVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_version'])!,
      pushToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}push_token']),
      installedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}installed_at'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String deviceId;
  final String? accountId;
  final String platform;
  final String appVersion;
  final String? pushToken;
  final DateTime installedAt;
  final DateTime lastSeenAt;
  const Device(
      {required this.deviceId,
      this.accountId,
      required this.platform,
      required this.appVersion,
      this.pushToken,
      required this.installedAt,
      required this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['platform'] = Variable<String>(platform);
    map['app_version'] = Variable<String>(appVersion);
    if (!nullToAbsent || pushToken != null) {
      map['push_token'] = Variable<String>(pushToken);
    }
    map['installed_at'] = Variable<DateTime>(installedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      deviceId: Value(deviceId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      platform: Value(platform),
      appVersion: Value(appVersion),
      pushToken: pushToken == null && nullToAbsent
          ? const Value.absent()
          : Value(pushToken),
      installedAt: Value(installedAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory Device.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      platform: serializer.fromJson<String>(json['platform']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      pushToken: serializer.fromJson<String?>(json['pushToken']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'accountId': serializer.toJson<String?>(accountId),
      'platform': serializer.toJson<String>(platform),
      'appVersion': serializer.toJson<String>(appVersion),
      'pushToken': serializer.toJson<String?>(pushToken),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  Device copyWith(
          {String? deviceId,
          Value<String?> accountId = const Value.absent(),
          String? platform,
          String? appVersion,
          Value<String?> pushToken = const Value.absent(),
          DateTime? installedAt,
          DateTime? lastSeenAt}) =>
      Device(
        deviceId: deviceId ?? this.deviceId,
        accountId: accountId.present ? accountId.value : this.accountId,
        platform: platform ?? this.platform,
        appVersion: appVersion ?? this.appVersion,
        pushToken: pushToken.present ? pushToken.value : this.pushToken,
        installedAt: installedAt ?? this.installedAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      platform: data.platform.present ? data.platform.value : this.platform,
      appVersion:
          data.appVersion.present ? data.appVersion.value : this.appVersion,
      pushToken: data.pushToken.present ? data.pushToken.value : this.pushToken,
      installedAt:
          data.installedAt.present ? data.installedAt.value : this.installedAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('deviceId: $deviceId, ')
          ..write('accountId: $accountId, ')
          ..write('platform: $platform, ')
          ..write('appVersion: $appVersion, ')
          ..write('pushToken: $pushToken, ')
          ..write('installedAt: $installedAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, accountId, platform, appVersion,
      pushToken, installedAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.deviceId == this.deviceId &&
          other.accountId == this.accountId &&
          other.platform == this.platform &&
          other.appVersion == this.appVersion &&
          other.pushToken == this.pushToken &&
          other.installedAt == this.installedAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> deviceId;
  final Value<String?> accountId;
  final Value<String> platform;
  final Value<String> appVersion;
  final Value<String?> pushToken;
  final Value<DateTime> installedAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const DevicesCompanion({
    this.deviceId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.platform = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.pushToken = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String deviceId,
    this.accountId = const Value.absent(),
    required String platform,
    required String appVersion,
    this.pushToken = const Value.absent(),
    required DateTime installedAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        platform = Value(platform),
        appVersion = Value(appVersion),
        installedAt = Value(installedAt),
        lastSeenAt = Value(lastSeenAt);
  static Insertable<Device> custom({
    Expression<String>? deviceId,
    Expression<String>? accountId,
    Expression<String>? platform,
    Expression<String>? appVersion,
    Expression<String>? pushToken,
    Expression<DateTime>? installedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (accountId != null) 'account_id': accountId,
      if (platform != null) 'platform': platform,
      if (appVersion != null) 'app_version': appVersion,
      if (pushToken != null) 'push_token': pushToken,
      if (installedAt != null) 'installed_at': installedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith(
      {Value<String>? deviceId,
      Value<String?>? accountId,
      Value<String>? platform,
      Value<String>? appVersion,
      Value<String?>? pushToken,
      Value<DateTime>? installedAt,
      Value<DateTime>? lastSeenAt,
      Value<int>? rowid}) {
    return DevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      accountId: accountId ?? this.accountId,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      pushToken: pushToken ?? this.pushToken,
      installedAt: installedAt ?? this.installedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (pushToken.present) {
      map['push_token'] = Variable<String>(pushToken.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('accountId: $accountId, ')
          ..write('platform: $platform, ')
          ..write('appVersion: $appVersion, ')
          ..write('pushToken: $pushToken, ')
          ..write('installedAt: $installedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localAccountIdMeta =
      const VerificationMeta('localAccountId');
  @override
  late final GeneratedColumn<String> localAccountId = GeneratedColumn<String>(
      'local_account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopifyCustomerIdMeta =
      const VerificationMeta('shopifyCustomerId');
  @override
  late final GeneratedColumn<String> shopifyCustomerId =
      GeneratedColumn<String>('shopify_customer_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _authProviderMeta =
      const VerificationMeta('authProvider');
  @override
  late final GeneratedColumn<String> authProvider = GeneratedColumn<String>(
      'auth_provider', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        localAccountId,
        shopifyCustomerId,
        email,
        displayName,
        authProvider,
        createdAt,
        lastSeenAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_account_id')) {
      context.handle(
          _localAccountIdMeta,
          localAccountId.isAcceptableOrUnknown(
              data['local_account_id']!, _localAccountIdMeta));
    } else if (isInserting) {
      context.missing(_localAccountIdMeta);
    }
    if (data.containsKey('shopify_customer_id')) {
      context.handle(
          _shopifyCustomerIdMeta,
          shopifyCustomerId.isAcceptableOrUnknown(
              data['shopify_customer_id']!, _shopifyCustomerIdMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('auth_provider')) {
      context.handle(
          _authProviderMeta,
          authProvider.isAcceptableOrUnknown(
              data['auth_provider']!, _authProviderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localAccountId};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      localAccountId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_account_id'])!,
      shopifyCustomerId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}shopify_customer_id']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      authProvider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}auth_provider']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String localAccountId;
  final String? shopifyCustomerId;
  final String? email;
  final String? displayName;
  final String? authProvider;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  const Account(
      {required this.localAccountId,
      this.shopifyCustomerId,
      this.email,
      this.displayName,
      this.authProvider,
      required this.createdAt,
      required this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_account_id'] = Variable<String>(localAccountId);
    if (!nullToAbsent || shopifyCustomerId != null) {
      map['shopify_customer_id'] = Variable<String>(shopifyCustomerId);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || authProvider != null) {
      map['auth_provider'] = Variable<String>(authProvider);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      localAccountId: Value(localAccountId),
      shopifyCustomerId: shopifyCustomerId == null && nullToAbsent
          ? const Value.absent()
          : Value(shopifyCustomerId),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      authProvider: authProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(authProvider),
      createdAt: Value(createdAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      localAccountId: serializer.fromJson<String>(json['localAccountId']),
      shopifyCustomerId:
          serializer.fromJson<String?>(json['shopifyCustomerId']),
      email: serializer.fromJson<String?>(json['email']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      authProvider: serializer.fromJson<String?>(json['authProvider']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localAccountId': serializer.toJson<String>(localAccountId),
      'shopifyCustomerId': serializer.toJson<String?>(shopifyCustomerId),
      'email': serializer.toJson<String?>(email),
      'displayName': serializer.toJson<String?>(displayName),
      'authProvider': serializer.toJson<String?>(authProvider),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  Account copyWith(
          {String? localAccountId,
          Value<String?> shopifyCustomerId = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> displayName = const Value.absent(),
          Value<String?> authProvider = const Value.absent(),
          DateTime? createdAt,
          DateTime? lastSeenAt}) =>
      Account(
        localAccountId: localAccountId ?? this.localAccountId,
        shopifyCustomerId: shopifyCustomerId.present
            ? shopifyCustomerId.value
            : this.shopifyCustomerId,
        email: email.present ? email.value : this.email,
        displayName: displayName.present ? displayName.value : this.displayName,
        authProvider:
            authProvider.present ? authProvider.value : this.authProvider,
        createdAt: createdAt ?? this.createdAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      localAccountId: data.localAccountId.present
          ? data.localAccountId.value
          : this.localAccountId,
      shopifyCustomerId: data.shopifyCustomerId.present
          ? data.shopifyCustomerId.value
          : this.shopifyCustomerId,
      email: data.email.present ? data.email.value : this.email,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      authProvider: data.authProvider.present
          ? data.authProvider.value
          : this.authProvider,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('localAccountId: $localAccountId, ')
          ..write('shopifyCustomerId: $shopifyCustomerId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('authProvider: $authProvider, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localAccountId, shopifyCustomerId, email,
      displayName, authProvider, createdAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.localAccountId == this.localAccountId &&
          other.shopifyCustomerId == this.shopifyCustomerId &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.authProvider == this.authProvider &&
          other.createdAt == this.createdAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> localAccountId;
  final Value<String?> shopifyCustomerId;
  final Value<String?> email;
  final Value<String?> displayName;
  final Value<String?> authProvider;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.localAccountId = const Value.absent(),
    this.shopifyCustomerId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.authProvider = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String localAccountId,
    this.shopifyCustomerId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.authProvider = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  })  : localAccountId = Value(localAccountId),
        createdAt = Value(createdAt),
        lastSeenAt = Value(lastSeenAt);
  static Insertable<Account> custom({
    Expression<String>? localAccountId,
    Expression<String>? shopifyCustomerId,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? authProvider,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localAccountId != null) 'local_account_id': localAccountId,
      if (shopifyCustomerId != null) 'shopify_customer_id': shopifyCustomerId,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (authProvider != null) 'auth_provider': authProvider,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith(
      {Value<String>? localAccountId,
      Value<String?>? shopifyCustomerId,
      Value<String?>? email,
      Value<String?>? displayName,
      Value<String?>? authProvider,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastSeenAt,
      Value<int>? rowid}) {
    return AccountsCompanion(
      localAccountId: localAccountId ?? this.localAccountId,
      shopifyCustomerId: shopifyCustomerId ?? this.shopifyCustomerId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localAccountId.present) {
      map['local_account_id'] = Variable<String>(localAccountId.value);
    }
    if (shopifyCustomerId.present) {
      map['shopify_customer_id'] = Variable<String>(shopifyCustomerId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (authProvider.present) {
      map['auth_provider'] = Variable<String>(authProvider.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('localAccountId: $localAccountId, ')
          ..write('shopifyCustomerId: $shopifyCustomerId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('authProvider: $authProvider, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (local_account_id) ON DELETE CASCADE'));
  static const VerificationMeta _secureStorageKeyRefMeta =
      const VerificationMeta('secureStorageKeyRef');
  @override
  late final GeneratedColumn<String> secureStorageKeyRef =
      GeneratedColumn<String>('secure_storage_key_ref', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accessTokenExpiresAtMeta =
      const VerificationMeta('accessTokenExpiresAt');
  @override
  late final GeneratedColumn<DateTime> accessTokenExpiresAt =
      GeneratedColumn<DateTime>('access_token_expires_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, accountId, secureStorageKeyRef, accessTokenExpiresAt, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('secure_storage_key_ref')) {
      context.handle(
          _secureStorageKeyRefMeta,
          secureStorageKeyRef.isAcceptableOrUnknown(
              data['secure_storage_key_ref']!, _secureStorageKeyRefMeta));
    } else if (isInserting) {
      context.missing(_secureStorageKeyRefMeta);
    }
    if (data.containsKey('access_token_expires_at')) {
      context.handle(
          _accessTokenExpiresAtMeta,
          accessTokenExpiresAt.isAcceptableOrUnknown(
              data['access_token_expires_at']!, _accessTokenExpiresAtMeta));
    } else if (isInserting) {
      context.missing(_accessTokenExpiresAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      secureStorageKeyRef: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}secure_storage_key_ref'])!,
      accessTokenExpiresAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}access_token_expires_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final String accountId;
  final String secureStorageKeyRef;

  /// The *access* token's expiry, not the id token's — they carry separate
  /// lifetimes in OIDC, and it's the access token that gates whether an
  /// API call needs a silent refresh first.
  final DateTime accessTokenExpiresAt;
  final DateTime createdAt;
  const Session(
      {required this.id,
      required this.accountId,
      required this.secureStorageKeyRef,
      required this.accessTokenExpiresAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<String>(accountId);
    map['secure_storage_key_ref'] = Variable<String>(secureStorageKeyRef);
    map['access_token_expires_at'] = Variable<DateTime>(accessTokenExpiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      secureStorageKeyRef: Value(secureStorageKeyRef),
      accessTokenExpiresAt: Value(accessTokenExpiresAt),
      createdAt: Value(createdAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      secureStorageKeyRef:
          serializer.fromJson<String>(json['secureStorageKeyRef']),
      accessTokenExpiresAt:
          serializer.fromJson<DateTime>(json['accessTokenExpiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String>(accountId),
      'secureStorageKeyRef': serializer.toJson<String>(secureStorageKeyRef),
      'accessTokenExpiresAt': serializer.toJson<DateTime>(accessTokenExpiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Session copyWith(
          {int? id,
          String? accountId,
          String? secureStorageKeyRef,
          DateTime? accessTokenExpiresAt,
          DateTime? createdAt}) =>
      Session(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        secureStorageKeyRef: secureStorageKeyRef ?? this.secureStorageKeyRef,
        accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
        createdAt: createdAt ?? this.createdAt,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      secureStorageKeyRef: data.secureStorageKeyRef.present
          ? data.secureStorageKeyRef.value
          : this.secureStorageKeyRef,
      accessTokenExpiresAt: data.accessTokenExpiresAt.present
          ? data.accessTokenExpiresAt.value
          : this.accessTokenExpiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('secureStorageKeyRef: $secureStorageKeyRef, ')
          ..write('accessTokenExpiresAt: $accessTokenExpiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, accountId, secureStorageKeyRef, accessTokenExpiresAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.secureStorageKeyRef == this.secureStorageKeyRef &&
          other.accessTokenExpiresAt == this.accessTokenExpiresAt &&
          other.createdAt == this.createdAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<String> accountId;
  final Value<String> secureStorageKeyRef;
  final Value<DateTime> accessTokenExpiresAt;
  final Value<DateTime> createdAt;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.secureStorageKeyRef = const Value.absent(),
    this.accessTokenExpiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String accountId,
    required String secureStorageKeyRef,
    required DateTime accessTokenExpiresAt,
    required DateTime createdAt,
  })  : accountId = Value(accountId),
        secureStorageKeyRef = Value(secureStorageKeyRef),
        accessTokenExpiresAt = Value(accessTokenExpiresAt),
        createdAt = Value(createdAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<String>? secureStorageKeyRef,
    Expression<DateTime>? accessTokenExpiresAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (secureStorageKeyRef != null)
        'secure_storage_key_ref': secureStorageKeyRef,
      if (accessTokenExpiresAt != null)
        'access_token_expires_at': accessTokenExpiresAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SessionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? accountId,
      Value<String>? secureStorageKeyRef,
      Value<DateTime>? accessTokenExpiresAt,
      Value<DateTime>? createdAt}) {
    return SessionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      secureStorageKeyRef: secureStorageKeyRef ?? this.secureStorageKeyRef,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (secureStorageKeyRef.present) {
      map['secure_storage_key_ref'] =
          Variable<String>(secureStorageKeyRef.value);
    }
    if (accessTokenExpiresAt.present) {
      map['access_token_expires_at'] =
          Variable<DateTime>(accessTokenExpiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('secureStorageKeyRef: $secureStorageKeyRef, ')
          ..write('accessTokenExpiresAt: $accessTokenExpiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OrderSummariesTable extends OrderSummaries
    with TableInfo<$OrderSummariesTable, OrderSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (local_account_id) ON DELETE CASCADE'));
  static const VerificationMeta _shopifyOrderIdMeta =
      const VerificationMeta('shopifyOrderId');
  @override
  late final GeneratedColumn<String> shopifyOrderId = GeneratedColumn<String>(
      'shopify_order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attributionCodeMeta =
      const VerificationMeta('attributionCode');
  @override
  late final GeneratedColumn<String> attributionCode = GeneratedColumn<String>(
      'attribution_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalAmountMeta =
      const VerificationMeta('totalAmount');
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
      'total_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currencyCodeMeta =
      const VerificationMeta('currencyCode');
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
      'currency_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _placedAtMeta =
      const VerificationMeta('placedAt');
  @override
  late final GeneratedColumn<DateTime> placedAt = GeneratedColumn<DateTime>(
      'placed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accountId,
        shopifyOrderId,
        source,
        attributionCode,
        status,
        totalAmount,
        currencyCode,
        placedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_summaries';
  @override
  VerificationContext validateIntegrity(Insertable<OrderSummary> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('shopify_order_id')) {
      context.handle(
          _shopifyOrderIdMeta,
          shopifyOrderId.isAcceptableOrUnknown(
              data['shopify_order_id']!, _shopifyOrderIdMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('attribution_code')) {
      context.handle(
          _attributionCodeMeta,
          attributionCode.isAcceptableOrUnknown(
              data['attribution_code']!, _attributionCodeMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
          _totalAmountMeta,
          totalAmount.isAcceptableOrUnknown(
              data['total_amount']!, _totalAmountMeta));
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
          _currencyCodeMeta,
          currencyCode.isAcceptableOrUnknown(
              data['currency_code']!, _currencyCodeMeta));
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('placed_at')) {
      context.handle(_placedAtMeta,
          placedAt.isAcceptableOrUnknown(data['placed_at']!, _placedAtMeta));
    } else if (isInserting) {
      context.missing(_placedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderSummary(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      shopifyOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}shopify_order_id']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      attributionCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}attribution_code']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      totalAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_amount'])!,
      currencyCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency_code'])!,
      placedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}placed_at'])!,
    );
  }

  @override
  $OrderSummariesTable createAlias(String alias) {
    return $OrderSummariesTable(attachedDatabase, alias);
  }
}

class OrderSummary extends DataClass implements Insertable<OrderSummary> {
  final String id;
  final String accountId;

  /// Null for an apartado order — those have no Shopify order id until the
  /// owner manually enters one, and some never get one recorded here at all.
  final String? shopifyOrderId;

  /// `shopifyCheckout` | `whatsappApartado`.
  final String source;

  /// The `MN-XXXX` code from `AttributionCodeGenerator`, set only for
  /// apartado orders.
  final String? attributionCode;
  final String status;
  final double totalAmount;
  final String currencyCode;
  final DateTime placedAt;
  const OrderSummary(
      {required this.id,
      required this.accountId,
      this.shopifyOrderId,
      required this.source,
      this.attributionCode,
      required this.status,
      required this.totalAmount,
      required this.currencyCode,
      required this.placedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || shopifyOrderId != null) {
      map['shopify_order_id'] = Variable<String>(shopifyOrderId);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || attributionCode != null) {
      map['attribution_code'] = Variable<String>(attributionCode);
    }
    map['status'] = Variable<String>(status);
    map['total_amount'] = Variable<double>(totalAmount);
    map['currency_code'] = Variable<String>(currencyCode);
    map['placed_at'] = Variable<DateTime>(placedAt);
    return map;
  }

  OrderSummariesCompanion toCompanion(bool nullToAbsent) {
    return OrderSummariesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      shopifyOrderId: shopifyOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(shopifyOrderId),
      source: Value(source),
      attributionCode: attributionCode == null && nullToAbsent
          ? const Value.absent()
          : Value(attributionCode),
      status: Value(status),
      totalAmount: Value(totalAmount),
      currencyCode: Value(currencyCode),
      placedAt: Value(placedAt),
    );
  }

  factory OrderSummary.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderSummary(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      shopifyOrderId: serializer.fromJson<String?>(json['shopifyOrderId']),
      source: serializer.fromJson<String>(json['source']),
      attributionCode: serializer.fromJson<String?>(json['attributionCode']),
      status: serializer.fromJson<String>(json['status']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      placedAt: serializer.fromJson<DateTime>(json['placedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'shopifyOrderId': serializer.toJson<String?>(shopifyOrderId),
      'source': serializer.toJson<String>(source),
      'attributionCode': serializer.toJson<String?>(attributionCode),
      'status': serializer.toJson<String>(status),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'placedAt': serializer.toJson<DateTime>(placedAt),
    };
  }

  OrderSummary copyWith(
          {String? id,
          String? accountId,
          Value<String?> shopifyOrderId = const Value.absent(),
          String? source,
          Value<String?> attributionCode = const Value.absent(),
          String? status,
          double? totalAmount,
          String? currencyCode,
          DateTime? placedAt}) =>
      OrderSummary(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        shopifyOrderId:
            shopifyOrderId.present ? shopifyOrderId.value : this.shopifyOrderId,
        source: source ?? this.source,
        attributionCode: attributionCode.present
            ? attributionCode.value
            : this.attributionCode,
        status: status ?? this.status,
        totalAmount: totalAmount ?? this.totalAmount,
        currencyCode: currencyCode ?? this.currencyCode,
        placedAt: placedAt ?? this.placedAt,
      );
  OrderSummary copyWithCompanion(OrderSummariesCompanion data) {
    return OrderSummary(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      shopifyOrderId: data.shopifyOrderId.present
          ? data.shopifyOrderId.value
          : this.shopifyOrderId,
      source: data.source.present ? data.source.value : this.source,
      attributionCode: data.attributionCode.present
          ? data.attributionCode.value
          : this.attributionCode,
      status: data.status.present ? data.status.value : this.status,
      totalAmount:
          data.totalAmount.present ? data.totalAmount.value : this.totalAmount,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      placedAt: data.placedAt.present ? data.placedAt.value : this.placedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderSummary(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('shopifyOrderId: $shopifyOrderId, ')
          ..write('source: $source, ')
          ..write('attributionCode: $attributionCode, ')
          ..write('status: $status, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('placedAt: $placedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, shopifyOrderId, source,
      attributionCode, status, totalAmount, currencyCode, placedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderSummary &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.shopifyOrderId == this.shopifyOrderId &&
          other.source == this.source &&
          other.attributionCode == this.attributionCode &&
          other.status == this.status &&
          other.totalAmount == this.totalAmount &&
          other.currencyCode == this.currencyCode &&
          other.placedAt == this.placedAt);
}

class OrderSummariesCompanion extends UpdateCompanion<OrderSummary> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String?> shopifyOrderId;
  final Value<String> source;
  final Value<String?> attributionCode;
  final Value<String> status;
  final Value<double> totalAmount;
  final Value<String> currencyCode;
  final Value<DateTime> placedAt;
  final Value<int> rowid;
  const OrderSummariesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.shopifyOrderId = const Value.absent(),
    this.source = const Value.absent(),
    this.attributionCode = const Value.absent(),
    this.status = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.placedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderSummariesCompanion.insert({
    required String id,
    required String accountId,
    this.shopifyOrderId = const Value.absent(),
    required String source,
    this.attributionCode = const Value.absent(),
    required String status,
    required double totalAmount,
    required String currencyCode,
    required DateTime placedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        accountId = Value(accountId),
        source = Value(source),
        status = Value(status),
        totalAmount = Value(totalAmount),
        currencyCode = Value(currencyCode),
        placedAt = Value(placedAt);
  static Insertable<OrderSummary> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? shopifyOrderId,
    Expression<String>? source,
    Expression<String>? attributionCode,
    Expression<String>? status,
    Expression<double>? totalAmount,
    Expression<String>? currencyCode,
    Expression<DateTime>? placedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (shopifyOrderId != null) 'shopify_order_id': shopifyOrderId,
      if (source != null) 'source': source,
      if (attributionCode != null) 'attribution_code': attributionCode,
      if (status != null) 'status': status,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (placedAt != null) 'placed_at': placedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderSummariesCompanion copyWith(
      {Value<String>? id,
      Value<String>? accountId,
      Value<String?>? shopifyOrderId,
      Value<String>? source,
      Value<String?>? attributionCode,
      Value<String>? status,
      Value<double>? totalAmount,
      Value<String>? currencyCode,
      Value<DateTime>? placedAt,
      Value<int>? rowid}) {
    return OrderSummariesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      shopifyOrderId: shopifyOrderId ?? this.shopifyOrderId,
      source: source ?? this.source,
      attributionCode: attributionCode ?? this.attributionCode,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      placedAt: placedAt ?? this.placedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (shopifyOrderId.present) {
      map['shopify_order_id'] = Variable<String>(shopifyOrderId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (attributionCode.present) {
      map['attribution_code'] = Variable<String>(attributionCode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (placedAt.present) {
      map['placed_at'] = Variable<DateTime>(placedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderSummariesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('shopifyOrderId: $shopifyOrderId, ')
          ..write('source: $source, ')
          ..write('attributionCode: $attributionCode, ')
          ..write('status: $status, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('placedAt: $placedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $CachedVariantsTable cachedVariants = $CachedVariantsTable(this);
  late final $CachedCollectionsTable cachedCollections =
      $CachedCollectionsTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $CatalogStatesTable catalogStates = $CatalogStatesTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $WishlistItemsTable wishlistItems = $WishlistItemsTable(this);
  late final $BagLinesTable bagLines = $BagLinesTable(this);
  late final $InteractionEventsTable interactionEvents =
      $InteractionEventsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $OrderSummariesTable orderSummaries = $OrderSummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cachedProducts,
        cachedVariants,
        cachedCollections,
        syncCursors,
        catalogStates,
        appPreferences,
        wishlistItems,
        bagLines,
        interactionEvents,
        devices,
        accounts,
        sessions,
        orderSummaries
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('cached_products',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('cached_variants', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('accounts',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sessions', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('accounts',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('order_summaries', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$CachedProductsTableCreateCompanionBuilder = CachedProductsCompanion
    Function({
  required String id,
  required String handle,
  required String title,
  required String vendor,
  required String productType,
  Value<String> tags,
  Value<String> images,
  Value<String> descriptionHtml,
  Value<String> collectionHandles,
  Value<String?> brandOverride,
  Value<String?> categoryOverride,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CachedProductsTableUpdateCompanionBuilder = CachedProductsCompanion
    Function({
  Value<String> id,
  Value<String> handle,
  Value<String> title,
  Value<String> vendor,
  Value<String> productType,
  Value<String> tags,
  Value<String> images,
  Value<String> descriptionHtml,
  Value<String> collectionHandles,
  Value<String?> brandOverride,
  Value<String?> categoryOverride,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$CachedProductsTableReferences
    extends BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct> {
  $$CachedProductsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CachedVariantsTable, List<CachedVariant>>
      _cachedVariantsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.cachedVariants,
              aliasName: $_aliasNameGenerator(
                  db.cachedProducts.id, db.cachedVariants.productId));

  $$CachedVariantsTableProcessedTableManager get cachedVariantsRefs {
    final manager = $$CachedVariantsTableTableManager($_db, $_db.cachedVariants)
        .filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cachedVariantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CachedProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get handle => $composableBuilder(
      column: $table.handle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vendor => $composableBuilder(
      column: $table.vendor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descriptionHtml => $composableBuilder(
      column: $table.descriptionHtml,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collectionHandles => $composableBuilder(
      column: $table.collectionHandles,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brandOverride => $composableBuilder(
      column: $table.brandOverride, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryOverride => $composableBuilder(
      column: $table.categoryOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> cachedVariantsRefs(
      Expression<bool> Function($$CachedVariantsTableFilterComposer f) f) {
    final $$CachedVariantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cachedVariants,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedVariantsTableFilterComposer(
              $db: $db,
              $table: $db.cachedVariants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get handle => $composableBuilder(
      column: $table.handle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vendor => $composableBuilder(
      column: $table.vendor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descriptionHtml => $composableBuilder(
      column: $table.descriptionHtml,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collectionHandles => $composableBuilder(
      column: $table.collectionHandles,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brandOverride => $composableBuilder(
      column: $table.brandOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryOverride => $composableBuilder(
      column: $table.categoryOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get handle =>
      $composableBuilder(column: $table.handle, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get descriptionHtml => $composableBuilder(
      column: $table.descriptionHtml, builder: (column) => column);

  GeneratedColumn<String> get collectionHandles => $composableBuilder(
      column: $table.collectionHandles, builder: (column) => column);

  GeneratedColumn<String> get brandOverride => $composableBuilder(
      column: $table.brandOverride, builder: (column) => column);

  GeneratedColumn<String> get categoryOverride => $composableBuilder(
      column: $table.categoryOverride, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> cachedVariantsRefs<T extends Object>(
      Expression<T> Function($$CachedVariantsTableAnnotationComposer a) f) {
    final $$CachedVariantsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cachedVariants,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedVariantsTableAnnotationComposer(
              $db: $db,
              $table: $db.cachedVariants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CachedProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (CachedProduct, $$CachedProductsTableReferences),
    CachedProduct,
    PrefetchHooks Function({bool cachedVariantsRefs})> {
  $$CachedProductsTableTableManager(
      _$AppDatabase db, $CachedProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> handle = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> vendor = const Value.absent(),
            Value<String> productType = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String> images = const Value.absent(),
            Value<String> descriptionHtml = const Value.absent(),
            Value<String> collectionHandles = const Value.absent(),
            Value<String?> brandOverride = const Value.absent(),
            Value<String?> categoryOverride = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion(
            id: id,
            handle: handle,
            title: title,
            vendor: vendor,
            productType: productType,
            tags: tags,
            images: images,
            descriptionHtml: descriptionHtml,
            collectionHandles: collectionHandles,
            brandOverride: brandOverride,
            categoryOverride: categoryOverride,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String handle,
            required String title,
            required String vendor,
            required String productType,
            Value<String> tags = const Value.absent(),
            Value<String> images = const Value.absent(),
            Value<String> descriptionHtml = const Value.absent(),
            Value<String> collectionHandles = const Value.absent(),
            Value<String?> brandOverride = const Value.absent(),
            Value<String?> categoryOverride = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion.insert(
            id: id,
            handle: handle,
            title: title,
            vendor: vendor,
            productType: productType,
            tags: tags,
            images: images,
            descriptionHtml: descriptionHtml,
            collectionHandles: collectionHandles,
            brandOverride: brandOverride,
            categoryOverride: categoryOverride,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CachedProductsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({cachedVariantsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (cachedVariantsRefs) db.cachedVariants
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cachedVariantsRefs)
                    await $_getPrefetchedData<CachedProduct,
                            $CachedProductsTable, CachedVariant>(
                        currentTable: table,
                        referencedTable: $$CachedProductsTableReferences
                            ._cachedVariantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CachedProductsTableReferences(db, table, p0)
                                .cachedVariantsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CachedProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (CachedProduct, $$CachedProductsTableReferences),
    CachedProduct,
    PrefetchHooks Function({bool cachedVariantsRefs})>;
typedef $$CachedVariantsTableCreateCompanionBuilder = CachedVariantsCompanion
    Function({
  required String id,
  required String productId,
  required String title,
  required double price,
  Value<double?> compareAtPrice,
  required bool available,
  Value<String?> sku,
  Value<int> rowid,
});
typedef $$CachedVariantsTableUpdateCompanionBuilder = CachedVariantsCompanion
    Function({
  Value<String> id,
  Value<String> productId,
  Value<String> title,
  Value<double> price,
  Value<double?> compareAtPrice,
  Value<bool> available,
  Value<String?> sku,
  Value<int> rowid,
});

final class $$CachedVariantsTableReferences
    extends BaseReferences<_$AppDatabase, $CachedVariantsTable, CachedVariant> {
  $$CachedVariantsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CachedProductsTable _productIdTable(_$AppDatabase db) =>
      db.cachedProducts.createAlias($_aliasNameGenerator(
          db.cachedVariants.productId, db.cachedProducts.id));

  $$CachedProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$CachedProductsTableTableManager($_db, $_db.cachedProducts)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CachedVariantsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVariantsTable> {
  $$CachedVariantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get compareAtPrice => $composableBuilder(
      column: $table.compareAtPrice,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  $$CachedProductsTableFilterComposer get productId {
    final $$CachedProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.cachedProducts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedProductsTableFilterComposer(
              $db: $db,
              $table: $db.cachedProducts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedVariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVariantsTable> {
  $$CachedVariantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get compareAtPrice => $composableBuilder(
      column: $table.compareAtPrice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  $$CachedProductsTableOrderingComposer get productId {
    final $$CachedProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.cachedProducts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedProductsTableOrderingComposer(
              $db: $db,
              $table: $db.cachedProducts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedVariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVariantsTable> {
  $$CachedVariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get compareAtPrice => $composableBuilder(
      column: $table.compareAtPrice, builder: (column) => column);

  GeneratedColumn<bool> get available =>
      $composableBuilder(column: $table.available, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  $$CachedProductsTableAnnotationComposer get productId {
    final $$CachedProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.cachedProducts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.cachedProducts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedVariantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedVariantsTable,
    CachedVariant,
    $$CachedVariantsTableFilterComposer,
    $$CachedVariantsTableOrderingComposer,
    $$CachedVariantsTableAnnotationComposer,
    $$CachedVariantsTableCreateCompanionBuilder,
    $$CachedVariantsTableUpdateCompanionBuilder,
    (CachedVariant, $$CachedVariantsTableReferences),
    CachedVariant,
    PrefetchHooks Function({bool productId})> {
  $$CachedVariantsTableTableManager(
      _$AppDatabase db, $CachedVariantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<double> price = const Value.absent(),
            Value<double?> compareAtPrice = const Value.absent(),
            Value<bool> available = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedVariantsCompanion(
            id: id,
            productId: productId,
            title: title,
            price: price,
            compareAtPrice: compareAtPrice,
            available: available,
            sku: sku,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required String title,
            required double price,
            Value<double?> compareAtPrice = const Value.absent(),
            required bool available,
            Value<String?> sku = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedVariantsCompanion.insert(
            id: id,
            productId: productId,
            title: title,
            price: price,
            compareAtPrice: compareAtPrice,
            available: available,
            sku: sku,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CachedVariantsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$CachedVariantsTableReferences._productIdTable(db),
                    referencedColumn:
                        $$CachedVariantsTableReferences._productIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CachedVariantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedVariantsTable,
    CachedVariant,
    $$CachedVariantsTableFilterComposer,
    $$CachedVariantsTableOrderingComposer,
    $$CachedVariantsTableAnnotationComposer,
    $$CachedVariantsTableCreateCompanionBuilder,
    $$CachedVariantsTableUpdateCompanionBuilder,
    (CachedVariant, $$CachedVariantsTableReferences),
    CachedVariant,
    PrefetchHooks Function({bool productId})>;
typedef $$CachedCollectionsTableCreateCompanionBuilder
    = CachedCollectionsCompanion Function({
  required String id,
  required String handle,
  required String title,
  Value<String> description,
  Value<String?> imageUrl,
  Value<int?> productCount,
  Value<int> rowid,
});
typedef $$CachedCollectionsTableUpdateCompanionBuilder
    = CachedCollectionsCompanion Function({
  Value<String> id,
  Value<String> handle,
  Value<String> title,
  Value<String> description,
  Value<String?> imageUrl,
  Value<int?> productCount,
  Value<int> rowid,
});

class $$CachedCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get handle => $composableBuilder(
      column: $table.handle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get productCount => $composableBuilder(
      column: $table.productCount, builder: (column) => ColumnFilters(column));
}

class $$CachedCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get handle => $composableBuilder(
      column: $table.handle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get productCount => $composableBuilder(
      column: $table.productCount,
      builder: (column) => ColumnOrderings(column));
}

class $$CachedCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get handle =>
      $composableBuilder(column: $table.handle, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get productCount => $composableBuilder(
      column: $table.productCount, builder: (column) => column);
}

class $$CachedCollectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedCollectionsTable,
    CachedCollection,
    $$CachedCollectionsTableFilterComposer,
    $$CachedCollectionsTableOrderingComposer,
    $$CachedCollectionsTableAnnotationComposer,
    $$CachedCollectionsTableCreateCompanionBuilder,
    $$CachedCollectionsTableUpdateCompanionBuilder,
    (
      CachedCollection,
      BaseReferences<_$AppDatabase, $CachedCollectionsTable, CachedCollection>
    ),
    CachedCollection,
    PrefetchHooks Function()> {
  $$CachedCollectionsTableTableManager(
      _$AppDatabase db, $CachedCollectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCollectionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> handle = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int?> productCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedCollectionsCompanion(
            id: id,
            handle: handle,
            title: title,
            description: description,
            imageUrl: imageUrl,
            productCount: productCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String handle,
            required String title,
            Value<String> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int?> productCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedCollectionsCompanion.insert(
            id: id,
            handle: handle,
            title: title,
            description: description,
            imageUrl: imageUrl,
            productCount: productCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedCollectionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedCollectionsTable,
    CachedCollection,
    $$CachedCollectionsTableFilterComposer,
    $$CachedCollectionsTableOrderingComposer,
    $$CachedCollectionsTableAnnotationComposer,
    $$CachedCollectionsTableCreateCompanionBuilder,
    $$CachedCollectionsTableUpdateCompanionBuilder,
    (
      CachedCollection,
      BaseReferences<_$AppDatabase, $CachedCollectionsTable, CachedCollection>
    ),
    CachedCollection,
    PrefetchHooks Function()>;
typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion
    Function({
  Value<int> id,
  Value<DateTime?> lastUpdatedAt,
  Value<DateTime?> lastFullSyncAt,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion
    Function({
  Value<int> id,
  Value<DateTime?> lastUpdatedAt,
  Value<DateTime?> lastFullSyncAt,
});

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastFullSyncAt => $composableBuilder(
      column: $table.lastFullSyncAt,
      builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastFullSyncAt => $composableBuilder(
      column: $table.lastFullSyncAt,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFullSyncAt => $composableBuilder(
      column: $table.lastFullSyncAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
    SyncCursor,
    PrefetchHooks Function()> {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime?> lastUpdatedAt = const Value.absent(),
            Value<DateTime?> lastFullSyncAt = const Value.absent(),
          }) =>
              SyncCursorsCompanion(
            id: id,
            lastUpdatedAt: lastUpdatedAt,
            lastFullSyncAt: lastFullSyncAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime?> lastUpdatedAt = const Value.absent(),
            Value<DateTime?> lastFullSyncAt = const Value.absent(),
          }) =>
              SyncCursorsCompanion.insert(
            id: id,
            lastUpdatedAt: lastUpdatedAt,
            lastFullSyncAt: lastFullSyncAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncCursorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
    SyncCursor,
    PrefetchHooks Function()>;
typedef $$CatalogStatesTableCreateCompanionBuilder = CatalogStatesCompanion
    Function({
  Value<int> id,
  required String source,
  Value<DateTime?> syncedAt,
  required int productCount,
  required String fingerprint,
  required String status,
  Value<String?> detail,
});
typedef $$CatalogStatesTableUpdateCompanionBuilder = CatalogStatesCompanion
    Function({
  Value<int> id,
  Value<String> source,
  Value<DateTime?> syncedAt,
  Value<int> productCount,
  Value<String> fingerprint,
  Value<String> status,
  Value<String?> detail,
});

class $$CatalogStatesTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogStatesTable> {
  $$CatalogStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get productCount => $composableBuilder(
      column: $table.productCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fingerprint => $composableBuilder(
      column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnFilters(column));
}

class $$CatalogStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogStatesTable> {
  $$CatalogStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get productCount => $composableBuilder(
      column: $table.productCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fingerprint => $composableBuilder(
      column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnOrderings(column));
}

class $$CatalogStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogStatesTable> {
  $$CatalogStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get productCount => $composableBuilder(
      column: $table.productCount, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
      column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$CatalogStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CatalogStatesTable,
    CatalogState,
    $$CatalogStatesTableFilterComposer,
    $$CatalogStatesTableOrderingComposer,
    $$CatalogStatesTableAnnotationComposer,
    $$CatalogStatesTableCreateCompanionBuilder,
    $$CatalogStatesTableUpdateCompanionBuilder,
    (
      CatalogState,
      BaseReferences<_$AppDatabase, $CatalogStatesTable, CatalogState>
    ),
    CatalogState,
    PrefetchHooks Function()> {
  $$CatalogStatesTableTableManager(_$AppDatabase db, $CatalogStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> productCount = const Value.absent(),
            Value<String> fingerprint = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> detail = const Value.absent(),
          }) =>
              CatalogStatesCompanion(
            id: id,
            source: source,
            syncedAt: syncedAt,
            productCount: productCount,
            fingerprint: fingerprint,
            status: status,
            detail: detail,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String source,
            Value<DateTime?> syncedAt = const Value.absent(),
            required int productCount,
            required String fingerprint,
            required String status,
            Value<String?> detail = const Value.absent(),
          }) =>
              CatalogStatesCompanion.insert(
            id: id,
            source: source,
            syncedAt: syncedAt,
            productCount: productCount,
            fingerprint: fingerprint,
            status: status,
            detail: detail,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CatalogStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CatalogStatesTable,
    CatalogState,
    $$CatalogStatesTableFilterComposer,
    $$CatalogStatesTableOrderingComposer,
    $$CatalogStatesTableAnnotationComposer,
    $$CatalogStatesTableCreateCompanionBuilder,
    $$CatalogStatesTableUpdateCompanionBuilder,
    (
      CatalogState,
      BaseReferences<_$AppDatabase, $CatalogStatesTable, CatalogState>
    ),
    CatalogState,
    PrefetchHooks Function()>;
typedef $$AppPreferencesTableCreateCompanionBuilder = AppPreferencesCompanion
    Function({
  Value<int> id,
  Value<String> themeMode,
  Value<String> onboardingState,
});
typedef $$AppPreferencesTableUpdateCompanionBuilder = AppPreferencesCompanion
    Function({
  Value<int> id,
  Value<String> themeMode,
  Value<String> onboardingState,
});

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get themeMode => $composableBuilder(
      column: $table.themeMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get onboardingState => $composableBuilder(
      column: $table.onboardingState,
      builder: (column) => ColumnFilters(column));
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get themeMode => $composableBuilder(
      column: $table.themeMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get onboardingState => $composableBuilder(
      column: $table.onboardingState,
      builder: (column) => ColumnOrderings(column));
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get onboardingState => $composableBuilder(
      column: $table.onboardingState, builder: (column) => column);
}

class $$AppPreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppPreferencesTable,
    AppPreference,
    $$AppPreferencesTableFilterComposer,
    $$AppPreferencesTableOrderingComposer,
    $$AppPreferencesTableAnnotationComposer,
    $$AppPreferencesTableCreateCompanionBuilder,
    $$AppPreferencesTableUpdateCompanionBuilder,
    (
      AppPreference,
      BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>
    ),
    AppPreference,
    PrefetchHooks Function()> {
  $$AppPreferencesTableTableManager(
      _$AppDatabase db, $AppPreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> themeMode = const Value.absent(),
            Value<String> onboardingState = const Value.absent(),
          }) =>
              AppPreferencesCompanion(
            id: id,
            themeMode: themeMode,
            onboardingState: onboardingState,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> themeMode = const Value.absent(),
            Value<String> onboardingState = const Value.absent(),
          }) =>
              AppPreferencesCompanion.insert(
            id: id,
            themeMode: themeMode,
            onboardingState: onboardingState,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppPreferencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppPreferencesTable,
    AppPreference,
    $$AppPreferencesTableFilterComposer,
    $$AppPreferencesTableOrderingComposer,
    $$AppPreferencesTableAnnotationComposer,
    $$AppPreferencesTableCreateCompanionBuilder,
    $$AppPreferencesTableUpdateCompanionBuilder,
    (
      AppPreference,
      BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>
    ),
    AppPreference,
    PrefetchHooks Function()>;
typedef $$WishlistItemsTableCreateCompanionBuilder = WishlistItemsCompanion
    Function({
  required String productId,
  Value<String?> accountId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$WishlistItemsTableUpdateCompanionBuilder = WishlistItemsCompanion
    Function({
  Value<String> productId,
  Value<String?> accountId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$WishlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$WishlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$WishlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$WishlistItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WishlistItemsTable,
    WishlistItem,
    $$WishlistItemsTableFilterComposer,
    $$WishlistItemsTableOrderingComposer,
    $$WishlistItemsTableAnnotationComposer,
    $$WishlistItemsTableCreateCompanionBuilder,
    $$WishlistItemsTableUpdateCompanionBuilder,
    (
      WishlistItem,
      BaseReferences<_$AppDatabase, $WishlistItemsTable, WishlistItem>
    ),
    WishlistItem,
    PrefetchHooks Function()> {
  $$WishlistItemsTableTableManager(_$AppDatabase db, $WishlistItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> productId = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishlistItemsCompanion(
            productId: productId,
            accountId: accountId,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String productId,
            Value<String?> accountId = const Value.absent(),
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WishlistItemsCompanion.insert(
            productId: productId,
            accountId: accountId,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WishlistItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WishlistItemsTable,
    WishlistItem,
    $$WishlistItemsTableFilterComposer,
    $$WishlistItemsTableOrderingComposer,
    $$WishlistItemsTableAnnotationComposer,
    $$WishlistItemsTableCreateCompanionBuilder,
    $$WishlistItemsTableUpdateCompanionBuilder,
    (
      WishlistItem,
      BaseReferences<_$AppDatabase, $WishlistItemsTable, WishlistItem>
    ),
    WishlistItem,
    PrefetchHooks Function()>;
typedef $$BagLinesTableCreateCompanionBuilder = BagLinesCompanion Function({
  required String productId,
  required String variantId,
  Value<String?> accountId,
  required int quantity,
  Value<int> rowid,
});
typedef $$BagLinesTableUpdateCompanionBuilder = BagLinesCompanion Function({
  Value<String> productId,
  Value<String> variantId,
  Value<String?> accountId,
  Value<int> quantity,
  Value<int> rowid,
});

class $$BagLinesTableFilterComposer
    extends Composer<_$AppDatabase, $BagLinesTable> {
  $$BagLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get variantId => $composableBuilder(
      column: $table.variantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));
}

class $$BagLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $BagLinesTable> {
  $$BagLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get variantId => $composableBuilder(
      column: $table.variantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));
}

class $$BagLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BagLinesTable> {
  $$BagLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$BagLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BagLinesTable,
    BagLine,
    $$BagLinesTableFilterComposer,
    $$BagLinesTableOrderingComposer,
    $$BagLinesTableAnnotationComposer,
    $$BagLinesTableCreateCompanionBuilder,
    $$BagLinesTableUpdateCompanionBuilder,
    (BagLine, BaseReferences<_$AppDatabase, $BagLinesTable, BagLine>),
    BagLine,
    PrefetchHooks Function()> {
  $$BagLinesTableTableManager(_$AppDatabase db, $BagLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BagLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BagLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BagLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> productId = const Value.absent(),
            Value<String> variantId = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BagLinesCompanion(
            productId: productId,
            variantId: variantId,
            accountId: accountId,
            quantity: quantity,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String productId,
            required String variantId,
            Value<String?> accountId = const Value.absent(),
            required int quantity,
            Value<int> rowid = const Value.absent(),
          }) =>
              BagLinesCompanion.insert(
            productId: productId,
            variantId: variantId,
            accountId: accountId,
            quantity: quantity,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BagLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BagLinesTable,
    BagLine,
    $$BagLinesTableFilterComposer,
    $$BagLinesTableOrderingComposer,
    $$BagLinesTableAnnotationComposer,
    $$BagLinesTableCreateCompanionBuilder,
    $$BagLinesTableUpdateCompanionBuilder,
    (BagLine, BaseReferences<_$AppDatabase, $BagLinesTable, BagLine>),
    BagLine,
    PrefetchHooks Function()>;
typedef $$InteractionEventsTableCreateCompanionBuilder
    = InteractionEventsCompanion Function({
  Value<int> id,
  required String type,
  required DateTime timestamp,
  Value<String?> productId,
  Value<int?> dwellMs,
  Value<String?> facetHint,
});
typedef $$InteractionEventsTableUpdateCompanionBuilder
    = InteractionEventsCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<DateTime> timestamp,
  Value<String?> productId,
  Value<int?> dwellMs,
  Value<String?> facetHint,
});

class $$InteractionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $InteractionEventsTable> {
  $$InteractionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dwellMs => $composableBuilder(
      column: $table.dwellMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get facetHint => $composableBuilder(
      column: $table.facetHint, builder: (column) => ColumnFilters(column));
}

class $$InteractionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $InteractionEventsTable> {
  $$InteractionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dwellMs => $composableBuilder(
      column: $table.dwellMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get facetHint => $composableBuilder(
      column: $table.facetHint, builder: (column) => ColumnOrderings(column));
}

class $$InteractionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InteractionEventsTable> {
  $$InteractionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get dwellMs =>
      $composableBuilder(column: $table.dwellMs, builder: (column) => column);

  GeneratedColumn<String> get facetHint =>
      $composableBuilder(column: $table.facetHint, builder: (column) => column);
}

class $$InteractionEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InteractionEventsTable,
    InteractionEvent,
    $$InteractionEventsTableFilterComposer,
    $$InteractionEventsTableOrderingComposer,
    $$InteractionEventsTableAnnotationComposer,
    $$InteractionEventsTableCreateCompanionBuilder,
    $$InteractionEventsTableUpdateCompanionBuilder,
    (
      InteractionEvent,
      BaseReferences<_$AppDatabase, $InteractionEventsTable, InteractionEvent>
    ),
    InteractionEvent,
    PrefetchHooks Function()> {
  $$InteractionEventsTableTableManager(
      _$AppDatabase db, $InteractionEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InteractionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InteractionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InteractionEventsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> productId = const Value.absent(),
            Value<int?> dwellMs = const Value.absent(),
            Value<String?> facetHint = const Value.absent(),
          }) =>
              InteractionEventsCompanion(
            id: id,
            type: type,
            timestamp: timestamp,
            productId: productId,
            dwellMs: dwellMs,
            facetHint: facetHint,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String type,
            required DateTime timestamp,
            Value<String?> productId = const Value.absent(),
            Value<int?> dwellMs = const Value.absent(),
            Value<String?> facetHint = const Value.absent(),
          }) =>
              InteractionEventsCompanion.insert(
            id: id,
            type: type,
            timestamp: timestamp,
            productId: productId,
            dwellMs: dwellMs,
            facetHint: facetHint,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InteractionEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InteractionEventsTable,
    InteractionEvent,
    $$InteractionEventsTableFilterComposer,
    $$InteractionEventsTableOrderingComposer,
    $$InteractionEventsTableAnnotationComposer,
    $$InteractionEventsTableCreateCompanionBuilder,
    $$InteractionEventsTableUpdateCompanionBuilder,
    (
      InteractionEvent,
      BaseReferences<_$AppDatabase, $InteractionEventsTable, InteractionEvent>
    ),
    InteractionEvent,
    PrefetchHooks Function()>;
typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String deviceId,
  Value<String?> accountId,
  required String platform,
  required String appVersion,
  Value<String?> pushToken,
  required DateTime installedAt,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> deviceId,
  Value<String?> accountId,
  Value<String> platform,
  Value<String> appVersion,
  Value<String?> pushToken,
  Value<DateTime> installedAt,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get platform => $composableBuilder(
      column: $table.platform, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pushToken => $composableBuilder(
      column: $table.pushToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get platform => $composableBuilder(
      column: $table.platform, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pushToken => $composableBuilder(
      column: $table.pushToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
      column: $table.appVersion, builder: (column) => column);

  GeneratedColumn<String> get pushToken =>
      $composableBuilder(column: $table.pushToken, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$DevicesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()> {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String> platform = const Value.absent(),
            Value<String> appVersion = const Value.absent(),
            Value<String?> pushToken = const Value.absent(),
            Value<DateTime> installedAt = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion(
            deviceId: deviceId,
            accountId: accountId,
            platform: platform,
            appVersion: appVersion,
            pushToken: pushToken,
            installedAt: installedAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            Value<String?> accountId = const Value.absent(),
            required String platform,
            required String appVersion,
            Value<String?> pushToken = const Value.absent(),
            required DateTime installedAt,
            required DateTime lastSeenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion.insert(
            deviceId: deviceId,
            accountId: accountId,
            platform: platform,
            appVersion: appVersion,
            pushToken: pushToken,
            installedAt: installedAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DevicesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String localAccountId,
  Value<String?> shopifyCustomerId,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> authProvider,
  required DateTime createdAt,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> localAccountId,
  Value<String?> shopifyCustomerId,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> authProvider,
  Value<DateTime> createdAt,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sessions,
          aliasName: $_aliasNameGenerator(
              db.accounts.localAccountId, db.sessions.accountId));

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager($_db, $_db.sessions).filter(
        (f) => f.accountId.localAccountId
            .sqlEquals($_itemColumn<String>('local_account_id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$OrderSummariesTable, List<OrderSummary>>
      _orderSummariesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.orderSummaries,
              aliasName: $_aliasNameGenerator(
                  db.accounts.localAccountId, db.orderSummaries.accountId));

  $$OrderSummariesTableProcessedTableManager get orderSummariesRefs {
    final manager = $$OrderSummariesTableTableManager($_db, $_db.orderSummaries)
        .filter((f) => f.accountId.localAccountId
            .sqlEquals($_itemColumn<String>('local_account_id')!));

    final cache = $_typedResult.readTableOrNull(_orderSummariesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localAccountId => $composableBuilder(
      column: $table.localAccountId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopifyCustomerId => $composableBuilder(
      column: $table.shopifyCustomerId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authProvider => $composableBuilder(
      column: $table.authProvider, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionsRefs(
      Expression<bool> Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAccountId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> orderSummariesRefs(
      Expression<bool> Function($$OrderSummariesTableFilterComposer f) f) {
    final $$OrderSummariesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAccountId,
        referencedTable: $db.orderSummaries,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderSummariesTableFilterComposer(
              $db: $db,
              $table: $db.orderSummaries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localAccountId => $composableBuilder(
      column: $table.localAccountId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopifyCustomerId => $composableBuilder(
      column: $table.shopifyCustomerId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authProvider => $composableBuilder(
      column: $table.authProvider,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localAccountId => $composableBuilder(
      column: $table.localAccountId, builder: (column) => column);

  GeneratedColumn<String> get shopifyCustomerId => $composableBuilder(
      column: $table.shopifyCustomerId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get authProvider => $composableBuilder(
      column: $table.authProvider, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
      Expression<T> Function($$SessionsTableAnnotationComposer a) f) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAccountId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> orderSummariesRefs<T extends Object>(
      Expression<T> Function($$OrderSummariesTableAnnotationComposer a) f) {
    final $$OrderSummariesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAccountId,
        referencedTable: $db.orderSummaries,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderSummariesTableAnnotationComposer(
              $db: $db,
              $table: $db.orderSummaries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, $$AccountsTableReferences),
    Account,
    PrefetchHooks Function({bool sessionsRefs, bool orderSummariesRefs})> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localAccountId = const Value.absent(),
            Value<String?> shopifyCustomerId = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> authProvider = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion(
            localAccountId: localAccountId,
            shopifyCustomerId: shopifyCustomerId,
            email: email,
            displayName: displayName,
            authProvider: authProvider,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localAccountId,
            Value<String?> shopifyCustomerId = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> authProvider = const Value.absent(),
            required DateTime createdAt,
            required DateTime lastSeenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            localAccountId: localAccountId,
            shopifyCustomerId: shopifyCustomerId,
            email: email,
            displayName: displayName,
            authProvider: authProvider,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$AccountsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {sessionsRefs = false, orderSummariesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionsRefs) db.sessions,
                if (orderSummariesRefs) db.orderSummaries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<Account, $AccountsTable, Session>(
                        currentTable: table,
                        referencedTable:
                            $$AccountsTableReferences._sessionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AccountsTableReferences(db, table, p0)
                                .sessionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.localAccountId),
                        typedResults: items),
                  if (orderSummariesRefs)
                    await $_getPrefetchedData<Account, $AccountsTable,
                            OrderSummary>(
                        currentTable: table,
                        referencedTable: $$AccountsTableReferences
                            ._orderSummariesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AccountsTableReferences(db, table, p0)
                                .orderSummariesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.localAccountId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, $$AccountsTableReferences),
    Account,
    PrefetchHooks Function({bool sessionsRefs, bool orderSummariesRefs})>;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required String accountId,
  required String secureStorageKeyRef,
  required DateTime accessTokenExpiresAt,
  required DateTime createdAt,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<String> accountId,
  Value<String> secureStorageKeyRef,
  Value<DateTime> accessTokenExpiresAt,
  Value<DateTime> createdAt,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias($_aliasNameGenerator(
          db.sessions.accountId, db.accounts.localAccountId));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager($_db, $_db.accounts)
        .filter((f) => f.localAccountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secureStorageKeyRef => $composableBuilder(
      column: $table.secureStorageKeyRef,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get accessTokenExpiresAt => $composableBuilder(
      column: $table.accessTokenExpiresAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableFilterComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secureStorageKeyRef => $composableBuilder(
      column: $table.secureStorageKeyRef,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get accessTokenExpiresAt => $composableBuilder(
      column: $table.accessTokenExpiresAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableOrderingComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get secureStorageKeyRef => $composableBuilder(
      column: $table.secureStorageKeyRef, builder: (column) => column);

  GeneratedColumn<DateTime> get accessTokenExpiresAt => $composableBuilder(
      column: $table.accessTokenExpiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableAnnotationComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool accountId})> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> secureStorageKeyRef = const Value.absent(),
            Value<DateTime> accessTokenExpiresAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            accountId: accountId,
            secureStorageKeyRef: secureStorageKeyRef,
            accessTokenExpiresAt: accessTokenExpiresAt,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String accountId,
            required String secureStorageKeyRef,
            required DateTime accessTokenExpiresAt,
            required DateTime createdAt,
          }) =>
              SessionsCompanion.insert(
            id: id,
            accountId: accountId,
            secureStorageKeyRef: secureStorageKeyRef,
            accessTokenExpiresAt: accessTokenExpiresAt,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SessionsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (accountId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.accountId,
                    referencedTable:
                        $$SessionsTableReferences._accountIdTable(db),
                    referencedColumn: $$SessionsTableReferences
                        ._accountIdTable(db)
                        .localAccountId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool accountId})>;
typedef $$OrderSummariesTableCreateCompanionBuilder = OrderSummariesCompanion
    Function({
  required String id,
  required String accountId,
  Value<String?> shopifyOrderId,
  required String source,
  Value<String?> attributionCode,
  required String status,
  required double totalAmount,
  required String currencyCode,
  required DateTime placedAt,
  Value<int> rowid,
});
typedef $$OrderSummariesTableUpdateCompanionBuilder = OrderSummariesCompanion
    Function({
  Value<String> id,
  Value<String> accountId,
  Value<String?> shopifyOrderId,
  Value<String> source,
  Value<String?> attributionCode,
  Value<String> status,
  Value<double> totalAmount,
  Value<String> currencyCode,
  Value<DateTime> placedAt,
  Value<int> rowid,
});

final class $$OrderSummariesTableReferences
    extends BaseReferences<_$AppDatabase, $OrderSummariesTable, OrderSummary> {
  $$OrderSummariesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias($_aliasNameGenerator(
          db.orderSummaries.accountId, db.accounts.localAccountId));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager($_db, $_db.accounts)
        .filter((f) => f.localAccountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OrderSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $OrderSummariesTable> {
  $$OrderSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopifyOrderId => $composableBuilder(
      column: $table.shopifyOrderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attributionCode => $composableBuilder(
      column: $table.attributionCode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get placedAt => $composableBuilder(
      column: $table.placedAt, builder: (column) => ColumnFilters(column));

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableFilterComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderSummariesTable> {
  $$OrderSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopifyOrderId => $composableBuilder(
      column: $table.shopifyOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attributionCode => $composableBuilder(
      column: $table.attributionCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get placedAt => $composableBuilder(
      column: $table.placedAt, builder: (column) => ColumnOrderings(column));

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableOrderingComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderSummariesTable> {
  $$OrderSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopifyOrderId => $composableBuilder(
      column: $table.shopifyOrderId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get attributionCode => $composableBuilder(
      column: $table.attributionCode, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode, builder: (column) => column);

  GeneratedColumn<DateTime> get placedAt =>
      $composableBuilder(column: $table.placedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.localAccountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableAnnotationComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderSummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderSummariesTable,
    OrderSummary,
    $$OrderSummariesTableFilterComposer,
    $$OrderSummariesTableOrderingComposer,
    $$OrderSummariesTableAnnotationComposer,
    $$OrderSummariesTableCreateCompanionBuilder,
    $$OrderSummariesTableUpdateCompanionBuilder,
    (OrderSummary, $$OrderSummariesTableReferences),
    OrderSummary,
    PrefetchHooks Function({bool accountId})> {
  $$OrderSummariesTableTableManager(
      _$AppDatabase db, $OrderSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String?> shopifyOrderId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> attributionCode = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double> totalAmount = const Value.absent(),
            Value<String> currencyCode = const Value.absent(),
            Value<DateTime> placedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderSummariesCompanion(
            id: id,
            accountId: accountId,
            shopifyOrderId: shopifyOrderId,
            source: source,
            attributionCode: attributionCode,
            status: status,
            totalAmount: totalAmount,
            currencyCode: currencyCode,
            placedAt: placedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String accountId,
            Value<String?> shopifyOrderId = const Value.absent(),
            required String source,
            Value<String?> attributionCode = const Value.absent(),
            required String status,
            required double totalAmount,
            required String currencyCode,
            required DateTime placedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderSummariesCompanion.insert(
            id: id,
            accountId: accountId,
            shopifyOrderId: shopifyOrderId,
            source: source,
            attributionCode: attributionCode,
            status: status,
            totalAmount: totalAmount,
            currencyCode: currencyCode,
            placedAt: placedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OrderSummariesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (accountId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.accountId,
                    referencedTable:
                        $$OrderSummariesTableReferences._accountIdTable(db),
                    referencedColumn: $$OrderSummariesTableReferences
                        ._accountIdTable(db)
                        .localAccountId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OrderSummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderSummariesTable,
    OrderSummary,
    $$OrderSummariesTableFilterComposer,
    $$OrderSummariesTableOrderingComposer,
    $$OrderSummariesTableAnnotationComposer,
    $$OrderSummariesTableCreateCompanionBuilder,
    $$OrderSummariesTableUpdateCompanionBuilder,
    (OrderSummary, $$OrderSummariesTableReferences),
    OrderSummary,
    PrefetchHooks Function({bool accountId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$CachedVariantsTableTableManager get cachedVariants =>
      $$CachedVariantsTableTableManager(_db, _db.cachedVariants);
  $$CachedCollectionsTableTableManager get cachedCollections =>
      $$CachedCollectionsTableTableManager(_db, _db.cachedCollections);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$CatalogStatesTableTableManager get catalogStates =>
      $$CatalogStatesTableTableManager(_db, _db.catalogStates);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$WishlistItemsTableTableManager get wishlistItems =>
      $$WishlistItemsTableTableManager(_db, _db.wishlistItems);
  $$BagLinesTableTableManager get bagLines =>
      $$BagLinesTableTableManager(_db, _db.bagLines);
  $$InteractionEventsTableTableManager get interactionEvents =>
      $$InteractionEventsTableTableManager(_db, _db.interactionEvents);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$OrderSummariesTableTableManager get orderSummaries =>
      $$OrderSummariesTableTableManager(_db, _db.orderSummaries);
}
