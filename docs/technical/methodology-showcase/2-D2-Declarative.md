# D2: The "Mermaid Killer" for Professionals

If Mermaid is "Markdown for diagrams," **D2** is "React for diagrams." It's built for those who find Mermaid too messy for complex systems but find LucidChart too slow.

## The Strategy: "Clean Code, Perfect Layout"

D2 uses a nested, curly-brace syntax that looks like JSON or CSS. It handles large-scale nesting and "sketch" modes better than any other tool.

### Diagram-as-Code (D2 Source)

```d2
# 1. Global Styles
classes: {
  service: { style: { fill: "#eef2ff"; stroke: "#6366f1"; stroke-width: 2 } }
  database: { shape: cylinder; style: { fill: "#ecfdf5"; stroke: "#10b981" } }
}

# 2. Structure
Mobile App: {
  style: { stroke-dash: 5 }
  
  Game Engine: {
    class: service
    Battle Simulator: {
      shape: hexagon
      style: { fill: "#fee2e2"; stroke: "#ef4444" }
    }
    Tempo System: { class: service }
    Command Model: { class: service }
  }

  Local Storage: {
    class: database
    label: "SQLite / SharedPreferences"
  }

  Game Engine.Battle Simulator -> Local Storage: "Save State"
}

GCP Backend: {
  Admin API: { class: service }
  Telemetry: { class: service }
}

Mobile App -> GCP Backend: "HTTPS / JSON" {
  style: { stroke: "#94a3b8"; stroke-width: 2; animated: true }
}
```

### Why D2 is Superior for Complexity:
1.  **Nested Syntax:** Using `{ }` for nesting makes it incredibly clear where a "boundary" starts and ends—much easier to read than `subgraph`.
2.  **Explicit Shapes:** You can easily define `shape: hexagon` or `shape: cylinder` without learning obscure Mermaid syntax (`[( )]`).
3.  **Advanced Animations:** D2 supports `animated: true` for arrows, allowing you to show data *flow* in a way that regular Mermaid cannot.
4.  **The "Sketch" Mode:** You can tell D2 to render the diagram as a "hand-drawn sketch" for early-stage design meetings where you don't want it to look "too final."
5.  **Auto-Layout (Tala Engine):** D2’s proprietary layout engine is specifically designed to prevent "spaghetti lines" in massive enterprise diagrams.

### How to use it:
To render this, you need the `d2` binary installed (`curl -fsSL https://d2lang.com/install.sh | sh`). You then run:
`d2 --theme 200 input.d2 output.svg`
