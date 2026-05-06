class GrowthExperimentsController < ApplicationController
  before_action :set_experiment

  def update_status
    new_status = params[:status]
    if GrowthExperiment::STATUSES.include?(new_status)
      @experiment.update!(status: new_status)
    end
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_experiment
    @experiment = current_user.growth_experiments.find(params[:id])
  end
end
