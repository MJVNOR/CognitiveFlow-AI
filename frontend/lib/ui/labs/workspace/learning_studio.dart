// Learning Studio: layout compartido de los laboratorios.
// Desktop (≥1080 px dentro del shell): actividad ~70% | tutor ~30%.
// Tablet/móvil: una columna; el tutor es un panel plegable sobre la actividad
// y la CTA + misiones quedan fijas al pie (siempre accesibles).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';

/// Ancho (del área del lab, no del viewport) desde el que el tutor va al lado.
const studioWideBreakpoint = 1080.0;

class LearningStudioScaffold extends StatelessWidget {
  final Widget header;
  final Widget stage;
  final Widget actionBar;
  final Widget missions;

  /// null = sin tutor (postest).
  final Widget? tutor;

  /// Resumen de una línea del tutor cuando está plegado (móvil/tablet).
  final String tutorSummary;
  final ScrollController? stageScroll;

  /// Identidad del escenario (misión): al cambiar, el área desplazable se
  /// recrea y arranca arriba con su semántica alineada (sin jumpTo).
  final Key? stageKey;

  const LearningStudioScaffold({
    super.key,
    required this.header,
    required this.stage,
    required this.actionBar,
    required this.missions,
    this.tutor,
    this.tutorSummary = '',
    this.stageScroll,
    this.stageKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= studioWideBreakpoint;
        final pad = c.maxWidth < 600 ? 16.0 : 24.0;
        if (wide) {
          final tutorW = (c.maxWidth * 0.3).clamp(320.0, 400.0);
          return Column(children: [
            header,
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Column(children: [
                    Expanded(
                      child: Scrollbar(
                        controller: stageScroll,
                        child: SingleChildScrollView(
                          key: stageKey,
                          controller: stageScroll,
                          padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
                          child: stage,
                        ),
                      ),
                    ),
                    actionBar,
                  ]),
                ),
                if (tutor != null)
                  SizedBox(
                    width: tutorW,
                    child: Material(
                      color: cs.surface,
                      shape: Border(left: BorderSide(color: cs.outlineVariant)),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: tutor,
                      ),
                    ),
                  ),
              ]),
            ),
            missions,
          ]);
        }
        return Column(children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              key: stageKey,
              controller: stageScroll,
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tutor != null) ...[
                    _FoldedTutor(summary: tutorSummary, child: tutor!),
                    const SizedBox(height: 12),
                  ],
                  stage,
                ],
              ),
            ),
          ),
          actionBar,
          missions,
        ]);
      }),
    );
  }
}

class _FoldedTutor extends StatelessWidget {
  final String summary;
  final Widget child;
  const _FoldedTutor({required this.summary, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.tertiary.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('tutor_fold'),
        maintainState: true,
        leading: Icon(Icons.psychology_alt_outlined, color: cs.tertiary),
        title: const Text('Tutor', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: summary.isEmpty
            ? null
            : Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        expansionAnimationStyle: AnimationStyle(
            duration: Motion.at(context, Motion.base), curve: Motion.mechanical),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}

/// Cabecera del studio: migas, desafío y progreso real de misiones.
class StudioHeader extends StatelessWidget {
  final List<(String, String?)> crumbs;
  final String title;
  final String missionLabel;
  final int done;
  final int total;
  final String? meta;
  final Widget? trailing;
  final String? backRoute;
  const StudioHeader({
    super.key,
    required this.crumbs,
    required this.title,
    required this.missionLabel,
    required this.done,
    required this.total,
    this.meta,
    this.trailing,
    this.backRoute,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = Semantics(
      label: '$done de $total misiones completadas',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$done/$total misiones',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          SizedBox(
            width: 132,
            child: Row(children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.at(context, Motion.base),
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: i < done ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 560;
        final crumbRow = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant),
                ),
              _Crumb(label: crumbs[i].$1, route: crumbs[i].$2),
            ],
          ],
        );
        final titleCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            crumbRow,
            const SizedBox(height: 2),
            Semantics(
              header: true,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(
              meta == null ? missionLabel : '$missionLabel · $meta',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (backRoute != null)
              IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(backRoute!),
              ),
            const SizedBox(width: 4),
            Expanded(child: titleCol),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (!narrow) ...[const SizedBox(width: 16), progress],
          ],
        );
      }),
    );
  }
}

class _Crumb extends StatelessWidget {
  final String label;
  final String? route;
  const _Crumb({required this.label, this.route});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 12,
      color: route == null ? cs.onSurfaceVariant : cs.primary,
      decoration: route == null ? null : TextDecoration.underline,
      decorationColor: cs.primary,
    );
    if (route == null) return Text(label, style: style);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => context.go(route!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

/// Barra de la única acción primaria de la fase. El texto de ayuda explica
/// por qué está deshabilitada (nunca un botón muerto sin razón).
class ActivityActionBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? helper;
  final bool busy;
  final Key buttonKey;
  const ActivityActionBar({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.buttonKey,
    this.helper,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = FilledButton.icon(
      key: buttonKey,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant))
          : Icon(icon),
      label: Text(label),
    );
    final help = helper == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Text(helper!,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          );
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (helper != null) ...[help, const SizedBox(height: 6)],
              button,
            ],
          );
        }
        return Row(children: [
          Expanded(child: help),
          const SizedBox(width: 12),
          button,
        ]);
      }),
    );
  }
}
