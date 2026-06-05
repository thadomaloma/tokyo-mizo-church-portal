module Admin
  class ResolutionsController < BaseController
    before_action :require_super_admin!, except: [:index, :show]
    before_action :set_resolution, only: [:show, :edit, :update, :destroy, :mark_completed]

    def index
      @resolutions = Resolution.includes(:assigned_to, :meeting_minute).latest
    end

    def show; end

    def new
      @resolution = Resolution.new(status: :pending, priority: :normal)
      load_options
    end

    def create
      @resolution = Resolution.new(resolution_params)

      if @resolution.save
        redirect_to admin_resolutions_path, notice: "Resolution was created."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_options
    end

    def update
      if @resolution.update(resolution_params)
        redirect_to admin_resolutions_path, notice: "Resolution was updated."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_completed
      @resolution.update(status: :completed, completed_at: Time.current)
      redirect_to admin_resolutions_path, notice: "Resolution was marked completed."
    end

    def destroy
      @resolution.destroy
      redirect_to admin_resolutions_path, notice: "Resolution was deleted."
    end

    private

    def set_resolution
      @resolution = Resolution.find(params[:id])
    end

    def load_options
      @users = User.active.order(:name)
      @meeting_minutes = MeetingMinute.latest
    end
end