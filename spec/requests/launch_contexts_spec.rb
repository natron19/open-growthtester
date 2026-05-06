require "rails_helper"

VALID_GEMINI_JSON = JSON.generate(
  experiments: Array.new(8) do |i|
    {
      "name"           => "Experiment #{i + 1}",
      "hypothesis"     => "If we do X, then Y will increase because Z.",
      "channel"        => "Content",
      "impact"         => 4,
      "confidence"     => 3,
      "effort"         => 2,
      "execution_note" => "Write the first draft."
    }
  end
)

RSpec.describe "LaunchContexts", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe "GET /launch_contexts/new" do
    context "when authenticated" do
      before { sign_in_as(user) }

      it "returns 200" do
        get new_launch_context_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get new_launch_context_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /launch_contexts" do
    let(:valid_params) do
      {
        launch_context: {
          product_name:     "TestProduct",
          description:      "A product that does something useful for developers.",
          target_audience:  "Solo developers",
          growth_challenge: "awareness"
        }
      }
    end

    context "when authenticated with valid data and Gemini succeeds" do
      before do
        sign_in_as(user)
        gemini_returns(VALID_GEMINI_JSON)
      end

      it "creates a LaunchContext" do
        expect { post launch_contexts_path, params: valid_params }
          .to change(LaunchContext, :count).by(1)
      end

      it "creates 8 GrowthExperiments" do
        expect { post launch_contexts_path, params: valid_params }
          .to change(GrowthExperiment, :count).by(8)
      end

      it "redirects to the show page" do
        post launch_contexts_path, params: valid_params
        expect(response).to redirect_to(launch_context_path(LaunchContext.last))
      end

    end

    context "when Gemini raises GeminiError" do
      before do
        sign_in_as(user)
        gemini_raises(GeminiService::GeminiError)
      end

      it "does not leave a LaunchContext behind" do
        expect { post launch_contexts_path, params: valid_params }
          .not_to change(LaunchContext, :count)
      end

      it "creates no experiments" do
        expect { post launch_contexts_path, params: valid_params }
          .not_to change(GrowthExperiment, :count)
      end

      it "returns a response" do
        post launch_contexts_path, params: valid_params
        expect(response).to have_http_status(:ok)
      end
    end

    context "when Gemini returns invalid JSON" do
      before do
        sign_in_as(user)
        gemini_returns("this is not json")
      end

      it "does not leave a LaunchContext behind" do
        expect { post launch_contexts_path, params: valid_params }
          .not_to change(LaunchContext, :count)
      end

      it "renders the new form" do
        post launch_contexts_path, params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        post launch_contexts_path, params: valid_params
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "GET /launch_contexts/:id" do
    let(:context) { create(:launch_context, user: user) }

    context "as the owner" do
      before { sign_in_as(user) }

      it "returns 200" do
        get launch_context_path(context)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a different authenticated user" do
      before { sign_in_as(other) }

      it "does not return 200" do
        get launch_context_path(context)
        expect(response).not_to have_http_status(:ok)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get launch_context_path(context)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /launch_contexts/:id" do
    let!(:context) { create(:launch_context, user: user) }

    before { sign_in_as(user) }

    it "destroys the context" do
      expect { delete launch_context_path(context) }
        .to change(LaunchContext, :count).by(-1)
    end

    it "redirects to the index" do
      delete launch_context_path(context)
      expect(response).to redirect_to(launch_contexts_path)
    end
  end
end
