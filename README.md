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

## License

MIT — see [LICENSE](LICENSE)
