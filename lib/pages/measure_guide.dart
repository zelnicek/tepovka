import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/elements/signal_quality_checker.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/tts_service.dart';

const Color _accent = Color(0xFFE53935);
const Color _background = Color.fromARGB(255, 242, 242, 242);

/// Co má člověk právě udělat, podle toho, jak detektor vidí signál.
///
/// Samotný štítek kvality („Žádný prst", „Špatný kontakt") říká, co je
/// špatně, ale ne co s tím. Tahle věta to doplní konkrétním pokynem.
String measureHint(L10n t, SignalQuality quality) => switch (quality) {
      SignalQuality.noFinger => t.hintPlaceFinger,
      SignalQuality.poorContact => t.hintPoorContact,
      SignalQuality.bad => t.hintWeakSignal,
      SignalQuality.good => t.hintGood,
    };

/// Návod, jak správně měřit: pět kroků, každý s obrázkem a jednou dvěma větami.
///
/// Sám se ukáže při prvním příchodu na obrazovku měření a kdykoli se dá
/// otevřít otazníkem v jejím záhlaví nebo ze stránky Jak to funguje. Kdo
/// aplikaci nikdy neviděl, neví, že prst musí krýt i blesk, že se nemá
/// tlačit a že náhled má být celý červený — a bez toho měří špatně.
class MeasureGuide extends StatefulWidget {
  const MeasureGuide({super.key});

  /// Klíč v SharedPreferences. Verze v názvu dovolí po větší změně postupu
  /// ukázat návod znovu i těm, kdo ho už viděli.
  static const String seenKey = 'measure_guide_seen_v1';

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const MeasureGuide(),
        ),
      );

  static Future<bool> shouldShowOnFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(seenKey) ?? false);
  }

  @override
  State<MeasureGuide> createState() => _MeasureGuideState();
}

class _GuideStep {
  const _GuideStep(this.title, this.body, this.picture);

  final String title;
  final String body;
  final Widget picture;
}

class _MeasureGuideState extends State<MeasureGuide> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Kdo návod jednou otevřel, viděl ho — i když ho přeskočil. Znovu se sám
    // neukáže, ale otazník na obrazovce měření ho kdykoli otevře.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(MeasureGuide.seenKey, true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speak(_steps(L10n.of(context))[0]);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<_GuideStep> _steps(L10n t) => [
        _GuideStep(t.guideRestTitle, t.guideRestBody,
            const _IconPicture(Icons.self_improvement)),
        _GuideStep(
          t.guideCoverTitle,
          t.guideCoverBody,
          Image.asset('assets/guide/finger_on_camera.png', fit: BoxFit.contain),
        ),
        _GuideStep(t.guidePreviewTitle, t.guidePreviewBody, const _PreviewPicture()),
        _GuideStep(t.guideStillTitle, t.guideStillBody,
            const _IconPicture(Icons.pan_tool_outlined)),
        _GuideStep(t.guideResultTitle, t.guideResultBody,
            const _IconPicture(Icons.timer_outlined)),
      ];

  /// V režimu pro seniory krok přečte hlasový průvodce; jinak `speak` mlčí.
  void _speak(_GuideStep step) =>
      TtsService.instance.speak('${step.title}. ${step.body}');

  void _next() => _pages.nextPage(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final r = Responsive.of(context);
    final steps = _steps(t);
    final last = _index == steps.length - 1;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        automaticallyImplyLeading: false,
        title: Text(
          t.guideTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: r.fontTitle),
        ),
        actions: [
          if (!last)
            TextButton(
              onPressed: _close,
              style: TextButton.styleFrom(foregroundColor: Colors.black54),
              child: Text(t.guideSkip, style: TextStyle(fontSize: r.fontBody)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: steps.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _speak(steps[i]);
                },
                itemBuilder: (context, i) => _StepView(
                  step: steps[i],
                  disclaimer: i == steps.length - 1 ? t.guideDisclaimer : null,
                ),
              ),
            ),
            Semantics(
              label: t.guideStepOf(_index + 1, steps.length),
              child: ExcludeSemantics(
                child: _Dots(count: steps.length, index: _index),
              ),
            ),
            Padding(
              padding: r.pagePadding.copyWith(top: r.spaceLg, bottom: r.spaceLg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: EdgeInsets.symmetric(vertical: r.spaceMd),
                  ),
                  onPressed: last ? _close : _next,
                  child: Text(
                    last ? t.guideDone : t.guideNext,
                    style: TextStyle(
                        fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step, this.disclaimer});

  final _GuideStep step;
  final String? disclaimer;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return LayoutBuilder(
      // Posuvné kvůli malým telefonům a velkému písmu v nastavení iOS:
      // text se nesmí uříznout, i kdyby se nevešel.
      builder: (context, constraints) => SingleChildScrollView(
        padding: r.pagePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - r.pagePadding.vertical)
                .clamp(0.0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.42).clamp(120.0, 320.0),
                child: Center(child: ExcludeSemantics(child: step.picture)),
              ),
              SizedBox(height: r.spaceXl),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: r.fontHeadline, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: r.spaceMd),
              Text(
                step.body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: r.fontBodyLg, height: 1.4),
              ),
              if (disclaimer != null) ...[
                SizedBox(height: r.spaceLg),
                Text(
                  disclaimer!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: r.fontSmall, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPicture extends StatelessWidget {
  const _IconPicture(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      FittedBox(child: Icon(icon, size: 160, color: _accent));
}

/// Kruh s náhledem tak, jak vypadá na obrazovce měření při správně
/// přiloženém prstu: celý červený, se zeleným okrajem dobré kvality.
class _PreviewPicture extends StatelessWidget {
  const _PreviewPicture();

  @override
  Widget build(BuildContext context) => FittedBox(
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFF7A59), Color(0xFFC62828)],
            ),
            border: Border.all(color: Colors.green, width: 7),
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? _accent : const Color(0xFFCACACA),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );
}
