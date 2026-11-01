import 'package:flutter/material.dart';

Future<bool> confirmAccountSwitch(
  BuildContext context, {
  required String targetSide,
  Color? confirmColor,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(child: Text('Switch accounts?')),
            ],
          ),
          content: Text(
            'Are you sure you want to switch to the $targetSide side?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: confirmColor == null
                  ? null
                  : FilledButton.styleFrom(backgroundColor: confirmColor),
              child: const Text('Yes, switch'),
            ),
          ],
        ),
      ) ??
      false;
}
