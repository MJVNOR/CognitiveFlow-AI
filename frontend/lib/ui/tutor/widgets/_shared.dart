// Helpers compartidos del catálogo (antes en genui/catalog.dart).
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

double? numProp(Map data, String key) {
  final v = data[key];
  return v is num ? v.toDouble() : null;
}

Widget titledCard(BuildContext context, String title, String body,
    {IconData? icon, Color? accent, List<Widget> children = const []}) {
  return Card(
    shape: accent == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent),
          ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ...children,
        ],
      ),
    ),
  );
}

Widget boundCard(CatalogItemContext ctx, String titleKey, String bodyKey,
    {IconData? icon, Color Function(ColorScheme cs)? accent}) {
  final data = ctx.data as Map;
  // ponytail: Builder para Theme real (ctx.buildContext es mock en tests).
  return Builder(builder: (context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent?.call(cs);
    return Card(
      shape: ac == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ac),
            ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: ac),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: BoundString(
                    dataContext: ctx.dataContext,
                    value: data[titleKey],
                    builder: (c, v) => AutoSizeText(v ?? '',
                        maxLines: 1,
                        minFontSize: 12,
                        style: Theme.of(c).textTheme.titleSmall),
                  ),
                ),
              ],
            ),
            BoundString(
              dataContext: ctx.dataContext,
              value: data[bodyKey],
              builder: (c, v) => AutoSizeText(v ?? '',
                  maxLines: 3, minFontSize: 11, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  });
}
