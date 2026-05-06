FactoryBot.define do
  factory :launch_context do
    association :user
    product_name     { "TestProduct" }
    description      { "A test product that helps developers ship faster by automating repetitive setup tasks." }
    target_audience  { "Solo developers" }
    growth_challenge { "awareness" }
  end
end
