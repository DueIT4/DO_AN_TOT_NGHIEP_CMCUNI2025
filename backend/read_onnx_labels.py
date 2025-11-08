import sys, ast, json
import onnx

def parse_names(val):
    if isinstance(val, (list, tuple)):
        return list(val)
    if isinstance(val, dict):
        ids = sorted(int(k) for k in val.keys())
        return [val[i] for i in ids]
    if not isinstance(val, str):
        return []
    try:
        obj = ast.literal_eval(val)
        return parse_names(obj)
    except Exception:
        pass
    try:
        obj = json.loads(val)
        return parse_names(obj)
    except Exception:
        pass
    parts = [p.strip() for p in val.split(",") if p.strip()]
    return parts

def read_labels_from_onnx(onnx_path: str):
    model = onnx.load(onnx_path)
    meta = {p.key: p.value for p in model.metadata_props}
    names_raw = meta.get("names")
    nc = meta.get("nc")
    imgsz = meta.get("imgsz")

    labels = parse_names(names_raw) if names_raw else []
    return labels, {"nc": nc, "imgsz": imgsz, "meta": meta}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python read_onnx_labels.py path/to/model.onnx [--save]")
        sys.exit(1)

    onnx_path = sys.argv[1]
    save = "--save" in sys.argv

    labels, info = read_labels_from_onnx(onnx_path)
    print("== ONNX metadata info ==")
    print(f"  nc        : {info['nc']}")
    print(f"  imgsz     : {info['imgsz']}")
    print(f"  labels(K) : {len(labels)}")
    for i, name in enumerate(labels):
        print(f"{i}: {name}")

    if save:
        out = "labels.txt"
        with open(out, "w", encoding="utf-8") as f:
            for name in labels:
                f.write(f"{name}\n")
        print(f"\n✅ Saved labels to {out}")
