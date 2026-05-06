class LaunchContextsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create

  before_action :set_launch_context, only: [:show, :destroy]

  def index
    @launch_contexts = current_user.launch_contexts.order(created_at: :desc)
  end

  def new
    @launch_context = LaunchContext.new
  end

  def create
    @launch_context = current_user.launch_contexts.build(launch_context_params)

    unless @launch_context.save
      render :new, status: :unprocessable_entity
      return
    end

    raw_json = GeminiService.generate(
      template:  "growthtester_backlog_v1",
      variables: {
        product_name:     @launch_context.product_name,
        description:      @launch_context.description,
        target_audience:  @launch_context.target_audience,
        growth_challenge: @launch_context.growth_challenge
      },
      generation_config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            experiments: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  name:           { type: "string" },
                  hypothesis:     { type: "string" },
                  channel:        { type: "string" },
                  impact:         { type: "integer" },
                  confidence:     { type: "integer" },
                  effort:         { type: "integer" },
                  execution_note: { type: "string" }
                },
                required: %w[name hypothesis channel impact confidence effort execution_note]
              }
            }
          },
          required: %w[experiments]
        }
      }
    )

    parsed = JSON.parse(raw_json)
    experiments = parsed["experiments"] || raise(JSON::ParserError, "missing experiments key")

    experiments.each_with_index do |exp, i|
      @launch_context.growth_experiments.create!(
        user:           current_user,
        name:           exp["name"],
        hypothesis:     exp["hypothesis"],
        channel:        exp["channel"],
        impact:         exp["impact"],
        confidence:     exp["confidence"],
        effort:         exp["effort"],
        execution_note: exp["execution_note"],
        status:         "idea",
        gemini_raw:     i == 0 ? raw_json : nil
      )
    end

    redirect_to @launch_context

  rescue JSON::ParserError => e
    Rails.logger.error("GrowthTester JSON parse failure: #{e.message} | raw (first 500): #{raw_json.to_s[0..500].inspect}")
    @launch_context.destroy
    flash.now[:alert] = "The AI returned an unexpected format. Please try again."
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
    sort_col = %w[name channel impact confidence effort ice_total status].include?(params[:sort]) ? params[:sort] : "ice_total"
    sort_dir = params[:dir] == "asc" ? "asc" : "desc"

    @experiments = if sort_col == "ice_total"
      direction = sort_dir == "asc" ? 1 : -1
      @launch_context.growth_experiments.to_a.sort_by { |e| direction * e.ice_total }
    else
      @launch_context.growth_experiments.order("#{sort_col} #{sort_dir}")
    end

    @raw_response = @launch_context.growth_experiments.where.not(gemini_raw: nil).first&.gemini_raw
    @sort_col = sort_col
    @sort_dir = sort_dir
  end

  def destroy
    @launch_context.destroy
    redirect_to launch_contexts_path, notice: "Backlog deleted."
  end

  private

  def set_launch_context
    @launch_context = current_user.launch_contexts.find(params[:id])
  end

  def launch_context_params
    params.require(:launch_context).permit(:product_name, :description, :target_audience, :growth_challenge)
  end
end
