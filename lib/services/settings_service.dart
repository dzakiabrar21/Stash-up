import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService(this._prefs, this._secure);

  static Future<SettingsService> create() async => SettingsService(
        await SharedPreferences.getInstance(),
        const FlutterSecureStorage(),
      );

  static const defaultGeminiModel = 'gemini-3.6-flash';

  /// Defaults that Google has retired. A saved value equal to one of these was
  /// almost certainly just the old default echoed back, so it is upgraded.
  static const _retiredDefaults = {'gemini-2.5-flash'};

  static const _kLastWallet = 'last_wallet_id';
  static const _kGeminiModel = 'gemini_model';
  static const _kGeminiKey = 'gemini_api_key';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  int? get lastWalletId => _prefs.getInt(_kLastWallet);
  Future<void> setLastWalletId(int id) => _prefs.setInt(_kLastWallet, id);

  String get geminiModel {
    final m = _prefs.getString(_kGeminiModel);
    if (m == null || m.trim().isEmpty || _retiredDefaults.contains(m.trim())) {
      return defaultGeminiModel;
    }
    return m;
  }

  Future<void> setGeminiModel(String model) => _prefs.setString(_kGeminiModel, model.trim());

  /// The API key is kept in the platform keystore/keychain, never in SQLite.
  Future<String?> getGeminiApiKey() => _secure.read(key: _kGeminiKey);

  Future<void> setGeminiApiKey(String? key) {
    final k = key?.trim() ?? '';
    return k.isEmpty ? _secure.delete(key: _kGeminiKey) : _secure.write(key: _kGeminiKey, value: k);
  }
}
