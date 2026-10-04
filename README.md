# GrowthTester Demo

> Describe your product launch. Get a prioritized growth experiment backlog.

Enter your product name, a one-paragraph description, your target audience, and your biggest growth challenge (awareness, conversion, retention, or referral). Gemini returns a scored backlog of 8–10 growth experiments, each with a hypothesis, a recommended channel, an ICE score, and a one-sentence execution note. Sort by any column, track experiments from idea to active to complete, and inspect the raw AI response.

Built on [Open Demo Starter](https://github.com/natron19/open-demo-starter) — a Rails 8 + Gemini boilerplate for single-purpose demo apps.

---

## Quick Start

```bash
git clone https://github.com/natron19/open-growthtester
cd open-growthtester
cp .env.example .env           # add your GEMINI_API_KEY
bin/setup                      # installs gems, creates and migrates the database, seeds demo data
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000) and sign in with:

| Email | Password |
|---|---|
| `demo@example.com` | `password123` |

The demo user has two pre-seeded backlogs (ShipFast CLI and MeetingCost.io) so you can explore the table and status features without generating anything first.

---

## Why I Built This

Most indie builders know they should run growth experiments. Almost none have a structured starting list. The blank-page problem — "where do I even begin?" — is real and common.

GrowthTester solves it in under a minute. You describe what you built and where you're stuck, and you get back a defensible, prioritized backlog you can actually start from. ICE scoring (Impact × Confidence ÷ Effort, computed as `impact + confidence + (6 - effort)`) gives each experiment a number so you're not just guessing what to try first.

This demo isolates the single most valuable feature from a larger multi-tenant platform: generating a credible first backlog for any product. It runs entirely on localhost with a free Gemini API key and has no external dependencies beyond PostgreSQL.

---

## Editing the AI Prompt

The prompt that generates the backlog is stored in the database as an `AiTemplate` record, not in code. You can edit it live without touching any files:

1. Sign in as `demo@example.com` / `password123`
2. Go to `/admin/ai_templates`
3. Find `growthtester_backlog_v1` and click Edit
4. Update the system prompt or user prompt template and save
5. Use the **Test** panel on the same page to run the prompt with sample inputs before going back to the main app

The template uses `{{variable_name}}` placeholders. The variables for this template are: `product_name`, `description`, `target_audience`, `growth_challenge`.

Common things worth tweaking:
- **Specificity:** Add "Every experiment must be specific enough that a founder could begin executing it tomorrow" to the system prompt to reduce generic suggestions
- **Experiment count:** Change "Return exactly 8 to 10 experiments" in the user prompt to get more or fewer results
- **ICE score spread:** Add "No more than two experiments may share the same ICE total" to force variation in scores

---

## No Additional Setup Steps

There is no Redis, no Sidekiq, no background job configuration, no file storage, no OAuth, and no external services beyond Gemini. The only thing you need is a `GEMINI_API_KEY` in `.env`.

Gemini calls are synchronous and happen inline during the `POST /launch_contexts` request. On a cold Gemini call this takes 5–10 seconds — normal for a generative AI response of this length.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"GrowthTester Demo"` | Displayed in the navbar and page title |
| `APP_TAGLINE` | — | Shown on the landing page and footer |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required) | Get one free at [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

---

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini (`gemini-2.5-flash`) via Faraday |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

---

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `growthtester_backlog_v1` must return valid JSON with `experiments`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 8 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Accurate:** The experiments target the stated growth challenge for this specific product and audience, not growth in general (the prompt allows only 2-3 in adjacent areas).
- **Useful:** Each experiment is concrete and testable. The hypothesis names a specific metric, and the execution note is a first step a founder could start tomorrow.
- **Steerable:** ICE scores are differentiated and plausible for this product (not all the same), and no experiment needs more than $500 in ad spend to validate.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (13/13 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## License

MIT — see [LICENSE](LICENSE)
