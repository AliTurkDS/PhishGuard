// lib/services/phishing_classifier.dart
// Loads the TFLite model + scaler params, runs inference on a raw URL string.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'url_feature_extractor.dart';

class PredictionResult {
  final String label;        // 'benign' | 'phishing' | 'malware' | 'defacement'
  final double confidence;   // 0.0 – 1.0
  final Map<String, double> allProbabilities;
  final bool isSafe;

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.allProbabilities,
    required this.isSafe,
  });

  /// Risk level: 0 = safe, 1 = suspicious, 2 = dangerous
  int get riskLevel {
    if (isSafe) return 0;
    if (confidence < 0.7) return 1;
    return 2;
  }

  String get riskLabel {
    switch (riskLevel) {
      case 0: return 'Safe';
      case 1: return 'Suspicious';
      default: return 'Dangerous';
    }
  }
}

class PhishingClassifier {
  static PhishingClassifier? _instance;
  Interpreter? _interpreter;
  List<String> _labelClasses = [];
  List<String> _featureNames = [];
  List<double> _mean = [];
  List<double> _std  = [];
  bool _isLoaded = false;

  PhishingClassifier._();

  static PhishingClassifier get instance {
    _instance ??= PhishingClassifier._();
    return _instance!;
  }

  bool get isLoaded => _isLoaded;

  /// Call once at app startup (e.g. in main() or initState of a splash screen).
  Future<void> initialize() async {
    if (_isLoaded) return;

    // Load scaler params
    final scalerJson = await rootBundle.loadString('assets/scaler_params.json');
    final scaler = jsonDecode(scalerJson) as Map<String, dynamic>;
    _labelClasses = List<String>.from(scaler['label_classes']);
    _featureNames = List<String>.from(scaler['feature_names']);
    _mean = List<double>.from(scaler['mean'].map((v) => (v as num).toDouble()));
    _std  = List<double>.from(scaler['std'].map((v) => (v as num).toDouble()));

    // Load TFLite model
    _interpreter = await Interpreter.fromAsset('assets/phishing_model.tflite');
    _isLoaded = true;
  }

  /// Classify a single URL. Returns null if the classifier is not yet loaded.
  Future<PredictionResult?> classify(String url) async {
    if (!_isLoaded || _interpreter == null) return null;

    // 1. Extract raw features
    final rawFeatures = UrlFeatureExtractor.extract(url);

    // 2. Normalise: (x - mean) / std
    final normalised = List<double>.generate(rawFeatures.length, (i) {
      final s = _std[i] == 0 ? 1e-8 : _std[i];
      return (rawFeatures[i] - _mean[i]) / s;
    });

    // 3. Run inference
    final input  = [normalised];                          // shape [1, n_features]
    final output = [List<double>.filled(_labelClasses.length, 0.0)];
    _interpreter!.run(input, output);

    final probs = output[0];
    final maxIdx = probs.indexWhere(
        (p) => p == probs.reduce((a, b) => a > b ? a : b));
    final label = _labelClasses[maxIdx];
    final confidence = probs[maxIdx];

    final allProbs = <String, double>{};
    for (int i = 0; i < _labelClasses.length; i++) {
      allProbs[_labelClasses[i]] = probs[i];
    }

    return PredictionResult(
      label: label,
      confidence: confidence,
      allProbabilities: allProbs,
      isSafe: label == 'benign',
    );
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
    _instance = null;
  }
}
