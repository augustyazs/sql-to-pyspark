from langgraph.graph import StateGraph, END
from pathlib import Path
from state.graph_state import GraphState
from agents.analyzer import analyzer_node
from agents.resolver import resolver_node
from agents.architect import architect_plan_node
from agents.generator import generator_node
from agents.reviewer import reviewer_node
from agents.fixer import fixer_node
from agents.documenter import documenter_node
from graph.conditions import after_analyzer, after_resolver, after_reviewer_fixer
from utils.dbt_writer import write_dbt_project
from config.settings import OUTPUTS_DIR


def write_output_node(state: GraphState) -> dict:
    """Write final generated output to disk."""
    print("\n[WRITE] Writing generated output to disk...")
    project = state["dbt_project"]
    if project.notebook_cells and not project.notebook_name:
        source_name = state.get("source_name", "generated_procedure.sql")
        project.notebook_name = f"{Path(source_name).stem}.ipynb"
    written = write_dbt_project(project, OUTPUTS_DIR)
    for f in written:
        print(f"  [OK] {f}")
    return {"status": "done"}


def halt_node(state: GraphState) -> dict:
    """Halt pipeline with error details."""
    print("\n[HALT] Pipeline stopped.")
    print(f"  Status : {state.get('status')}")
    print(f"  Error  : {state.get('error', 'See resolver/analyzer output for details')}")
    if state.get("resolved_mappings"):
        rm = state["resolved_mappings"]
        if rm.unresolved_tables:
            print(f"  Unresolved tables: {rm.unresolved_tables}")
    return {"status": "halted"}


def build_graph() -> StateGraph:
    """Construct the LangGraph state machine.

    Flow:
        Analyzer → Resolver → Architect → Generator
        → Reviewer → Fixer (loop) → Write Output
        → Documenter → END
    """
    graph = StateGraph(GraphState)

    graph.add_node("analyzer",     analyzer_node)
    graph.add_node("resolver",     resolver_node)
    graph.add_node("architect",    architect_plan_node)
    graph.add_node("generator",    generator_node)
    graph.add_node("reviewer",     reviewer_node)
    graph.add_node("fixer",        fixer_node)
    graph.add_node("write_output", write_output_node)
    graph.add_node("documenter",   documenter_node)
    graph.add_node("halt",         halt_node)

    graph.set_entry_point("analyzer")

    graph.add_conditional_edges("analyzer", after_analyzer, {
        "resolver": "resolver",
        "halt":     "halt",
    })

    graph.add_conditional_edges("resolver", after_resolver, {
        "architect": "architect",
        "halt":      "halt",
    })

    graph.add_edge("architect", "generator")
    graph.add_edge("generator", "reviewer")

    # Reviewer → Fixer → Reviewer loop, or exit to write_output
    graph.add_conditional_edges("reviewer", after_reviewer_fixer, {
        "fixer":        "fixer",
        "write_output": "write_output",
    })
    graph.add_edge("fixer", "reviewer")

    # After writing outputs, run documentation agent
    graph.add_edge("write_output", "documenter")
    graph.add_edge("documenter", END)

    graph.add_edge("halt", END)

    return graph.compile()