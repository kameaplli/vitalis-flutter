import 'package:flutter/material.dart';
import '../../models/easi_models.dart';
import 'eczema_helpers.dart';

// ─── EASI scoring panel (bottom sheet) ───────────────────────────────────────

class EasiPanel extends StatefulWidget {
  final BodyRegion region;
  final EasiRegionScore initial;
  final Map<String, EasiRegionScore> allScores;
  final ScrollController? scrollController;
  final void Function(EasiRegionScore) onConfirm;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  const EasiPanel({
    super.key,
    required this.region,
    required this.initial,
    required this.allScores,
    this.scrollController,
    required this.onConfirm,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  State<EasiPanel> createState() => _EasiPanelState();
}

class _EasiPanelState extends State<EasiPanel> {
  late int _erythema, _papulation, _excoriation, _lichenification, _areaScore;
  late int _oozing, _dryness, _pigmentation;

  @override
  void initState() {
    super.initState();
    _erythema = widget.initial.erythema;
    _papulation = widget.initial.papulation;
    _excoriation = widget.initial.excoriation;
    _lichenification = widget.initial.lichenification;
    _areaScore = widget.initial.areaScore;
    _oozing = widget.initial.oozing;
    _dryness = widget.initial.dryness;
    _pigmentation = widget.initial.pigmentation;
  }

  double get _regional {
    return EasiRegionScore(
      regionId: widget.region.id, erythema: _erythema,
      papulation: _papulation, excoriation: _excoriation,
      lichenification: _lichenification, areaScore: _areaScore,
    ).easiContribution(widget.region.group);
  }

  double get _totalEasi {
    final updated = Map<String, EasiRegionScore>.from(widget.allScores);
    updated[widget.region.id] = EasiRegionScore(
      regionId: widget.region.id, erythema: _erythema,
      papulation: _papulation, excoriation: _excoriation,
      lichenification: _lichenification, areaScore: _areaScore,
    );
    return computeEasi(updated);
  }

  static const _areaLabels = [
    'Tiny\n<1%', 'Small\n1–9%', 'Some\n10–29%',
    'Large\n30–49%', 'Mostly\n50–69%', 'All\n≥70%',
  ];

  @override
  Widget build(BuildContext context) {
    final total = _totalEasi;
    final groupColor = easiColor(_regional * 2);

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.only(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.region.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(widget.region.group.label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () {
                Navigator.pop(context);
                widget.onDismiss();
              }),
            ]),
            const Divider(height: 16),

            // ── Skin appearance ─────────────────────────────────────────────
            Text('How does the skin look?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),

            SkinParamRow(
              icon: '🔴', label: 'Redness',
              question: 'How red or dark is the skin?',
              value: _erythema,
              onChanged: (v) => setState(() => _erythema = v),
            ),
            SkinParamRow(
              icon: '🫧', label: 'Bumps & Swelling',
              question: 'Raised bumps or puffiness?',
              value: _papulation,
              onChanged: (v) => setState(() => _papulation = v),
            ),
            SkinParamRow(
              icon: '🩹', label: 'Scratch Marks',
              question: 'Scratch marks or broken skin?',
              value: _excoriation,
              onChanged: (v) => setState(() => _excoriation = v),
            ),
            SkinParamRow(
              icon: '🪨', label: 'Skin Thickening',
              question: 'Thick, rough, or sandpaper-like texture?',
              value: _lichenification,
              onChanged: (v) => setState(() => _lichenification = v),
            ),
            SkinParamRow(
              icon: '💧', label: 'Weeping / Crusting',
              question: 'Oozy, wet, or crusty patches?',
              value: _oozing,
              onChanged: (v) => setState(() => _oozing = v),
            ),
            SkinParamRow(
              icon: '🌵', label: 'Dryness / Flaking',
              question: 'Dry, flaky, or scaly skin?',
              value: _dryness,
              onChanged: (v) => setState(() => _dryness = v),
            ),
            SkinParamRow(
              icon: '🌑', label: 'Skin Darkening',
              question: 'Turned darker — brown or blackish patches?',
              value: _pigmentation,
              onChanged: (v) => setState(() => _pigmentation = v),
            ),

            const SizedBox(height: 6),
            const Divider(height: 8),
            const SizedBox(height: 4),

            // ── Area affected ───────────────────────────────────────────────
            Text('How much of this zone is affected?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final val = i + 1;
                final selected = _areaScore == val;
                final fillColor = selected
                    ? Color.lerp(
                        const Color(0xFF43A047), const Color(0xFFB71C1C), i / 5)!
                    : Colors.transparent;
                final borderColor = selected
                    ? Color.lerp(
                        const Color(0xFF43A047), const Color(0xFFB71C1C), i / 5)!
                    : Colors.grey.shade300;
                return GestureDetector(
                  onTap: () => setState(() => _areaScore = val),
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text('$val',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_areaLabels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: selected ? borderColor : Colors.grey.shade400,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        height: 1.2,
                      ),
                    ),
                  ]),
                );
              }),
            ),

            const SizedBox(height: 10),
            const Divider(height: 8),

            // ── Running score ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: easiColor(total).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Text('Zone: ${_regional.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
                const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                Text('Total EASI: ${total.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: easiColor(total))),
                const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                Text(easiLabel(total),
                    style: TextStyle(fontSize: 11, color: easiColor(total))),
              ]),
            ),
            const SizedBox(height: 10),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () { Navigator.pop(context); widget.onRemove(); },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirm'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(EasiRegionScore(
                    regionId: widget.region.id,
                    erythema: _erythema, papulation: _papulation,
                    excoriation: _excoriation, lichenification: _lichenification,
                    areaScore: _areaScore,
                    oozing: _oozing, dryness: _dryness,
                    pigmentation: _pigmentation,
                  ));
                },
              ),
            ]),
          ],
        ),
      ),
    ],
    );
  }
}

// ─── Skin parameter row ───────────────────────────────────────────────────────
// Icon + plain-language label + 4-dot severity selector + text label.
// Used in the zone scoring panel to replace raw clinical terminology.

class SkinParamRow extends StatelessWidget {
  final String icon;
  final String label;
  final String question;
  final int value; // 0–3
  final void Function(int) onChanged;

  const SkinParamRow({
    super.key,
    required this.icon,
    required this.label,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  static const _dotColors = [
    Color(0xFF9E9E9E), // 0 None     — grey
    Color(0xFFFF9800), // 1 Mild     — amber
    Color(0xFFEF6C00), // 2 Moderate — deep orange
    Color(0xFFB71C1C), // 3 Severe   — deep red
  ];
  static const _textLabels = ['None', 'Mild', 'Moderate', 'Severe'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        // Emoji icon
        SizedBox(width: 26, child: Text(icon, style: const TextStyle(fontSize: 17))),
        const SizedBox(width: 8),
        // Label + sub-question
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(question, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(width: 10),
        // 4-dot selector
        Row(
          children: List.generate(4, (i) {
            final selected = value == i;
            final color = _dotColors[i];
            return GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : Colors.transparent,
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        // Severity text
        SizedBox(
          width: 58,
          child: Text(
            _textLabels[value],
            style: TextStyle(
              fontSize: 11,
              color: value == 0 ? Colors.grey.shade400 : _dotColors[value],
              fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ]),
    );
  }
}
