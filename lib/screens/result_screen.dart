// lib/screens/result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/phishing_classifier.dart';

class ResultScreen extends StatelessWidget {
  final String url;
  final PredictionResult result;

  const ResultScreen({super.key, required this.url, required this.result});

  Color _riskColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (result.riskLevel) {
      0 => const Color(0xFF2E7D32),
      1 => const Color(0xFFE65100),
      _ => const Color(0xFFC62828),
    };
  }

  IconData get _riskIcon => switch (result.riskLevel) {
    0 => Icons.verified_user_rounded,
    1 => Icons.warning_amber_rounded,
    _ => Icons.dangerous_rounded,
  };

  String get _riskMessage => switch (result.riskLevel) {
    0 => 'This URL appears to be safe.',
    1 => 'This URL looks suspicious. Be careful.',
    _ => 'Do NOT visit this URL. It is likely malicious.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riskColor = _riskColor(context);
    final sortedProbs = result.allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Result',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: BackButton(color: theme.colorScheme.primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Verdict card ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: riskColor.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(_riskIcon, size: 72, color: riskColor),
                    const SizedBox(height: 16),
                    Text(result.riskLabel,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: riskColor)),
                    const SizedBox(height: 8),
                    Text(_riskMessage,
                        style: TextStyle(
                            fontSize: 15,
                            color: riskColor.withOpacity(0.85)),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${(result.confidence * 100).toStringAsFixed(1)}% confidence  ·  ${_capitalize(result.label)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: riskColor,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── URL display ────────────────────────────────────
              _SectionHeader('Scanned URL'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(url,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: theme.colorScheme.onSurface),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied'),
                              duration: Duration(seconds: 1)));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy URL',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Probability breakdown ──────────────────────────
              _SectionHeader('Probability breakdown'),
              const SizedBox(height: 12),
              ...sortedProbs.map((e) => _ProbabilityBar(
                    label: _capitalize(e.key),
                    value: e.value,
                    isSafe: e.key == 'benign',
                    isHighest: e.key == result.label,
                  )),
              const SizedBox(height: 32),

              // ── What does this mean? ───────────────────────────
              if (!result.isSafe) ...[
                _SectionHeader('What should you do?'),
                const SizedBox(height: 12),
                _TipCard(
                  icon: Icons.block_rounded,
                  text: 'Do not click on or open this link.',
                  color: const Color(0xFFC62828),
                ),
                const SizedBox(height: 8),
                _TipCard(
                  icon: Icons.share_rounded,
                  text: 'Report it to your email/SMS provider if received as a message.',
                  color: const Color(0xFFE65100),
                ),
                const SizedBox(height: 8),
                _TipCard(
                  icon: Icons.person_rounded,
                  text: 'If you already visited it, change your passwords immediately.',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 24),
              ],

              // ── Scan again button ──────────────────────────────
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Scan another URL'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
}

class _ProbabilityBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isSafe;
  final bool isHighest;

  const _ProbabilityBar({
    required this.label, required this.value,
    required this.isSafe, required this.isHighest,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = isSafe
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isHighest)
                    const Icon(Icons.arrow_right_rounded,
                        size: 18, color: Colors.blue),
                  Text(label,
                      style: TextStyle(
                          fontWeight: isHighest
                              ? FontWeight.w700
                              : FontWeight.normal,
                          fontSize: 14)),
                ],
              ),
              Text('${(value * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isHighest ? barColor : null)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: barColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(
                  isHighest ? barColor : barColor.withOpacity(0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TipCard({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
