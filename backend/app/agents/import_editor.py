"""Import command parser — turns a coach's natural-language (or voice) command
into structured edit actions on the import-review table.

Examples it handles:
  "Change Wang Wu's jersey number to 15"  -> edit
  "Merge Li Gang and 李刚"                 -> merge
  "Delete Zhao Liu"                        -> delete

The agent resolves spoken names to the numeric item_id / target ids from the
lists we pass in; the router then applies each action to the temporary session.
"""

from app.agents import build_agent
from app.schemas import CommandResult

SYSTEM_PROMPT = (
    "You convert a football coach's natural-language command into structured "
    "actions on a roster import review table. Allowed action `type` values:\n"
    "  - 'edit': change an item's name/number/preferred_position. Set only the "
    "fields that change.\n"
    "  - 'delete': remove an import item.\n"
    "  - 'merge': fold one import item into another import item "
    "(target_item_id) OR into an existing player (target_player_id).\n"
    "Always set `item_id` to the import item the command refers to, resolved "
    "from the IMPORT ITEMS list by name. For merges, prefer target_player_id "
    "when the other name is in the EXISTING PLAYERS list, otherwise "
    "target_item_id. Only produce actions the command clearly asks for. If a "
    "name is ambiguous or not found, produce no action for it and say so in "
    "`reply`. Put a short human confirmation in `reply`."
)


async def parse_command(
    text: str,
    items: list[dict],
    existing: list[dict],
) -> CommandResult:
    """Parse `text` into actions. `items` = current import items (id, name,
    number, preferred_position, classification); `existing` = existing players
    (id, name) usable as merge targets."""
    agent = build_agent("import_command", CommandResult, SYSTEM_PROMPT)
    item_lines = "\n".join(
        f"  item_id={it['id']}: {it['name']}"
        + (f" #{it['number']}" if it.get("number") is not None else "")
        + (f" [{it['preferred_position']}]" if it.get("preferred_position") else "")
        for it in items
    ) or "  (none)"
    existing_lines = "\n".join(
        f"  player_id={e['id']}: {e['name']}" for e in existing
    ) or "  (none)"
    prompt = (
        f"Coach command: {text!r}\n\n"
        "IMPORT ITEMS (the review table):\n"
        f"{item_lines}\n\n"
        "EXISTING PLAYERS (already in the database, valid merge targets):\n"
        f"{existing_lines}\n\n"
        "Produce the structured actions."
    )
    result = await agent.run(prompt)
    return result.output
