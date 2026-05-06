require "rails_helper"

RSpec.describe "GrowthExperiments", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:context)    { create(:launch_context, user: user) }
  let(:experiment) { create(:growth_experiment, launch_context: context, user: user, status: "idea") }

  describe "PATCH update_status" do
    context "with valid status from owner" do
      before { sign_in_as(user) }

      it "updates the status" do
        patch update_status_growth_experiment_path(experiment), params: { status: "active" }
        expect(experiment.reload.status).to eq("active")
      end

      it "returns Turbo Stream content type" do
        patch update_status_growth_experiment_path(experiment),
              params: { status: "active" },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "with an invalid status" do
      before { sign_in_as(user) }

      it "does not change the status" do
        patch update_status_growth_experiment_path(experiment), params: { status: "bogus" }
        expect(experiment.reload.status).to eq("idea")
      end
    end

    context "for a different user's experiment" do
      before { sign_in_as(other) }

      it "returns 404 or redirects (not found)" do
        patch update_status_growth_experiment_path(experiment), params: { status: "active" }
        expect(response.status).to be_in([302, 404])
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        patch update_status_growth_experiment_path(experiment), params: { status: "active" }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
