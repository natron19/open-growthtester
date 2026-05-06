class LaunchContext < ApplicationRecord
  belongs_to :user
  has_many :growth_experiments, dependent: :destroy

  GROWTH_CHALLENGES = %w[awareness conversion retention referral].freeze

  validates :product_name,     presence: true
  validates :description,      presence: true, length: { maximum: 1000 }
  validates :target_audience,  presence: true, length: { maximum: 200 }
  validates :growth_challenge, presence: true, inclusion: { in: GROWTH_CHALLENGES }
end
