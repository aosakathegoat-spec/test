#!/usr/bin/env python3
"""
Adopt Me House Builder - Powered by Claude AI
Helps players design and plan houses for the Roblox game Adopt Me.
"""

import os
import anthropic

SYSTEM_PROMPT = """You are an expert Adopt Me house designer for the Roblox game Adopt Me.
You have deep knowledge of:
- Adopt Me's building mechanics, including plot sizes (Starter, Small, Medium, Large, Huge, Massive)
- All available furniture, decorations, and building items in the game
- In-game currency (Bucks) and approximate item costs
- Room layout best practices for different house styles (modern, cozy, fantasy, tropical, aesthetic, etc.)
- Popular design trends among Adopt Me players
- How to maximize space efficiency on different plot sizes
- Color schemes and aesthetic combinations that work well together
- Functional areas: nurseries for pets, trading rooms, living spaces, themed rooms, roleplay areas

When a player describes their dream house, you provide:
1. A detailed room-by-room layout plan with specific placement guidance
2. Specific furniture and decoration recommendations
3. Approximate Bucks cost estimates for the overall build
4. Step-by-step building instructions in logical order
5. Color palette and aesthetic suggestions
6. Tips for making the house look professional and impressive to other players
7. Budget-friendly alternatives when items are expensive

Always be encouraging, specific, and practical. Use clear section headers and bullet points
so the player can easily follow along while building. Reference actual Adopt Me mechanics
and items. Keep advice grounded in what's actually possible within the game."""


def print_welcome() -> None:
    print()
    print("=" * 60)
    print("  🏠  ADOPT ME HOUSE BUILDER — Powered by Claude AI  🏠")
    print("=" * 60)
    print()
    print("Welcome! I'll help you design your perfect Adopt Me house.")
    print("Describe what you want and I'll give you a full building")
    print("plan: room layouts, furniture picks, budget estimates, and")
    print("step-by-step instructions.")
    print()
    print("Commands:  'new'  → start a fresh design")
    print("           'quit' → exit")
    print("=" * 60)
    print()


def print_separator() -> None:
    print()
    print("-" * 60)
    print()


def get_initial_input() -> str:
    print("To get started, describe your dream house. You can mention:")
    print("  • Style  (modern, cozy, fantasy, tropical, aesthetic …)")
    print("  • Plot size you have (Starter / Small / Medium / Large /")
    print("    Huge / Massive)")
    print("  • Bucks budget")
    print("  • Must-have rooms or features")
    print("  • Favourite colours or themes")
    print()
    return input("Your house idea: ").strip()


def display_response(text: str, usage: anthropic.types.Usage, turn: int) -> None:
    print()
    print("=" * 60)
    print(text)
    print("=" * 60)

    # Show caching feedback
    cache_create = getattr(usage, "cache_creation_input_tokens", 0) or 0
    cache_read = getattr(usage, "cache_read_input_tokens", 0) or 0

    if turn == 1 and cache_create:
        print(f"\n💾 System prompt cached for this session ({cache_create} tokens written).")
    elif cache_read:
        print(f"\n⚡ Prompt cache hit — {cache_read} tokens served from cache.")
    print()


def run_conversation(client: anthropic.Anthropic) -> None:
    """Run one house-design conversation until the user starts over or quits."""
    messages: list[anthropic.types.MessageParam] = []

    user_input = get_initial_input()
    if not user_input or user_input.lower() in ("quit", "exit"):
        return None  # signal to quit

    if user_input.lower() == "new":
        return "new"  # restart

    print("\n⏳ Designing your house…\n")
    turn = 0

    while True:
        turn += 1
        messages.append({"role": "user", "content": user_input})

        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=4096,
            system=[
                {
                    "type": "text",
                    "text": SYSTEM_PROMPT,
                    # Cache the system prompt — it's identical on every turn
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=messages,
        )

        assistant_text = next(
            (block.text for block in response.content if block.type == "text"),
            "",
        )
        messages.append({"role": "assistant", "content": assistant_text})

        display_response(assistant_text, response.usage, turn)

        print("What would you like to know next?")
        print("Ask for more detail, adjustments, specific rooms, budget tips, etc.")
        print("Or type 'new' to design a different house, 'quit' to exit.")
        print()

        user_input = input("Follow-up question: ").strip()

        if not user_input or user_input.lower() in ("quit", "exit"):
            return None  # signal to quit

        if user_input.lower() == "new":
            return "new"  # restart

        print_separator()
        print("⏳ Updating your design…")


def main() -> None:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable is not set.")
        print("Set it with:  export ANTHROPIC_API_KEY='your-key-here'")
        return

    client = anthropic.Anthropic(api_key=api_key)

    print_welcome()

    while True:
        result = run_conversation(client)

        if result is None:
            print("\nGoodbye! Happy building in Adopt Me! 🏠✨")
            break

        # result == "new" — loop back and start fresh
        print()
        print("=" * 60)
        print("  Starting a new house design!")
        print("=" * 60)
        print()


if __name__ == "__main__":
    main()
