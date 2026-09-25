module Admin
  class ChurchResolutionsController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_church_resolution, only: %i[show edit update destroy mark_completed]

    def index
      @status_filter = params[:status].presence_in(ChurchResolution.statuses.keys)
      @year = params[:year].presence&.to_i
      @assigned_to_id = params[:assigned_to_id].presence

      resolutions = ChurchResolution.includes(:assigned_to, :meeting_minute).latest
      resolutions = resolutions.where(status: @status_filter) if @status_filter
      resolutions = resolutions.where("EXTRACT(YEAR FROM created_at) = ?", @year) if @year
      resolutions = resolutions.where(assigned_to_id: @assigned_to_id) if @assigned_to_id

      @pending_count = ChurchResolution.where(status: :pending).count
      @in_progress_count = ChurchResolution.where(status: :in_progress).count
      @completed_count = ChurchResolution.where(status: :completed).count
      @overdue_count = ChurchResolution.overdue.count

      @pagy, @church_resolutions = pagy(resolutions, limit: 10)
      @assignable_users = User.active.order(:name)
      @year_options = ChurchResolution.pluck(:created_at).map(&:year).uniq.sort.reverse
    end

    def show
      respond_to do |format|
        format.html
        format.pdf do
          pdf = ChurchResolutionPdf.new(@church_resolution)

          send_data pdf.render,
                    filename: "#{pdf_filename(@church_resolution)}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end
      end
    end

    def new
      @church_resolution = ChurchResolution.new(status: :pending, priority: :normal)
      @church_resolution.meeting_minute_id = params[:meeting_minute_id] if params[:meeting_minute_id].present?
      load_options
    end

    def create
      @church_resolution = ChurchResolution.new(church_resolution_params)

      if @church_resolution.save
        notify("New Resolution", "#{current_user.name} in resolution a dah: #{@church_resolution.title}.")
        redirect_to admin_church_resolutions_path, notice: "Resolution siam fel a ni."
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
        notify("Resolution Updated", "#{current_user.name} in resolution a siam tha: #{@church_resolution.title}.")
        redirect_to admin_church_resolutions_path, notice: "Resolution siamthat fel a ni."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_completed
      @church_resolution.update!(status: :completed, completed_at: Time.current)
      notify("Resolution Completed", "#{current_user.name} in resolution a complete: #{@church_resolution.title}.")
      redirect_to admin_church_resolutions_path, notice: "Resolution chu completed anga dah a ni."
    end

    def destroy
      @church_resolution.destroy
      redirect_to admin_church_resolutions_path, notice: "Resolution delete fel a ni."
    end

    private

    def set_church_resolution
      @church_resolution = ChurchResolution.find(params[:id])
    end

    def pdf_filename(church_resolution)
      [ church_resolution.number, church_resolution.title ].compact.join("-").parameterize
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
