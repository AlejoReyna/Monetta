/// Client guide personalisation: edit, persist, restore and apply choices.
library;

import 'package:flutter/material.dart';
import '../../app/catalog_store.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../catalog/categories_screen.dart';
import 'personalization_preferences.dart';

Future<bool?> openPersonalization(BuildContext context) {
  final store = StoreScope.of(context);
  final scope = AccountScope.maybeOf(context)?.account?.localAccountId ?? '';
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        StoreScope(notifier: store, child: OnboardingSheet(scopeKey: scope)),
  );
}

void applyPersonalization(
  CatalogStore store,
  PersonalizationPreferences preferences,
) {
  final selected = clientGuideCategories
      .where((c) => preferences.collections.contains(c.id));
  store.seedFrom(
    brands: preferences.brands,
    categories: selected.map((c) => c.filter.category!).toSet().toList(),
    silhouettes:
        selected.map((c) => c.filter.silhouette).whereType<String>().toList(),
  );
}

const Map<String, String> _kBrandLogoAssets = <String, String>{
  'anne_klein': 'assets/images/brands/anne_klein.webp',
  'coach': 'assets/images/brands/coach.webp',
  'christian_dior': 'assets/images/brands/dior.webp',
  'dior': 'assets/images/brands/dior.webp',
  'guess': 'assets/images/brands/guess.webp',
  'laneige': 'assets/images/brands/laneige.webp',
  'michael_kors': 'assets/images/brands/michael_kors.webp',
  'olaplex': 'assets/images/brands/olaplex.webp',
  'rhode': 'assets/images/brands/rhode.webp',
  'steve_madden': 'assets/images/brands/steve_madden.webp',
  'summer_fridays': 'assets/images/brands/summer_fridays.webp',
  'the_ordinary': 'assets/images/brands/the_ordinary.webp',
  'tommy_hilfiger': 'assets/images/brands/tommy_hilfiger.webp',
};

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({
    this.preferencesStore = const LocalPersonalizationPreferencesStore(),
    this.scopeKey,
    super.key,
  });
  final PersonalizationPreferencesStore preferencesStore;
  final String? scopeKey;
  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final _brands = <String>{};
  final _collections = <String>{};
  String? _purchaseType;
  String? _scope;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = widget.scopeKey ??
        AccountScope.maybeOf(context)?.account?.localAccountId ??
        '';
    if (_scope != scope) {
      _scope = scope;
      _load(scope);
    }
  }

  Future<void> _load(String scope) async {
    try {
      final preferences = await widget.preferencesStore.load(scope);
      if (!mounted || _scope != scope) return;
      setState(() {
        _brands
          ..clear()
          ..addAll(preferences.brands);
        _collections
          ..clear()
          ..addAll(preferences.collections);
        _purchaseType = preferences.purchaseType;
        _loading = false;
        _loadFailed = false;
        _error = null;
      });
    } on Object {
      if (mounted && _scope == scope) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _error = 'No pudimos cargar tus preferencias. Puedes reintentar.';
        });
      }
    }
  }

  void _toggle(Set<String> choices, String value) => setState(() {
        if (!choices.remove(value)) choices.add(value);
      });

  Future<void> _save() async {
    if (_saving || _loading || _loadFailed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final preferences = PersonalizationPreferences(
      brands: _brands.toList(),
      collections: _collections.toList(),
      purchaseType: _purchaseType,
    );
    try {
      await widget.preferencesStore.save(_scope!, preferences);
      if (!mounted) return;
      applyPersonalization(StoreScope.of(context), preferences);
      Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se guardaron tus preferencias. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final palette = context.boutique;
    final brands = store.availableBrands;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Material(
        color: palette.canvas,
        child: SafeArea(
          minimum: EdgeInsets.only(
            top: MediaQueryData.fromView(View.of(context)).padding.top,
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(MonettaTokens.space[2]),
                child: Row(
                  children: [
                    const Expanded(
                      child: MonettaWordmark(height: MonettaTokens.logoHeight),
                    ),
                    IconButton(
                      key: const ValueKey('onboarding-close'),
                      tooltip: 'Omitir',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('onboarding-scroll'),
                  padding: EdgeInsets.all(
                    MonettaTokens.gutterFor(
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  children: [
                    Text(
                      'Personalización',
                      textAlign: TextAlign.center,
                      style:
                          clientGuideStyle(context, MonettaTokens.screenTitle),
                    ),
                    SizedBox(height: MonettaTokens.space[1]),
                    Text(
                      'Cuéntanos cuáles son tus marcas, categorías y tipo de compra favoritos para recibir recomendaciones personalizadas.',
                      textAlign: TextAlign.center,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.body,
                        color: palette.inkMuted,
                      ),
                    ),
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null) ...[
                      SizedBox(height: MonettaTokens.space[2]),
                      Text(
                        _error!,
                        style:
                            clientGuideStyle(context, MonettaTokens.cardLabel),
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => _load(_scope!),
                        child: const Text('Reintentar carga'),
                      ),
                    ],
                    SizedBox(height: MonettaTokens.space[4]),
                    Text(
                      'Marcas favoritas',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.sectionTitle,
                      ),
                    ),
                    Text(
                      'Selecciona tus marcas preferidas.',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                    SizedBox(height: MonettaTokens.space[2]),
                    if (brands.isEmpty)
                      Text(
                        'Las marcas estarán disponibles al cargar el catálogo.',
                        style: clientGuideStyle(context, MonettaTokens.body),
                      ),
                    _ChoicesGrid(
                      children: [
                        for (final slug in brands)
                          _Choice(
                            key: ValueKey('onboarding-brand-$slug'),
                            label: brandLabel(slug),
                            asset: _kBrandLogoAssets[slug],
                            selected: _brands.contains(slug),
                            onTap: _loading || _saving || _loadFailed
                                ? null
                                : () => _toggle(_brands, slug),
                          ),
                      ],
                    ),
                    SizedBox(height: MonettaTokens.space[4]),
                    Text(
                      'Categorías de interés',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.sectionTitle,
                      ),
                    ),
                    Text(
                      'Selecciona las categorías que más te interesan.',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                    SizedBox(height: MonettaTokens.space[2]),
                    _ChoicesGrid(
                      children: [
                        for (final category in clientGuideCategories)
                          _Choice(
                            key: ValueKey(
                              'onboarding-collection-${category.id}',
                            ),
                            label: category.title,
                            asset: category.asset,
                            icon: category.icon,
                            selected: _collections.contains(category.id),
                            onTap: _loading || _saving || _loadFailed
                                ? null
                                : () => _toggle(_collections, category.id),
                          ),
                      ],
                    ),
                    SizedBox(height: MonettaTokens.space[4]),
                    Text(
                      'Tipo de compra favorita',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.sectionTitle,
                      ),
                    ),
                    Text(
                      'Cuéntanos cómo prefieres comprar.',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                    SizedBox(height: MonettaTokens.space[2]),
                    RadioGroup<String>(
                      groupValue: _purchaseType,
                      onChanged: (next) => setState(() => _purchaseType = next),
                      child: Column(
                        children: [
                          for (final (value, label) in [
                            ('retail', 'Menudeo'),
                            ('wholesale', 'Mayoreo'),
                          ])
                            RadioListTile<String>(
                              key: ValueKey('onboarding-purchase-$value'),
                              value: value,
                              toggleable: true,
                              enabled: !_loading && !_saving && !_loadFailed,
                              title: Text(
                                label,
                                style: clientGuideStyle(
                                  context,
                                  MonettaTokens.accountRow,
                                ),
                              ),
                              subtitle: Text(
                                'Condiciones comerciales por confirmar.',
                                style: clientGuideStyle(
                                  context,
                                  MonettaTokens.navLabel,
                                  color: palette.inkMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      'El tipo de compra expresa tu preferencia; no activa precios ni condiciones especiales.',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                    SizedBox(height: MonettaTokens.space[4]),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(MonettaTokens.space[3]),
                child: Column(
                  children: [
                    ClientGuideButton(
                      key: const ValueKey('onboarding-continue'),
                      label: _saving ? 'Guardando…' : 'Guardar preferencias',
                      chevron: true,
                      onPressed:
                          _loading || _saving || _loadFailed ? null : _save,
                    ),
                    TextButton(
                      key: const ValueKey('onboarding-skip'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Omitir por ahora'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicesGrid extends StatelessWidget {
  const _ChoicesGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? MonettaTokens.productColumnsNarrow
              : MonettaTokens.categoryColumnsCompact;
          final gap = MonettaTokens.space[1];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - gap * (columns - 1)) / columns,
                  child: child,
                ),
            ],
          );
        },
      );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    this.asset,
    this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String label;
  final String? asset;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.surface : palette.surfaceDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonettaTokens.radiusTile),
          side: BorderSide(
            color: selected ? palette.action : palette.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[1]),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: palette.goldText,
                    size: MonettaTokens.space[3],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 2,
                  child: asset == null
                      ? Icon(
                          icon ?? Icons.storefront_outlined,
                          color: palette.goldText,
                          size: MonettaTokens.space[5],
                        )
                      : Image.asset(
                          asset!,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon ?? Icons.storefront_outlined),
                        ),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.cardLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
