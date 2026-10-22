// Secuencia horizontal de misiones del Learning Studio. El estado de cada
// misión lo deriva la página desde el servidor; aquí solo se presenta.
import 'package:flutter/material.dart';

import '../../core/motion.dart';

enum MissionStatus { done, current, available, locked }

class Mission {
  final String id;
  final String title;
  final String goal;
  final IconData icon;
  const Mission(this.id, this.title, this.goal, this.icon);
}

class MissionView {
  final Mission mission;
  final MissionStatus status;
  final bool navigable;
  const MissionView(this.mission, this.status, {required this.navigable});
}

String missionStatusLabel(MissionStatus s) => switch (s) {
      MissionStatus.done => 'Completada',
      MissionStatus.current => 'Actual',
      MissionStatus.available => 'Disponible',
      MissionStatus.locked => 'Bloqueada',
    };

class MissionNavigation extends StatefulWidget {
  final List<MissionView> missions;
  final int selected;
  final ValueChanged<int> onSelect;
  const MissionNavigation({
    super.key,
    required this.missions,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<MissionNavigation> createState() => _MissionNavigationState();
}

class _MissionNavigationState extends State<MissionNavigation> {
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(MissionNavigation old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // En la tira desplazable, la misión actual siempre queda a la vista.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.selected]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.5, duration: Motion.at(context, Motion.base));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Misiones del laboratorio',
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(builder: (context, c) {
          final n = widget.missions.length;
          final fits = c.maxWidth >= n * 150;
          final tiles = [
            for (var i = 0; i < n; i++)
              _MissionTile(
                key: _keys.putIfAbsent(i, GlobalKey.new),
                index: i,
                view: widget.missions[i],
                selected: i == widget.selected,
                onTap: widget.missions[i].navigable ? () => widget.onSelect(i) : null,
              ),
          ];
          if (fits) {
            return Row(children: [
              for (final t in tiles) Expanded(child: t),
            ]);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in tiles) SizedBox(width: 160, child: t),
            ]),
          );
        }),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final int index;
  final MissionView view;
  final bool selected;
  final VoidCallback? onTap;
  const _MissionTile({
    super.key,
    required this.index,
    required this.view,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = view.status;
    final locked = status == MissionStatus.locked;
    final done = status == MissionStatus.done;
    final fg = locked ? cs.onSurfaceVariant : (selected ? cs.primary : cs.onSurface);
    final badge = done
        ? Icon(Icons.check_circle, size: 16, color: cs.primary)
            .enterCheck(context, ValueKey('done-${view.mission.id}'))
        : locked
            ? Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant)
            : const SizedBox(width: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: 'Misión ${index + 1}: ${view.mission.title}, '
            '${selected ? 'actual' : missionStatusLabel(status)}',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('mission_${view.mission.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.at(context, Motion.quick),
              curve: Motion.mechanical,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? cs.primaryContainer.withValues(alpha: 0.55) : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: locked ? cs.surfaceContainerHighest : cs.secondaryContainer,
                    ),
                    child: Icon(view.mission.icon,
                        size: 18,
                        color: locked ? cs.onSurfaceVariant : cs.onSecondaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Misión ${index + 1} · ${selected ? 'Actual' : missionStatusLabel(status)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                        Text(
                          view.mission.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  badge,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
