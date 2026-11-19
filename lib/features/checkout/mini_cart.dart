/// Confirmed adds use the same editable cart that opens from navigation.
library;

import 'package:flutter/material.dart';

import '../navigation/duo_workspace.dart';
import 'checkout_screen.dart';

Future<void> showMiniCart(BuildContext context) {
  if (DuoWorkspace.confirmAdded(context)) return Future<void>.value();
  return showBagDrawer(context, title: 'Agregado al carrito');
}
