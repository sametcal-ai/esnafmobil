import 'package:flutter/material.dart';

Future<T> runWithLoadingDialog<T>(
  BuildContext context,
  Future<T> Function() action, {
  bool useRootNavigator = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);

  showDialog<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    return await action();
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
