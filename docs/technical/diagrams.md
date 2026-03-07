# Visual Architecture Diagrams — Drift Command

This document provides visual representations of the Drift Command architecture using Mermaid diagrams.

## 1. High-Level System Overview

```mermaid
graph TD
    subgraph MobileDevice [Mobile Device]
        App[Flutter + Flame App]
        BS[Battle Sim]
        CM[Command Model]
        TS[Tempo System]
        LS[(Local Save)]
        App --- BS
        App --- CM
        App --- TS
        App --- LS
    end

    subgraph GCPBackend [GCP Backend]
        AR[Admin API]
        TA[Telemetry API]
        CS[(Cloud Storage)]
    end

    App -- HTTPS --> AR
    App -- HTTPS --> TA
    AR --> CS
```

## 2. Order Propagation Sequence

How orders move from the Flagship to individual units over time.

```mermaid
sequenceDiagram
    participant P as Player
    participant F as Flagship
    participant C as Command Ship (Relay)
    participant U as Unit

    P->>F: Issue Order (T=0)
    F->>C: Propagate (T = distance / speed)
    alt Relay Chain Healthy
        C->>U: Fan out (T = T_relay + local_delay)
        U->>U: Execute Order
    else Relay Chain Broken
        U->>U: Fallback to Doctrine (Hold/Engage/Retreat)
    end
```

## 3. Tempo System Transitions

The game dynamically adjusts its "pulse" based on combat proximity.

```mermaid
stateDiagram-v2
    [*] --> Distant: Start
    
    Distant --> Contact: Enemy within 2x weapon range
    Contact --> Distant: All enemies beyond 2x range
    
    Contact --> Engaged: Active weapons fire
    Engaged --> Contact: Cease fire (timeout)
    
    Distant --> Engaged: Ambush / Warp-in
    Engaged --> Distant: Retreat / Warp-out

    state Distant {
        note right of Distant: Pulse: 10-20s
    }
    state Contact {
        note right of Contact: Pulse: 5-10s
    }
    state Engaged {
        note right of Engaged: Pulse: 2-5s
    }
```

## 4. GCP Authentication Flow (WIF)

Secure deployment without long-lived keys.

```mermaid
sequenceDiagram
    participant GHA as GitHub Actions Runner
    participant GH as GitHub OIDC
    participant WIF as GCP Workload Identity Federation
    participant GCP as GCP APIs (Deploy)

    GHA->>GH: Request OIDC Token
    GH-->>GHA: Signed JWT Token
    GHA->>WIF: Exchange JWT for GCP Token
    WIF->>WIF: Validate Token & Claims
    WIF-->>GHA: Short-lived Access Token
    GHA->>GCP: Deploy using Token
```

## 5. CI/CD Pipeline

```mermaid
graph LR
    subgraph PR [Pull Request]
        FCI[Flutter CI]
        IP[Infra Plan]
    end

    subgraph Main [Push to main]
        IA[Infra Apply]
        AB[Android Build]
    end

    PR -- Merge --> Main
    
    FCI --> Analyze[flutter analyze]
    FCI --> Test[flutter test]
    IP --> TPlan[terraform plan]
    IA --> TApply[terraform apply]
    AB --> APK[flutter build apk]
```
