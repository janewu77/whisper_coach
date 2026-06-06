"""Shared PydanticAI configuration.

Agents are built lazily so importing a router does not require ANTHROPIC_API_KEY
(tests monkeypatch the agent functions and never construct a real agent).
In tests you can also do `agent.override(model=TestModel())`.
"""

from functools import cache

from pydantic_ai import Agent

from app.config import settings


@cache
def build_agent(name: str, output_type, system_prompt: str) -> Agent:
    """Construct (once) and cache an Agent for the configured model."""
    return Agent(
        settings.llm_model,
        output_type=output_type,
        system_prompt=system_prompt,
    )
