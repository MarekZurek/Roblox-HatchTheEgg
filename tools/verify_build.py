"""Static Rojo artifact boundary check. Does not run Roblox or prove replication."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def main():
    model = ET.parse(ROOT / "build/HatchTheEgg.rbxlx").getroot()
    modules = []
    scripts = []

    def visit(item, path):
        name = item.findtext("Properties/string[@name='Name']")
        current = path + [name]
        kind = item.attrib.get("class")
        if kind == "ModuleScript":
            modules.append("/".join(current))
        if kind in ("Script", "LocalScript"):
            scripts.append("/".join(current))
        for child in item.findall("Item"):
            visit(child, current)

    for item in model.findall("Item"):
        visit(item, [])
    shared = "ReplicatedStorage/HatchTheEgg/Shared/"
    private = "ServerScriptService/HatchTheEgg/"
    client = "StarterPlayer/StarterPlayerScripts/HatchTheEggClient/"
    assert set(p for p in modules if p.startswith(shared)) == {
        shared + "NumericCodec", shared + "ProtocolSchemas"}
    for name in ("SessionRepository", "ProfileSchema", "PersistenceData",
                 "RobloxDataStorePort", "CatalogRegistry", "CatalogRegistry/Data",
                 "FarmMath/production_research", "FarmMath/ihr",
                 "FarmMath/hatching_rcb", "FarmMath/PopulationMath",
                 "FarmMath/fv_se",
                 "PlayerCoordinator", "TimelineSimulation", "FarmActions",
                 "ViewProjector", "NetworkGateway", "Bootstrap"):
        assert private + name in modules, name
    for name in ("ClientTransport", "ClientStateStore", "RoutePresentation",
                 "IntentControllers", "HUD", "Bootstrap"):
        assert client + name in modules, name
    assert not scripts, scripts
    result = {"status": "PASS_STATIC_BUILD", "modules": modules,
              "runtimeReplicationTested": False, "studioTested": False}
    (ROOT / "build/mapping-results.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Rojo mapping PASS_STATIC_BUILD: {len(modules)} modules, no entrypoint scripts")


if __name__ == "__main__":
    main()
