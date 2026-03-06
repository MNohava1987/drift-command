import '../../core/models/ship_data.dart';

// ── Base weapon DPS ────────────────────────────────────────────────────────
const Map<RoleTag, double> kWeaponDps = {
  RoleTag.directFire:   8.0,
  RoleTag.missile:     15.0,
  RoleTag.pointDefense: 5.0,
};

// ── Point defense ─────────────────────────────────────────────────────────
const double kPointDefenseInterceptRate = 0.4;  // 40 % missile reduction
const double kPointDefenseRange         = 160.0; // world units

// ── Ship mode modifiers ───────────────────────────────────────────────────
const double kAttackModeRangeBonus    = 1.15;
const double kAttackModeDamageBonus   = 1.25;
const double kDefensiveModeReduction  = 0.80;

// ── Torpedo (M7) ──────────────────────────────────────────────────────────
const double kTorpedoReloadTime      = 5.0;  // seconds between salvos
const double kTorpedoSalvoMultiplier = 3.0;  // burst damage × multiplier

// ── Repair tender (M7) ────────────────────────────────────────────────────
const double kRepairRange = 120.0; // world units
const double kRepairHps   = 6.0;   // HP healed per second

// ── EW / jamming (M7) ────────────────────────────────────────────────────
const double kJammingRange        = 150.0; // world units
const double kJammingRangePenalty = 0.35;  // effective range × (1 − 0.35)

// ── Flak area (M7) ───────────────────────────────────────────────────────
const double kFlakAreaRadius = 60.0; // world units; damages friend + foe

// ── Flanking bonus (M7) ──────────────────────────────────────────────────
const double kFlankingDamageBonus = 1.35; // rear-arc attack multiplier

// ── Heavy broadside (M7) ─────────────────────────────────────────────────
const double kHeavyBroadsideBonus = 1.40; // perpendicular fire multiplier
