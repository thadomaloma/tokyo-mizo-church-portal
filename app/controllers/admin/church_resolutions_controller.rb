module Admin
  class ChurchResolutionsController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_church_resolution, only: %i[show edit update destroy mark_completed]

    def index
      @church_resolutions = ChurchResolution.includes(:assigned_to, :meeting_minute).latest
    end

    def show; end

    def new
      @church_resolution = ChurchResolution.new(status: :pending, priority: :normal)
      load_options
    end

    def create
      @church_resolution = ChurchResolution.new(church_resolution_params)

      if @church_resolution.save
        notify("New Resolution", "#{current_user.name} added resolution: #{@church_resolution.title}.")
        redirect_to admin_church_resolutions_path, notice: "Resolution was created."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_options
    end

    def update
      if @church_resolution.update(church_resolution_params)
        notify("Resolution Updated", "#{current_user.name} updated resolution: #{@church_resolution.title}.")
        redirect_to admin_church_resolutions_path, notice: "Resolution was updated."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_completed
      @church_resolution.update!(status: :completed, completed_at: Time.current)
      notify("Resolution Completed", "#{current_user.name} completed resolution: #{@church_resolution.title}.")
      redirect_to admin_church_resolutions_path, notice: "Resolution was marked completed."
    end

    def destroy
      @church_resolution.destroy
      redirect_to admin_church_resolutions_path, notice: "Resolution was deleted."
    end

    private

    def set_church_resolution
      @church_resolution = ChurchResolution.find(params[:id])
    end

    def load_options
      @users = User.active.order(:name)
      @meeting_minutes = MeetingMinute.latest
    end

    def church_resolution_params
      params.require(:church_resolution).permit(
        :title,
        :description,
        :status,
        :priority,
        :due_date,
        :meeting_minute_id,
        :assigned_to_id
      )
    end

    def notify(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "resolution",
        link: admin_church_resolutions_path
      )
    end
  end
end
