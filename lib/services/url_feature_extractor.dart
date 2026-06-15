// lib/services/url_feature_extractor.dart
// Dart port of the Python extract_features() function from the Colab notebook.
// Must produce features in EXACTLY the same order as scaler_params.json.

import 'dart:math';

class UrlFeatureExtractor {
  /// Returns a list of 40 numerical features in the order defined by
  /// scaler_params.json → feature_names.
  static List<double> extract(String rawUrl) {
    final url = rawUrl.trim();
    final Uri? uri = Uri.tryParse(
        url.startsWith('http') ? url : 'http://$url');

    final hostname = uri?.host ?? '';
    final path = uri?.path ?? '';
    final query = uri?.query ?? '';
    final netloc = uri != null ? '${uri.host}${uri.hasPort ? ":${uri.port}" : ""}' : '';

    // ── Length features ────────────────────────────────────────
    final urlLen = url.length.toDouble();
    final hostnameLen = hostname.length.toDouble();
    final pathLen = path.length.toDouble();
    final queryLen = query.length.toDouble();

    // ── Character counts ───────────────────────────────────────
    int count(String src, String ch) => ch.allMatches(src).length;
    final numDots       = count(url, '.').toDouble();
    final numHyphens    = count(url, '-').toDouble();
    final numUnderscores= count(url, '_').toDouble();
    final numSlashes    = count(url, '/').toDouble();
    final numAt         = count(url, '@').toDouble();
    final numQuestion   = count(url, '?').toDouble();
    final numAmpersand  = count(url, '&').toDouble();
    final numEquals     = count(url, '=').toDouble();
    final numPercent    = count(url, '%').toDouble();
    final numHash       = count(url, '#').toDouble();
    final numDigits     = url.runes.where((r) => r >= 48 && r <= 57).length.toDouble();
    final numLetters    = url.runes.where((r) =>
        (r >= 65 && r <= 90) || (r >= 97 && r <= 122)).length.toDouble();
    final digitLetterRatio = urlLen > 0 ? numDigits / urlLen : 0.0;

    // ── Domain-level features ──────────────────────────────────
    final numSubdomains = hostname.isEmpty ? 0.0 : count(hostname, '.').toDouble();
    final hasIp = _isIpAddress(hostname) ? 1.0 : 0.0;
    final hasPort = (netloc.contains(':') && !netloc.contains('@')) ? 1.0 : 0.0;
    final hasHttps = url.startsWith('https') ? 1.0 : 0.0;

    // ── Suspicious keywords ────────────────────────────────────
    final lower = url.toLowerCase();
    double kw(String word) => lower.contains(word) ? 1.0 : 0.0;
    final hasLogin   = kw('login');
    final hasSignin  = kw('signin');
    final hasAccount = kw('account');
    final hasSecure  = kw('secure');
    final hasUpdate  = kw('update');
    final hasConfirm = kw('confirm');
    final hasBanking = kw('bank');
    final hasPaypal  = kw('paypal');
    final hasVerify  = kw('verify');
    final hasFree    = kw('free');
    final hasLucky   = kw('lucky');
    final hasPrize   = kw('prize');
    final hasClick   = kw('click');
    final hasWin     = kw('win');

    // ── Path features ──────────────────────────────────────────
    final pathDepth = count(path, '/').toDouble();
    final hasDoubleSlash = (url.length > 7 && url.substring(7).contains('//')) ? 1.0 : 0.0;
    final hasHexChars = RegExp(r'%[0-9a-fA-F]{2}').hasMatch(url) ? 1.0 : 0.0;

    // ── Entropy features ───────────────────────────────────────
    final urlEntropy      = _shannonEntropy(url);
    final hostnameEntropy = _shannonEntropy(hostname);
    final pathEntropy     = _shannonEntropy(path);

    // ── TLD features ───────────────────────────────────────────
    final parts = hostname.split('.');
    final tld = parts.isNotEmpty ? parts.last.toLowerCase() : '';
    final tldLength = tld.length.toDouble();
    const commonTlds = {'com','org','net','edu','gov','io','co','uk','de','fr'};
    final isCommonTld = (hostname.contains('.') && commonTlds.contains(tld)) ? 1.0 : 0.0;

    return [
      urlLen, hostnameLen, pathLen, queryLen,
      numDots, numHyphens, numUnderscores, numSlashes,
      numAt, numQuestion, numAmpersand, numEquals, numPercent, numHash,
      numDigits, numLetters, digitLetterRatio,
      numSubdomains, hasIp, hasPort, hasHttps,
      hasLogin, hasSignin, hasAccount, hasSecure, hasUpdate, hasConfirm,
      hasBanking, hasPaypal, hasVerify, hasFree, hasLucky, hasPrize, hasClick, hasWin,
      pathDepth, hasDoubleSlash, hasHexChars,
      urlEntropy, hostnameEntropy, pathEntropy,
      tldLength, isCommonTld,
    ];
  }

  static double _shannonEntropy(String s) {
    if (s.isEmpty) return 0.0;
    final freq = <String, int>{};
    for (final ch in s.split('')) {
      freq[ch] = (freq[ch] ?? 0) + 1;
    }
    double entropy = 0.0;
    for (final count in freq.values) {
      final p = count / s.length;
      entropy -= p * (log(p) / log(2));
    }
    return entropy;
  }

  static bool _isIpAddress(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }
}
