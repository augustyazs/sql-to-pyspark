from state.graph_state import GraphState
from models.schemas import MigrationPlan
from tools.llm_client import call_llm
from config.prompts_oracle import ARCHITECT_SYSTEM, ARCHITECT_USER
from utils.logger import log_step


def architect_plan_node(state: GraphState) -> dict:
    """Plan notebook transformation stages based on analysis and mappings."""
    print("\n[ARCHITECT] Planning migration structure...")

    analysis    = state["analysis"]
    resolved    = state["resolved_mappings"]
    conventions = state["conventions"]

    user_prompt = ARCHITECT_USER.format(
        analysis_json=analysis.model_dump_json(indent=2),
        resolved_mappings_json=resolved.model_dump_json(indent=2),
        conventions_json=conventions.model_dump_json(indent=2),
    )

    result = call_llm(ARCHITECT_SYSTEM, user_prompt, step_name="architect_plan")
    result = _normalize_plan_result(result)
    plan   = MigrationPlan(**result)

    print(f"  Models planned : {len(plan.models)}")
    print(f"  Edge cases     : {len(plan.edge_cases)}")
    for ec in plan.edge_cases:
        print(f"    [WARN:{ec.risk}] {ec.pattern}")

    log_step("architect_plan", plan)
    return {"migration_plan": plan, "status": "planned"}


def _normalize_plan_result(result: dict) -> dict:
    """Coerce minor LLM schema drift into MigrationPlan-compatible payload."""
    if not isinstance(result, dict):
        return {"models": [], "edge_cases": [], "dependency_order": [], "notes": ["Architect response malformed."]}

    def _list(v):
        return v if isinstance(v, list) else []

    models = []
    for idx, m in enumerate(_list(result.get("models"))):
        if not isinstance(m, dict):
            continue
        logic = m.get("logic", "")
        if isinstance(logic, list):
            logic = " ".join(str(x) for x in logic if x is not None)
        name = m.get("name") or m.get("model_name") or f"stage_{idx + 1}"
        layer = m.get("layer") or "notebook_stage"
        materialization = m.get("materialization") or "table"
        sources = m.get("sources") if isinstance(m.get("sources"), list) else []
        depends_on = m.get("depends_on") if isinstance(m.get("depends_on"), list) else []
        join_keys = m.get("join_keys") if isinstance(m.get("join_keys"), list) else []
        models.append({
            "name": str(name),
            "layer": str(layer),
            "materialization": str(materialization),
            "sources": [str(x) for x in sources],
            "depends_on": [str(x) for x in depends_on],
            "logic": str(logic),
            "join_keys": [str(x) for x in join_keys],
        })

    edge_cases = []
    for ec in _list(result.get("edge_cases")):
        if not isinstance(ec, dict):
            continue
        edge_cases.append({
            "pattern": str(ec.get("pattern", "")),
            "recommendation": str(ec.get("recommendation", "")),
            "risk": str(ec.get("risk", "low")),
        })

    def _str_list(v):
        return [str(x) for x in v] if isinstance(v, list) else []

    return {
        "models": models,
        "edge_cases": edge_cases,
        "dependency_order": _str_list(result.get("dependency_order")),
        "notes": _str_list(result.get("notes")),
    }
