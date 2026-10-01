from state.graph_state import GraphState
from models.schemas import ReviewResult
from tools.llm_client import call_llm
from config.prompts_oracle import REVIEWER_SYSTEM, REVIEWER_USER
from utils.logger import log_step


def reviewer_node(state: GraphState) -> dict:
    """Review generated notebook output for logic parity and PySpark correctness."""
    review_count = state.get("review_count", 0) + 1
    print(f"\n[REVIEWER] Review attempt {review_count}...")

    project = state["dbt_project"]
    analysis = state["analysis"]
    resolved = state["resolved_mappings"]

    user_prompt = REVIEWER_USER.format(
        generated_files_json=project.model_dump_json(indent=2),
        analysis_json=analysis.model_dump_json(indent=2),
        resolved_mappings_json=resolved.model_dump_json(indent=2),
    )

    result = call_llm(REVIEWER_SYSTEM, user_prompt, step_name=f"reviewer_attempt{review_count}")
    result = _normalize_review_result(result)
    review = ReviewResult(**result)

    errors   = [i for i in review.issues if i.severity == "error"]
    warnings = [i for i in review.issues if i.severity == "warning"]

    print(f"  Valid   : {review.is_valid}")
    print(f"  Errors  : {len(errors)}, Warnings: {len(warnings)}")
    print(f"  Summary : {review.summary[:150]}")

    log_step(f"reviewer_attempt{review_count}", review)

    if not review.is_valid and errors:
        return {
            "review":       review,
            "review_count": review_count,
            "status":       "needs_fix",
        }

    status = "complete" if review.is_valid else "complete_with_warnings"
    return {"review": review, "review_count": review_count, "status": status}


def _normalize_review_result(result: dict) -> dict:
    """Accept minor schema drift from LLM and coerce to ReviewResult shape."""
    if not isinstance(result, dict):
        return {"is_valid": False, "issues": [{"file": "", "issue": "Reviewer returned invalid response type.", "severity": "error", "fix_suggestion": ""}], "summary": "Reviewer response was malformed."}

    if "is_valid" not in result:
        verdict = str(result.get("overall_verdict", "")).strip().lower()
        result["is_valid"] = verdict in {"pass", "passed", "valid", "true", "ok"}

    if "issues" not in result or not isinstance(result.get("issues"), list):
        result["issues"] = []

    normalized_issues = []
    for raw in result["issues"]:
        if isinstance(raw, str):
            normalized_issues.append({
                "file": "",
                "issue": raw,
                "severity": "warning",
                "fix_suggestion": "",
            })
            continue
        if not isinstance(raw, dict):
            continue
        normalized_issues.append({
            "file": str(raw.get("file", raw.get("cell", raw.get("path", "")))),
            "issue": str(raw.get("issue", raw.get("message", raw.get("finding", "Unspecified review issue")))),
            "severity": str(raw.get("severity", "warning")).lower(),
            "fix_suggestion": str(raw.get("fix_suggestion", raw.get("recommendation", ""))),
        })

    result["issues"] = normalized_issues
    if "summary" not in result:
        result["summary"] = str(result.get("review_summary", result.get("overall_summary", "Review completed.")))
    return result
