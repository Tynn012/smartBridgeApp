import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'services/camera_service.dart';
import 'services/model_service.dart';
import 'services/permission_handler.dart';

const String _onboardingSeenKey = 'onboarding_seen';
const String _termsAcceptedKey = 'accepted_terms';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class SmartBridgeLogo extends StatelessWidget {
  const SmartBridgeLogo({
    super.key,
    this.size = 38,
    this.backgroundColor,
    this.borderColor,
  });

  final double size;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: backgroundColor ?? scheme.primaryContainer,
        border: Border.all(
          color: borderColor ?? scheme.primary.withValues(alpha: 0.45),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          'smartbridge.png',
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return Icon(
                  Icons.sign_language,
                  size: size * 0.5,
                  color: scheme.primary,
                );
              },
        ),
      ),
    );
  }
}

@immutable
class AppUiPreferences {
  const AppUiPreferences({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
    this.hapticsEnabled = true,
    this.autoSpeakSigns = false,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsVolume = 1.0,
    this.recognitionThreshold = 35.0,
    this.historyConfidenceThreshold = 60.0,
    this.frameStride = 2,
  });

  static const String _themeModeKey = 'pref_theme_mode';
  static const String _textScaleKey = 'pref_text_scale';
  static const String _highContrastKey = 'pref_high_contrast';
  static const String _reduceMotionKey = 'pref_reduce_motion';
  static const String _hapticsKey = 'pref_haptics_enabled';
  static const String _autoSpeakSignsKey = 'pref_auto_speak_signs';
  static const String _ttsRateKey = 'pref_tts_rate';
  static const String _ttsPitchKey = 'pref_tts_pitch';
  static const String _ttsVolumeKey = 'pref_tts_volume';
  static const String _recognitionThresholdKey = 'pref_recognition_threshold';
  static const String _historyThresholdKey =
      'pref_history_confidence_threshold';
  static const String _frameStrideKey = 'pref_frame_stride';

  final ThemeMode themeMode;
  final double textScale;
  final bool highContrast;
  final bool reduceMotion;
  final bool hapticsEnabled;
  final bool autoSpeakSigns;
  final double ttsRate;
  final double ttsPitch;
  final double ttsVolume;
  final double recognitionThreshold;
  final double historyConfidenceThreshold;
  final int frameStride;

  AppUiPreferences copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? autoSpeakSigns,
    double? ttsRate,
    double? ttsPitch,
    double? ttsVolume,
    double? recognitionThreshold,
    double? historyConfidenceThreshold,
    int? frameStride,
  }) {
    return AppUiPreferences(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      autoSpeakSigns: autoSpeakSigns ?? this.autoSpeakSigns,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      recognitionThreshold: recognitionThreshold ?? this.recognitionThreshold,
      historyConfidenceThreshold:
          historyConfidenceThreshold ?? this.historyConfidenceThreshold,
      frameStride: frameStride ?? this.frameStride,
    );
  }

  factory AppUiPreferences.fromSharedPreferences(SharedPreferences prefs) {
    final String mode = prefs.getString(_themeModeKey) ?? 'system';

    ThemeMode themeMode = ThemeMode.system;
    if (mode == 'light') {
      themeMode = ThemeMode.light;
    } else if (mode == 'dark') {
      themeMode = ThemeMode.dark;
    }

    return AppUiPreferences(
      themeMode: themeMode,
      textScale: (prefs.getDouble(_textScaleKey) ?? 1.0).clamp(0.85, 1.4),
      highContrast: prefs.getBool(_highContrastKey) ?? false,
      reduceMotion: prefs.getBool(_reduceMotionKey) ?? false,
      hapticsEnabled: prefs.getBool(_hapticsKey) ?? true,
      autoSpeakSigns: prefs.getBool(_autoSpeakSignsKey) ?? false,
      ttsRate: (prefs.getDouble(_ttsRateKey) ?? 0.5).clamp(0.1, 1.0),
      ttsPitch: (prefs.getDouble(_ttsPitchKey) ?? 1.0).clamp(0.5, 2.0),
      ttsVolume: (prefs.getDouble(_ttsVolumeKey) ?? 1.0).clamp(0.0, 1.0),
      recognitionThreshold: (prefs.getDouble(_recognitionThresholdKey) ?? 35.0)
          .clamp(10, 95),
      historyConfidenceThreshold:
          (prefs.getDouble(_historyThresholdKey) ?? 60.0).clamp(35, 99),
      frameStride: (prefs.getInt(_frameStrideKey) ?? 2).clamp(1, 5),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    String mode = 'system';
    if (themeMode == ThemeMode.light) {
      mode = 'light';
    } else if (themeMode == ThemeMode.dark) {
      mode = 'dark';
    }

    await prefs.setString(_themeModeKey, mode);
    await prefs.setDouble(_textScaleKey, textScale);
    await prefs.setBool(_highContrastKey, highContrast);
    await prefs.setBool(_reduceMotionKey, reduceMotion);
    await prefs.setBool(_hapticsKey, hapticsEnabled);
    await prefs.setBool(_autoSpeakSignsKey, autoSpeakSigns);
    await prefs.setDouble(_ttsRateKey, ttsRate);
    await prefs.setDouble(_ttsPitchKey, ttsPitch);
    await prefs.setDouble(_ttsVolumeKey, ttsVolume);
    await prefs.setDouble(_recognitionThresholdKey, recognitionThreshold);
    await prefs.setDouble(_historyThresholdKey, historyConfidenceThreshold);
    await prefs.setInt(_frameStrideKey, frameStride);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppUiPreferences _prefs = const AppUiPreferences();
  bool _ready = false;

  static const Color _seedColor = Color(0xFF0A7A75);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _prefs = AppUiPreferences.fromSharedPreferences(prefs);
      _ready = true;
    });
  }

  Future<void> _updatePreferences(AppUiPreferences next) async {
    setState(() => _prefs = next);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await next.save(prefs);
  }

  ThemeData _buildTheme(Brightness brightness) {
    ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    scheme = scheme.copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFF44D9D1)
          : const Color(0xFF006F69),
      onPrimary: Colors.white,
      surface: brightness == Brightness.dark
          ? const Color(0xFF0E1416)
          : const Color(0xFFF8FBFC),
      onSurface: brightness == Brightness.dark
          ? const Color(0xFFF2F7F8)
          : const Color(0xFF0E2325),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF213237)
          : const Color(0xFFDDECEF),
      onSurfaceVariant: brightness == Brightness.dark
          ? const Color(0xFFC2D4D8)
          : const Color(0xFF315258),
      outline: brightness == Brightness.dark
          ? const Color(0xFF638086)
          : const Color(0xFF5B7B81),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF375158)
          : const Color(0xFFB1C7CB),
    );

    if (_prefs.highContrast) {
      scheme = scheme.copyWith(
        primary: brightness == Brightness.dark
            ? const Color(0xFF4DEAE2)
            : const Color(0xFF005A56),
        onPrimary: Colors.white,
        surface: brightness == Brightness.dark
            ? const Color(0xFF101418)
            : Colors.white,
        onSurface: brightness == Brightness.dark ? Colors.white : Colors.black,
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.manropeTextTheme(),
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartBridge',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _prefs.themeMode,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(_prefs.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _ready
          ? AppEntryGate(
              prefs: _prefs,
              onPreferencesChanged: _updatePreferences,
            )
          : const _LoadingScaffold(label: 'Loading SmartBridge...'),
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    required this.prefs,
    required this.onPreferencesChanged,
  });

  final AppUiPreferences prefs;
  final ValueChanged<AppUiPreferences> onPreferencesChanged;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool _gateReady = false;
  bool _hasSeenOnboarding = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadGateState();
  }

  Future<void> _loadGateState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _hasSeenOnboarding = prefs.getBool(_onboardingSeenKey) ?? false;
      _acceptedTerms = prefs.getBool(_termsAcceptedKey) ?? false;
      _gateReady = true;
    });
  }

  Future<void> _completeOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    await prefs.setBool(_termsAcceptedKey, true);

    if (!mounted) return;
    setState(() {
      _hasSeenOnboarding = true;
      _acceptedTerms = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateReady) {
      return const _LoadingScaffold(label: 'Preparing your workspace...');
    }

    if (!_hasSeenOnboarding || !_acceptedTerms) {
      return OnboardingFlow(onAccepted: _completeOnboarding);
    }

    return SmartBridgeShell(
      prefs: widget.prefs,
      onPreferencesChanged: widget.onPreferencesChanged,
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onAccepted});

  final Future<void> Function() onAccepted;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _agreed = false;
  bool _submitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }

    if (!_agreed || _submitting) return;

    setState(() => _submitting = true);
    await widget.onAccepted();
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _back() async {
    if (_page == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _buildSlide({
    required IconData icon,
    required String title,
    required String body,
    Widget? footer,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.primaryContainer,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 28, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 20),
            Expanded(
              child: Align(alignment: Alignment.topLeft, child: footer),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
              scheme.surface,
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Row(
                          children: [
                            SmartBridgeLogo(
                              size: 44,
                              backgroundColor: scheme.surface,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SmartBridge',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Guided setup and quick orientation',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (int value) =>
                              setState(() => _page = value),
                          children: [
                            _buildSlide(
                              icon: Icons.waving_hand_rounded,
                              title: 'Welcome to SmartBridge',
                              body:
                                  'Translate hand signs, speech, and text in one place. '
                                  'Swipe to learn core app features before you begin.',
                            ),
                            _buildSlide(
                              icon: Icons.translate,
                              title: 'Live Translation Tools',
                              body:
                                  'Use camera-powered sign recognition, speech-to-text, '
                                  'and text-to-speech from a single minimal interface.',
                            ),
                            _buildSlide(
                              icon: Icons.accessibility_new,
                              title: 'Accessibility First',
                              body:
                                  'Adjust text size, contrast, motion, and haptic feedback '
                                  'to match your preferred interaction style.',
                            ),
                            _buildSlide(
                              icon: Icons.gavel_rounded,
                              title: 'Terms and Conditions',
                              body:
                                  'SmartBridge assists communication and does not replace '
                                  'professional interpretation in medical, legal, or '
                                  'emergency situations. You are responsible for safe and '
                                  'lawful use of camera, microphone, and generated output.',
                              footer: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.78),
                                  border: Border.all(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'I agree to the Terms and Conditions',
                                  ),
                                  value: _agreed,
                                  onChanged: (bool? value) {
                                    setState(() => _agreed = value ?? false);
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            for (int i = 0; i < 4; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(right: 6),
                                width: i == _page ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: i == _page
                                      ? scheme.primary
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: _page == 0 ? null : _back,
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: (_page == 3 && !_agreed) || _submitting
                                  ? null
                                  : _next,
                              child: Text(_page == 3 ? 'Enter App' : 'Next'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmartBridgeShell extends StatefulWidget {
  const SmartBridgeShell({
    super.key,
    required this.prefs,
    required this.onPreferencesChanged,
  });

  final AppUiPreferences prefs;
  final ValueChanged<AppUiPreferences> onPreferencesChanged;

  @override
  State<SmartBridgeShell> createState() => _SmartBridgeShellState();
}

class _SmartBridgeShellState extends State<SmartBridgeShell> {
  static const double _maxContentWidth = 940;

  final PageController _pageController = PageController();
  final List<HistoryItem> _history = <HistoryItem>[];

  int _currentIndex = 0;

  static const List<String> _titles = [
    'Translate',
    'History',
    'Settings',
    'About',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onAddHistory(HistoryItem item) {
    setState(() => _history.add(item));
  }

  void _onClearHistory() {
    setState(() => _history.clear());
  }

  Future<void> _goToPage(int index) async {
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<Widget> pages = [
      TranslatorPage(prefs: widget.prefs, onAddHistory: _onAddHistory),
      HistoryPage(history: _history, onClearHistory: _onClearHistory),
      SettingsPage(
        prefs: widget.prefs,
        onPreferencesChanged: widget.onPreferencesChanged,
        onClearHistory: _onClearHistory,
      ),
      const AboutPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SmartBridgeLogo(
              size: 34,
              backgroundColor: scheme.surface,
              borderColor: scheme.outlineVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SmartBridge',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    _titles[_currentIndex],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              final ThemeMode next =
                  Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              widget.onPreferencesChanged(
                widget.prefs.copyWith(themeMode: next),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.18),
              scheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Swipe left or right to switch pages quickly.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int value) {
                  setState(() => _currentIndex = value);
                },
                children: pages
                    .map(
                      (Widget page) => Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxContentWidth,
                          ),
                          child: page,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sign_language_outlined),
            selectedIcon: Icon(Icons.sign_language),
            label: 'Translate',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }
}

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({
    super.key,
    required this.prefs,
    required this.onAddHistory,
  });

  final AppUiPreferences prefs;
  final ValueChanged<HistoryItem> onAddHistory;

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final CameraService _cameraService = CameraService();
  final ModelService _modelService = ModelService();

  late final AnimationController _listeningController;
  late final AnimationController _speakingController;
  final TextEditingController _ttsController = TextEditingController();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _permissionsGranted = false;
  bool _isCameraInitialized = false;
  bool _isCameraRunning = false;
  bool _isModelLoaded = false;
  bool _isFallbackMode = false;
  bool _isProcessingFrame = false;

  int _selectedCameraIndex = 0;
  int _frameCounter = 0;

  String _recognizedText = '';
  String _speechText = '';
  String _initializationError = '';

  List<SignPrediction> _topPredictions = <SignPrediction>[];

  bool get _motionEnabled => !widget.prefs.reduceMotion;

  @override
  void initState() {
    super.initState();
    _listeningController = AnimationController(
      duration: const Duration(milliseconds: 850),
      vsync: this,
    );
    _speakingController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _configureTtsCallbacks();
    _applyVoiceSettings();
    _initializeServices();
  }

  @override
  void didUpdateWidget(covariant TranslatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool voicePrefsChanged =
        oldWidget.prefs.ttsRate != widget.prefs.ttsRate ||
        oldWidget.prefs.ttsPitch != widget.prefs.ttsPitch ||
        oldWidget.prefs.ttsVolume != widget.prefs.ttsVolume;

    if (voicePrefsChanged) {
      _applyVoiceSettings();
    }

    if (!_motionEnabled) {
      _listeningController.stop();
      _speakingController.stop();
    }
  }

  Future<void> _applyVoiceSettings() async {
    await _tts.setSpeechRate(widget.prefs.ttsRate);
    await _tts.setPitch(widget.prefs.ttsPitch);
    await _tts.setVolume(widget.prefs.ttsVolume);
  }

  void _configureTtsCallbacks() {
    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
      if (_motionEnabled) {
        _speakingController.repeat(reverse: true);
      }
    });

    void onDone() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _speakingController.stop();
      _speakingController.reset();
    }

    _tts.setCompletionHandler(onDone);
    _tts.setCancelHandler(onDone);
    _tts.setErrorHandler((message) {
      onDone();
      _showSnackBar('TTS error: ${message.toString()}');
    });
  }

  Future<void> _initializeServices() async {
    setState(() {
      _initializationError = '';
      _isFallbackMode = false;
    });

    try {
      final bool granted = await PermissionHandler.requestAllPermissions();
      if (!mounted) return;

      setState(() => _permissionsGranted = granted);
      if (!granted) {
        setState(() {
          _initializationError =
              'Camera and microphone permissions are needed for full mode.';
          _isFallbackMode = true;
        });
      }

      if (granted) {
        await _cameraService.initializeCamera();
        if (_cameraService.cameras.isNotEmpty) {
          await _cameraService.startCameraStream(
            cameraIndex: _selectedCameraIndex,
            frameProcessor: _processFrame,
          );

          if (!mounted) return;
          setState(() {
            _isCameraInitialized = true;
            _isCameraRunning = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isCameraRunning = false;
        _isFallbackMode = true;
        _initializationError = 'Camera error: $e';
      });
    }

    try {
      await _modelService.loadModel();
      if (!mounted) return;
      setState(() => _isModelLoaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelLoaded = false;
        _isFallbackMode = true;
      });
      if (kDebugMode) {
        debugPrint('Model initialization failed: $e');
      }
    }

    if (!mounted) return;
    if (_isFallbackMode) {
      _showSnackBar('Running in manual fallback mode');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    _frameCounter++;
    if (_frameCounter % widget.prefs.frameStride != 0) {
      return;
    }

    if (_isProcessingFrame ||
        !_isModelLoaded ||
        !_isCameraRunning ||
        !mounted) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final int sensorOrientation =
          _cameraService.cameraController?.description.sensorOrientation ?? 0;
      final SignPrediction prediction = await _modelService.runInference(
        image,
        sensorOrientation: sensorOrientation,
      );

      final List<SignPrediction> topPredictions = _modelService
          .getTopKPredictions(prediction.rawScores, topK: 3);

      if (!mounted) return;

      if (prediction.label == 'No hand') {
        if (_topPredictions.isNotEmpty) {
          setState(() => _topPredictions = <SignPrediction>[]);
        }
        return;
      }

      final bool shouldUpdateRecognized =
          prediction.label != 'Error' &&
          prediction.label != 'Unknown' &&
          prediction.confidence >= widget.prefs.recognitionThreshold &&
          prediction.label != _recognizedText;

      setState(() {
        _topPredictions = topPredictions;
        if (shouldUpdateRecognized) {
          _recognizedText = prediction.label;
        }
      });

      if (shouldUpdateRecognized) {
        if (widget.prefs.autoSpeakSigns) {
          await _speak(prediction.label, addToHistory: false);
        }

        if (prediction.confidence >= widget.prefs.historyConfidenceThreshold) {
          widget.onAddHistory(
            HistoryItem(
              type: 'sign',
              text: prediction.label,
              confidence: prediction.confidence.toInt(),
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Frame processing error: $e');
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _vibrateLight() {
    if (widget.prefs.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _vibrateMedium() {
    if (widget.prefs.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _toggleListening() async {
    _vibrateMedium();

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      _listeningController.stop();
      _listeningController.reset();

      if (_speechText.isNotEmpty) {
        widget.onAddHistory(
          HistoryItem(
            type: 'speech',
            text: _speechText,
            timestamp: DateTime.now(),
          ),
        );
      }
      return;
    }

    try {
      final bool available = await _speech.initialize(
        onError: (error) => _showSnackBar('Speech error: $error'),
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
            _listeningController.stop();
          }
        },
      );

      if (!mounted) return;

      if (!available) {
        _showSnackBar('Speech recognition is not available');
        return;
      }

      setState(() => _isListening = true);
      if (_motionEnabled) {
        _listeningController.repeat(reverse: true);
      }

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _speechText = result.recognizedWords);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Speech service is unavailable in this environment');
      if (kDebugMode) {
        debugPrint('Speech init error: $e');
      }
    }
  }

  Future<void> _speak(String text, {bool addToHistory = true}) async {
    if (text.trim().isEmpty) return;

    if (_isSpeaking) {
      await _tts.stop();
      return;
    }

    _vibrateLight();
    await _tts.speak(text);

    if (addToHistory) {
      widget.onAddHistory(
        HistoryItem(type: 'tts', text: text.trim(), timestamp: DateTime.now()),
      );
    }
  }

  Future<void> _startCamera() async {
    if (_isCameraRunning) {
      _showSnackBar('Camera already running');
      return;
    }

    try {
      if (!_permissionsGranted) {
        final bool granted = await PermissionHandler.requestAllPermissions();
        if (!mounted) return;
        setState(() => _permissionsGranted = granted);
        if (!granted) {
          _showSnackBar('Permission is required for camera mode');
          return;
        }
      }

      await _cameraService.initializeCamera();
      if (_selectedCameraIndex >= _cameraService.cameras.length) {
        _selectedCameraIndex = 0;
      }

      await _cameraService.startCameraStream(
        cameraIndex: _selectedCameraIndex,
        frameProcessor: _processFrame,
      );

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _isCameraRunning = true;
        _initializationError = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isCameraRunning = false;
        _initializationError = 'Unable to start camera: $e';
      });
      _showSnackBar('Unable to start camera');
    }
  }

  Future<void> _stopCamera() async {
    await _cameraService.dispose();
    if (!mounted) return;
    setState(() {
      _isCameraInitialized = false;
      _isCameraRunning = false;
      _isProcessingFrame = false;
    });
  }

  Future<void> _switchCamera() async {
    if (!_isCameraRunning || _cameraService.cameras.length < 2) {
      _showSnackBar('No additional camera available');
      return;
    }

    final int nextIndex =
        (_selectedCameraIndex + 1) % _cameraService.cameras.length;
    final bool switched = await _cameraService.switchCamera(
      cameraIndex: nextIndex,
      frameProcessor: _processFrame,
    );

    if (!mounted) return;

    if (switched) {
      setState(() => _selectedCameraIndex = nextIndex);
    } else {
      _showSnackBar('Unable to switch camera');
    }
  }

  Future<void> _captureSnapshot() async {
    if (!_isCameraRunning) {
      _showSnackBar('Start camera first');
      return;
    }

    final XFile? image = await _cameraService.captureImage();
    if (image == null) {
      _showSnackBar('Snapshot failed');
      return;
    }
    _showSnackBar('Snapshot captured');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  double _cameraAspectRatio() {
    final CameraController? controller = _cameraService.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return 4 / 3;
    }

    final double ratio = controller.value.aspectRatio;
    if (!ratio.isFinite || ratio <= 0) {
      return 4 / 3;
    }

    return ratio.clamp(0.75, 1.65);
  }

  Widget _buildMicPulse() {
    if (!_isListening || !_motionEnabled) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _listeningController,
      builder: (BuildContext context, Widget? child) {
        final double scale = 1 + (_listeningController.value * 0.14);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget content;
    if (_initializationError.isNotEmpty) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(height: 10),
          Text(
            _initializationError,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: PermissionHandler.openAppSettingsPage,
                child: const Text('Open Settings'),
              ),
              FilledButton(
                onPressed: _initializeServices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    } else if (!_isCameraRunning) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Camera stopped',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _startCamera,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Camera'),
          ),
        ],
      );
    } else if (!_isCameraInitialized ||
        _cameraService.cameraController == null) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(_cameraService.cameraController!),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                _recognizedText.isEmpty ? 'No sign detected' : _recognizedText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 640;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.videocam_outlined),
                          SizedBox(width: 8),
                          Text(
                            'Sign Recognition',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            tooltip: _isCameraRunning
                                ? 'Stop camera'
                                : 'Start camera',
                            onPressed: _isCameraRunning
                                ? _stopCamera
                                : _startCamera,
                            icon: Icon(
                              _isCameraRunning
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_outline,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Switch camera',
                            onPressed: _switchCamera,
                            icon: const Icon(Icons.cameraswitch_outlined),
                          ),
                          IconButton(
                            tooltip: 'Snapshot',
                            onPressed: _captureSnapshot,
                            icon: const Icon(Icons.photo_camera_outlined),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(Icons.videocam_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Sign Recognition',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: _isCameraRunning
                          ? 'Stop camera'
                          : 'Start camera',
                      onPressed: _isCameraRunning ? _stopCamera : _startCamera,
                      icon: Icon(
                        _isCameraRunning
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Switch camera',
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_outlined),
                    ),
                    IconButton(
                      tooltip: 'Snapshot',
                      onPressed: _captureSnapshot,
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double previewHeight =
                    (constraints.maxWidth / _cameraAspectRatio()).clamp(
                      220.0,
                      370.0,
                    );

                return Container(
                  width: double.infinity,
                  height: previewHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                );
              },
            ),
            const SizedBox(height: 10),
            if (_topPredictions.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _topPredictions.map((SignPrediction prediction) {
                  return Chip(
                    label: Text(
                      '${prediction.label} (${prediction.confidence.toStringAsFixed(0)}%)',
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    _permissionsGranted
                        ? 'Permissions: OK'
                        : 'Permissions: Required',
                  ),
                ),
                Chip(
                  label: Text(
                    _isModelLoaded ? 'Model: Ready' : 'Model: Loading',
                  ),
                ),
                Chip(
                  label: Text(_isFallbackMode ? 'Mode: Manual' : 'Mode: AI'),
                ),
              ],
            ),
          ),
        ),
        _buildCameraCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Speech to Text',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Widget micButton = Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildMicPulse(),
                        FilledButton(
                          onPressed: _toggleListening,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            minimumSize: const Size(56, 56),
                            backgroundColor: _isListening
                                ? scheme.error
                                : scheme.primary,
                          ),
                          child: Icon(_isListening ? Icons.stop : Icons.mic),
                        ),
                      ],
                    );

                    final Widget transcriptBox = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      child: Text(
                        _speechText.isEmpty
                            ? 'Tap the mic button to start listening.'
                            : _speechText,
                      ),
                    );

                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: micButton,
                          ),
                          const SizedBox(height: 12),
                          transcriptBox,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        micButton,
                        const SizedBox(width: 14),
                        Expanded(child: transcriptBox),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Text to Speech',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ttsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Type text to speak...',
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSpeaking && _motionEnabled)
                  SizedBox(
                    height: 28,
                    child: AnimatedBuilder(
                      animation: _speakingController,
                      builder: (BuildContext context, Widget? child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(3, (int index) {
                            final double v =
                                (_speakingController.value + (index * 0.2)) %
                                1.0;
                            final double h = 8 + (v * 16);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: scheme.primary,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final String text = _ttsController.text.isNotEmpty
                        ? _ttsController.text
                        : (_recognizedText.isNotEmpty
                              ? _recognizedText
                              : _speechText);
                    _speak(text);
                  },
                  icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                  label: Text(_isSpeaking ? 'Stop' : 'Speak'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();

    _listeningController.dispose();
    _speakingController.dispose();
    _ttsController.dispose();

    _cameraService.dispose();
    _modelService.dispose();
    super.dispose();
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.history,
    required this.onClearHistory,
  });

  final List<HistoryItem> history;
  final VoidCallback onClearHistory;

  String _formatTime(DateTime time) {
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'sign':
        return Icons.sign_language;
      case 'speech':
        return Icons.mic;
      case 'tts':
        return Icons.volume_up;
      default:
        return Icons.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text('No translation history yet.'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextButton.icon(
              onPressed: onClearHistory,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear history'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: history.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final HistoryItem item = history[index];
              return Card(
                child: ListTile(
                  leading: Icon(_iconForType(item.type)),
                  title: Text(item.text),
                  subtitle: Text(
                    item.confidence == null
                        ? _formatTime(item.timestamp)
                        : '${item.confidence}% confidence - ${_formatTime(item.timestamp)}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.prefs,
    required this.onPreferencesChanged,
    required this.onClearHistory,
  });

  final AppUiPreferences prefs;
  final ValueChanged<AppUiPreferences> onPreferencesChanged;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accessibility',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: prefs.themeMode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System default'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      onPreferencesChanged(prefs.copyWith(themeMode: value));
                    }
                  },
                ),
                const SizedBox(height: 10),
                _LabeledSlider(
                  label: 'Text size',
                  value: prefs.textScale,
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  valueLabel: '${prefs.textScale.toStringAsFixed(2)}x',
                  onChanged: (double value) {
                    onPreferencesChanged(prefs.copyWith(textScale: value));
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('High contrast mode'),
                  value: prefs.highContrast,
                  onChanged: (bool value) {
                    onPreferencesChanged(prefs.copyWith(highContrast: value));
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  value: prefs.reduceMotion,
                  onChanged: (bool value) {
                    onPreferencesChanged(prefs.copyWith(reduceMotion: value));
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable haptic feedback'),
                  value: prefs.hapticsEnabled,
                  onChanged: (bool value) {
                    onPreferencesChanged(prefs.copyWith(hapticsEnabled: value));
                  },
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recognition and Voice',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-speak recognized signs'),
                  value: prefs.autoSpeakSigns,
                  onChanged: (bool value) {
                    onPreferencesChanged(prefs.copyWith(autoSpeakSigns: value));
                  },
                ),
                _LabeledSlider(
                  label: 'Recognition threshold',
                  value: prefs.recognitionThreshold,
                  min: 10,
                  max: 95,
                  divisions: 17,
                  valueLabel:
                      '${prefs.recognitionThreshold.toStringAsFixed(0)}%',
                  onChanged: (double value) {
                    onPreferencesChanged(
                      prefs.copyWith(recognitionThreshold: value),
                    );
                  },
                ),
                _LabeledSlider(
                  label: 'History confidence',
                  value: prefs.historyConfidenceThreshold,
                  min: 35,
                  max: 99,
                  divisions: 16,
                  valueLabel:
                      '${prefs.historyConfidenceThreshold.toStringAsFixed(0)}%',
                  onChanged: (double value) {
                    onPreferencesChanged(
                      prefs.copyWith(historyConfidenceThreshold: value),
                    );
                  },
                ),
                _LabeledSlider(
                  label: 'Frame processing step',
                  value: prefs.frameStride.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  valueLabel: prefs.frameStride.toString(),
                  onChanged: (double value) {
                    onPreferencesChanged(
                      prefs.copyWith(frameStride: value.round()),
                    );
                  },
                ),
                _LabeledSlider(
                  label: 'Voice speed',
                  value: prefs.ttsRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  valueLabel: prefs.ttsRate.toStringAsFixed(1),
                  onChanged: (double value) {
                    onPreferencesChanged(prefs.copyWith(ttsRate: value));
                  },
                ),
                _LabeledSlider(
                  label: 'Voice pitch',
                  value: prefs.ttsPitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  valueLabel: prefs.ttsPitch.toStringAsFixed(1),
                  onChanged: (double value) {
                    onPreferencesChanged(prefs.copyWith(ttsPitch: value));
                  },
                ),
                _LabeledSlider(
                  label: 'Voice volume',
                  value: prefs.ttsVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  valueLabel: prefs.ttsVolume.toStringAsFixed(1),
                  onChanged: (double value) {
                    onPreferencesChanged(prefs.copyWith(ttsVolume: value));
                  },
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_applications_outlined),
                  title: const Text('Open app permissions'),
                  subtitle: const Text(
                    'Manage camera and microphone access from system settings.',
                  ),
                  onTap: PermissionHandler.openAppSettingsPage,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Clear translation history'),
                  onTap: onClearHistory,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<PackageInfo> _getPackageInfo() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _getPackageInfo(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final String version = snapshot.hasData
            ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
            : '1.0.0+1';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SmartBridgeLogo(size: 46),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SmartBridge',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Communication Assistant',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A sign language communication assistant with live camera recognition, speech-to-text, and text-to-speech tools.',
                    ),
                    const SizedBox(height: 12),
                    Text('Version: $version'),
                    const SizedBox(height: 4),
                    Text(
                      'Release date: April 15, 2026',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'System Functions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10),
                    Text('1. Real-time hand sign detection with camera input.'),
                    Text('2. Voice transcription using speech recognition.'),
                    Text('3. Spoken output through text-to-speech.'),
                    Text('4. Accessibility customization and motion controls.'),
                    Text('5. Swipe-based page navigation for easier access.'),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Terms Notice',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'SmartBridge provides assistive output and may not always be perfectly accurate. '
                      'Do not use this app as the only source for medical, legal, financial, or emergency communication decisions.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class HistoryItem {
  HistoryItem({
    required this.type,
    required this.text,
    required this.timestamp,
    this.confidence,
  });

  final String type;
  final String text;
  final DateTime timestamp;
  final int? confidence;
}
