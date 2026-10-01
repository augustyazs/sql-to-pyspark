import re


WRAPPER_PATTERNS = [
    (r"(?im)^\s*set\s+define\s+off\s*;\s*$", "set define off"),
    (r"(?im)^\s*set\s+serveroutput\s+on\s*;\s*$", "set serveroutput"),
    (r"(?im)^\s*show\s+errors\s*;\s*$", "show errors"),
    (r"(?m)^\s*/\s*$", "sqlplus slash terminator"),
]


def preprocess_oracle(raw_code: str) -> tuple[str, list[str]]:
    """Strip SQL*Plus wrappers while preserving procedure business logic."""
    clean = raw_code
    flagged: list[str] = []

    for pattern, label in WRAPPER_PATTERNS:
        matches = re.findall(pattern, clean)
        for m in matches:
            flagged.append(f"[WRAPPER - {label}]: {str(m).strip()}")
        clean = re.sub(pattern, "", clean)

    clean = re.sub(r"\n{3,}", "\n\n", clean)
    return clean.strip(), flagged
