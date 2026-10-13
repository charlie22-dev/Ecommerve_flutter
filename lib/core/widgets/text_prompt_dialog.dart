import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

/// Asks for one or more lines of text (a rejection reason, a tracking
/// number…). Returns the trimmed values, or null if cancelled. Every field
/// is required unless [optional] is set.
Future<List<String>?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required List<String> fields,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  bool optional = false,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      fields: fields,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      optional: optional,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.fields,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    required this.optional,
  });

  final String title;
  final List<String> fields;
  final String? message;
  final String confirmLabel;
  final bool destructive;
  final bool optional;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controllers = [for (final _ in widget.fields) TextEditingController()];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < widget.fields.length; i++) ...[
              TextFormField(
                controller: _controllers[i],
                autofocus: i == 0,
                minLines: 1,
                maxLines: widget.fields.length == 1 ? 3 : 1,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(hintText: widget.fields[i]),
                validator: (v) => widget.optional || (v ?? '').trim().isNotEmpty ? null : 'Required',
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop([for (final c in _controllers) c.text.trim()]);
          },
          child: Text(
            widget.confirmLabel,
            style: TextStyle(color: widget.destructive ? colors.error : colors.textPrimary),
          ),
        ),
      ],
    );
  }
}
