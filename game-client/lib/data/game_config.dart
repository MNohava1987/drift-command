import '../core/models/ship_data.dart';

// ── World dimensions ───────────────────────────────────────────────────────
const double kWorldWidth  = 2000.0;
const double kWorldHeight = 1200.0;

// ── Input ──────────────────────────────────────────────────────────────────
const double kSelectionRadius = 40.0;

// ── Renderer ───────────────────────────────────────────────────────────────
const double kTrajectorySeconds = 8.0;
const double kSensorSpeed       = 400.0;

// ── Tactical ──────────────────────────────────────────────────────────────
const double kContactRange              = 250.0;
const double kRepresentativeWeaponRange = 150.0;

// ── Ship speed caps by mass class ─────────────────────────────────────────
const Map<MassClass, double> kMaxSpeedByMass = {
  MassClass.light:   120.0,
  MassClass.medium:   80.0,
  MassClass.heavy:    50.0,
  MassClass.capital:  30.0,
};

// ── Audio asset paths ─────────────────────────────────────────────────────
const String kSoundOrderClick = 'order_click.ogg';
const String kSoundWeaponFire = 'weapon_fire.ogg';
const String kSoundExplosion  = 'explosion.ogg';
const String kSoundEngineHum  = 'engine_hum.ogg';
