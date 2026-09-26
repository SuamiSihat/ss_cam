# Plugin Architecture & Modularity

CAM Studio is built around a lightweight, high-performance plugin engine. Rather than maintaining separate application forks for different industry editions, every auxiliary module implements the canonical `IAppPlugin` interface.

---

## 1. Architectural Principles

1. **One Canonical Component:** Core workstation logic (such as navigation, diffing, and the command palette) is never duplicated.
2. **Configuration-Driven Lifecycle:** Modules are initialized, bound, or unmounted dynamically based on settings in `TenantConfig.json`.
3. **Graceful Degradation:** If a network-dependent plugin (e.g. an external stream or webhook) fails, it must never block or crash the main WPF UI thread.

---

## 2. The `IAppPlugin` Contract

Each feature module adheres to the following contract:

```csharp
public interface IAppPlugin
{
    string PluginId { get; }
    string DisplayName { get; }
    string IconSymbol { get; }
    int NavigationOrder { get; }
    bool IsEnabledByDefault { get; }

    void Initialize(TenantConfig config);
    UIElement CreateView();
    void OnNavigatedTo();
    void OnNavigatedFrom();
}
```

---

## 3. Dynamic Navigation Binding

When `MainWindow` starts, it interrogates `PluginRegistry`:
1. Inspects `TenantConfig.plugins`.
2. For each enabled plugin, instantiates a `NavigationViewItem`.
3. Binds the plugin's navigation trigger to the shell's central frame navigator.
4. Injects matching searchable commands into the global `CommandPaletteService` (accessible via `Ctrl + K`).

If a module is set to `"enabled": false` in `TenantConfig.json`, it is omitted entirely from the sidebar, memory allocation is skipped, and hotkeys are unbound.
