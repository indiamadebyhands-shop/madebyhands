import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool> confirmAccountSwitch(
  BuildContext context, {
  required String targetSide,
  Color? confirmColor,
  bool isCreatingAccount = false,
}) async {
  final actionColor = confirmColor ?? const Color(0xFF8B261D);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFFFFF3E2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            isCreatingAccount
                ? 'Create $targetSide account?'
                : 'Switch accounts?',
            maxLines: 1,
            style: GoogleFonts.montserrat(
              color: actionColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            isCreatingAccount
                ? 'This will add a $targetSide account to the same email address. Continue?'
                : 'Are you sure you want to switch to the $targetSide side?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: actionColor,
                      side: BorderSide(color: actionColor, width: 1.3),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(
                      isCreatingAccount ? 'Yes create' : 'Yes switch',
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;
}
