/// Owner-only administration, presented inside the Monetta app.
library;

import 'package:flutter/material.dart';

import '../../app/admin_controller.dart';
import '../../app/admin_notification_controller.dart';
import '../../app/catalog_store.dart';
import '../../app/external_catalog_controller.dart';
import '../../app/media/monetta_image.dart';
import '../../app/theme.dart';
import '../../domain/admin_control.dart';
import '../../data/notifications/admin_notification_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    required this.controller,
    this.notificationController,
    required this.catalogStore,
    required this.externalCatalogController,
    super.key,
  });

  final AdminController controller;
  final AdminNotificationController? notificationController;
  final CatalogStore catalogStore;
  final ExternalCatalogController externalCatalogController;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _section = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      widget.notificationController?.load();
    });
  }

  Future<void> _load() {
    return widget.controller.load(
      appProducts: widget.catalogStore.products,
      externalSources: widget.externalCatalogController.sources,
    );
  }

  Future<void> _sync() async {
    final ok = await widget.controller.syncAll();
    if (!mounted) return;
    if (ok && widget.controller.mode == AdminConnectionMode.live) {
      await _load();
    }
    if (!mounted) return;
    _toast(
      ok
          ? widget.controller.mode == AdminConnectionMode.live
              ? 'Shopify, la app y las fuentes quedaron sincronizados.'
              : 'Sincronización simulada en vista previa.'
          : widget.controller.lastError ?? 'No se pudo sincronizar.',
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MonettaWordmark.appBar(),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(.5),
          child: Divider(height: .5),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return Column(
              children: [
                _AdminHeader(
                  mode: controller.mode,
                  loading: controller.loading,
                  error: controller.lastError,
                ),
                _SectionPicker(
                  selected: _section,
                  onSelected: (value) => setState(() => _section = value),
                ),
                const Divider(height: .5),
                Expanded(
                  child: IndexedStack(
                    index: _section,
                    children: [
                      _OverviewSection(controller: controller, onSync: _sync),
                      _ProductsSection(
                        controller: controller,
                        onMessage: _toast,
                      ),
                      _StorefrontSection(
                        key: ValueKey(controller.storefront.hashCode),
                        controller: controller,
                        onMessage: _toast,
                      ),
                      _SourcesSection(
                        controller: controller,
                        onMessage: _toast,
                      ),
                      _NotificationsSection(
                        controller: widget.notificationController,
                        products: controller.products,
                        onMessage: _toast,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.mode,
    required this.loading,
    required this.error,
  });

  final AdminConnectionMode mode;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final live = mode == AdminConnectionMode.live;
    return Container(
      width: double.infinity,
      color: live ? const Color(0xFFEAF4EC) : const Color(0xFFF7F0E6),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? const Color(0xFF3B7B4A) : kGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live ? 'CONTROL EN VIVO' : 'VISTA PREVIA',
                  style: eyebrow(
                    size: 9,
                    color: live ? const Color(0xFF2F633B) : kGold,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error ??
                      (live
                          ? 'Los cambios se publican en Shopify y se reflejan '
                              'en la app.'
                          : 'Puedes revisar el panel; los cambios todavía no '
                              'se publican.'),
                  style: sans(size: 11, color: kInkMuted, height: 1.35),
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 5),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.grid_view_rounded, 'Resumen'),
    (Icons.inventory_2_outlined, 'Productos'),
    (Icons.storefront_outlined, 'Tienda'),
    (Icons.language_rounded, 'Fuentes'),
    (Icons.notifications_outlined, 'Avisos'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final item = _items[index];
          final active = selected == index;
          return Semantics(
            selected: active,
            button: true,
            child: InkWell(
              key: ValueKey('admin-section-$index'),
              onTap: () => onSelected(index),
              child: Container(
                width: 88,
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? kGold : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(item.$1, size: 19, color: active ? kInk : kInkMuted),
                    const SizedBox(height: 5),
                    Text(
                      item.$2,
                      style: sans(
                        size: 10,
                        color: active ? kInk : kInkMuted,
                        weight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.controller, required this.onSync});

  final AdminController controller;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final inStock = controller.products.where((item) => item.inStock).length;
    final externalItems = controller.sources.fold<int>(
      0,
      (total, source) => total + source.itemCount,
    );
    return _AdminScroll(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: kInk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRACIÓN',
                style: eyebrow(size: 9, color: kGold),
              ),
              const SizedBox(height: 10),
              Text(
                'Todo Monetta,\nen un solo lugar.',
                style: display(30, color: Colors.white, height: 1.08),
              ),
              const SizedBox(height: 12),
              Text(
                'Catálogo, portada, comisiones e inventario conectados con '
                'Shopify y la app.',
                style: sans(size: 12, color: const Color(0xFFCACACA)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('HOY', style: eyebrow()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                value: '${controller.products.length}',
                label: 'productos',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _Metric(value: '$inStock', label: 'con stock')),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(value: '$externalItems', label: 'externos'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('CANALES', style: eyebrow()),
        const SizedBox(height: 10),
        const _ChannelRow(
          icon: Icons.shopping_bag_outlined,
          title: 'Shopify',
          description: 'Precios, publicación e inventario',
          status: 'Conectado',
        ),
        const _ChannelRow(
          icon: Icons.phone_iphone_rounded,
          title: 'App Monetta',
          description: 'Catálogo y contenido visible',
          status: 'Activa',
        ),
        const _ChannelRow(
          icon: Icons.language_rounded,
          title: 'Fuentes externas',
          description: 'Selección, comisión y disponibilidad',
          status: 'Monitoreo',
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('admin-sync-all'),
          onPressed: controller.saving ? null : onSync,
          icon: controller.saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: const Text('SINCRONIZAR TODO'),
        ),
        if (controller.audit.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('ACTIVIDAD RECIENTE', style: eyebrow()),
          const SizedBox(height: 8),
          for (final event in controller.audit) _AuditRow(event: event),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: kLine, width: .5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: display(24)),
          Text(label, style: sans(size: 10, color: kInkMuted)),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kLine, width: .5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sans(size: 13, weight: FontWeight.w600)),
                Text(description, style: sans(size: 10, color: kInkMuted)),
              ],
            ),
          ),
          _StatusPill(label: status),
        ],
      ),
    );
  }
}

class _ProductsSection extends StatefulWidget {
  const _ProductsSection({required this.controller, required this.onMessage});

  final AdminController controller;
  final ValueChanged<String> onMessage;

  @override
  State<_ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<_ProductsSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final products = widget.controller.products
        .where(
          (product) =>
              query.isEmpty || product.title.toLowerCase().contains(query),
        )
        .toList();
    return _AdminScroll(
      children: [
        Text('Catálogo', style: display(28)),
        const SizedBox(height: 6),
        Text(
          'Cambios de precio y visibilidad se envían a Shopify y después se '
          'actualizan en la app.',
          style: sans(size: 12, color: kInkMuted),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('admin-product-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Buscar producto',
            prefixIcon: Icon(Icons.search, size: 20),
            filled: true,
            fillColor: kSearchFill,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        Text('${products.length} PRODUCTOS', style: eyebrow(size: 9)),
        const SizedBox(height: 6),
        for (final product in products)
          _ProductRow(
            product: product,
            onTap: () => _openEditor(product),
          ),
      ],
    );
  }

  Future<void> _openEditor(AdminProductRecord product) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _ProductEditor(
        product: product,
        controller: widget.controller,
      ),
    );
    if (!mounted || saved != true) return;
    widget.onMessage(
      widget.controller.mode == AdminConnectionMode.live
          ? 'Producto actualizado en Shopify y la app.'
          : 'Cambio guardado solamente en la vista previa.',
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final AdminProductRecord product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('admin-product-${product.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine, width: .5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 72,
              child: MonettaImage(
                url: product.imageUrl,
                fallbackLabel: product.title,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: sans(size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(kMoney.format(product.price), style: sans(size: 12)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _StatusPill(
                        label: product.inStock ? 'Con stock' : 'Agotado',
                        muted: !product.inStock,
                      ),
                      const SizedBox(width: 6),
                      const _StatusPill(label: 'Shopify'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kInkMuted),
          ],
        ),
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.product, required this.controller});

  final AdminProductRecord product;
  final AdminController controller;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  late final TextEditingController _title;
  late final TextEditingController _price;
  late bool _visible;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.product.title);
    _price =
        TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _visible = widget.product.visible;
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text('Editar producto', style: display(26)),
            const SizedBox(height: 5),
            Text(
              'Se actualizará en Shopify y en la app Monetta.',
              style: sans(size: 11, color: kInkMuted),
            ),
            const SizedBox(height: 22),
            TextField(
              key: const ValueKey('admin-product-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('admin-product-price'),
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixText: r'$ ',
                suffixText: 'MXN',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Visible en la tienda', style: sans(size: 13)),
              subtitle: Text(
                _visible ? 'Publicado' : 'Oculto para clientes',
                style: sans(size: 11, color: kInkMuted),
              ),
              value: _visible,
              onChanged: (value) => setState(() => _visible = value),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('admin-save-product'),
              onPressed: widget.controller.saving ? null : _save,
              child: const Text('REVISAR Y GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.replaceAll(',', '').trim());
    final title = _title.text.trim();
    if (price == null || price <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el nombre y el precio.')),
      );
      return;
    }
    final confirmed = await _confirmChange(
      context,
      title: '¿Guardar este producto?',
      description: 'El cambio afectará Shopify y el catálogo de la app.',
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.controller.saveProduct(
      widget.product.copyWith(title: title, price: price, visible: _visible),
    );
    if (mounted && ok) Navigator.pop(context, true);
  }
}

class _StorefrontSection extends StatefulWidget {
  const _StorefrontSection({
    required this.controller,
    required this.onMessage,
    super.key,
  });

  final AdminController controller;
  final ValueChanged<String> onMessage;

  @override
  State<_StorefrontSection> createState() => _StorefrontSectionState();
}

class _StorefrontSectionState extends State<_StorefrontSection> {
  late final TextEditingController _announcement;
  late bool _hero;
  late bool _newest;
  late bool _external;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.storefront;
    _announcement = TextEditingController(text: settings.announcement);
    _announcement.addListener(_refreshPreview);
    _hero = settings.showHero;
    _newest = settings.showNewest;
    _external = settings.showExternalPicks;
  }

  @override
  void dispose() {
    _announcement.removeListener(_refreshPreview);
    _announcement.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScroll(
      children: [
        Text('Tienda', style: display(28)),
        const SizedBox(height: 6),
        Text(
          'Controla lo que ven tus clientes sin salir de Monetta.',
          style: sans(size: 12, color: kInkMuted),
        ),
        const SizedBox(height: 24),
        Text('AVISO SUPERIOR', style: eyebrow()),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('admin-announcement'),
          controller: _announcement,
          maxLength: 70,
          decoration: const InputDecoration(
            labelText: 'Mensaje',
            helperText: 'Aparece arriba de la portada.',
          ),
        ),
        const SizedBox(height: 18),
        Text('SECCIONES DE PORTADA', style: eyebrow()),
        const SizedBox(height: 8),
        _SettingSwitch(
          title: 'Campaña principal',
          description: 'Video e imagen editorial de portada',
          value: _hero,
          onChanged: (value) => setState(() => _hero = value),
        ),
        _SettingSwitch(
          title: 'Novedades',
          description: 'Productos recién agregados en Shopify',
          value: _newest,
          onChanged: (value) => setState(() => _newest = value),
        ),
        _SettingSwitch(
          title: 'Selección externa',
          description: 'Bolsas y perfumes elegidos por el monitor',
          value: _external,
          onChanged: (value) => setState(() => _external = value),
        ),
        const SizedBox(height: 22),
        _PhonePreview(
          announcement: _announcement.text,
          showHero: _hero,
          showNewest: _newest,
          showExternal: _external,
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('admin-save-storefront'),
          onPressed: widget.controller.saving ? null : _save,
          child: const Text('GUARDAR PORTADA'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final confirmed = await _confirmChange(
      context,
      title: '¿Publicar cambios de portada?',
      description: 'Se reflejarán en Shopify y en la app Monetta.',
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.controller.saveStorefront(
      AdminStorefrontSettings(
        announcement: _announcement.text.trim(),
        showHero: _hero,
        showNewest: _newest,
        showExternalPicks: _external,
      ),
    );
    if (!mounted) return;
    widget.onMessage(
      ok
          ? widget.controller.mode == AdminConnectionMode.live
              ? 'Portada publicada en Shopify y la app.'
              : 'Portada guardada solamente en vista previa.'
          : widget.controller.lastError ?? 'No se pudo guardar.',
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: sans(size: 13, weight: FontWeight.w600)),
      subtitle: Text(description, style: sans(size: 10, color: kInkMuted)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({
    required this.announcement,
    required this.showHero,
    required this.showNewest,
    required this.showExternal,
  });

  final String announcement;
  final bool showHero;
  final bool showNewest;
  final bool showExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      color: kMist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VISTA PREVIA', style: eyebrow(size: 9)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kInk, width: 1.5),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: 22,
                    width: double.infinity,
                    color: kInk,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      announcement.isEmpty ? 'MONETTA' : announcement,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: eyebrow(size: 5, color: Colors.white),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: MonettaWordmark(height: 12),
                  ),
                  if (showHero)
                    Container(
                      height: 92,
                      width: double.infinity,
                      color: const Color(0xFFEAE4DC),
                      alignment: Alignment.center,
                      child: Text('CAMPAÑA', style: eyebrow(size: 6)),
                    ),
                  if (showNewest)
                    _PreviewLine(label: 'NOVEDADES', color: kGold),
                  if (showExternal)
                    const _PreviewLine(
                      label: 'SELECCIÓN ESPECIAL',
                      color: kInk,
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: eyebrow(size: 5, color: color)),
          const SizedBox(height: 5),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(child: Container(height: 38, color: kMist)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.controller, required this.onMessage});

  final AdminController controller;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    return _AdminScroll(
      children: [
        Text('Fuentes', style: display(28)),
        const SizedBox(height: 6),
        Text(
          'Decide qué proveedores monitorear y cuánto margen aplicar. Los '
          'artículos externos no entran al inventario de Shopify.',
          style: sans(size: 12, color: kInkMuted),
        ),
        const SizedBox(height: 22),
        for (final source in controller.sources)
          _SourceCard(
            source: source,
            onTap: () => _openSource(context, source),
          ),
      ],
    );
  }

  Future<void> _openSource(
    BuildContext context,
    AdminSourcePolicy source,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _SourceEditor(source: source, controller: controller),
    );
    if (!context.mounted || saved != true) return;
    onMessage(
      controller.mode == AdminConnectionMode.live
          ? 'Fuente actualizada en el monitor y la app.'
          : 'Fuente guardada solamente en vista previa.',
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});

  final AdminSourcePolicy source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('admin-source-${source.id}'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: kLine, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    source.merchant,
                    style: sans(size: 14, weight: FontWeight.w600),
                  ),
                ),
                _StatusPill(
                  label: source.enabled ? 'Activa' : 'Pausada',
                  muted: !source.enabled,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: kInkMuted),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _SourceMetric(
                    value: '${source.itemCount}',
                    label: 'en catálogo',
                  ),
                ),
                Expanded(
                  child: _SourceMetric(
                    value: '${(source.baseCommissionRate * 100).round()}%',
                    label: 'comisión base',
                  ),
                ),
                Expanded(
                  child: _SourceMetric(
                    value: '${source.itemLimit}',
                    label: 'máximo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceMetric extends StatelessWidget {
  const _SourceMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: sans(size: 13, weight: FontWeight.w600)),
        Text(label, style: sans(size: 9, color: kInkMuted)),
      ],
    );
  }
}

class _SourceEditor extends StatefulWidget {
  const _SourceEditor({required this.source, required this.controller});

  final AdminSourcePolicy source;
  final AdminController controller;

  @override
  State<_SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<_SourceEditor> {
  late bool _enabled;
  late final TextEditingController _limit;
  late final TextEditingController _baseRate;
  late final TextEditingController _highRate;
  late final TextEditingController _threshold;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _enabled = source.enabled;
    _limit = TextEditingController(text: '${source.itemLimit}');
    _baseRate = TextEditingController(
      text: '${(source.baseCommissionRate * 100).round()}',
    );
    _highRate = TextEditingController(
      text: '${(source.highValueCommissionRate * 100).round()}',
    );
    _threshold = TextEditingController(
      text: source.highValueThreshold.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _limit.dispose();
    _baseRate.dispose();
    _highRate.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text(widget.source.merchant, style: display(26)),
            const SizedBox(height: 5),
            Text(
              'Curaduría automática para el catálogo de la app.',
              style: sans(size: 11, color: kInkMuted),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Monitorear esta fuente', style: sans(size: 13)),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Máx. artículos',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _baseRate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Comisión base',
                      suffixText: '%',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Desde',
                      prefixText: r'$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _highRate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Comisión alta gama',
                      suffixText: '%',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'La comisión menor aplica cuando el precio supera el umbral.',
              style: sans(size: 10, color: kInkMuted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('admin-save-source'),
              onPressed: widget.controller.saving ? null : _save,
              child: const Text('REVISAR Y GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final limit = int.tryParse(_limit.text.trim());
    final base = double.tryParse(_baseRate.text.trim());
    final high = double.tryParse(_highRate.text.trim());
    final threshold =
        double.tryParse(_threshold.text.replaceAll(',', '').trim());
    if (limit == null ||
        limit < 1 ||
        limit > 100 ||
        base == null ||
        base < 0 ||
        base > 100 ||
        high == null ||
        high < 0 ||
        high > 100 ||
        threshold == null ||
        threshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa límites y porcentajes.')),
      );
      return;
    }
    final confirmed = await _confirmChange(
      context,
      title: '¿Actualizar esta fuente?',
      description: 'El monitor usará estas reglas en su próxima ejecución.',
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.controller.saveSource(
      widget.source.copyWith(
        enabled: _enabled,
        itemLimit: limit,
        baseCommissionRate: base / 100,
        highValueCommissionRate: high / 100,
        highValueThreshold: threshold,
      ),
    );
    if (mounted && ok) Navigator.pop(context, true);
  }
}

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection({
    required this.controller,
    required this.products,
    required this.onMessage,
  });

  final AdminNotificationController? controller;
  final List<AdminProductRecord> products;
  final ValueChanged<String> onMessage;

  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _trait = TextEditingController();
  String _audience = 'announcements';
  bool _openProduct = false;
  String? _productId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _trait.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null || !controller.available) {
      return _AdminScroll(
        children: [
          Text('Notificaciones', style: display(28)),
          const SizedBox(height: 8),
          Text(
            'Configura la URL del servicio para crear campañas y activar automatizaciones.',
            style: sans(size: 12, color: kInkMuted),
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _AdminScroll(
        children: [
          Text('Notificaciones', style: display(28)),
          const SizedBox(height: 6),
          Text(
            'El servidor decide la audiencia con consentimiento, horario '
            'silencioso, límite de frecuencia y perfil resumido.',
            style: sans(size: 12, color: kInkMuted, height: 1.45),
          ),
          if (controller.loading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(minHeight: 1.5),
          ],
          if (controller.lastError != null) ...[
            const SizedBox(height: 14),
            Text(
              controller.lastError!,
              style: sans(size: 11, color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${controller.overview.grantedEndpoints}',
                  label: 'dispositivos',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  value: '${controller.overview.personalizedProfiles}',
                  label: 'perfiles',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  value: '${controller.overview.queuedDeliveries}',
                  label: 'en cola',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('NUEVA CAMPAÑA', style: eyebrow()),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('notification-campaign-title'),
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('notification-campaign-body'),
            controller: _body,
            maxLength: 180,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Mensaje'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('notification-campaign-audience'),
            initialValue: _audience,
            decoration: const InputDecoration(labelText: 'Audiencia'),
            items: const [
              DropdownMenuItem(
                value: 'announcements',
                child: Text('Anuncios · personas suscritas'),
              ),
              DropdownMenuItem(
                value: 'high_intent',
                child: Text('Ofertas · alta intención'),
              ),
              DropdownMenuItem(
                value: 'brand',
                child: Text('Ofertas · afinidad de marca'),
              ),
              DropdownMenuItem(
                value: 'category',
                child: Text('Ofertas · afinidad de categoría'),
              ),
            ],
            onChanged: controller.pendingCampaign == null
                ? (value) => setState(() => _audience = value ?? _audience)
                : null,
          ),
          if (_audience == 'brand' || _audience == 'category') ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('notification-campaign-trait'),
              controller: _trait,
              decoration: InputDecoration(
                labelText: _audience == 'brand'
                    ? 'Slug de marca (ej. coach)'
                    : 'Slug de categoría (ej. bolsa)',
              ),
            ),
          ],
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Abrir un producto', style: sans(size: 13)),
            subtitle: Text(
              _openProduct
                  ? 'La notificación abre la pieza.'
                  : 'Abre la portada.',
              style: sans(size: 11, color: kInkMuted),
            ),
            value: _openProduct,
            onChanged: controller.pendingCampaign == null
                ? (value) => setState(() => _openProduct = value)
                : null,
          ),
          if (_openProduct && widget.products.isNotEmpty)
            DropdownButtonFormField<String>(
              key: const ValueKey('notification-campaign-product'),
              initialValue: _productId,
              decoration: const InputDecoration(labelText: 'Producto'),
              items: [
                for (final product in widget.products)
                  DropdownMenuItem(
                    value: product.id,
                    child: SizedBox(
                      width: 240,
                      child: Text(
                        product.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _productId = value),
            ),
          const SizedBox(height: 16),
          if (controller.pendingCampaign == null)
            FilledButton.icon(
              key: const ValueKey('notification-create-preview'),
              onPressed: controller.saving ? null : _createPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('CREAR Y REVISAR AUDIENCIA'),
            )
          else
            _CampaignReview(
              preview: controller.pendingCampaign!,
              saving: controller.saving,
              onTest: _sendTest,
              onSchedule: _schedule,
              onDiscard: controller.discardPending,
            ),
          const SizedBox(height: 32),
          Text('AUTOMATIZACIONES', style: eyebrow()),
          const SizedBox(height: 8),
          for (final rule in controller.rules)
            SwitchListTile.adaptive(
              key: ValueKey('notification-rule-${rule.key}'),
              contentPadding: EdgeInsets.zero,
              title: Text(_ruleLabel(rule.key), style: sans(size: 13)),
              subtitle: Text(
                _ruleDescription(rule.key),
                style: sans(size: 10.5, color: kInkMuted),
              ),
              value: rule.enabled,
              onChanged: controller.saving
                  ? null
                  : (_) async {
                      final ok = await controller.toggleRule(rule);
                      if (ok) widget.onMessage('Automatización actualizada.');
                    },
            ),
          if (controller.overview.recentCampaigns.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('CAMPAÑAS RECIENTES', style: eyebrow()),
            const SizedBox(height: 8),
            for (final campaign in controller.overview.recentCampaigns)
              _CampaignRow(campaign: campaign),
          ],
        ],
      ),
    );
  }

  Future<void> _createPreview() async {
    final controller = widget.controller!;
    final title = _title.text.trim();
    final body = _body.text.trim();
    final trait = _trait.text.trim().toLowerCase();
    if (title.isEmpty || body.isEmpty) {
      widget.onMessage('Escribe el título y el mensaje.');
      return;
    }
    if ((_audience == 'brand' || _audience == 'category') && trait.isEmpty) {
      widget.onMessage('Escribe la marca o categoría de la audiencia.');
      return;
    }
    if (_openProduct && _productId == null) {
      widget.onMessage('Elige el producto que abrirá la notificación.');
      return;
    }
    final segment = switch (_audience) {
      'high_intent' => <String, Object>{'kind': 'high_intent'},
      'brand' => <String, Object>{
          'kind': 'brand',
          'value': trait,
          'minimumScore': 60,
        },
      'category' => <String, Object>{
          'kind': 'category',
          'value': trait,
          'minimumScore': 60,
        },
      _ => <String, Object>{'kind': 'all'},
    };
    final route = _openProduct
        ? <String, Object>{
            'type': 'product',
            'productKey': 'shopify:${_productId!}',
          }
        : <String, Object>{'type': 'home'};
    final ok = await controller.createDraft(
      CampaignDraftInput(
        title: title,
        body: body,
        purpose: _audience == 'announcements'
            ? 'announcements'
            : 'personalized_offers',
        segment: segment,
        route: route,
      ),
    );
    if (ok) widget.onMessage('Audiencia calculada. Revisa antes de enviar.');
  }

  Future<void> _sendTest() async {
    final ok = await widget.controller!.sendPendingTest();
    widget.onMessage(
      ok
          ? 'Prueba puesta en cola para este dispositivo.'
          : 'No se envió la prueba.',
    );
  }

  Future<void> _schedule() async {
    final confirmed = await _confirmChange(
      context,
      title: '¿Enviar esta campaña?',
      description:
          'Se creará una entrega por dispositivo elegible. Esta acción queda auditada.',
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.controller!.schedulePending();
    if (ok) {
      _title.clear();
      _body.clear();
    }
    widget.onMessage(
      ok ? 'Campaña puesta en cola.' : 'No se programó la campaña.',
    );
  }

  static String _ruleLabel(String key) => switch (key) {
        'restock' => 'Regreso de producto',
        'price_drop' => 'Baja de precio',
        'new_arrival' => 'Nueva llegada afín',
        'local_cart_reminder' => 'Recordatorio local de bolsa',
        _ => key,
      };

  static String _ruleDescription(String key) => switch (key) {
        'restock' => 'Sólo para personas que tocaron “Avísame”.',
        'price_drop' => 'Usa afinidad resumida y consentimiento de ofertas.',
        'new_arrival' => 'Segmenta por marca o categoría afín.',
        'local_cart_reminder' =>
          'Se programa en el dispositivo, no en el servidor.',
        _ => 'Regla automática del servicio.',
      };
}

class _CampaignReview extends StatelessWidget {
  const _CampaignReview({
    required this.preview,
    required this.saving,
    required this.onTest,
    required this.onSchedule,
    required this.onDiscard,
  });

  final CampaignPreview preview;
  final bool saving;
  final VoidCallback onTest;
  final VoidCallback onSchedule;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E6),
        border: Border.all(color: kLine, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${preview.eligible}', style: display(30)),
          Text('dispositivos elegibles ahora', style: sans(size: 11)),
          const SizedBox(height: 14),
          OutlinedButton(
            key: const ValueKey('notification-send-test'),
            onPressed: saving ? null : onTest,
            child: const Text('ENVIAR PRUEBA A ESTE TELÉFONO'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('notification-schedule-now'),
            onPressed: saving ? null : onSchedule,
            child: const Text('ENVIAR AHORA'),
          ),
          Center(
            child: TextButton(
              onPressed: saving ? null : onDiscard,
              child: const Text('DESCARTAR BORRADOR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({required this.campaign});

  final NotificationCampaignSummary campaign;

  @override
  Widget build(BuildContext context) {
    final openRate = campaign.acceptedCount == 0
        ? 0
        : (campaign.openedCount * 100 / campaign.acceptedCount).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kLine, width: .5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(campaign.title, style: sans(size: 12.5)),
                Text(
                  '${campaign.acceptedCount} enviados · ${campaign.openedCount} abiertos · $openRate%',
                  style: sans(size: 10, color: kInkMuted),
                ),
              ],
            ),
          ),
          _StatusPill(label: campaign.status),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.event});

  final AdminAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final minute = event.createdAt.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: kGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.description, style: sans(size: 12)),
                Text(
                  '${event.createdAt.hour}:$minute · '
                  '${event.previewOnly ? 'Vista previa' : 'Publicado'}',
                  style: sans(size: 9, color: kInkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? kMist : const Color(0xFFF4EEE6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: sans(size: 8, color: muted ? kInkMuted : kGold),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 3,
        margin: const EdgeInsets.only(bottom: 22),
        color: kLine,
      ),
    );
  }
}

class _AdminScroll extends StatelessWidget {
  const _AdminScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmChange(
  BuildContext context, {
  required String title,
  required String description,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: display(22)),
          content: Text(description, style: sans(size: 12, color: kInkMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              key: const ValueKey('admin-confirm-change'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONFIRMAR'),
            ),
          ],
        ),
      ) ??
      false;
}
