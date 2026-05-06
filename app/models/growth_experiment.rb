class GrowthExperiment < ApplicationRecord
  belongs_to :launch_context
  belongs_to :user

  STATUSES  = %w[idea active complete].freeze
  ICE_RANGE = (1..5)

  validates :name,       presence: true
  validates :hypothesis, presence: true
  validates :channel,    presence: true
  validates :status,     presence: true, inclusion: { in: STATUSES }
  validates :impact,     presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :confidence, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :effort,     presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }

  def ice_total
    impact + confidence + (6 - effort)
  end
end
