"""
Injects all current Luau scripts from src/ into the root HatchTheEgg.rbxlx place file.
Preserves all Roblox Studio XML referents, properties, unique IDs, and instances.
"""
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from sync_studio import collect_scripts

def update_rbxlx(rbxlx_path: Path):
    scripts = collect_scripts()
    print(f"Collected {len(scripts)} scripts from src/")
    
    # Read text
    text = rbxlx_path.read_text(encoding="utf-8")
    
    # We parse XML to find the exact referent or unique id of each item path
    tree = ET.parse(rbxlx_path)
    root = tree.getroot()
    
    def get_path_map(elem, current_path=""):
        mapping = {}
        for item in elem.findall("./Item"):
            name_elem = item.find("./Properties/string[@name='Name']")
            name = name_elem.text if name_elem is not None else item.attrib.get("class")
            item_path = f"{current_path}.{name}" if current_path else name
            ref = item.attrib.get("referent")
            cls = item.attrib.get("class")
            mapping[item_path] = (ref, cls)
            mapping.update(get_path_map(item, item_path))
        return mapping
    
    path_map = get_path_map(root)
    
    updated_count = 0
    for s in scripts:
        path = s["path"]
        source = s["source"]
        if path not in path_map:
            print(f"Warning: {path} not found in {rbxlx_path.name}")
            continue
        
        ref, cls = path_map[path]
        
        # Locate <Item class="{cls}" referent="{ref}"> ... </Properties>
        # in text
        start_tag = f'<Item class="{cls}" referent="{ref}">'
        start_pos = text.find(start_tag)
        if start_pos == -1:
            print(f"Could not find tag for {path} (ref {ref})")
            continue
            
        end_props = text.find('</Properties>', start_pos)
        if end_props == -1:
            continue
            
        block = text[start_pos:end_props]
        
        # Check if <ProtectedString name="Source"> exists in this block
        source_start_tag = '<ProtectedString name="Source">'
        source_pos = block.find(source_start_tag)
        
        new_source_xml = f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
        
        if source_pos != -1:
            # Replace existing ProtectedString
            source_end_tag = '</ProtectedString>'
            source_end_pos = block.find(source_end_tag, source_pos)
            if source_end_pos != -1:
                old_source_xml = block[source_pos:source_end_pos + len(source_end_tag)]
                new_block = block[:source_pos] + new_source_xml + block[source_end_pos + len(source_end_tag):]
                text = text[:start_pos] + new_block + text[end_props:]
                updated_count += 1
        else:
            # Insert before </Properties>
            new_block = block + f'\n\t\t\t\t\t{new_source_xml}'
            text = text[:start_pos] + new_block + text[end_props:]
            updated_count += 1
            
    rbxlx_path.write_text(text, encoding="utf-8")
    print(f"Successfully updated {updated_count}/{len(scripts)} scripts in {rbxlx_path.name}")

if __name__ == "__main__":
    update_rbxlx(ROOT / "HatchTheEgg.rbxlx")
