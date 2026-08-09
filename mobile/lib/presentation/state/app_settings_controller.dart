import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number.dart';
import '../../data/local/key_value_store.dart';

/// User-level preferences that are not tied to an account.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._store, {this.onCountryCodeChanged});

  final KeyValueStore _store;

  /// Notified whenever the dialling code changes so the messaging provider can
  /// be rebuilt with it.
  final void Function(String? code)? onCountryCodeChanged;

  ThemeMode _themeMode = ThemeMode.system;
  String? _defaultCountryCode;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _loaded;

  /// Dialling code (digits only, e.g. `92`) applied to guardian numbers stored
  /// in national format. `null` means numbers must already be international.
  String? get defaultCountryCode => _defaultCountryCode;

  bool get hasCountryCode => _defaultCountryCode != null;

  Future<void> load() async {
    final String? stored = await _store.read(StorageKeys.themeMode);
    _themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _defaultCountryCode =
        PhoneNumber.normaliseCountryCode(await _store.read(StorageKeys.countryCode));
    onCountryCodeChanged?.call(_defaultCountryCode);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefaultCountryCode(String? value) async {
    final String? normalised = PhoneNumber.normaliseCountryCode(value);
    if (_defaultCountryCode == normalised) return;
    _defaultCountryCode = normalised;
    onCountryCodeChanged?.call(normalised);
    notifyListeners();

    if (normalised == null) {
      await _store.delete(StorageKeys.countryCode);
    } else {
      await _store.write(StorageKeys.countryCode, normalised);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _store.write(StorageKeys.themeMode, mode.name);
  }

  /// Cycles system → light → dark → system, used by the app-bar toggle.
  Future<void> cycleThemeMode() {
    return setThemeMode(switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

  String get themeModeLabel => switch (_themeMode) {
        ThemeMode.system => 'Match device',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
