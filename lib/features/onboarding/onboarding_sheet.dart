/// Cold-start onboarding: three taps, then the first feed is already personal.
///
/// Optional by design — skipping it falls back to trending, never an empty
/// screen. See `lib/reco/README.md` § 5.
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Qué te gusta?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 4),
            Text(
              'Para mostrarte lo tuyo primero. Puedes cambiarlo cuando quieras.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('MARCAS'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: store.availableBrands
                  .map(
                    (brand) => _Choice(
                      label: brandLabel(brand),
                      selected: _brands.contains(brand),
                      onTap: () => setState(
                        () => _brands.contains(brand)
                            ? _brands.remove(brand)
                            : _brands.add(brand),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('CATEGORÍAS'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryLabels.entries
                  .map(
                    (entry) => _Choice(
                      label: entry.value,
                      selected: _categories.contains(entry.key),
                      onTap: () => setState(
                        () => _categories.contains(entry.key)
                            ? _categories.remove(entry.key)
                            : _categories.add(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                store.seedFrom(
                  brands: _brands.toList(),
                  categories: _categories.toList(),
                );
                Navigator.of(context).pop();
              },
              child: Text(
                _brands.isEmpty && _categories.isEmpty
                    ? 'Ver todo'
                    : 'Ver mis recomendaciones',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kGold : Colors.transparent,
          border: Border.all(
            color: selected ? kGold : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? Colors.white : kInk,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
