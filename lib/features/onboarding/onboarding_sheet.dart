/// Cold-start onboarding: three taps, then the first feed is already personal.
///
/// Optional by design — skipping it falls back to trending, never an empty
/// screen. See `lib/reco/README.md` § 5.
///
/// Styled as a full menu panel — wordmark, close, hairline — rather than
/// the small rounded card a `showModalBottomSheet` gives by default. It still
/// arrives *through* that same call (`isScrollControlled: true`, and
/// `bottomSheetTheme` already squares the corners — see `app/theme.dart`), it
/// just requests the full viewport height so nothing peeks up from the
/// bottom: the shopper sees one continuous panel, not a sheet over a page.
/// No gender split — the catalog is effectively single-audience, unlike the
/// reference this was modeled on.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../main.dart';
import '../../reco/explainer.dart';

const Map<String, String> _categoryLabels = {
  'bolsa': 'Bolsas',
  'cartera': 'Carteras',
  'reloj': 'Relojes',
  'monedero': 'Monederos',
  'cosmetiquera': 'Cosmetiqueras',
};

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final Set<String> _brands = {};
  final Set<String> _categories = {};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final colors = context.monettaColors;
    // `showModalBottomSheet` strips `MediaQuery.padding.top` from the
    // ambient MediaQuery it hands to its builder — a sheet is expected to
    // leave the status bar exposed, not to need a top inset. But this panel
    // asks for the *full* screen height (see the class doc), so with the
    // ambient value zeroed, `SafeArea` has nothing left to pad by and the
    // header ends up drawn underneath the status bar. Reading the real
    // device inset straight from the view sidesteps that stripped value.
    final viewPadding = MediaQueryData.fromView(View.of(context)).padding;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Material(
        color: colors.surface,
        child: Padding(
          padding: EdgeInsets.only(
            top: viewPadding.top,
            bottom: viewPadding.bottom,
          ),
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop(false)),
              const Divider(height: 0.5),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: Text(
                        'Elige marcas',
                        style: display(27, weight: FontWeight.w500),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        'Para mostrarte primero lo que te interesa. Puedes cambiarlo cuando quieras.',
                        style: sans(size: 12.5, color: colors.contentMuted),
                      ),
                    ),
                    for (final entry in _categoryLabels.entries)
                      _CategoryRow(
                        label: entry.value,
                        selected: _categories.contains(entry.key),
                        onTap: () => setState(
                          () => _categories.contains(entry.key)
                              ? _categories.remove(entry.key)
                              : _categories.add(entry.key),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                      child: Text('Marcas'.toUpperCase(), style: eyebrow()),
                    ),
                    for (final brand in store.availableBrands)
                      _LinkRow(
                        label: brandLabel(brand),
                        selected: _brands.contains(brand),
                        onTap: () => setState(
                          () => _brands.contains(brand)
                              ? _brands.remove(brand)
                              : _brands.add(brand),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const Divider(height: 0.5),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: FilledButton(
                  onPressed: () {
                    store.seedFrom(
                      brands: _brands.toList(),
                      categories: _categories.toList(),
                    );
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    (_brands.isEmpty && _categories.isEmpty
                            ? 'Ver todo'
                            : 'Ver mi selección')
                        .toUpperCase(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wordmark left, close right — identical row to [_MainDrawer]'s header, so
/// the panel this opens into reads as the same system as the hamburger menu
/// rather than a one-off modal.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Row(
        children: [
          const Expanded(child: MonettaWordmark(height: 19)),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

/// A product section — serif, with a trailing chevron that flips to a gold
/// check once selected. The chevron is repurposed rather than dropped: on
/// the reference this app's panel borrows from, it means "drill in"; here,
/// with no sub-pages to drill into, it doubles as the unselected state of a
/// toggle, so the row never needs a second visual language for "tap me."
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: .5)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: display(18))),
            Icon(
              selected ? Icons.check : Icons.chevron_right,
              size: 18,
              color: selected ? colors.accent : colors.contentMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain toggleable link — the register of the secondary block on the
/// reference (Mi Cuenta, Ayuda…): no chevron, just weight and colour to show
/// state.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: .5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: sans(
                  size: 14,
                  color: selected ? colors.contentPrimary : colors.contentMuted,
                  weight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 15, color: colors.accent),
          ],
        ),
      ),
    );
  }
}
