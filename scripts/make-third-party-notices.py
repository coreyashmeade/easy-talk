#!/usr/bin/env python3 -I
"""Generate THIRD_PARTY_NOTICES.md from the resolved Swift packages and their license files.
Run after building the app (needs app/.build-xc/SourcePackages/checkouts). Usage: scripts/make-third-party-notices.py"""
import json, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
checkouts = root / "app/.build-xc/SourcePackages/checkouts"
pins = json.loads((root / "app/Package.resolved").read_text())["pins"]

# Libraries vendored inside packages, with their own licenses.
vendored = {
    "mlx-swift": [("MLX", "Source/Cmlx/mlx/LICENSE"), ("MLX C", "Source/Cmlx/mlx-c/LICENSE"),
                  ("metal-cpp", "Source/Cmlx/metal-cpp/LICENSE.txt"), ("fmt", "Source/Cmlx/fmt/LICENSE"),
                  ("nlohmann/json", "Source/Cmlx/json/LICENSE.MIT")],
    "mlx-swift-lm": [("XGrammar", "Libraries/MLXCXGrammar/xgrammar/LICENSE"), ("XGrammar (NOTICE)", "Libraries/MLXCXGrammar/xgrammar/NOTICE")],
}
build_only = {"swift-syntax"}  # used by Swift macros at compile time; not linked into the app

def folder_for(location):
    name = location.rstrip("/").split("/")[-1].removesuffix(".git")
    for d in checkouts.iterdir():
        if d.name.lower() == name.lower():
            return d
    raise SystemExit(f"checkout not found for {location}")

out = ["# Third-Party Notices", "",
       "Easy Talk includes or uses the following open-source software. Each component's license text follows.",
       "",
       "## Models (downloaded at first launch, not bundled)",
       "- **Parakeet TDT 0.6B v2** by NVIDIA, licensed under CC-BY-4.0: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2 "
       "(Core ML conversion by FluidInference: https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml)",
       "- **Qwen 3.5 4B** by the Qwen team (Alibaba Cloud), licensed under Apache-2.0: https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit",
       ""]
sections = []
for p in sorted(pins, key=lambda p: p["identity"]):
    d = folder_for(p["location"])
    version = p["state"].get("version") or p["state"].get("revision", "")[:12]
    files = sorted(f for f in d.iterdir() if f.is_file() and f.name.upper().startswith(("LICENSE", "NOTICE", "COPYING")))
    note = " (build tool only; not included in the app)" if p["identity"] in build_only else ""
    sections.append((f"{d.name} {version}{note}", p["location"], files))
    for name, rel in vendored.get(p["identity"], []):
        sections.append((f"{name} (vendored in {d.name})", p["location"], [d / rel]))
fa = folder_for("https://github.com/FluidInference/FluidAudio.git") / "LICENSE"
sections.append(("NemoTextProcessing 0.3.1 (prebuilt binary used by FluidAudio), Apache-2.0",
                 "https://github.com/FluidInference/text-processing-rs", [fa]))

out.append("## Software")
for title, url, _ in sections:
    out.append(f"- {title}: {url}")
for title, url, files in sections:
    out += ["", "---", "", f"## {title}", url]
    for f in files:
        out += ["", "```", f.read_text(errors="replace").strip(), "```"]
(root / "THIRD_PARTY_NOTICES.md").write_text("\n".join(out) + "\n")
print(f"wrote THIRD_PARTY_NOTICES.md: {len(sections)} components")
