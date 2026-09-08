import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:tepovka/services/app_settings.dart';

/// Formulář metadat, který se ve výzkumném režimu ukáže před měřením.
///
/// Vyplněné hodnoty se ukládají se záznamem a jdou do exportu, takže se
/// měření dá zpětně přiřadit k probandovi a protokolu. Pole si uživatel
/// nastavuje v [AppSettings.setResearchFields]; datum a čas se doplňují samy.
class ResearchMetadataDialog extends StatefulWidget {
  const ResearchMetadataDialog({
    super.key,
    required this.fields,
    this.initialValues = const {},
  });

  final List<String> fields;
  final Map<String, String> initialValues;

  /// Vrátí vyplněná metadata, nebo null když uživatel měření zruší.
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required List<String> fields,
    Map<String, String> initialValues = const {},
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResearchMetadataDialog(
        fields: fields,
        initialValues: initialValues,
      ),
    );
  }

  @override
  State<ResearchMetadataDialog> createState() => _ResearchMetadataDialogState();
}

class _ResearchMetadataDialogState extends State<ResearchMetadataDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field: TextEditingController(text: widget.initialValues[field] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stamp = '${now.day}. ${now.month}. ${now.year}, '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(L10n.of(context).researchDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).researchDialogAutoStamp(stamp),
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),
            for (final field in widget.fields) ...[
              TextField(
                controller: _controllers[field],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: field,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                // První pole bývá ID, které se často zadává opakovaně —
                // klávesnice se proto nesnaží nic opravovat.
                autocorrect: field != widget.fields.first,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(L10n.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final values = <String, String>{};
            _controllers.forEach((field, controller) {
              final text = controller.text.trim();
              if (text.isNotEmpty) values[field] = text;
            });
            Navigator.of(context).pop(values);
          },
          child: Text(L10n.of(context).researchDialogStart),
        ),
      ],
    );
  }
}
