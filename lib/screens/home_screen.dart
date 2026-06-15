// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/phishing_classifier.dart';
import '../services/history_repository.dart';
import '../models/scan_record.dart';
import 'result_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isScanning = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _scanUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a URL to scan.');
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    _pulseController.repeat(reverse: true);

    try {
      final result = await PhishingClassifier.instance.classify(url);
      if (result == null) {
        setState(() {
          _errorMessage = 'Classifier not ready. Please restart the app.';
          _isScanning = false;
        });
        _pulseController.stop();
        return;
      }

      // Save to history
      await HistoryRepository.instance.insert(ScanRecord(
        url: url,
        label: result.label,
        confidence: result.confidence,
        isSafe: result.isSafe,
        scannedAt: DateTime.now(),
      ));

      if (!mounted) return;
      _pulseController.stop();
      setState(() => _isScanning = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(url: url, result: result),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isScanning = false;
      });
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.security, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text('PhishGuard',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan history',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Hero illustration ──────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _isScanning ? _pulseAnimation.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      _isScanning
                          ? Icons.radar_rounded
                          : Icons.shield_rounded,
                      size: 60,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Check any link',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Instantly detect phishing, malware & defacement — fully offline.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── URL input ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  border: Border.all(
                    color: _errorMessage != null
                        ? colorScheme.error
                        : colorScheme.outline.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: (_) => setState(() => _errorMessage = null),
                      onSubmitted: (_) => _scanUrl(),
                      decoration: InputDecoration(
                        hintText: 'https://example.com/...',
                        hintStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.4)),
                        prefixIcon: Icon(Icons.link_rounded,
                            color: colorScheme.primary),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste_rounded),
                          tooltip: 'Paste from clipboard',
                          onPressed: _pasteFromClipboard,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(color: colorScheme.error,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // ── Scan button ────────────────────────────────────
              FilledButton.icon(
                onPressed: _isScanning ? null : _scanUrl,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded),
                label: Text(_isScanning ? 'Scanning...' : 'Scan URL',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 36),

              // ── Info cards ─────────────────────────────────────
              _InfoCard(
                icon: Icons.offline_bolt_rounded,
                title: '100% offline',
                subtitle: 'No data leaves your device.',
                color: colorScheme.tertiaryContainer,
                iconColor: colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.speed_rounded,
                title: 'Instant results',
                subtitle: 'On-device AI, results in milliseconds.',
                color: colorScheme.secondaryContainer,
                iconColor: colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.category_rounded,
                title: '4-class detection',
                subtitle: 'Benign · Phishing · Malware · Defacement',
                color: colorScheme.primaryContainer,
                iconColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;

  const _InfoCard({
    required this.icon, required this.title,
    required this.subtitle, required this.color, required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
