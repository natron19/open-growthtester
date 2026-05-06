RSpec.describe LaunchContext, type: :model do
  subject { build(:launch_context) }

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

  describe "factory" do
    it "produces a valid record" do
      expect(build(:launch_context)).to be_valid
    end
  end
end
