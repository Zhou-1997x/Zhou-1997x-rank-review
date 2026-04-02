"""
Random Joke Generator
Fetches a random joke from the JokeAPI (https://v2.jokeapi.dev/).

Usage:
    python joke_generator.py
    python joke_generator.py --category Programming
    python joke_generator.py --category Any --count 3

Categories: Any, Misc, Programming, Dark, Pun, Spooky, Christmas
"""

import argparse
import sys

try:
    import requests
except ImportError:
    print("Error: 'requests' library not found. Install it with: pip install requests")
    sys.exit(1)

API_BASE_URL = "https://v2.jokeapi.dev/joke"
DEFAULT_CATEGORY = "Any"
SAFE_FLAGS = "?blacklistFlags=nsfw,racist,sexist,explicit"


def fetch_joke(category: str = DEFAULT_CATEGORY) -> dict:
    """Fetch a single joke from the JokeAPI."""
    url = f"{API_BASE_URL}/{category}{SAFE_FLAGS}"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
    if data.get("error"):
        raise ValueError(f"API error: {data.get('message', 'Unknown error')}")
    return data


def format_joke(joke: dict) -> str:
    """Format a joke dict into a printable string."""
    joke_type = joke.get("type")
    if joke_type == "single":
        return joke.get("joke", "")
    elif joke_type == "twopart":
        setup = joke.get("setup", "")
        delivery = joke.get("delivery", "")
        return f"{setup}\n  → {delivery}"
    return "Could not parse joke format."


def main():
    parser = argparse.ArgumentParser(description="Fetch random jokes from the JokeAPI.")
    parser.add_argument(
        "--category",
        default=DEFAULT_CATEGORY,
        help="Joke category (default: Any). Options: Any, Misc, Programming, Dark, Pun, Spooky, Christmas",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=1,
        help="Number of jokes to fetch (default: 1)",
    )
    args = parser.parse_args()

    MAX_COUNT = 20
    if args.count < 1 or args.count > MAX_COUNT:
        print(f"Error: --count must be between 1 and {MAX_COUNT}.")
        sys.exit(1)

    failures = 0
    for i in range(args.count):
        try:
            joke = fetch_joke(args.category)
            print(f"Joke {i + 1}:" if args.count > 1 else "Here's your joke:")
            print(format_joke(joke))
            if i < args.count - 1:
                print()
        except requests.exceptions.ConnectionError:
            print(f"Error (joke {i + 1}): Could not connect to the JokeAPI. Check your internet connection.")
            failures += 1
        except requests.exceptions.Timeout:
            print(f"Error (joke {i + 1}): Request timed out. Skipping.")
            failures += 1
        except requests.exceptions.HTTPError as e:
            print(f"Error (joke {i + 1}): HTTP {e.response.status_code} from JokeAPI. Skipping.")
            failures += 1
        except ValueError as e:
            print(f"Error (joke {i + 1}): {e}. Skipping.")
            failures += 1

    if failures == args.count:
        sys.exit(1)


if __name__ == "__main__":
    main()
