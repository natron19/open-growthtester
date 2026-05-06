# ── Demo user ─────────────────────────────────────────────────────────────────
demo_user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name                  = "Demo User"
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.admin                 = true
end

puts "Demo user: demo@example.com / password123"

# ── Health ping template — used by /up/llm ────────────────────────────────────
AiTemplate.find_or_create_by!(name: "health_ping") do |t|
  t.description          = "Minimal prompt used by the /up/llm health check endpoint."
  t.system_prompt        = "You are a health check endpoint. Respond with exactly: ok"
  t.user_prompt_template = "ping"
  t.model                = "gemini-2.5-flash"
  t.max_output_tokens    = 10
  t.temperature          = 0.0
  t.notes                = "Do not modify. Used by HealthController#llm."
end

puts "Seeded: health_ping AI template"

# ── GrowthTester backlog template ─────────────────────────────────────────────
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
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 3000
  t.temperature       = 0.6
  t.notes             = <<~NOTES.strip
    Common failure modes: (1) Generic experiments ("Post on social media") — tighten system prompt with "Every experiment must be specific enough that a founder could begin executing it tomorrow." (2) Uniform ICE scores — add rule "No more than two experiments may share the same ICE total." (3) JSON wrapped in ```json fences — the no-markdown rule in the user prompt handles this; monitor in the admin request log.
  NOTES
end

puts "Seeded: growthtester_backlog_v1 AI template"

# ── Sample domain data ────────────────────────────────────────────────────────

SHIPFAST_RAW = <<~JSON.strip
  {"experiments":[{"name":"Founder-led Twitter/X Thread Series","hypothesis":"If we publish weekly founder threads documenting real Rails SaaS challenges, then brand awareness sign-ups will increase 30% because indie developers trust peer expertise over marketing copy.","channel":"Content","impact":4,"confidence":4,"effort":2,"execution_note":"Write a 10-tweet thread about the single biggest pain point ShipFast CLI eliminates and schedule it for Tuesday morning."},{"name":"ProductHunt Launch","hypothesis":"If we launch on ProductHunt with a polished page and coordinated upvote campaign, then sign-up rate will spike 150% in the first 48 hours because PH concentrates an audience of indie builders actively seeking new tools.","channel":"PR","impact":5,"confidence":3,"effort":3,"execution_note":"Prepare a 60-second demo GIF and schedule the launch for a Tuesday at 12:01 AM ET."},{"name":"SEO-Targeted Docs for Rails Boilerplate Queries","hypothesis":"If we publish SEO-optimized pages targeting 'rails saas boilerplate' and five related long-tail keywords, then organic trial sign-ups will increase 40% within 90 days because developers search for this exact thing before starting a new project.","channel":"SEO","impact":4,"confidence":3,"effort":3,"execution_note":"Research the top 10 keywords with a free Ahrefs trial and create a dedicated landing page for each cluster."},{"name":"Ship in Public YouTube Series","hypothesis":"If we release a weekly episode showing a real SaaS being built end-to-end with ShipFast CLI, then email list will grow 25% per month because visual proof converts skeptics faster than text documentation.","channel":"Content","impact":3,"confidence":3,"effort":4,"execution_note":"Record the first episode: zero to a deployed Rails app with auth and billing in under an hour."},{"name":"Rails Podcast Sponsorship and Guest Appearances","hypothesis":"If we sponsor or guest on three top Rails podcasts within 60 days, then qualified sign-ups will increase 15% because podcast listeners are high-intent early adopters already invested in the Rails ecosystem.","channel":"Partnership","impact":3,"confidence":4,"effort":2,"execution_note":"Email Remote Ruby, Rails Changelog, and Indie Rails with a concise partnership proposal and a free license offer."},{"name":"Reddit r/rails Transparent AMA","hypothesis":"If we host an AMA in r/rails about building and shipping ShipFast CLI, then community referral sign-ups will increase 10% because authentic founder stories outperform ads in technical communities.","channel":"Community","impact":3,"confidence":3,"effort":1,"execution_note":"Post a 'I built a Rails SaaS boilerplate CLI in public — ask me anything' thread in r/rails on a weekday morning."},{"name":"Made with ShipFast Showcase Page","hypothesis":"If we publish a public gallery of projects built with ShipFast CLI, then referral sign-ups will increase 20% because social proof from peers reduces perceived risk for new users.","channel":"Community","impact":3,"confidence":3,"effort":2,"execution_note":"Build a /showcase page and email the first 20 users asking permission to feature their project with a screenshot."},{"name":"Free Tier with Three-Scaffold Limit","hypothesis":"If we release a free tier capped at three scaffold commands, then trial-to-paid conversion will reach 15% within 30 days because low-friction entry removes the biggest objection for first-time users.","channel":"Product","impact":4,"confidence":3,"effort":4,"execution_note":"Define the free tier limits in the CLI config and add an in-terminal upgrade prompt when users hit the cap."}]}
JSON

MEETINGCOST_RAW = <<~JSON.strip
  {"experiments":[{"name":"In-Product Share Card After Each Meeting","hypothesis":"If we add a one-click share card showing the dollar cost of the just-ended meeting, then viral referral installs will grow 25% per month because cost shock is inherently shareable on LinkedIn and Twitter.","channel":"Referral","impact":5,"confidence":4,"effort":3,"execution_note":"Design a shareable card template with meeting cost, headcount, and a 'calculated by MeetingCost.io' attribution link."},{"name":"LinkedIn Post Template for Engineering Managers","hypothesis":"If we provide a fill-in-the-blank LinkedIn post template showing a team's weekly meeting cost, then referral installs from engineering managers will increase 20% because peer managers are the primary install vector.","channel":"Referral","impact":4,"confidence":4,"effort":1,"execution_note":"Write three post templates in different tones and add them to an in-extension 'Share this stat' button."},{"name":"Slack Bot Integration with Post-Meeting Cost Digest","hypothesis":"If we build a Slack bot that posts a weekly meeting-cost digest to a team channel, then 30-day retention will increase 35% because recurring passive value creates stickiness without user effort.","channel":"Product","impact":4,"confidence":3,"effort":4,"execution_note":"Scope a minimal Slack app that reads calendar data and posts a Monday morning cost summary."},{"name":"Remote Work Newsletter Sponsorships","hypothesis":"If we sponsor three remote-work newsletters with a combined audience of 50k, then qualified installs will increase 15% in the sponsorship month because remote-work readers are primed to care about meeting overhead.","channel":"Partnership","impact":3,"confidence":3,"effort":2,"execution_note":"Identify the top five remote-work newsletters on Substack and email their editors with a sponsorship rate card request."},{"name":"Engineering Manager LinkedIn Content Series","hypothesis":"If we publish a biweekly LinkedIn series on the true cost of meeting culture, then brand-attributed installs will grow 10% per quarter because long-form thought leadership builds authority with the exact buyer persona.","channel":"Content","impact":3,"confidence":3,"effort":3,"execution_note":"Write the first post: 'I tracked my team's meeting costs for 30 days. Here is what I found.'"},{"name":"Browser Extension Store Referral Program","hypothesis":"If we add a referral code system where installers get a custom link, then peer-driven installs will increase 30% because extension users have credibility with their immediate network.","channel":"Referral","impact":4,"confidence":3,"effort":3,"execution_note":"Set up a simple referral tracking page at meetingcost.io/refer and generate unique codes on install."},{"name":"'What Did That Meeting Cost?' Landing Page Calculator","hypothesis":"If we publish a free standalone calculator at meetingcost.io/calculate, then organic installs from SEO will increase 20% within 60 days because people searching for meeting cost calculators are the exact target user.","channel":"SEO","impact":3,"confidence":4,"effort":2,"execution_note":"Build a single-page calculator with salary and headcount inputs and a CTA to install the extension for real-time tracking."},{"name":"Direct Outreach to Remote-Work Influencers","hypothesis":"If we send personalized cold emails to 20 remote-work LinkedIn influencers offering a co-branded data report, then referral installs will spike 25% from a single campaign because influencer audiences match the target persona exactly.","channel":"Outbound","impact":3,"confidence":2,"effort":2,"execution_note":"Identify 20 influencers with 10k+ LinkedIn followers posting about remote work and draft a personalized outreach template."},{"name":"ProductHunt Launch with Referral CTA","hypothesis":"If we launch on ProductHunt and embed a referral CTA in the first comment, then new installs will increase 100% in the launch week because PH surfaces tools to early adopters actively seeking productivity solutions.","channel":"PR","impact":4,"confidence":3,"effort":3,"execution_note":"Prepare the PH listing with a demo video, schedule for a Tuesday, and draft a first-comment referral offer."}]}
JSON

# ── LaunchContext 1: ShipFast CLI (awareness) ─────────────────────────────────
shipfast = LaunchContext.find_or_create_by!(product_name: "ShipFast CLI", user: demo_user) do |lc|
  lc.description      = "A command-line tool that scaffolds opinionated Rails 8 SaaS boilerplates with authentication, billing, and AI integrations pre-wired. Reduces new project setup from a week to under an hour."
  lc.target_audience  = "Solo Rails developers building their first SaaS product"
  lc.growth_challenge = "awareness"
end

if shipfast.growth_experiments.empty?
  [
    { name: "Founder-led Twitter/X Thread Series",
      hypothesis: "If we publish weekly founder threads documenting real Rails SaaS challenges, then brand awareness sign-ups will increase 30% because indie developers trust peer expertise over marketing copy.",
      channel: "Content", impact: 4, confidence: 4, effort: 2,
      execution_note: "Write a 10-tweet thread about the single biggest pain point ShipFast CLI eliminates and schedule it for Tuesday morning.",
      gemini_raw: SHIPFAST_RAW },
    { name: "ProductHunt Launch",
      hypothesis: "If we launch on ProductHunt with a polished page and coordinated upvote campaign, then sign-up rate will spike 150% in the first 48 hours because PH concentrates an audience of indie builders actively seeking new tools.",
      channel: "PR", impact: 5, confidence: 3, effort: 3,
      execution_note: "Prepare a 60-second demo GIF and schedule the launch for a Tuesday at 12:01 AM ET." },
    { name: "SEO-Targeted Docs for Rails Boilerplate Queries",
      hypothesis: "If we publish SEO-optimized pages targeting 'rails saas boilerplate' and five related long-tail keywords, then organic trial sign-ups will increase 40% within 90 days because developers search for this exact thing before starting a new project.",
      channel: "SEO", impact: 4, confidence: 3, effort: 3,
      execution_note: "Research the top 10 keywords with a free Ahrefs trial and create a dedicated landing page for each cluster." },
    { name: "Ship in Public YouTube Series",
      hypothesis: "If we release a weekly episode showing a real SaaS being built end-to-end with ShipFast CLI, then email list will grow 25% per month because visual proof converts skeptics faster than text documentation.",
      channel: "Content", impact: 3, confidence: 3, effort: 4,
      execution_note: "Record the first episode: zero to a deployed Rails app with auth and billing in under an hour." },
    { name: "Rails Podcast Sponsorship and Guest Appearances",
      hypothesis: "If we sponsor or guest on three top Rails podcasts within 60 days, then qualified sign-ups will increase 15% because podcast listeners are high-intent early adopters already invested in the Rails ecosystem.",
      channel: "Partnership", impact: 3, confidence: 4, effort: 2,
      execution_note: "Email Remote Ruby, Rails Changelog, and Indie Rails with a concise partnership proposal and a free license offer." },
    { name: "Reddit r/rails Transparent AMA",
      hypothesis: "If we host an AMA in r/rails about building and shipping ShipFast CLI, then community referral sign-ups will increase 10% because authentic founder stories outperform ads in technical communities.",
      channel: "Community", impact: 3, confidence: 3, effort: 1,
      execution_note: "Post a 'I built a Rails SaaS boilerplate CLI in public — ask me anything' thread in r/rails on a weekday morning." },
    { name: "Made with ShipFast Showcase Page",
      hypothesis: "If we publish a public gallery of projects built with ShipFast CLI, then referral sign-ups will increase 20% because social proof from peers reduces perceived risk for new users.",
      channel: "Community", impact: 3, confidence: 3, effort: 2,
      execution_note: "Build a /showcase page and email the first 20 users asking permission to feature their project with a screenshot." },
    { name: "Free Tier with Three-Scaffold Limit",
      hypothesis: "If we release a free tier capped at three scaffold commands, then trial-to-paid conversion will reach 15% within 30 days because low-friction entry removes the biggest objection for first-time users.",
      channel: "Product", impact: 4, confidence: 3, effort: 4,
      execution_note: "Define the free tier limits in the CLI config and add an in-terminal upgrade prompt when users hit the cap." }
  ].each do |attrs|
    shipfast.growth_experiments.create!(attrs.merge(user: demo_user, status: "idea"))
  end
  puts "Seeded: ShipFast CLI launch context (8 experiments)"
else
  puts "Skipped: ShipFast CLI launch context (already exists)"
end

# ── LaunchContext 2: MeetingCost.io (referral) ────────────────────────────────
meetingcost = LaunchContext.find_or_create_by!(product_name: "MeetingCost.io", user: demo_user) do |lc|
  lc.description      = "A browser extension that overlays a real-time dollar cost counter on Google Meet and Zoom calls, calculated from headcount and average salaries. Helps teams feel the cost of unnecessary meetings."
  lc.target_audience  = "Engineering managers and startup CTOs who want to reduce meeting overhead"
  lc.growth_challenge = "referral"
end

if meetingcost.growth_experiments.empty?
  [
    { name: "In-Product Share Card After Each Meeting",
      hypothesis: "If we add a one-click share card showing the dollar cost of the just-ended meeting, then viral referral installs will grow 25% per month because cost shock is inherently shareable on LinkedIn and Twitter.",
      channel: "Referral", impact: 5, confidence: 4, effort: 3,
      execution_note: "Design a shareable card template with meeting cost, headcount, and a 'calculated by MeetingCost.io' attribution link.",
      gemini_raw: MEETINGCOST_RAW },
    { name: "LinkedIn Post Template for Engineering Managers",
      hypothesis: "If we provide a fill-in-the-blank LinkedIn post template showing a team's weekly meeting cost, then referral installs from engineering managers will increase 20% because peer managers are the primary install vector.",
      channel: "Referral", impact: 4, confidence: 4, effort: 1,
      execution_note: "Write three post templates in different tones and add them to an in-extension 'Share this stat' button." },
    { name: "Slack Bot Integration with Post-Meeting Cost Digest",
      hypothesis: "If we build a Slack bot that posts a weekly meeting-cost digest to a team channel, then 30-day retention will increase 35% because recurring passive value creates stickiness without user effort.",
      channel: "Product", impact: 4, confidence: 3, effort: 4,
      execution_note: "Scope a minimal Slack app that reads calendar data and posts a Monday morning cost summary." },
    { name: "Remote Work Newsletter Sponsorships",
      hypothesis: "If we sponsor three remote-work newsletters with a combined audience of 50k, then qualified installs will increase 15% in the sponsorship month because remote-work readers are primed to care about meeting overhead.",
      channel: "Partnership", impact: 3, confidence: 3, effort: 2,
      execution_note: "Identify the top five remote-work newsletters on Substack and email their editors with a sponsorship rate card request." },
    { name: "Engineering Manager LinkedIn Content Series",
      hypothesis: "If we publish a biweekly LinkedIn series on the true cost of meeting culture, then brand-attributed installs will grow 10% per quarter because long-form thought leadership builds authority with the exact buyer persona.",
      channel: "Content", impact: 3, confidence: 3, effort: 3,
      execution_note: "Write the first post: 'I tracked my team's meeting costs for 30 days. Here is what I found.'" },
    { name: "Browser Extension Store Referral Program",
      hypothesis: "If we add a referral code system where installers get a custom link, then peer-driven installs will increase 30% because extension users have credibility with their immediate network.",
      channel: "Referral", impact: 4, confidence: 3, effort: 3,
      execution_note: "Set up a simple referral tracking page at meetingcost.io/refer and generate unique codes on install." },
    { name: "'What Did That Meeting Cost?' Landing Page Calculator",
      hypothesis: "If we publish a free standalone calculator at meetingcost.io/calculate, then organic installs from SEO will increase 20% within 60 days because people searching for meeting cost calculators are the exact target user.",
      channel: "SEO", impact: 3, confidence: 4, effort: 2,
      execution_note: "Build a single-page calculator with salary and headcount inputs and a CTA to install the extension for real-time tracking." },
    { name: "Direct Outreach to Remote-Work Influencers",
      hypothesis: "If we send personalized cold emails to 20 remote-work LinkedIn influencers offering a co-branded data report, then referral installs will spike 25% from a single campaign because influencer audiences match the target persona exactly.",
      channel: "Outbound", impact: 3, confidence: 2, effort: 2,
      execution_note: "Identify 20 influencers with 10k+ LinkedIn followers posting about remote work and draft a personalized outreach template." },
    { name: "ProductHunt Launch with Referral CTA",
      hypothesis: "If we launch on ProductHunt and embed a referral CTA in the first comment, then new installs will increase 100% in the launch week because PH surfaces tools to early adopters actively seeking productivity solutions.",
      channel: "PR", impact: 4, confidence: 3, effort: 3,
      execution_note: "Prepare the PH listing with a demo video, schedule for a Tuesday, and draft a first-comment referral offer." }
  ].each do |attrs|
    meetingcost.growth_experiments.create!(attrs.merge(user: demo_user, status: "idea"))
  end
  puts "Seeded: MeetingCost.io launch context (9 experiments)"
else
  puts "Skipped: MeetingCost.io launch context (already exists)"
end
