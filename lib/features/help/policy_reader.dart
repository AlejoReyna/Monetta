/// UI for merchant-published policies. The source is supplied by the host.
library;

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';
import '../../data/customer_auth/customer_graphql_client.dart';
import '../../data/shopify/shop_policy_repository.dart';

typedef PolicyLoader
    = Future<Map<ShopPolicyKind, CapabilityRead<ShopPolicyContent>>> Function();
typedef PolicyLinkOpener = Future<bool> Function(Uri uri);

/// A00 may pass `repository.fetch` and place this scope above shared ends.
class PolicyController extends ChangeNotifier {
  PolicyController(this.load);
  final PolicyLoader load;
  Map<ShopPolicyKind, CapabilityRead<ShopPolicyContent>>? policies;
  bool loading = false;
  bool failed = false;
  int _generation = 0;
  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await load();
      if (generation != _generation) return;
      policies = result;
    } catch (_) {
      if (generation != _generation) return;
      policies = null;
      failed = true;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class PolicyScope extends InheritedNotifier<PolicyController> {
  const PolicyScope(
      {required PolicyController controller, required super.child, super.key})
      : super(notifier: controller);
  static PolicyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PolicyScope>()?.notifier;
}

Future<void> openPolicy(BuildContext context, ShopPolicyKind kind,
    {PolicyLinkOpener? openLink}) {
  final controller = PolicyScope.maybeOf(context);
  if (controller == null) return Future.value();
  // Refresh every visit so withdrawn content is not presented as current.
  controller.refresh();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) =>
        PolicyReader(kind: kind, controller: controller, openLink: openLink),
  ));
}

class PolicyReader extends StatefulWidget {
  const PolicyReader(
      {required this.kind, required this.controller, this.openLink, super.key});
  final ShopPolicyKind kind;
  final PolicyController controller;
  final PolicyLinkOpener? openLink;
  @override
  State<PolicyReader> createState() => _PolicyReaderState();
}

class _PolicyReaderState extends State<PolicyReader> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.policies == null &&
        !widget.controller.loading &&
        !widget.controller.failed) widget.controller.refresh();
  }

  Future<void> _open(Uri uri) async {
    try {
      final ok = await (widget.openLink ??
          ((u) => launchUrl(u, mode: LaunchMode.externalApplication)))(uri);
      if (ok || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted)
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final read = controller.policies?[widget.kind];
        final content =
            read?.status == CapabilityReadStatus.supported ? read?.value : null;
        return Scaffold(
            appBar: AppBar(title: const Text('Política')),
            body: SafeArea(
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.failed ||
                            read?.status == CapabilityReadStatus.failed
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('No se pudo cargar la política.'),
                                TextButton(
                                    onPressed: controller.refresh,
                                    child: const Text('Reintentar'))
                              ]))
                        : content == null
                            ? const Center(
                                child:
                                    Text('Esta política no está disponible.'))
                            : ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                    Text(content.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: 16),
                                    ..._policyBlocks(context, content.bodyHtml,
                                        content.url, _open),
                                  ])));
      });
}

// Render text and safe HTTPS links only. Scripts, forms, images and embedded
// content are never interpreted or loaded. Relative links resolve against CMS URL.
List<Widget> _policyBlocks(
    BuildContext context, String source, Uri base, void Function(Uri) open) {
  final document = html.parseFragment(source);
  final widgets = <Widget>[];
  const excluded = {
    'script',
    'style',
    'iframe',
    'object',
    'form',
    'svg',
    'img'
  };
  const blocks = {
    'p',
    'a',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'pre'
  };

  void render(dom.Node node, {bool block = false}) {
    if (node is dom.Element && excluded.contains(node.localName)) return;
    if (node is dom.Element && !block && !blocks.contains(node.localName)) {
      for (final child in node.nodes) {
        render(child);
      }
      return;
    }
    final text = StringBuffer();
    final links = <(String, Uri)>[];
    void collect(dom.Node part) {
      if (part is dom.Text) {
        text.write(part.text);
        return;
      }
      if (part is! dom.Element || excluded.contains(part.localName)) return;
      if (part.localName == 'br') {
        text.write('\n');
        return;
      }
      if (part.localName == 'a') {
        final href = part.attributes['href'];
        final parsed =
            href == null || href.trim().isEmpty ? null : Uri.tryParse(href);
        final uri = parsed == null ? null : base.resolveUri(parsed);
        final label = part.text.trim();
        if (label.isNotEmpty &&
            uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty) links.add((label, uri));
      }
      for (final child in part.nodes) {
        collect(child);
      }
    }

    collect(node);
    final value = text.toString().replaceAll(RegExp(r'[ \t\r\f]+'), ' ').trim();
    if (value.isEmpty) return;
    final heading = node is dom.Element &&
        const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(node.localName);
    widgets.add(Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText(
          node is dom.Element && node.localName == 'li' ? '• $value' : value,
          style: heading ? Theme.of(context).textTheme.titleLarge : null),
    ));
    for (final (label, uri) in links) {
      widgets.add(Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                  textStyle: const TextStyle(
                      fontFamily: 'DM Sans',
                      decoration: TextDecoration.underline)),
              onPressed: () => open(uri),
              child: Text(label))));
    }
  }

  for (final node in document.nodes) {
    render(node);
  }
  return widgets;
}

/// FAQ entries must come from an approved source supplied by the host.
class HelpQuestion {
  const HelpQuestion({required this.question, required this.answer});
  final String question;
  final String answer;
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({this.questions = const [], this.onContact, super.key});
  final List<HelpQuestion> questions;
  final VoidCallback? onContact;
  @override
  Widget build(BuildContext context) {
    final controller = PolicyScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: SafeArea(
          child: ListView(children: [
        for (final question in questions)
          ExpansionTile(title: Text(question.question), children: [
            Padding(
                padding: const EdgeInsets.all(16), child: Text(question.answer))
          ]),
        for (final entry in const <(ShopPolicyKind, String)>[
          (ShopPolicyKind.shipping, 'Envíos'),
          (ShopPolicyKind.refund, 'Cambios y devoluciones'),
          (ShopPolicyKind.privacy, 'Privacidad'),
          (ShopPolicyKind.terms, 'Términos')
        ])
          if (controller?.policies?[entry.$1]?.status ==
              CapabilityReadStatus.supported)
            ListTile(
                title: Text(entry.$2),
                onTap: () => openPolicy(context, entry.$1)),
        if (controller?.failed == true)
          ListTile(
              title: const Text('No se pudieron cargar las políticas'),
              trailing: TextButton(
                  onPressed: controller!.refresh,
                  child: const Text('Reintentar'))),
        if (onContact != null)
          ListTile(title: const Text('Contacto'), onTap: onContact),
      ])),
    );
  }
}

Future<void> openHelp(BuildContext context,
    {List<HelpQuestion> questions = const [], VoidCallback? onContact}) {
  final controller = PolicyScope.maybeOf(context);
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) {
    final screen = HelpScreen(questions: questions, onContact: onContact);
    return controller == null
        ? screen
        : PolicyScope(controller: controller, child: screen);
  }));
}
