# GrowthTester Demo — Build Task Tracker

**Spec:** `docs/open-growthtester/growthtester-demo-spec.md`  
**Phase guide:** `docs/open-growthtester/growthtester-build-phases.md`  
**Status key:** `[ ]` todo · `[x]` done · `[-]` skipped/n/a

---

## Phase 1 — Foundation: Data Models, Environment, Factories

### Environment & Styling
- [x] Update `.env.example` with `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`
- [x] Update `app/assets/stylesheets/application.css` — accent color `#0891b2` / `#0e7490`
- [x] Add `.ice-total-column` and `.experiment-row--active` utility classes to CSS

### Migrations
- [x] Generate and write migration for `launch_contexts` table (uuid PK, all fields, indexes)
- [x] Generate and write migration for `growth_experiments` table (uuid PK, all fields, indexes)
- [ ] Run `rails db:migrate` — confirm schema matches spec

### Models
- [x] Create `app/models/launch_context.rb` — associations, `GROWTH_CHALLENGES` constant, validations
- [x] Create `app/models/growth_experiment.rb` — associations, `STATUSES`, `ICE_RANGE`, validations, `ice_total` method

### Factories
- [x] Create `spec/factories/launch_contexts.rb`
- [x] Create `spec/factories/growth_experiments.rb` (with `:active`, `:complete`, `:with_raw` traits)

### Model Specs
- [x] Write `spec/models/launch_context_spec.rb` — associations + all validations
- [x] Write `spec/models/growth_experiment_spec.rb` — associations + validations + `ice_total` behavior

### Phase 1 Gate
- [ ] `bundle exec rspec spec/models/launch_context_spec.rb spec/models/growth_experiment_spec.rb` — all pass
- [ ] Manual: `rails db:migrate` — no errors
- [ ] Manual: `LaunchContext.new.valid?` → false; `GrowthExperiment.new.valid?` → false
- [ ] Manual: `GrowthExperiment.new(impact: 4, confidence: 3, effort: 2).ice_total` → `9`

---

## Phase 2 — Routes, Navbar, and AI Template Seed

### Routes
- [x] Add `resources :launch_contexts, only: [:index, :new, :create, :show, :destroy]` to `config/routes.rb`
- [x] Add `resources :growth_experiments, only: []` with `member { patch :update_status }` to `config/routes.rb`

### Navbar
- [x] Add "My Backlogs" nav link pointing to `launch_contexts_path` in `app/views/layouts/application.html.erb`

### Seeds — AI Template
- [x] Remove `demo_placeholder_v1` from `db/seeds.rb`
- [x] Add `growthtester_backlog_v1` seed with full system prompt, user prompt template, model `gemini-2.5-flash`, `max_output_tokens: 3000`, `temperature: 0.6`, notes

### Seeds — Sample Domain Data
- [x] Add demo user reference (`User.find_by!(email: "demo@example.com")`)
- [x] Seed LaunchContext 1 — "ShipFast CLI" (awareness) with 8 sample GrowthExperiment records; first experiment has `gemini_raw` JSON
- [x] Seed LaunchContext 2 — "MeetingCost.io" (referral) with 9 sample GrowthExperiment records; first experiment has `gemini_raw` JSON
- [x] Both seeds are idempotent (`find_or_create_by!` keyed on `product_name` + `user`)

### Phase 2 Gate
- [ ] `rails db:seed` — no errors, all `puts` lines print
- [ ] `rails routes | grep launch` — 5 routes present
- [ ] `rails routes | grep growth_experiment` — `update_status` route present
- [ ] Manual: sign in → "My Backlogs" in navbar
- [ ] Manual: `/admin/ai_templates` → `growthtester_backlog_v1` listed; variables auto-detected in test panel

---

## Phase 3 — Controllers and Turbo Stream

### LaunchContextsController
- [x] Create `app/controllers/launch_contexts_controller.rb`
  - [x] `index` action — scoped to `current_user`, ordered by `created_at: :desc`
  - [x] `new` action — builds empty `LaunchContext`
  - [x] `create` action — saves record, calls `GeminiService.generate`, parses JSON, bulk-creates experiments, stores `gemini_raw` on first, redirects to show
  - [x] `create` rescue `JSON::ParserError` — destroys context, renders new with flash
  - [x] `create` rescue all four `GeminiService` error types — destroys context, renders `shared/ai_error`
  - [x] `show` action — scoped find, eager-loads experiments, applies sort from query params
  - [x] `destroy` action — scoped find, destroys, redirects to index
  - [x] `launch_context_params` strong params
  - [x] Rate limit: 10 requests/minute on `create`

### GrowthExperimentsController
- [x] Create `app/controllers/growth_experiments_controller.rb`
  - [x] `update_status` action — scoped find, validates status inclusion, updates, renders Turbo Stream

### Turbo Stream View
- [x] Create `app/views/growth_experiments/update_status.turbo_stream.erb` — `turbo_stream.update` targeting `dom_id(@experiment, :status_cell)`
- [x] Create `app/views/growth_experiments/_status_dropdown.html.erb` — Bootstrap dropdown with form posts to `update_status_growth_experiment_path`

### Phase 3 Gate
- [ ] `bundle exec rspec spec/requests/launch_contexts_spec.rb spec/requests/growth_experiments_spec.rb` — all pass
- [ ] Manual: `POST /launch_contexts` with valid form → `LaunchContext.count` increases, `GrowthExperiment.count` shows 8-10

---

## Phase 4 — Views, Partials, and Stimulus Controllers

### Stimulus Controllers
- [x] Create `app/javascript/controllers/character_count_controller.js` — live count for description textarea
- [x] Create `app/javascript/controllers/challenge_toggle_controller.js` — exclusive button selection, syncs hidden input; handles form re-render re-selection
- [x] Create `app/javascript/controllers/row_expand_controller.js` — toggles full/preview hypothesis text on row click

### Shared Partials
- [x] Create `app/views/shared/_ice_badge.html.erb` — colored badge for scores 1-5
- [x] Create `app/views/shared/_growth_challenge_badge.html.erb` — colored badge per challenge (awareness/conversion/retention/referral)

### Launch Context Views
- [x] Create `app/views/launch_contexts/new.html.erb`
  - [x] `product_name` text input
  - [x] `description` textarea with `character-count` Stimulus controller and 1000-char counter
  - [x] `target_audience` text input
  - [x] Growth challenge toggle: hidden input + 4-button `btn-group` with `challenge-toggle` Stimulus controller
  - [x] Submit button with accent color
  - [x] "5-10 second" explainer note below form
- [x] Create `app/views/launch_contexts/show.html.erb`
  - [x] Header: product name, target audience, growth challenge badge, "New Backlog" button
  - [x] AI disclaimer line above table
  - [x] Sortable `.table .table-hover .table-dark` with ICE badge cells
  - [x] Each `<tr>` has `data-controller="row-expand"` and `.experiment-row--active` class when status is active
  - [x] Status cell `<td id="<%= dom_id(exp, :status_cell) %>">` with status dropdown partial
  - [x] ICE Total column header styled with `.ice-total-column`
  - [x] Sort links with correct `?sort=&dir=` query params
  - [x] Bootstrap collapse "Show raw Gemini response" section at bottom
- [x] Create `app/views/launch_contexts/index.html.erb`
  - [x] Table: product name (link), challenge badge, experiment count, created date, delete button
  - [x] Empty state card when no contexts exist

### Home and Dashboard
- [x] Replace `app/views/home/index.html.erb` with GrowthTester landing page
  - [x] Two-column hero (pitch + static ICE table mockup)
  - [x] Three-step how-it-works list
  - [x] "Generate My Backlog" CTA → `new_launch_context_path` (only shows if user signed in, otherwise sign up)
  - [x] Four growth challenge description cards below hero
  - [x] All text using `ENV.fetch(...)` for app name/tagline
- [x] Replace `app/views/dashboard/show.html.erb`
  - [x] Empty state: centered CTA card
  - [x] Populated state: most recent context card + past 5 backlogs list + "New Backlog" button

### Phase 4 Gate
- [ ] Manual: Visit `/` — landing page renders correctly with hero and challenge section
- [ ] Manual: Sign in → dashboard shows seeded backlogs
- [ ] Manual: Fill and submit form → experiments table renders with ICE badge colors
- [ ] Manual: Click column header → table re-sorts
- [ ] Manual: Click table row → hypothesis expands/collapses
- [ ] Manual: Change experiment status → only status cell updates (Turbo Stream, no full reload)
- [ ] Manual: "Show raw Gemini response" collapse toggles correctly
- [ ] Manual: Delete backlog → redirect to index, backlog removed

---

## Phase 5 — RSpec Test Suite

### New Factories (if not already written in Phase 1)
- [ ] Confirm `spec/factories/launch_contexts.rb` is complete
- [ ] Confirm `spec/factories/growth_experiments.rb` is complete with all traits

### Request Specs
- [x] Write `spec/requests/launch_contexts_spec.rb`
  - [x] `GET /launch_contexts/new` — 200 for authenticated user
  - [x] `GET /launch_contexts/new` — redirect to sign in for unauthenticated user
  - [x] `POST /launch_contexts` valid + `gemini_returns(json)` — creates context + 8 experiments + redirects
  - [x] `POST /launch_contexts` valid — creates an `LlmRequest` record
  - [x] `POST /launch_contexts` + `gemini_raises(GeminiError)` — destroys context, no experiments, renders new
  - [x] `POST /launch_contexts` + `JSON::ParserError` simulation — destroys context, flash error
  - [x] `GET /launch_contexts/:id` — 200 for owner
  - [x] `GET /launch_contexts/:id` — 404 for different authenticated user
  - [x] `DELETE /launch_contexts/:id` — destroys context + experiments, redirects to index
- [x] Write `spec/requests/growth_experiments_spec.rb`
  - [x] `PATCH update_status` valid status `"active"` — updates status, returns Turbo Stream content type
  - [x] `PATCH update_status` invalid status — record unchanged (stays `"idea"`)
  - [x] `PATCH update_status` — 404 for different user's experiment
  - [x] `PATCH update_status` — redirect to sign in for unauthenticated user

### Phase 5 Gate
- [ ] `bundle exec rspec` — full suite passes, 0 failures
- [ ] Confirm 0 real Gemini API calls in output

---

## Phase 6 — README, Final Polish, QA Pass

### README
- [ ] Update `README.md` — app name, tagline, description, screenshot placeholder
- [ ] Add "Why I Built This" section
- [ ] Add "Editing the AI Prompt" section
- [ ] Add "No Additional Setup Steps" note
- [ ] Confirm seeded credentials (`demo@example.com` / `password123`) are documented

### ENV Audit
- [ ] Run `grep -r "GrowthTester" app/views/ --include="*.erb"` — all hits must be inside `ENV.fetch(...)` or comments
- [ ] Verify `.env.example` has all three app vars with correct values (no `GEMINI_API_KEY` value)

### Admin Template Validation
- [ ] Test `growthtester_backlog_v1` in admin panel with ShipFast CLI sample inputs
- [ ] Verify response is valid JSON with 8-10 experiments
- [ ] Verify LlmRequest logged in `/admin/llm_requests`

### Final QA Walkthrough
- [ ] `rails db:drop db:create db:migrate db:seed` — clean slate, no errors
- [ ] Visit `/` — landing correct, APP_NAME from ENV
- [ ] Sign in as `demo@example.com` / `password123`
- [ ] Dashboard shows two seeded backlogs
- [ ] "ShipFast CLI" backlog — 8 experiments, ICE scores, channel badges
- [ ] Sort ICE Total ascending/descending — correct order
- [ ] Change experiment status to "active" — accent border on row, Turbo Stream cell-only update
- [ ] Generate a new backlog with real inputs — real Gemini call succeeds, experiments created
- [ ] Delete new backlog — redirects to index, count drops
- [ ] `/admin/llm_requests` — all Gemini calls logged
- [ ] `bundle exec rspec` — all green

---

*tasks.md — GrowthTester Demo build tracker. Update checkboxes as you complete each item.*
