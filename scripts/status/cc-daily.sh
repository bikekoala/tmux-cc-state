#!/usr/bin/env bash
# Part of cc-state tmux plugin.
# Usage: cc-daily.sh token   → e.g. "50M"
#        cc-daily.sh cost    → e.g. "$4.50"

set -euo pipefail

MODE="${1:-token}"
DATE="$(date -u +%Y-%m-%d)"

# Collect all JSONL files from both log paths (including subagents)
LOG_DIRS=()
[[ -d "$HOME/.claude/projects" ]] && LOG_DIRS+=("$HOME/.claude/projects")
[[ -d "$HOME/.config/claude/projects" ]] && LOG_DIRS+=("$HOME/.config/claude/projects")

if [[ ${#LOG_DIRS[@]} -eq 0 ]]; then
  if [[ "$MODE" == "cost" ]]; then
    echo '$0.00'
  else
    echo "0"
  fi
  exit 0
fi

# Pre-filter with grep to avoid feeding all 200MB+ of logs into jq.
# Only scan files modified on or after the target date.
{ find "${LOG_DIRS[@]}" -name '*.jsonl' -newermt "$DATE" -exec grep -h "\"$DATE" {} + 2>/dev/null |
  grep '"assistant"' || true; } |
  jq -c "
  try (
    select(.type == \"assistant\" and (.timestamp | startswith(\"$DATE\")))
    | {
        dedup_key: ((.message.id // empty) + \":\" + (.requestId // empty)),
        model: (.message.model // \"unknown\"),
        input: (.message.usage.input_tokens // 0),
        output: (.message.usage.output_tokens // 0),
        cache_create: (.message.usage.cache_creation_input_tokens // 0),
        cache_read: (.message.usage.cache_read_input_tokens // 0)
      }
  )
" 2>/dev/null |
  jq -s --arg date "$DATE" --arg mode "$MODE" '
  unique_by(.dedup_key) |

  def price_for(model):
    if   (model | test("^claude-opus-4-[56]"))   then { input: 5,    output: 25, cache_write: 6.25,  cache_read: 0.50 }
    elif (model | startswith("claude-opus-4"))    then { input: 15,   output: 75, cache_write: 18.75, cache_read: 1.50 }
    elif (model | startswith("claude-sonnet-4"))  then { input: 3,    output: 15, cache_write: 3.75,  cache_read: 0.30 }
    elif (model | startswith("claude-haiku-4"))   then { input: 1,    output: 5,  cache_write: 1.25,  cache_read: 0.10 }
    else                                               { input: 0,    output: 0,  cache_write: 0,     cache_read: 0    }
    end;

  def human_tokens(n):
    if   n >= 1000000000 then ((n / 100000000 | round | . / 10) | tostring) + "B"
    elif n >= 1000000    then ((n / 100000    | round | . / 10) | tostring) + "M"
    elif n >= 1000       then ((n / 1000      | round)          | tostring) + "K"
    else                      (n | tostring)
    end;

  (map(.input)        | add // 0) as $input |
  (map(.output)       | add // 0) as $output |
  (map(.cache_create) | add // 0) as $cache_create |
  (map(.cache_read)   | add // 0) as $cache_read |
  ($input + $output + $cache_create + $cache_read) as $total |

  if $mode == "cost" then
    (group_by(.model) | map(
      .[0].model as $model |
      price_for($model) as $p |
      ((map(.input)        | add // 0) * $p.input +
       (map(.output)       | add // 0) * $p.output +
       (map(.cache_create) | add // 0) * $p.cache_write +
       (map(.cache_read)   | add // 0) * $p.cache_read) / 1000000
    ) | add // 0 | . * 100 | round | . / 100) as $cost |
    "$\($cost)"
  else
    human_tokens($total)
  end
' | tr -d '"'
