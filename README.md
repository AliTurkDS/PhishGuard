# PhishGuard — Flutter App

Offline AI-powered phishing URL detector. Classifies URLs as **Benign**, **Phishing**, **Malware**, or **Defacement** using an on-device TFLite model.

---

## Project structure

```
lib/
  main.dart                         ← App entry, theme, classifier init
  models/
    scan_record.dart                ← SQLite row model
  services/
    url_feature_extractor.dart      ← Dart port of Python feature engineering
    phishing_classifier.dart        ← TFLite inference service (singleton)
    history_repository.dart         ← SQLite CRUD via sqflite
  screens/
    home_screen.dart                ← URL input + scan button
    result_screen.dart              ← Verdict + probability breakdown
    history_screen.dart             ← Past scans list
assets/
  phishing_model.tflite             ← ⚠️  Copy from Colab output
  scaler_params.json                ← ⚠️  Copy from Colab output
```

---

## Setup

### 1. Add your model files

Copy the two files downloaded from the Colab notebook into `assets/`:

```
assets/phishing_model.tflite
assets/scaler_params.json
```

> Use `phishing_model_quantized.tflite` instead if you want a smaller APK (~70 KB vs ~216 KB). Just rename it to `phishing_model.tflite`.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Android permissions

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Only needed if you add URL opening via url_launcher -->
```

For Android 9+, add inside `<application>`:
```xml
android:usesCleartextTraffic="true"
```

### 4. iOS — add TFLite support

In `ios/Podfile`, ensure the deployment target is at least iOS 12:
```ruby
platform :ios, '12.0'
```

### 5. Run

```bash
flutter run
```

---

## How inference works

```
Raw URL string
     │
     ▼
UrlFeatureExtractor.extract(url)
→ List<double> of 40 features (same order as Colab)
     │
     ▼
Normalise: (x - mean) / std
(mean & std from scaler_params.json)
     │
     ▼
TFLite interpreter
→ softmax output: [benign, defacement, malware, phishing]
     │
     ▼
argmax → label + confidence
```

> The feature order in `url_feature_extractor.dart` MUST match `scaler_params.json → feature_names` exactly. If you add or change features in the Colab notebook, retrain and regenerate `scaler_params.json`, then update the Dart extractor to match.

---

## Key dependencies

| Package | Purpose |
|---|---|
| `tflite_flutter` | On-device TFLite inference |
| `sqflite` | Local SQLite history storage |
| `path_provider` | File system paths for DB |
| `url_launcher` | Open URLs in browser (optional) |
| `share_plus` | Share scan results |

---

## Building a release APK

```bash
flutter build apk --release --split-per-abi
```

The output APK is typically **10–15 MB** with the quantized model.
