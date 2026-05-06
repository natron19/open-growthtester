RSpec.describe GrowthExperiment, type: :model do
  subject { build(:growth_experiment) }

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
      expect(exp.ice_total).to eq(11)
    end

    it "scores lower-effort experiments higher than high-effort with same impact and confidence" do
      low_effort  = build(:growth_experiment, impact: 3, confidence: 3, effort: 1)
      high_effort = build(:growth_experiment, impact: 3, confidence: 3, effort: 5)
      expect(low_effort.ice_total).to be > high_effort.ice_total
    end

    it "returns the minimum score (3) when all values are 1" do
      exp = build(:growth_experiment, impact: 1, confidence: 1, effort: 1)
      expect(exp.ice_total).to eq(7)
    end

    it "returns the maximum score when impact and confidence are 5 and effort is 1" do
      exp = build(:growth_experiment, impact: 5, confidence: 5, effort: 1)
      expect(exp.ice_total).to eq(15)
    end
  end

  describe "factory" do
    it "produces a valid record" do
      expect(build(:growth_experiment)).to be_valid
    end

    it ":active trait sets status to active" do
      exp = build(:growth_experiment, :active)
      expect(exp.status).to eq("active")
    end

    it ":complete trait sets status to complete" do
      exp = build(:growth_experiment, :complete)
      expect(exp.status).to eq("complete")
    end
  end
end
