import 'package:flutter/material.dart';

Future<bool> confirmExit(BuildContext context, {bool playback = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(playback ? 'Stop playback?' : 'Exit PurePlay?'),
      content: Text(playback
          ? 'Stop the current media and close the player?'
          : 'Are you sure you want to exit PurePlay?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EXIT')),
      ],
    ),
  );
  return result ?? false;
}
