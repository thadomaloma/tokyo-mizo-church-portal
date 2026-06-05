module Admin
  class MeetingMinutesController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_meeting_minute, only: %i[show edit update destroy]
    before_action :set_attendance_members, only: %i[new edit create update]

    def index
      @meeting_minutes = MeetingMinute.regular_records.latest.with_attached_pdf_file
      @archived_minutes = MeetingMinute.pdf_archives.latest.with_attached_pdf_file
    end

    def show
      respond_to do |format|
        format.html
        format.pdf do
          pdf = MeetingMinutePdf.new(@meeting_minute)

          send_data pdf.render,
                    filename: "#{pdf_filename(@meeting_minute)}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end
      end
    end

    def new
      @meeting_minute = MeetingMinute.new
    end

    def new_archive
      @meeting_minute = MeetingMinute.new(archive_only: true)
    end

    def create
      @meeting_minute = MeetingMinute.new(meeting_minute_params)
      @meeting_minute.uploaded_by = current_user

      if @meeting_minute.save
        if @meeting_minute.archive_only?
          notify("Minute PDF Archived", "#{current_user.name} archived #{@meeting_minute.title}.")
          redirect_to admin_meeting_minutes_path, notice: "Minute PDF archived."
        else
          notify("New Meeting Minutes", "#{current_user.name} recorded #{@meeting_minute.meeting_type} minutes.")
          redirect_to admin_meeting_minutes_path, notice: "Meeting minutes recorded."
        end
      else
        render @meeting_minute.archive_only? ? :new_archive : :new,
               status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @meeting_minute.update(meeting_minute_params)
        notify("Meeting Minutes Updated", "#{current_user.name} updated #{@meeting_minute.title}.")
        redirect_to admin_meeting_minutes_path, notice: "Meeting minutes updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @meeting_minute.destroy
      redirect_to admin_meeting_minutes_path, notice: "Meeting minutes deleted."
    end

    private

    def set_meeting_minute
      @meeting_minute = MeetingMinute.find(params[:id])
    end

    def meeting_minute_params
      params.require(:meeting_minute).permit(
        :title,
        :meeting_type,
        :meeting_date,
        :location,
        :start_time,
        :end_time,
        :chairperson,
        :secretary_name,
        :attendees,
        :absentees,
        :guests,
        :quorum_status,
        :call_to_order,
        :opening_prayer,
        :previous_minutes,
        :agenda_items,
        :old_business,
        :new_business,
        :correspondence,
        :reports,
        :safeguarding_notes,
        :motions,
        :action_items,
        :any_other_business,
        :next_meeting_date,
        :adjournment,
        :approved_by,
        :archive_only,
        :description,
        :pdf_file,
        :secretary_signature,
        present_member_ids: []
      )
    end

    def set_attendance_members
      @attendance_members = User.active.order(:role, :name)
    end

    def pdf_filename(meeting_minute)
      [
        "meeting-minute",
        meeting_minute.meeting_date&.strftime("%Y-%m-%d"),
        meeting_minute.title
      ].compact.join("-").parameterize
    end

    def notify(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "meeting_minutes",
        link: admin_meeting_minutes_path
      )
    end
  end
end
