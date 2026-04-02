# Zhou-1997x-rank-review
for rank

## Random Joke Generator

Fetches a random joke from the [JokeAPI](https://v2.jokeapi.dev/).

### Setup

```bash
pip install -r requirements.txt
```

### Usage

```bash
# One random joke (any category)
python joke_generator.py

# Pick a category
python joke_generator.py --category Programming

# Fetch multiple jokes
python joke_generator.py --count 3

# Combine options
python joke_generator.py --category Pun --count 5
```

**Available categories:** `Any`, `Misc`, `Programming`, `Dark`, `Pun`, `Spooky`, `Christmas`
