# GrowthTester Demo — Phased Build Specification

**Source spec:** `docs/open-growthtester/growthtester-demo-spec.md`  
**Boilerplate:** Open Demo Starter v2.0  
**Last updated:** 2026-05-04

This document breaks the demo spec into six sequential phases. Each phase is self-contained: it ends with a defined test gate before the next phase begins. Complete each gate before moving forward.

---

## Implementation Notes

### Model Override: Use `gemini-2.5-flash`, not `gemini-2.0-flash`

The demo spec (Section 7) specifies `gemini-2.0-flash`, but `docs/ai-templates.md` and `CLAUDE.md` explicitly prohibit it — it returns 404 on v1beta for new API keys. **Use `gemini-2.5-flash` in all seeds and references.** The reasoning (specificity-focused output, no long reasoning chains) still holds with 2.5-flash.

### Accent CSS Location

The demo spec references `_accent.scss`, but this boilerplate uses Propshaft with no SCSS compilation. Accent variables go in `app/assets/stylesheets/application.css` as `:root` custom properties, as specified in `CLAUDE.md`.

---

## Phase 1 — Foundation: Data Models, Environment, Factories

**Goal:** Schema exists, models validate correctly, factories work, ENV is set.

### 1.1 Environment

Update `.env.example`:
```
APP_NAME=GrowthTester Demo
APP_TAGLINE=Describe your product launch. Get a prioritized growth experiment backlog.
APP_DESCRIPTION=Enter your product, audience, and biggest growth challenge. Get a scored, sortable backlog of 8-10 actionable growth experiments in seconds.
```
Developer must copy to `.env` and fill in `GEMINI_API_KEY`.

### 1.2 Accent Color

In `app/assets/stylesheets/application.css`, update the `:root` block:
```css
:root {
  --accent: #0891b2;
  --accent-hover: #0e7490;
}
```
Add utility classes below `:root`:
```css
.ice-total-column { font-weight: 700; }
.experiment-row--active { border-left: 3px solid var(--accent); }
```

### 1.3 Migration — `launch_contexts`

```ruby
create_table :launch_contexts, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string  :product_name,     null: false
  t.text    :description,      null: false
  t.string  :target_audience,  null: false
  t.string  :growth_challenge, null: false
  t.timestamps null: false
end
add_index :launch_contexts, :user_id
add_index :launch_contexts, :created_at
```

### 1.4 Migration — `growth_experiments`

```ruby
create_table :growth_experiments, id: :uuid do |t|
  t.references :launch_context, null: false, foreign_key: true, type: :uuid
  t.references :user,           null: false, foreign_key: true, type: :uuid
  t.string  :name,           null: false
  t.text    :hypothesis,     null: false
  t.string  :channel,        null: false
  t.integer :impact,         null: false
  t.integer :confidence,     null: false
  t.integer :effort,         null: false
  t.text    :execution_note
  t.string  :status,         null: false, default: "idea"
  t.text    :gemini_raw
  t.timestamps null: false
end
add_index :growth_experiments, :launch_context_id
add_index :growth_experiments, :user_id
add_index :growth_experiments, :status
```

### 1.5 Model — `LaunchContext`

```ruby
# app/models/launch_context.rb
class LaunchContext < ApplicationRecord
  belongs_to :user
  has_many :growth_experiments, dependent: :destroy

  GROWTH_CHALLENGES = %w[awareness conversion retention referral].freeze

  validates :product_name,     presence: true
  validates :description,      presence: true, length: { maximum: 1000 }
  validates :target_audience,  presence: true, length: { maximum: 200 }
  validates :growth_challenge, presence: true, inclusion: { in: GROWTH_CHALLENGES }
end
```

### 1.6 Model — `GrowthExperiment`

```ruby
# app/models/growth_experiment.rb
class GrowthExperiment < ApplicationRecord
  belongs_to :launch_context
  belongs_to :user

  STATUSES  = %w[idea active complete].freeze
  ICE_RANGE = (1..5)

  validates :name,       presence: true
  validates :hypothesis, presence: true
  validates :channel,    presence: true
  validates :status,     presence: true, inclusion: { in: STATUSES }
  validates :impact,     presence: true, numericality: { only_integer: true, in: ICE_RANGE }
  validates :confidence, presence: true, numericality: { only_integer: true, in: ICE_RANGE }
  validates :effort,     presence: true, numericality: { only_integer: true, in: ICE_RANGE }

  def ice_total
    impact + confidence + (6 - effort)
  end
end
```

### 1.7 Factories

**`spec/factories/launch_contexts.rb`**
```ruby
FactoryBot.define do
  factory :launch_context do
    association :user
    product_name     { "TestProduct" }
    description      { "A test product description that is long enough to be realistic." }
    target_audience  { "Solo developers" }
    growth_challenge { "awareness" }
  end
end
```

**`spec/factories/growth_experiments.rb`**
```ruby
FactoryBot.define do
  factory :growth_experiment do
    association :launch_context
    association :user
    name           { "Founder-led Twitter thread series" }
    hypothesis     { "If we publish weekly threads, then sign-up rate will increase because founders trust founders." }
    channel        { "Content" }
    impact         { 4 }
    confidence     { 3 }
    effort         { 2 }
    execution_note { "Write the first thread about the problem your product solves." }
    status         { "idea" }
    gemini_raw     { nil }

    trait :active   { status { "active" } }
    trait :complete { status { "complete" } }
    trait :with_raw { gemini_raw { '{"experiments":[]}' } }
  end
end
```

### Phase 1 Test Gate

**RSpec:**
```bash
bundle exec rspec spec/models/launch_context_spec.rb spec/models/growth_experiment_spec.rb
```
All model specs must pass (see Phase 5 for spec content — write them now alongside the models).

**Manual:**
1. `rails db:migrate` — no errors
2. `rails console` — `LaunchContext.new.valid?` returns false; `GrowthExperiment.new.valid?` returns false
3. `LaunchContext::GROWTH_CHALLENGES` returns the four values
4. `GrowthExperiment.new(impact: 4, confidence: 3, effort: 2).ice_total` returns `9`

---

## Phase 2 — Routes, Navbar, and AI Template Seed

**Goal:** Routes registered, navbar updated, seeds idempotently create the AI template and sample data.

### 2.1 Routes

Add to `config/routes.rb` inside the draw block:
```ruby
resources :launch_contexts, only: [:index, :new, :create, :show, :destroy]

resources :growth_experiments, only: [] do
  member do
    patch :update_status
  end
end
```

Named helpers this adds:
- `launch_contexts_path`, `new_launch_context_path`, `launch_context_path(id)` 
- `update_status_growth_experiment_path(id)`

### 2.2 Navbar

In `app/views/layouts/application.html.erb`, add to the authenticated nav section:
```erb
<% if Current.user %>
  <%= link_to "My Backlogs", launch_contexts_path, class: "nav-link" %>
<% end %>
```

### 2.3 Seeds — AI Template

Replace `demo_placeholder_v1` in `db/seeds.rb` with the GrowthTester template. Remove the placeholder entirely. Add:

```ruby
AiTemplate.find_or_create_by!(name: "growthtester_backlog_v1") do |t|
  t.description = "Generates a prioritized ICE-scored growth experiment backlog from a product brief."
  t.system_prompt = <<~PROMPT.strip
    You are a growth strategist with deep experience in B2B and consumer SaaS, e-commerce, and creator tools. You specialize in traction channels and growth experimentation frameworks. Your role is to produce actionable, specific growth experiments that a solo founder or small team can begin running within one to two weeks. You do not produce generic advice. Every experiment you output is grounded in a specific channel, a testable hypothesis, and a realistic execution path.

    Always respond with valid JSON. No markdown fences. No prose outside the JSON object. The JSON must strictly follow the schema provided in the user message.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model            = "gemini-2.5-flash"
  t.max_output_tokens = 3000
  t.temperature      = 0.6
  t.notes            = <<~NOTES.strip
    Common failure modes: (1) generic experiments ("Post on social media") — tighten system prompt with "Every experiment must be specific enough that a founder could begin executing it tomorrow." (2) uniform ICE scores — add rule "No more than two experiments may share the same ICE total." (3) JSON wrapped in ```json fences — the no-markdown rule in the user prompt handles this; monitor in admin request log.
  NOTES
end
puts "Seeded: growthtester_backlog_v1 AI template"
```

### 2.4 Seeds — Sample Domain Data

After the AI template seed, add two sample `LaunchContext` records for the demo user. Each gets a realistic pre-generated set of `GrowthExperiment` records so the app looks populated on first run.

**Key details:**
- Wrap in `demo_user = User.find_by!(email: "demo@example.com")`
- Use `find_or_create_by!` on `product_name` + `user` to stay idempotent
- The first experiment in each set gets a `gemini_raw` sample JSON string; all others get `nil`
- See spec Section 10 for exact product names, descriptions, audiences, challenges, and the 8-9 experiment names per set

### Phase 2 Test Gate

**Manual:**
1. `rails db:seed` — no errors, `puts` lines appear
2. `rails routes | grep launch` — all 5 routes present
3. `rails routes | grep growth_experiment` — update_status route present
4. Sign in at `/sign_in` as `demo@example.com` — "My Backlogs" appears in navbar
5. `/admin/ai_templates` — `growthtester_backlog_v1` is listed
6. Click "Edit" on the template → variable fields `product_name`, `description`, `target_audience`, `growth_challenge` are auto-detected in the test panel

---

## Phase 3 — Controllers and Turbo Stream

**Goal:** Full HTTP flow works end-to-end (even with placeholder views). Status toggle works via Turbo Stream.

### 3.1 `LaunchContextsController`

```ruby
# app/controllers/launch_contexts_controller.rb
class LaunchContextsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: [:create],
             with: -> { redirect_to new_launch_context_path, alert: "Please wait before generating again." }

  def index
    @launch_contexts = current_user.launch_contexts.order(created_at: :desc)
  end

  def new
    @launch_context = LaunchContext.new
  end

  def create
    @launch_context = current_user.launch_contexts.build(launch_context_params)
    unless @launch_context.save
      render :new, status: :unprocessable_entity and return
    end

    result = GeminiService.generate(
      template:  "growthtester_backlog_v1",
      variables: {
        product_name:     @launch_context.product_name,
        description:      @launch_context.description,
        target_audience:  @launch_context.target_audience,
        growth_challenge: @launch_context.growth_challenge
      }
    )

    parsed   = JSON.parse(result)
    raw_json = result
    parsed["experiments"].each_with_index do |exp, i|
      @launch_context.growth_experiments.create!(
        user:           current_user,
        name:           exp["name"],
        hypothesis:     exp["hypothesis"],
        channel:        exp["channel"],
        impact:         exp["impact"],
        confidence:     exp["confidence"],
        effort:         exp["effort"],
        execution_note: exp["execution_note"],
        gemini_raw:     i.zero? ? raw_json : nil
      )
    end

    redirect_to @launch_context

  rescue JSON::ParserError
    @launch_context.destroy
    flash.now[:alert] = "Gemini returned an unexpected format. Please try again."
    render :new, status: :unprocessable_entity

  rescue GeminiService::BudgetExceededError
    @launch_context.destroy
    render partial: "shared/ai_error", locals: { error_type: :budget_exceeded }
  rescue GeminiService::GatekeeperError
    @launch_context.destroy
    render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }
  rescue GeminiService::TimeoutError
    @launch_context.destroy
    render partial: "shared/ai_error", locals: { error_type: :timeout }
  rescue GeminiService::GeminiError
    @launch_context.destroy
    render partial: "shared/ai_error", locals: { error_type: :error }
  end

  def show
    @launch_context = current_user.launch_contexts.find(params[:id])
    @sort_col       = params[:sort].presence_in(%w[impact confidence effort ice_total]) || "ice_total"
    @sort_dir       = params[:dir] == "asc" ? "asc" : "desc"

    @experiments = if @sort_col == "ice_total"
      @launch_context.growth_experiments
                     .sort_by { |e| @sort_dir == "asc" ? e.ice_total : -e.ice_total }
    else
      @launch_context.growth_experiments
                     .order(@sort_col => @sort_dir)
    end
  end

  def destroy
    @launch_context = current_user.launch_contexts.find(params[:id])
    @launch_context.destroy
    redirect_to launch_contexts_path, notice: "Backlog deleted."
  end

  private

  def launch_context_params
    params.require(:launch_context)
          .permit(:product_name, :description, :target_audience, :growth_challenge)
  end
end
```

**Note on scoping:** `current_user.launch_contexts.find(params[:id])` raises `ActiveRecord::RecordNotFound` (→ 404) automatically if the record belongs to a different user. No separate ownership check needed.

### 3.2 `GrowthExperimentsController`

```ruby
# app/controllers/growth_experiments_controller.rb
class GrowthExperimentsController < ApplicationController
  def update_status
    @experiment = current_user.growth_experiments.find(params[:id])
    if GrowthExperiment::STATUSES.include?(params[:status])
      @experiment.update!(status: params[:status])
    end
    render "growth_experiments/update_status"
  end
end
```

### 3.3 Turbo Stream — `growth_experiments/update_status.turbo_stream.erb`

```erb
<%= turbo_stream.update dom_id(@experiment, :status_cell) do %>
  <%= render "growth_experiments/status_dropdown", experiment: @experiment %>
<% end %>
```

The status cell `<td>` in `show.html.erb` must have `id="<%= dom_id(@experiment, :status_cell) %>"`. The `_status_dropdown` partial contains the Bootstrap dropdown form. See Phase 4 for full view markup.

### Phase 3 Test Gate

**RSpec:** Run the request specs written in Phase 5 (write stubs now):
```bash
bundle exec rspec spec/requests/launch_contexts_spec.rb spec/requests/growth_experiments_spec.rb
```

**Manual with placeholder views:**
1. `GET /launch_contexts/new` — renders without error (empty scaffold view is fine)
2. Sign in, navigate to `/launch_contexts/new`, submit a valid form → redirects to show
3. In rails console: `LaunchContext.count` increases; `GrowthExperiment.count` shows 8-10

---

## Phase 4 — Views, Partials, and Stimulus Controllers

**Goal:** Full UI renders correctly. All interactions work. Golden path fully functional.

### 4.1 Stimulus Controllers

Create these three controllers in `app/javascript/controllers/`:

**`character_count_controller.js`**
- Targets: `textarea` (the description field), `counter` (a `<span>` below it)
- Action: `input->character-count#update`
- `update()`: sets `counterTarget.textContent = \`${textareaTarget.value.length} / 1000\``
- Optionally adds `text-danger` class when count exceeds 1000

**`challenge_toggle_controller.js`**
- Targets: `buttons` (the four `.btn` elements), `input` (the hidden `growth_challenge` field)
- Action: `click->challenge-toggle#select` on each button
- `select(event)`: removes `active` / `btn-primary` from all buttons, adds to clicked button, sets `inputTarget.value` to `event.currentTarget.dataset.challengeToggleValueParam`
- On `connect()`: if `inputTarget.value` is already set (form re-render), activate the matching button

**`row_expand_controller.js`**
- Targets: `full` (the full hypothesis text, hidden by default), `preview` (the truncated one-line text)
- Action: `click->row-expand#toggle` on the table row
- `toggle()`: toggles `.d-none` on both targets

### 4.2 Shared Partials

**`app/views/shared/_ice_badge.html.erb`**
```erb
<%# locals: score (integer 1-5) %>
<% css_class = case score
   when 1, 2 then "bg-secondary"
   when 3    then "bg-warning text-dark"
   when 4, 5 then "bg-info text-dark"
   end %>
<span class="badge <%= css_class %>"><%= score %></span>
```

**`app/views/shared/_growth_challenge_badge.html.erb`**
```erb
<%# locals: challenge (string) %>
<% css_class = { "awareness" => "bg-primary", "conversion" => "bg-success",
                 "retention" => "bg-warning text-dark", "referral" => "bg-purple" }[challenge] || "bg-secondary" %>
<span class="badge <%= css_class %>"><%= challenge.capitalize %></span>
```
Note: Bootstrap 5 dark mode does not have `bg-purple` by default — use `style="background-color: #7c3aed;"` or a utility override for the referral badge.

**`app/views/growth_experiments/_status_dropdown.html.erb`**
A Bootstrap dropdown form for a single experiment's status. Renders the current status as a colored badge trigger. The dropdown menu shows the other two statuses as form submit links (each a small `form_with` posting to `update_status_growth_experiment_path`).

### 4.3 `launch_contexts/new.html.erb`

Single-column card form:
- `product_name`: text input, required
- `description`: textarea, maxlength=1000, `data-controller="character-count"`, `data-character-count-target="textarea"` + `data-action="input->character-count#update"`. Counter `<span>` below with `data-character-count-target="counter"`.
- `target_audience`: text input, required
- `growth_challenge`: hidden input (`launch_context[growth_challenge]`, `data-challenge-toggle-target="input"`); four Bootstrap `.btn-outline-secondary` buttons in a `.btn-group` using `data-controller="challenge-toggle"` on the wrapper, each with `data-action="click->challenge-toggle#select"` and `data-challenge-toggle-value-param` set to the challenge name.
- Submit: "Generate Backlog" button with accent color styling
- Below form: `<p class="text-muted small">Gemini will generate 8–10 scored experiments. This takes about 5–10 seconds.</p>`

### 4.4 `launch_contexts/show.html.erb`

Header section:
- `product_name` as `<h1>`
- Target audience as `<p class="text-muted">`
- Growth challenge badge: `<%= render "shared/growth_challenge_badge", challenge: @launch_context.growth_challenge %>`
- "New Backlog" button (accent) → `new_launch_context_path`
- AI disclaimer: `<p class="text-muted small">ICE scores are AI estimates based on your description. Adjust them to match your knowledge of your specific market.</p>`

Sortable ICE table — Bootstrap `.table .table-hover .table-dark`:

Column headers for Impact, Confidence, Effort, ICE Total are anchor links that append `?sort=column&dir=asc|desc` query params. ICE Total header gets `class="ice-total-column"`. Toggle direction: if current sort is this column + "desc", next click is "asc"; otherwise "desc".

Each `<tr>` with `data-controller="row-expand"` and `class="<%= 'experiment-row--active' if exp.status == 'active' %>"`:
- Experiment name cell
- Hypothesis cell: truncated `<span data-row-expand-target="preview">` + hidden `<span data-row-expand-target="full" class="d-none">`
- Channel badge
- Impact/Confidence/Effort cells: `<%= render "shared/ice_badge", score: exp.impact %>`
- ICE Total cell: `<span class="fw-bold"><%= exp.ice_total %></span>`
- Status cell: `<td id="<%= dom_id(exp, :status_cell) %>"><%= render "growth_experiments/status_dropdown", experiment: exp %></td>`

At page bottom: Bootstrap `.collapse` for raw Gemini response:
```erb
<% first_experiment = @experiments.first %>
<% if first_experiment&.gemini_raw.present? %>
  <a class="btn btn-link btn-sm" data-bs-toggle="collapse" href="#raw-response">Show raw Gemini response</a>
  <div class="collapse" id="raw-response">
    <pre class="bg-dark border rounded p-3 small"><%= first_experiment.gemini_raw %></pre>
  </div>
<% end %>
```

### 4.5 `launch_contexts/index.html.erb`

Bootstrap table with columns: Product Name (link to show), Growth Challenge badge, Experiment count, Created date, Delete button (uses `link_to` with `data: { turbo_method: :delete, turbo_confirm: "Delete this backlog and all its experiments?" }`). Empty state card if `@launch_contexts.empty?`.

### 4.6 Replace `home/index.html.erb`

Two-column Bootstrap hero (`.row` with `.col-lg-6`):
- Left: heading using `ENV.fetch("APP_NAME", "GrowthTester Demo")`, tagline, numbered three-step list (Describe your product / Pick your growth challenge / Get a scored, sortable backlog), "Generate My Backlog" CTA → `new_launch_context_path`
- Right: a static Bootstrap card mocking the ICE table (hardcoded sample rows — this is a demo, no JS needed)

Below hero: four Bootstrap cards or a simple grid showing the four growth challenges with one-line descriptions.

### 4.7 Replace `dashboard/show.html.erb`

Check `current_user.launch_contexts.count`:
- **Zero contexts:** centered card with CTA button → `new_launch_context_path`
- **One or more:** most recent context card (product name, growth challenge badge, experiment count, "View Backlog" link) + list of last 5 past backlogs + "New Backlog" button (accent) pinned top-right via `d-flex justify-content-between align-items-center`

Both states use `ENV.fetch("APP_NAME", "GrowthTester Demo")` in any headings.

### Phase 4 Test Gate

**Manual golden path:**
1. Visit `/` — landing page renders with hero, how-it-works, challenge descriptions
2. Sign in → dashboard shows "no backlogs" CTA (on fresh seed)
3. Click "Generate My Backlog" → form renders; character counter works; challenge toggle selects one challenge at a time
4. Submit form → Gemini is called (takes 5-10s) → redirect to show
5. Show page: experiments table renders; ICE scores are colored badges
6. Click a column header → table re-sorts
7. Click a table row → hypothesis expands/collapses
8. Change status on an experiment → only the status cell updates (Turbo Stream, no full reload)
9. Scroll to bottom → "Show raw Gemini response" collapse toggles the `<pre>` block
10. "My Backlogs" navbar link → index page lists the backlog
11. Delete button → context and all experiments are destroyed

---

## Phase 5 — RSpec Test Suite

**Goal:** Full spec suite passes with no real API calls.

### 5.1 `spec/models/launch_context_spec.rb`

```ruby
RSpec.describe LaunchContext, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:growth_experiments).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:product_name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:target_audience) }
    it { is_expected.to validate_presence_of(:growth_challenge) }
    it { is_expected.to validate_length_of(:description).is_at_most(1000) }
    it { is_expected.to validate_length_of(:target_audience).is_at_most(200) }
    it { is_expected.to validate_inclusion_of(:growth_challenge).in_array(%w[awareness conversion retention referral]) }
  end
end
```

### 5.2 `spec/models/growth_experiment_spec.rb`

```ruby
RSpec.describe GrowthExperiment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:launch_context) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:hypothesis) }
    it { is_expected.to validate_presence_of(:channel) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[idea active complete]) }
    it { is_expected.to validate_numericality_of(:impact).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5) }
    it { is_expected.to validate_numericality_of(:confidence).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5) }
    it { is_expected.to validate_numericality_of(:effort).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5) }
  end

  describe "#ice_total" do
    it "returns impact + confidence + (6 - effort)" do
      exp = build(:growth_experiment, impact: 4, confidence: 3, effort: 2)
      expect(exp.ice_total).to eq(9)
    end

    it "scores lower-effort experiments higher" do
      low_effort  = build(:growth_experiment, impact: 3, confidence: 3, effort: 1)
      high_effort = build(:growth_experiment, impact: 3, confidence: 3, effort: 5)
      expect(low_effort.ice_total).to be > high_effort.ice_total
    end
  end
end
```

### 5.3 `spec/requests/launch_contexts_spec.rb`

Cover these cases:
1. `GET /launch_contexts/new` — 200 for authenticated user
2. `GET /launch_contexts/new` — redirects unauthenticated user to sign in
3. `POST /launch_contexts` with valid params + `gemini_returns(valid_json)` — creates LaunchContext, creates 8 GrowthExperiment records, redirects to show
4. `POST /launch_contexts` with valid params — creates an LlmRequest record (verify logging runs)
5. `POST /launch_contexts` when `gemini_raises(GeminiService::GeminiError)` — destroys the LaunchContext, does not create experiments, renders new with error
6. `POST /launch_contexts` when `JSON::ParserError` — destroys LaunchContext, renders new with flash alert
7. `GET /launch_contexts/:id` — 200 for owner
8. `GET /launch_contexts/:id` — 404 (RecordNotFound) when signed in as different user
9. `DELETE /launch_contexts/:id` — destroys context and associated experiments, redirects to index

The `valid_json` stub response must be a real JSON string matching the `growthtester_backlog_v1` schema with 8 experiment objects.

### 5.4 `spec/requests/growth_experiments_spec.rb`

Cover these cases:
1. `PATCH /growth_experiments/:id/update_status` with `status: "active"` — updates status, returns Turbo Stream content type
2. `PATCH /growth_experiments/:id/update_status` with an invalid status — does not update record (status stays "idea")
3. `PATCH /growth_experiments/:id/update_status` signed in as different user — 404 (RecordNotFound)
4. Unauthenticated request — redirects to sign in

### Phase 5 Test Gate

```bash
bundle exec rspec
```
Full suite must pass: 0 failures, 0 real Gemini API calls. Check for "stubbed" in any error output if calls escape.

---

## Phase 6 — README, Final Polish, and QA Pass

**Goal:** App is presentable, documented, and ready to share as an open-source demo.

### 6.1 README Updates

Update `README.md` with the content from spec Section 11:
- App name and tagline at the top
- Description paragraph
- Screenshot placeholder
- "Why I Built This" section
- "Editing the AI Prompt" section
- "No Additional Setup Steps" note

### 6.2 ENV Audit

Run a global search for any hardcoded "GrowthTester" strings in views and layouts. Every occurrence of the app name, tagline, or description in `.html.erb` files must use `ENV.fetch(...)`, not a string literal.

```bash
grep -r "GrowthTester" app/views/ --include="*.erb"
```
All results must be inside `ENV.fetch(...)` calls or in comments.

### 6.3 Admin Template Validation

Using the admin test panel at `/admin/ai_templates`:
- Open `growthtester_backlog_v1`
- Fill in all four variable fields with the ShipFast CLI sample values from spec Section 10
- Click "Test" — verify the response is valid JSON with 8-10 experiments
- Verify token count and duration are logged in `/admin/llm_requests`

### 6.4 Rate Limit Verification

In the request spec for `POST /launch_contexts`, add one example that submits 11 times from the same IP and verifies the 11th is redirected (rate-limited). Use the `rate_limit_helpers.rb` support file to clear cache between non-rate-limit tests.

### Phase 6 Test Gate

**Full manual walkthrough (clean slate):**
1. `rails db:drop db:create db:migrate db:seed`
2. Visit `/` — landing page correct; APP_NAME from ENV
3. Sign in as `demo@example.com` / `password123`
4. Dashboard shows two seeded backlogs
5. Click into "ShipFast CLI" backlog — 8 experiments render with ICE scores and correct channel badges
6. Sort by "ICE Total" ascending and descending — order changes correctly
7. Change one experiment's status to "active" — row turns teal border, Turbo Stream updates only that cell
8. Generate a new backlog with your own product description — real Gemini call succeeds
9. Delete the new backlog — redirects to index, count drops
10. Visit `/admin/llm_requests` — the real Gemini call and any admin test calls are logged
11. `bundle exec rspec` — all green

---

*End of GrowthTester Demo Build Phases — v1.0*
