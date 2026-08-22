/// Branded search. The empty state already sells.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import 'product_card.dart';

const _kFrequent = <String>['bolsa', 'cartera', 'reloj', 'Coach', 'Guess'];

void openSearch(BuildContext context, {String initialQuery = ''}) {
  final store = StoreScope.of(context);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: SearchScreen(initialQuery: initialQuery),
      ),
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialQuery.isEmpty) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Product> _matches(String raw) {
    final store = StoreScope.of(context);
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    return store.products.where((product) {
      final facets = store.facetsFor(product.id);
      final brand = facets?.brand?.value == null
          ? ''
          : brandLabel(facets!.brand!.value).toLowerCase();
      final category = categoryLabel(facets?.category?.value).toLowerCase();
      final silhouette =
          silhouetteLabel(facets?.silhouette?.value).toLowerCase();
      return product.title.toLowerCase().contains(normalized) ||
          brand.contains(normalized) ||
          category.contains(normalized) ||
          silhouette.contains(normalized) ||
          product.productType.toLowerCase().contains(normalized);
    }).toList();
  }

  List<Product> _featured() {
    final newest = [...StoreScope.of(context).products]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return newest.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final matches = _matches(query);
    final emptyQuery = query.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Buscar'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              cursorColor: kInk,
              style: sans(size: 16),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar bolsas, marcas o estilos',
                hintStyle: sans(size: 16, color: kInkMuted),
                border: InputBorder.none,
                enabledBorder:
                    const UnderlineInputBorder(borderSide: kHairline),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: kInk, width: 0.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 10),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          _focus.requestFocus();
                        },
                        icon: const Icon(Icons.close, size: 18, color: kInk),
                      ),
              ),
            ),
          ),
          Expanded(
            child: emptyQuery
                ? _EmptySearch(
                    featured: _featured(),
                    onTerm: (term) {
                      _controller.text = term;
                      _controller.selection = TextSelection.collapsed(
                        offset: term.length,
                      );
                      setState(() {});
                    },
                  )
                : matches.isEmpty
                    ? _NoResults(query: query.trim(), featured: _featured())
                    : _ResultGrid(products: matches),
          ),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.featured, required this.onTerm});

  final List<Product> featured;
  final ValueChanged<String> onTerm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text('Búsquedas frecuentes'.toUpperCase(), style: eyebrow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: Wrap(
            spacing: 0,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _kFrequent.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('·', style: sans(size: 15, color: kInkMuted)),
                  ),
                GestureDetector(
                  onTap: () => onTerm(_kFrequent[i]),
                  child: Text(
                    _kFrequent[i],
                    style: sans(size: 15, height: 1.2),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (featured.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Piezas que buscan más', style: display(22)),
          ),
          _ResultGrid(products: featured, shrinkWrap: true),
        ],
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.featured});

  final String query;
  final List<Product> featured;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'No hay piezas para “$query”.',
            style: sans(size: 15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Text(
            'Prueba otra marca o silueta, o mira lo que acaba de llegar.',
            style: sans(size: 13, color: kInkMuted),
          ),
        ),
        if (featured.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Novedades', style: display(22)),
          ),
          _ResultGrid(products: featured, shrinkWrap: true),
        ],
      ],
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.products, this.shrinkWrap = false});

  final List<Product> products;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      shrinkWrap: shrinkWrap,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.52,
        crossAxisSpacing: 8,
        mainAxisSpacing: 28,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}
