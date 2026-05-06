FactoryBot.define do
  factory :growth_experiment do
    association :launch_context
    association :user
    name           { "Founder-led Twitter thread series" }
    hypothesis     { "If we publish weekly founder threads, then sign-up rate will increase 20% because founders trust founders." }
    channel        { "Content" }
    impact         { 4 }
    confidence     { 3 }
    effort         { 2 }
    execution_note { "Write the first thread about the core problem your product solves." }
    status         { "idea" }
    gemini_raw     { nil }

    trait :active do
      status { "active" }
    end

    trait :complete do
      status { "complete" }
    end

    trait :with_raw do
      gemini_raw { '{"experiments":[]}' }
    end
  end
end
