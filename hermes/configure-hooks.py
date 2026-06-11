#!/usr/bin/env python3
"""Set the sprite keep-alive hook in Hermes' config.yaml.

Run with the hermes venv python (it ships PyYAML):
    ~/.hermes/hermes-agent/venv/bin/python configure-hooks.py [config_path]

Idempotent: only sets hooks.pre_llm_call and hooks_auto_accept, everything
else in the config is preserved (comments are not — the file is
machine-generated and has none).
"""
import sys
from pathlib import Path

import yaml

HOOK_CMD = str(Path.home() / ".hermes/agent-hooks/refresh-task.sh")


def main():
    cfg_path = (
        Path(sys.argv[1]) if len(sys.argv) > 1
        else Path.home() / ".hermes/config.yaml"
    )
    cfg = {}
    if cfg_path.exists():
        cfg = yaml.safe_load(cfg_path.read_text()) or {}
    if not isinstance(cfg.get("hooks"), dict):
        cfg["hooks"] = {}
    cfg["hooks"]["pre_llm_call"] = [{"command": HOOK_CMD, "timeout": 10}]
    cfg["hooks_auto_accept"] = True
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    cfg_path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True))
    print(f"keep-alive hook configured in {cfg_path}")


if __name__ == "__main__":
    main()
