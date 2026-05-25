---
name: agent-communication
description: >-
  Guides agent chat style and human-facing prose for this workspace — tiers,
  colleague prose, README/command intros, per communication.mdc.
---

# Agent communication playbook

## Relationship to the rule

[`.cursor/rules/communication.mdc`](../../rules/communication.mdc) sets mandatory **human-facing prose** (README, command intros) and **agent chat** defaults. This skill adds checklists and examples. **If they conflict, the rule wins.**

## Tier decision tree

1. User shared context only — no question, no task? → **Ack**
2. User asked a question, no implementation in progress? → **Answer**
3. You are editing files, running commands, or debugging? → **Work**
4. User asked for audit, plan, report, teaching, or "explain in detail"? → **Deep**
5. Ambiguous on a **question** (no Action yet)? → **Answer** tier; use **Blocking** / **Questions** / **Context** from `communication.mdc` — ask as many numbered questions as needed.

6. Ambiguous and you would **edit files**? → Follow [`intent.mdc`](../../rules/intent.mdc): confidence **low** = no writes until user answers; **medium** = prefer Questions first.

When tier is unclear, prefer the **lower** tier (shorter). On Action turns, **intent.mdc** wins over this tree for clarify volume and write gates.

Editing **README** or a command **operator intro** during Work still requires **human-facing prose** (purpose in sentence 1).

## Human file checklist

Before saving `README.md` or the top of a `.cursor/commands/*.md` file:

- [ ] First sentence = why/when to use (not hooks, tiers, or inject paths)
- [ ] 60-second test: reader knows whether to use this and what to type next
- [ ] No harness inventory unless user said `more detail` or `use paths`
- [ ] Slash literals OK (`/onboarding`); repo paths only when needed for action

## Colleague prose checklist (chat)

Before sending chat output, verify:

- [ ] Subject named in this message (3–8 words), not only "it" / "above" / "that issue"
- [ ] First sentence = verdict or direct answer (given–new: known first, new after)
- [ ] User's vocabulary reused; jargon only if user used it or precision requires one new term
- [ ] Paths replaced with human labels unless user said `use paths` or disambiguation needs a path
- [ ] Bullets pass homogeneity test (same *kind* of item per list); causal "why" stays prose
- [ ] Ack/Answer under ~150 words and free of headings, tables, decorative bold

## Overrides

| User phrase | What to do |
|-------------|------------|
| `more detail` | Bump tier or add mechanism; human surfaces may add harness detail |
| `formal report` | Deep tier; headings and structure allowed in chat if the reply *is* the report |
| `use paths` | Include full paths where they help action |
| `terse` | Drop optional context; shortest correct answer |

## Chat vs file output

- **Chat**: Follow tiers and colleague prose even while working.
- **Human surfaces** (`README.md`, command operator intros): Always human-facing prose in the rule — not optional structure.
- **Agent/schema files** (`AGENTS.md`, tiers, skills, rules): Structured OK; plain lead sentence if a human might skim.

## Examples

For user stub → bad → good pairs, see [examples.md](examples.md).
