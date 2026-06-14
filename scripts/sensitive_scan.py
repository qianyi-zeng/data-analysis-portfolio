#!/usr/bin/env python3
"""Scan public portfolio text for obvious sensitive patterns."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_EXTENSIONS = {".md", ".sql", ".py", ".txt"}

PATTERNS = {
    "phone_cn": re.compile(r"\b1[3-9]\d{9}\b"),
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "url_or_internal_host": re.compile(r"(https?://|[-.]int\b|intranet|internal|corp\.)", re.IGNORECASE),
    "raw_identifier": re.compile(
        r"((店铺|主播|商品|视频)\s*ID\s*[:：]?\s*\d+|user_id\s*=\s*\d+)",
        re.IGNORECASE,
    ),
    "budget_pool": re.compile(r"(预算池|资金池|审批群|群号)\s*(ID|编号)?\s*[:：]?\s*\d+"),
}


def iter_files() -> list[Path]:
    paths: list[Path] = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts:
            continue
        if path == Path(__file__).resolve():
            continue
        if path.is_file() and path.suffix in TEXT_EXTENSIONS:
            paths.append(path)
    return sorted(paths)


def main() -> int:
    findings: list[str] = []
    for path in iter_files():
        text = path.read_text(encoding="utf-8")
        for name, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                line_no = text[: match.start()].count("\n") + 1
                snippet = match.group(0)
                findings.append(f"{path.relative_to(ROOT)}:{line_no}: {name}: {snippet}")

    if findings:
        print("Sensitive scan failed:")
        print("\n".join(findings))
        return 1

    print("Sensitive scan passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
