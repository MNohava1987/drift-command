# C4 Model: Architectural Strategy

For large, complex systems, the "C4 Model" is the gold standard. It’s not just about "drawing boxes"—it’s about **layering your documentation** so that you don't overwhelm the reader.

## The Strategy: "Zooming In"

1.  **Level 1 (System Context):** High-level view for non-technical stakeholders (The User, The App, The Backend).
2.  **Level 2 (Containers):** The tech stack (Mobile App, API, Database).
3.  **Level 3 (Components):** The internal modules (Battle Sim, AI Doctrine).
4.  **Level 4 (Code):** Class diagrams (Ship Model, Weapon Model).

### Diagram-as-Code (Mermaid C4 Syntax)

```mermaid
C4Context
    title System Context Diagram for Drift Command

    Person(player, "Player", "A person who plays the game on their mobile device.")
    System(driftCommand, "Drift Command", "Mobile-first tactical space combat game (mostly local).")
    System_Ext(gcp, "GCP Backend", "Optional services for telemetry and remote config.")

    Rel(player, driftCommand, "Plays and issues orders")
    Rel(driftCommand, gcp, "Sends anonymous telemetry (optional)", "HTTPS/JSON")
    Rel(gcp, driftCommand, "Provides remote scenario updates", "HTTPS/JSON")
```

```mermaid
C4Container
    title Container Diagram for Drift Command

    Person(player, "Player")

    System_Boundary(c1, "Mobile Device") {
        Container(app, "Flutter/Flame App", "Dart", "Provides the UI and the real-time battle simulation.")
        ContainerDb(localSave, "Local State", "SharedPreferences/SQLite", "Stores player progress and save files.")
    }

    System_Boundary(c2, "GCP Cloud") {
        Container(telemetryApi, "Telemetry API", "Cloud Run (Go/Node)", "Ingests gameplay events for balancing.")
        Container(adminApi, "Admin API", "Cloud Run", "Allows scenario uploads.")
        ContainerDb(storage, "Cloud Storage", "GCS", "Stores JSON scenario files.")
    }

    Rel(player, app, "Uses", "Touch UI")
    Rel(app, localSave, "Reads from and writes to", "Local I/O")
    Rel(app, telemetryApi, "Sends events to", "HTTPS")
    Rel(telemetryApi, storage, "Logs data to", "Internal API")
    Rel(adminApi, storage, "Uploads scenarios to", "Internal API")
```

### Why C4 is Crucial for Complex Systems:
1.  **Prevents Cognitive Overload:** You never try to show the "Ship Model" and the "GCP Admin API" in the same diagram. You "zoom in" to see more detail.
2.  **Standardized Vocabulary:** Everyone understands what a `Person`, `System`, `Container`, and `Component` is.
3.  **Cross-Team Communication:** Level 1 is for product managers. Level 2 is for architects. Level 3/4 is for developers.

### How to use it:
Mermaid now has **native C4 support** (using `C4Context`, `C4Container`, etc.). You can paste this directly into GitHub or any Mermaid-compatible viewer.
