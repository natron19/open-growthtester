# GrowthTester Demo - Product Requirements Document

**Document Version:** 1.0
**Last Updated:** May 1, 2026
**Built on:** Open Demo Starter v2.0
**License:** MIT

---

## 1. App Overview

GrowthTester Demo is a single-purpose Rails 8 app that turns a plain-English product description into a prioritized growth experiment backlog in seconds. The user describes their product, names their target audience, and picks their biggest growth challenge (awareness, conversion, retention, or referral). Gemini returns a scored backlog of 8 to 10 growth experiments, each with a hypothesis, a recommended channel, an ICE score (Impact, Confidence, Effort on a 1-to-5 scale), and a one-sentence execution note. The user can save the backlog, sort the table by any ICE column or total, and track each experiment through idea, active, and complete states.

The problem this solves: most indie builders know they need to run growth experiments but do not know where to start or how to sequence them. A structured ICE-scored backlog removes the blank-page problem and gives every builder a defensible first list to work from.

This demo isolates the backlog-generation feature from GrowthTester, a larger multi-tenant SaaS platform where teams track experiments, assign owners, record results, and analyze which channels produce the highest lift. The full platform adds team workspaces, shared backlogs, experiment result logging, and statistical significance tracking. This demo shows the single most valuable thing a solo builder can do in that tool: generate a credible starting backlog for any product in under a minute.

The demo is open source under the MIT license, scoped to a single signed-in user, and runs on localhost. There is no production deployment, no Stripe billing, and no team functionality. Visitors can clone the repo, add a Gemini API key, run `bin/setup`, and have a working local demo in under 10 minutes.

---

## 2. Customizations Applied to the Boilerplate

- **App name:** `GrowthTester Demo` set via `APP_NAME` in `.env.example`
- **Tagline:** `Describe your product launch. Get a prioritized growth experiment backlog.` set via `APP_TAGLINE`
- **Description:** `Enter your product, audience, and biggest growth challenge. Get a scored, sortable backlog of 8-10 actionable growth experiments in seconds.` set via `APP_DESCRIPTION`
- **Accent color:** `#0891b2` (teal) with hover `#0e7490` set in `app/assets/stylesheets/_accent.scss` via `--accent` and `--accent-hover` custom properties
- **Navbar links:** "My Backlogs" link added to the authenticated nav, pointing to `launch_contexts_path`
- **Home page:** `home/index.html.erb` replaced with the GrowthTester landing pitch (see Section 6)
- **Dashboard:** `dashboard/show.html.erb` replaced with a summary of the user's most recent launch context and a prompt to create a new one if none exist
- **UX pattern:** Form-then-result with a sortable ICE-scored Bootstrap table. The form is on `launch_contexts/new.html.erb`; the result is on `launch_contexts/show.html.erb`
- **AI templates seeded:** `growthtester_backlog_v1` (see Section 7 for full content)

---

## 3. Data Model

### LaunchContext

Stores the user's product description and growth challenge inputs. One row per generation request. Each user can have multiple launch contexts.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; `belongs_to :user` |
| `product_name` | string | Required. **(template variable)** |
| `description` | text | Required, max 1000 chars. One paragraph describing the product. **(template variable)** |
| `target_audience` | string | Required, max 200 chars. Who the product is for. **(template variable)** |
| `growth_challenge` | string | Required. One of: `awareness`, `conversion`, `retention`, `referral`. **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:**
- `belongs_to :user`
- `has_many :growth_experiments, dependent: :destroy`

**Validations:**
- `product_name`: presence
- `description`: presence, maximum length 1000
- `target_audience`: presence, maximum length 200
- `growth_challenge`: presence, inclusion in `%w[awareness conversion retention referral]`

---

### GrowthExperiment

Stores one scored experiment from the Gemini-generated backlog. One `LaunchContext` produces 8 to 10 of these on creation.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `launch_context_id` | uuid | Foreign key |
| `user_id` | uuid | Foreign key; denormalized for simpler scoping |
| `name` | string | Experiment name (e.g., "Founder-led Twitter thread series") |
| `hypothesis` | text | If we do X, then Y will happen because Z |
| `channel` | string | e.g., "Content", "Paid Search", "Referral", "Email", "Community" |
| `impact` | integer | 1 to 5. How big is the potential upside? |
| `confidence` | integer | 1 to 5. How sure are we this will work? |
| `effort` | integer | 1 to 5. How much work is required? (higher = more effort) |
| `execution_note` | text | One-sentence practical starting point |
| `status` | string | Default `idea`. One of: `idea`, `active`, `complete` |
| `gemini_raw` | text | Full raw JSON response from Gemini for this backlog. Stored on the first experiment in the set; nil on subsequent experiments. **(Gemini output, used for Show raw response toggle)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:**
- `belongs_to :launch_context`
- `belongs_to :user`

**Validations:**
- `name`: presence
- `hypothesis`: presence
- `channel`: presence
- `impact`, `confidence`, `effort`: presence, numericality (integer, 1..5)
- `status`: presence, inclusion in `%w[idea active complete]`

**Computed attribute (not stored):**
- `ice_total`: `impact + confidence + (6 - effort)` -- effort is inverted so lower effort scores higher

**Note on `gemini_raw`:** The raw JSON response is stored once on the first `GrowthExperiment` record in the set. All other experiments in the same batch have `gemini_raw: nil`. The "Show raw response" toggle on `launch_contexts/show.html.erb` reads `gemini_raw` from the first experiment.

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/` | `home#index` | Public landing page |
| GET | `/dashboard` | `dashboard#show` | Authenticated home; shows recent backlog or create prompt |
| GET | `/launch_contexts` | `launch_contexts#index` | List all user's launch contexts |
| GET | `/launch_contexts/new` | `launch_contexts#new` | Brief input form |
| POST | `/launch_contexts` | `launch_contexts#create` | Submit form, call Gemini, parse and save experiments, redirect to show |
| GET | `/launch_contexts/:id` | `launch_contexts#show` | Show scored experiment table for one context |
| DELETE | `/launch_contexts/:id` | `launch_contexts#destroy` | Delete context and all its experiments |
| PATCH | `/growth_experiments/:id/status` | `growth_experiments#update_status` | Inline status toggle via Turbo Stream |

Auth routes (`/sign_up`, `/sign_in`, `/sign_out`, `/passwords/*`) and admin routes (`/admin/*`) come from the boilerplate.

---

## 5. Controllers and Actions

### `LaunchContextsController`

Inherits from `ApplicationController`. All queries scoped to `current_user`.

- **`index`:** Loads `current_user.launch_contexts.order(created_at: :desc)` and renders a list of past backlogs with experiment counts and creation dates. Each row links to `show`.

- **`new`:** Instantiates an empty `LaunchContext` and renders the brief input form.

- **`create`:** Validates the `LaunchContext` params and saves the record. Then calls `GeminiService.generate(template: "growthtester_backlog_v1", variables: { product_name:, description:, target_audience:, growth_challenge: })`. Parses the JSON response into individual `GrowthExperiment` records and saves them in bulk. Stores the raw Gemini response on the first experiment's `gemini_raw` field. Redirects to `show` on success. On `GeminiService::GeminiError`, destroys the partially saved `LaunchContext`, adds a flash alert, and re-renders `new` with the user's inputs intact.

- **`show`:** Loads the `LaunchContext` by id, scoped to `current_user`, and eager-loads its `growth_experiments`. Renders the sortable ICE table.

- **`destroy`:** Deletes the `LaunchContext` and its experiments (via `dependent: :destroy`). Redirects to `index` with a flash notice.

### `GrowthExperimentsController`

Inherits from `ApplicationController`. Minimal controller: only one action.

- **`update_status`:** Finds the `GrowthExperiment` by id, scoped to `current_user.growth_experiments`. Updates the `status` field to the submitted value. Responds with a Turbo Stream that updates the status badge cell for that row in-place.

---

## 6. Views

### `home/index.html.erb`

Replaces the boilerplate placeholder. Two-column Bootstrap hero: left column is a concise pitch ("Turn any product description into a growth experiment backlog in 30 seconds"), a three-step how-it-works list (Describe your product / Pick your growth challenge / Get a scored, sortable backlog), and a "Generate My Backlog" CTA button pointing to `new_launch_context_path`. Right column is a static screenshot or mockup of the ICE-scored table. Below the hero, a small section lists the four growth challenges (awareness, conversion, retention, referral) with one-line descriptions of what kinds of experiments to expect for each.

### `dashboard/show.html.erb`

If the user has no launch contexts: a centered card with the same CTA as the home page. If the user has launch contexts: shows the most recent `LaunchContext` card with its product name, growth challenge badge, experiment count, and a "View Backlog" link. Below that, a small "Past Backlogs" list (last 5, links to each `show`). A persistent "New Backlog" button styled in the accent color is pinned to the top right of the page.

### `launch_contexts/new.html.erb`

A clean single-column form card. Fields: product name (text input), description (textarea, max 1000 chars with a live character counter via a lightweight Stimulus controller), target audience (text input), and a growth challenge selector rendered as four Bootstrap toggle buttons (one per challenge, only one selectable at a time). A "Generate Backlog" submit button in the accent color. Below the form, a small explainer note: "Gemini will generate 8-10 scored experiments. This takes about 5-10 seconds."

**Stimulus behavior:** `CharacterCountController` updates a live count below the description textarea. `ChallengeToggleController` manages exclusive selection among the four challenge buttons and keeps a hidden `growth_challenge` input in sync.

### `launch_contexts/index.html.erb`

A Bootstrap table listing past launch contexts. Columns: product name (link to show), growth challenge badge, experiment count, created date, delete button. Empty state if no contexts exist yet.

### `launch_contexts/show.html.erb`

The main result page. Header section shows product name, target audience, growth challenge badge, and a "New Backlog" button.

Below the header: the sortable ICE experiment table. Columns: experiment name, hypothesis (truncated to one line, expands on row click), channel badge, Impact, Confidence, Effort, ICE Total (computed), and Status (toggle dropdown). The table header row has sortable column links for Impact, Confidence, Effort, and ICE Total (ascending and descending). Sorting is handled by query params passed back to `show` so the page re-renders with the sorted set.

Status column: a Bootstrap dropdown in each row showing `idea`, `active`, `complete`. Selecting a new status submits to `growth_experiments#update_status` via a Turbo Stream form, updating only the status cell of that row without a full page reload.

At the bottom of the page, a Bootstrap collapse section labeled "Show raw Gemini response." When expanded, it renders the `gemini_raw` text from the first experiment in a `<pre>` block. This is the required raw response toggle inherited from the boilerplate's UX expectations.

**Stimulus behavior:** `RowExpandController` toggles the full hypothesis text inline. No other custom JavaScript; sorting and status updates are Turbo-native.

### `growth_experiments/update_status.turbo_stream.erb`

A Turbo Stream response that targets the status cell `dom_id` for the updated experiment and replaces it with the new status dropdown partial. Uses `turbo_stream.update` (not `replace`) per the boilerplate's critical rule.

### `shared/_ice_badge.html.erb`

A small partial that renders a colored circle or pill for a 1-to-5 ICE score. Color scale: 1-2 in muted gray, 3 in yellow, 4-5 in the accent teal. Reused for Impact, Confidence, and Effort cells.

### `shared/_growth_challenge_badge.html.erb`

A Bootstrap badge showing the growth challenge label with a consistent color per challenge (awareness = blue, conversion = green, retention = orange, referral = purple). Reused in the index and show views.

---

## 7. AI Templates and Gemini Integration

### Template: `growthtester_backlog_v1`

**Description:** Generates a prioritized ICE-scored growth experiment backlog from a product brief.

**System prompt:**

```
You are a growth strategist with deep experience in B2B and consumer SaaS, e-commerce, and creator tools. You specialize in traction channels and growth experimentation frameworks. Your role is to produce actionable, specific growth experiments that a solo founder or small team can begin running within one to two weeks. You do not produce generic advice. Every experiment you output is grounded in a specific channel, a testable hypothesis, and a realistic execution path.

Always respond with valid JSON. No markdown fences. No prose outside the JSON object. The JSON must strictly follow the schema provided in the user message.
```

**User prompt template:**

```
Generate a growth experiment backlog for this product.

Product name: {{product_name}}
Product description: {{description}}
Target audience: {{target_audience}}
Biggest growth challenge: {{growth_challenge}}

Return a JSON object with this exact schema:

{
  "experiments": [
    {
      "name": "string - short, specific experiment name",
      "hypothesis": "string - If we [do X], then [Y metric] will [change] because [reason]",
      "channel": "string - one of: Content, SEO, Paid Search, Paid Social, Email, Community, Referral, Partnership, Product, Outbound, Event, PR",
      "impact": integer between 1 and 5,
      "confidence": integer between 1 and 5,
      "effort": integer between 1 and 5,
      "execution_note": "string - one sentence describing the first concrete step"
    }
  ]
}

Rules:
- Return exactly 8 to 10 experiments.
- Prioritize the {{growth_challenge}} channel category but include 2 to 3 experiments in adjacent channels.
- ICE scoring: impact is potential upside (5 = massive), confidence is how sure you are it will work for this specific product (5 = very sure), effort is how much work is required (5 = very high effort, which scores lower in ICE-total calculations).
- Hypotheses must name a specific metric (e.g., sign-up rate, trial-to-paid conversion, 30-day retention).
- Execution notes must start with a verb (e.g., "Write", "Set up", "Launch", "Partner with").
- Do not include experiments that require more than $500 in ad spend to validate.
- Do not return markdown. Return only the JSON object.
```

**Variables consumed:**
- `{{product_name}}` - from `LaunchContext#product_name`
- `{{description}}` - from `LaunchContext#description`
- `{{target_audience}}` - from `LaunchContext#target_audience`
- `{{growth_challenge}}` - from `LaunchContext#growth_challenge`

**Model:** `gemini-2.0-flash`. The default model is appropriate here; responses are structured JSON with no long reasoning chains required.

**max_output_tokens:** 3000. The default 2000 may truncate a full 10-experiment JSON object with longer hypotheses. 3000 provides comfortable headroom.

**temperature:** 0.6. Slightly below default. Growth experiments benefit from specificity and internal consistency across the ICE scores. A lower temperature reduces hallucinated scores (e.g., a high-impact, high-confidence experiment with no plausible rationale) without making outputs formulaic.

**Author's notes:** The most common failure mode is generic experiments ("Run Facebook ads," "Post on social media") that do not name a specific angle or audience segment. If you see these, tighten the system prompt by adding: "Every experiment must be specific enough that a founder could begin executing it tomorrow without further clarification." A second failure mode is inconsistent ICE scoring where every experiment receives the same scores; if this occurs, add a rule requiring variation: "No more than two experiments may share the same ICE total." The JSON schema rule in the user prompt (no markdown fences) is critical; Gemini frequently wraps JSON in ```json blocks by default. Monitor for this in the admin request log.

**Where it's called:** `LaunchContextsController#create`, immediately after the `LaunchContext` record is saved.

**Expected output format:** JSON object matching the schema above. The `experiments` array contains 8 to 10 objects.

**How the response is parsed:** The controller calls `JSON.parse(result)` on the Gemini response, then iterates over `parsed["experiments"]` and calls `GrowthExperiment.create!` for each, associating with both the `LaunchContext` and the `current_user`. The first experiment in the set receives the full raw response in `gemini_raw`. If `JSON.parse` fails, the controller rescues `JSON::ParserError`, destroys the `LaunchContext`, and renders a flash error asking the user to try again.

**Raw response storage:** `GrowthExperiment#gemini_raw` on the first record in the set.

---

## 8. AI Safety Considerations

### Content Sensitivity

Growth experimentation is a low-stakes domain. The outputs are marketing and product strategy suggestions, not medical advice, legal guidance, or financial recommendations. A user acting on a poorly scored experiment risks wasted time and a small amount of ad spend, not personal harm. This app sits in the same risk tier as course outline generators and social content tools.

### Consequential Outputs

The most realistic adverse outcome is a user running an experiment that wastes a week of their time or a few hundred dollars in ad spend on a low-quality Gemini suggestion. This risk is inherent to any advice tool and is bounded by the execution-note rule ("no experiments requiring more than $500 in ad spend to validate") embedded in the prompt. The ICE framework itself signals that scores are estimates, not guarantees.

### Domain Accuracy Requirements

ICE scores are inherently subjective and Gemini's estimates reflect patterns in training data, not market-specific knowledge. Users should treat scores as a starting point for discussion, not ground truth. A traction channel that scores 4 on confidence for one product category may score 2 for a different niche.

### App-Specific Disclaimers

The boilerplate's footer disclaimer ("AI-generated content can be incorrect. Verify before acting.") is sufficient for this domain. Additionally, the `launch_contexts/show.html.erb` view adds a one-line note directly above the experiment table: "ICE scores are AI estimates based on your description. Adjust them to match your knowledge of your specific market."

### Tightened Settings

No tightening required beyond lowering temperature to 0.6 (see Section 7). The default 50-call-per-day budget cap and 15-second timeout are appropriate for this use case.

### What This Demo Deliberately Does Not Do

- Does not validate that the product description is real or sensible. A user can generate a backlog for a nonsense product; the output will be correspondingly unreliable. This is acceptable for a local demo with no real users.
- Does not cross-reference experiment suggestions against external databases of experiment results or channel benchmarks. Each backlog is generated from Gemini's training data only, with no retrieval augmentation.
- Does not persist experiment results or success metrics. The status field (idea, active, complete) is a tracking convenience, not an analytics system. The full GrowthTester production app adds result logging and statistical significance tracking; this demo deliberately omits those features.
- Does not enforce uniqueness of experiments across multiple backlogs. A user generating multiple backlogs for the same product may receive overlapping suggestions. This is expected behavior.

---

## 9. RSpec Outline

### `spec/models/launch_context_spec.rb`

1. Validates presence of `product_name`, `description`, `target_audience`, and `growth_challenge`
2. Validates `description` maximum length of 1000 characters
3. Validates `growth_challenge` inclusion in the allowed set
4. `has_many :growth_experiments` association with `dependent: :destroy`
5. `belongs_to :user` association

### `spec/models/growth_experiment_spec.rb`

1. Validates presence of `name`, `hypothesis`, `channel`, `status`
2. Validates `impact`, `confidence`, and `effort` are integers between 1 and 5
3. Validates `status` inclusion in `%w[idea active complete]`
4. `ice_total` computed attribute returns `impact + confidence + (6 - effort)`
5. `belongs_to :launch_context` and `belongs_to :user`

### `spec/requests/launch_contexts_spec.rb`

1. `GET /launch_contexts/new` - renders the form for authenticated users; redirects to sign in for unauthenticated users
2. `POST /launch_contexts` with valid params - calls `GeminiService.generate` (stubbed), creates the `LaunchContext`, creates 8 to 10 `GrowthExperiment` records, and redirects to `show`
3. `POST /launch_contexts` with valid params - creates an `LlmRequest` record (verifies the boilerplate's logging runs)
4. `POST /launch_contexts` when `GeminiService` raises `GeminiError` - destroys the `LaunchContext`, does not create experiments, renders `new` with a flash error
5. `GET /launch_contexts/:id` - a signed-in user cannot access another user's `LaunchContext` (returns 404 or redirect)
6. `DELETE /launch_contexts/:id` - destroys the context and all associated experiments

### `spec/requests/growth_experiments_spec.rb`

1. `PATCH /growth_experiments/:id/status` with a valid status - updates the `status` field and returns a Turbo Stream response
2. `PATCH /growth_experiments/:id/status` with an invalid status - does not update the record, returns an error
3. A signed-in user cannot update another user's `GrowthExperiment` (returns 404 or redirect)

### `spec/services/launch_context_backlog_parser_spec.rb` (optional, if parsing logic is extracted to a service)

1. Parses a valid JSON Gemini response into an array of experiment attribute hashes
2. Returns an empty array (or raises) on invalid JSON
3. Filters out experiments missing required fields rather than crashing

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates the `growthtester_backlog_v1` template with the full values specified in Section 7: name, description, system_prompt, user_prompt_template, model (`gemini-2.0-flash`), max_output_tokens (3000), temperature (0.6), and notes. The seed is idempotent: `AiTemplate.find_or_create_by!(name: "growthtester_backlog_v1")`.

### Domain Seeds

Two sample `LaunchContext` records are created for the seeded demo user, each with a realistic set of pre-generated `GrowthExperiment` records so the app looks populated on first run.

**First context:** A developer tool for indie hackers.
- `product_name`: "ShipFast CLI"
- `description`: "A command-line tool that scaffolds opinionated Rails 8 SaaS boilerplates with authentication, billing, and AI integrations pre-wired. Reduces new project setup from a week to under an hour."
- `target_audience`: "Solo Rails developers building their first SaaS product"
- `growth_challenge`: "awareness"

Seeded with 8 experiments (representative of what Gemini would produce): founder-led Twitter/X thread series, a free tier of the CLI with usage-based upsell, a "Ship in public" YouTube series, a ProductHunt launch, a "Made with ShipFast" community showcase, partnerships with Rails podcasts, a Reddit AMA in r/rails, and SEO-targeted docs pages for "rails saas boilerplate" searches.

**Second context:** A B2B SaaS tool.
- `product_name`: "MeetingCost.io"
- `description`: "A browser extension that overlays a real-time dollar cost counter on Google Meet and Zoom calls, calculated from headcount and average salaries. Helps teams feel the cost of unnecessary meetings."
- `target_audience`: "Engineering managers and startup CTOs who want to reduce meeting overhead"
- `growth_challenge`: "referral"

Seeded with 9 experiments covering viral sharing mechanics, a "Share your meeting cost" social card, integration with Slack to post post-meeting cost summaries, partner promotions with remote-work newsletters, and an engineering-manager LinkedIn content series.

The `gemini_raw` field on the first experiment in each set contains a realistic sample JSON string. All other experiments have `gemini_raw: nil`.

---

## 11. README Additions

### App Name and Tagline

**GrowthTester Demo** - Describe your product launch. Get a prioritized growth experiment backlog.

### Description

GrowthTester Demo generates a scored, sortable growth experiment backlog from a plain-English product brief. Enter your product name, one paragraph of description, your target audience, and your biggest growth challenge (awareness, conversion, retention, or referral). Gemini returns 8 to 10 growth experiments in seconds, each with a hypothesis, a recommended channel, an ICE score (Impact, Confidence, Effort), and a one-sentence execution note. You can sort the table by any ICE column, and track each experiment from idea through active to complete.

### Screenshot

`[screenshot of the ICE-scored experiment table goes here]`

### Why I Built This

Every indie builder eventually hits the "I need to grow but I don't know what to try first" wall. The ICE framework is one of the best tools for cutting through that paralysis, but building and scoring a backlog from scratch takes hours you don't have.

This demo is the backlog-generation engine from GrowthTester, a structured growth testing platform I'm building for indie hackers and small product teams. The full version adds team workspaces, experiment result logging, and statistical significance tracking across channels. [Visit the full app here.](https://growthtester.com) (placeholder URL)

The code is MIT licensed. Clone it, swap in your Gemini API key, and use the admin panel at `/admin/ai_templates` to tune the prompt for your use case. The `growthtester_backlog_v1` template is the whole product; it took about 30 iterations to get the ICE scoring consistent and the hypotheses specific enough to be actionable. You can see the iteration notes in the template's `notes` field.

### Editing the AI Prompt

Sign in as `demo@example.com` / `password123` and visit `/admin/ai_templates`. Click into `growthtester_backlog_v1`. The right column of the editor lets you paste in sample variable values and click "Test" to see Gemini's response inline, without saving. Iterate until you like the results, then click "Save" to persist your changes. The seed file in `db/seeds.rb` has the shipped-version prompt; copy your final prompt back there before committing.

### No Additional Setup Steps

This demo requires only a `GEMINI_API_KEY` in `.env`. Run `bin/setup` and you're done. No Serper.dev key, no Stripe key, no background workers.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### UX Pattern

Form-then-result. The form (`new.html.erb`) is a focused single-column card that collects the brief. The result (`show.html.erb`) is a full-width sortable table that dominates the viewport. Navigation between them is linear: fill in the form, submit, land on the result. The index page provides a simple history list for returning to past backlogs.

### Accent Color Application

Accent teal (`#0891b2`, hover `#0e7490`) is applied consistently via `var(--accent)` to:
- Primary action buttons ("Generate Backlog", "New Backlog") using `.btn` with a custom `--accent` background
- Active nav link state for the "My Backlogs" link
- The ICE Total column header to signal that it is the primary sort dimension
- The `active` status badge in the experiment table (active = teal, idea = gray, complete = muted green)
- The four growth-challenge toggle buttons' selected state

The `_accent.scss` partial sets:
```css
:root {
  --accent: #0891b2;
  --accent-hover: #0e7490;
}
```

All buttons that use the accent color apply Bootstrap's `btn` class with an inline or utility override for `background-color: var(--accent); border-color: var(--accent);` and the hover state. No custom button component is introduced.

### Component Choices

- **Experiment table:** Bootstrap `.table .table-hover .table-dark` with `data-sortable` column headers rendered as anchor tags with query params. No JavaScript sort library; the controller re-queries with an `order` param on each column header click.
- **Status toggle:** Bootstrap `.dropdown` in each table row. The dropdown trigger shows the current status badge; the menu lists the other two options. Submitting changes a hidden form via Turbo Streams.
- **Growth challenge selector on the form:** Bootstrap `.btn-group` with four `.btn-outline-secondary` buttons. The `ChallengeToggleController` Stimulus controller toggles the active state and writes the selected value to a hidden `<input name="launch_context[growth_challenge]">`.
- **Raw response collapse:** Bootstrap `.collapse` triggered by a `.btn-link` labeled "Show raw Gemini response." No JavaScript beyond what Bootstrap provides.
- **ICE score cells:** The `_ice_badge.html.erb` partial renders a small `.badge` with a background color derived from the score value using inline Bootstrap utility classes (`bg-secondary` for 1-2, `bg-warning` for 3, `bg-info` or accent for 4-5). No custom SVG or charting.

### Custom CSS

Minimal custom CSS beyond what the boilerplate provides:
- `.ice-total-column` - bold font weight to visually distinguish the computed total from the individual scores
- `.experiment-row--active` - a subtle left border in the accent color on rows with `status: active`, applied via a helper method in the view

All other styling uses Bootstrap utilities. No custom card components, no custom modals, no flexbox gymnastics outside Bootstrap's grid.

---

*v1.0 - GrowthTester Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
