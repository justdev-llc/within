import 'package:envied/envied.dart';

part 'env.g.dart';

/// Values from the project-root `.env`, compiled in by code generation.
/// After changing `.env`, regenerate with:
///
///   dart run build_runner build
///
/// A missing `.env` yields empty strings, so the app still runs without accounts.
@Envied(path: '.env', requireEnvFile: false)
abstract final class Env {
  @EnviedField(varName: 'SUPABASE_URL', defaultValue: '')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY', defaultValue: '')
  static const String supabaseKey = _Env.supabaseKey;
}
