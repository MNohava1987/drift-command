import '../../core/models/battle_state.dart';

// ── AI re-plan intervals (seconds) by tempo band ─────────────────────────
const Map<TempoBand, double> kAiReplanInterval = {
  TempoBand.distant:  15.0,
  TempoBand.contact:   7.0,
  TempoBand.engaged:   3.0,
};

// ── Flanking posture lateral offset (world units) ─────────────────────────
const double kFlankingLateralOffset = 150.0;

// ── Defensive posture hold radius (world units) ───────────────────────────
const double kDefensiveHoldRange = 200.0;

// ── Ghost evade distance (world units) ────────────────────────────────────
const double kGhostEvadeDistance = 180.0;
