import json
import re
from state.graph_state import GraphState
from models.schemas import SASAnalysis
from tools.llm_client import call_llm
from tools.oracle_preprocessor import preprocess_oracle
from config.prompts_oracle import ANALYZER_SYSTEM, ANALYZER_USER
from utils.logger import log_step


def _coerce_nulls(result: dict) -> dict:
    """
    Coerce None values to empty strings for all string fields the LLM
    occasionally returns as null. Prevents Pydantic validation errors.
    """
    def _as_dict_list(items):
        if not isinstance(items, list):
            return []
        return [x for x in items if isinstance(x, dict)]

    # source_tables / output_tables: schema_name
    for key in ("source_tables", "output_tables"):
        sanitized = _as_dict_list(result.get(key, []))
        result[key] = sanitized
        for t in sanitized:
            if t.get("table") is None or not str(t.get("table", "")).strip():
                if t.get("name"):
                    t["table"] = str(t.get("name"))
                elif t.get("table_name"):
                    t["table"] = str(t.get("table_name"))
                elif t.get("object_name"):
                    t["table"] = str(t.get("object_name"))
            if t.get("schema") is None:
                t["schema"] = ""
            if t.get("schema_name") is None:
                t["schema_name"] = ""
            if t.get("description") is None:
                t["description"] = ""
            if t.get("access_method") is None:
                t["access_method"] = "direct"
            if not isinstance(t.get("columns_used"), list):
                t["columns_used"] = []

    # intermediate_tables
    result["intermediate_tables"] = _as_dict_list(result.get("intermediate_tables", []))
    for t in result["intermediate_tables"]:
        if t.get("table") is None or not str(t.get("table", "")).strip():
            if t.get("name"):
                t["table"] = str(t.get("name"))
            elif t.get("table_name"):
                t["table"] = str(t.get("table_name"))
            elif t.get("object_name"):
                t["table"] = str(t.get("object_name"))
        for field in ("created_by", "logic_summary"):
            if t.get(field) is None:
                t[field] = ""
        if not isinstance(t.get("columns_produced"), list):
            t["columns_produced"] = []

    # macros
    result["macros"] = _as_dict_list(result.get("macros", []))
    for m in result["macros"]:
        for field in ("loop_description", "description"):
            if m.get(field) is None:
                m[field] = ""

    # macro_variables: value must be string
    result["macro_variables"] = _as_dict_list(result.get("macro_variables", []))
    for mv in result["macro_variables"]:
        val = mv.get("value")
        if isinstance(val, list):
            mv["value"] = ", ".join(f"'{str(v)}'" for v in val)
        elif val is None:
            mv["value"] = ""
        else:
            mv["value"] = str(val)

    # transformation_blocks
    result["transformation_blocks"] = _as_dict_list(result.get("transformation_blocks", []))
    for idx, b in enumerate(result["transformation_blocks"]):
        if b.get("name") is None or not str(b.get("name", "")).strip():
            block_id = b.get("block_id")
            if block_id is not None:
                b["name"] = f"block_{block_id}"
            else:
                b["name"] = f"block_{idx + 1}"
        for field in ("type", "logic_summary", "sql_hint"):
            if b.get(field) is None:
                b[field] = ""
        # output_table must be a string — LLM occasionally returns a list
        ot = b.get("output_table")
        if isinstance(ot, list):
            b["output_table"] = ot[0] if ot else ""
        elif ot is None:
            b["output_table"] = ""

    # reporting_blocks
    result["reporting_blocks"] = _as_dict_list(result.get("reporting_blocks", []))
    for b in result["reporting_blocks"]:
        for field in ("description", "note"):
            if b.get(field) is None:
                b[field] = ""

    def _stringify_list(items):
        if not isinstance(items, list):
            return []
        out = []
        for item in items:
            if isinstance(item, str):
                out.append(item)
            elif isinstance(item, dict):
                out.append(json.dumps(item, ensure_ascii=True))
            else:
                out.append(str(item))
        return out

    result["constructs"] = _stringify_list(result.get("constructs", []))
    result["dependency_order"] = _stringify_list(result.get("dependency_order", []))
    result["complexity_notes"] = _stringify_list(result.get("complexity_notes", []))

    return result


def _split_schema_table(name: str) -> tuple[str, str]:
    n = name.strip().strip('"').strip("`")
    n = ".".join(part.strip('"').strip("`") for part in n.split("."))
    if "." in n:
        parts = n.split(".")
        return parts[-2], parts[-1]
    return "", n


def _derive_tables_from_sql(clean_code: str, result: dict) -> dict:
    """Derive source/target tables from SQL when LLM table extraction is sparse."""
    if result.get("source_tables") and result.get("output_tables"):
        return result

    insert_targets = re.findall(r"(?im)\bINSERT\s+INTO\s+([A-Z0-9_$.\"`]+)", clean_code)
    merge_targets = re.findall(r"(?im)\bMERGE\s+INTO\s+([A-Z0-9_$.\"`]+)", clean_code)
    update_targets = re.findall(r"(?im)\bUPDATE\s+([A-Z0-9_$.\"`]+)\b", clean_code)
    truncate_targets = re.findall(r"(?im)\bTRUNCATE\s+TABLE\s+([A-Z0-9_$.\"`]+)", clean_code)
    delete_targets = re.findall(r"(?im)\bDELETE\s+FROM\s+([A-Z0-9_$.\"`]+)", clean_code)

    output_names = insert_targets + merge_targets + update_targets + truncate_targets + delete_targets
    output_seen: set[str] = set()
    derived_outputs: list[dict] = []
    for raw in output_names:
        key = raw.lower()
        if key in output_seen:
            continue
        output_seen.add(key)
        schema, table = _split_schema_table(raw)
        derived_outputs.append({
            "schema_name": schema,
            "table": table,
            "description": "Derived from Oracle DML target",
        })

    from_sources = re.findall(r"(?im)\bFROM\s+([A-Z0-9_$.\"`]+)", clean_code)
    join_sources = re.findall(r"(?im)\bJOIN\s+([A-Z0-9_$.\"`]+)", clean_code)
    source_names = from_sources + join_sources
    source_seen: set[str] = set()
    derived_sources: list[dict] = []
    ignored = {"dual", "select"}
    target_name_set = {t["table"].lower() for t in derived_outputs}
    for raw in source_names:
        schema, table = _split_schema_table(raw)
        if not table or table.lower() in ignored:
            continue
        if table.lower() in target_name_set:
            continue
        full_key = f"{schema}.{table}".lower() if schema else table.lower()
        if full_key in source_seen:
            continue
        source_seen.add(full_key)
        derived_sources.append({
            "schema_name": schema,
            "table": table,
            "columns_used": [],
            "access_method": "direct",
        })

    if not result.get("output_tables"):
        result["output_tables"] = derived_outputs
    if not result.get("source_tables"):
        result["source_tables"] = derived_sources
    return result


def analyzer_node(state: GraphState) -> dict:
    """Preprocess Oracle SQL and extract structured metadata via LLM."""
    print("\n[ANALYZER] Preprocessing Oracle procedure...")
    clean_code, ingestion_blocks = preprocess_oracle(state["sas_code_raw"])

    print(f"  Stripped {len(ingestion_blocks)} ingestion/reporting blocks")
    if not clean_code.strip():
        return {
            "status": "error",
            "error": "No transformation logic found after stripping wrapper statements.",
            "sas_code_clean": "",
            "ingestion_blocks": ingestion_blocks,
        }

    print("[ANALYZER] Analyzing transformation logic via LLM...")
    user_prompt = ANALYZER_USER.format(sas_code=clean_code)
    result = call_llm(ANALYZER_SYSTEM, user_prompt, step_name="analyzer")

    # Normalise schema field name
    for key in ["source_tables", "intermediate_tables", "output_tables"]:
        for t in result.get(key, []):
            if "schema" in t and "schema_name" not in t:
                t["schema_name"] = t.pop("schema")

    # Coerce nulls before Pydantic validation
    result = _coerce_nulls(result)
    result = _derive_tables_from_sql(clean_code, result)

    analysis = SASAnalysis(**result)

    print(f"  Source tables      : {[t.table for t in analysis.source_tables]}")
    print(f"  Intermediate tables: {[t.table for t in analysis.intermediate_tables]}")
    print(f"  Output tables      : {[t.table for t in analysis.output_tables]}")
    print(f"  Constructs         : {analysis.constructs}")
    print(f"  Transformation blocks: {len(analysis.transformation_blocks)}")
    print(f"  Reporting blocks   : {len(analysis.reporting_blocks)}")
    print(f"  Summary            : {analysis.logic_summary[:150]}...")

    log_step("analyzer_output", analysis)
    log_step("ingestion_blocks", ingestion_blocks, is_pydantic=False)

    return {
        "sas_code_clean":   clean_code,
        "ingestion_blocks": ingestion_blocks,
        "analysis":         analysis,
        "status":           "analyzed",
    }
