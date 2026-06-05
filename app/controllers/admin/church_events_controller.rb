module Admin
  class ChurchEventsController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_church_event, only: %i[show edit update destroy]

    def index
      @church_events = ChurchEvent.order(start_date: :asc)
    end

    def show; end

    def new
      @church_event = ChurchEvent.new
    end

    def create
      @church_event = ChurchEvent.new(church_event_params)
      @church_event.created_by = current_user

      if @church_event.save
        notify("New Church Event", "#{current_user.name} added event: #{@church_event.title}.")
        redirect_to admin_church_events_path, notice: "Church event was created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @church_event.update(church_event_params)
        notify("Church Event Updated", "#{current_user.name} updated event: #{@church_event.title}.")
        redirect_to admin_church_events_path, notice: "Church event was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @church_event.destroy
      redirect_to admin_church_events_path, notice: "Church event was deleted."
    end

    private

    def set_church_event
      @church_event = ChurchEvent.find(params[:id])
    end

    def church_event_params
      params.require(:church_event).permit(
        :title,
        :start_date,
        :end_date,
        :location,
        :description
      )
    end

    def notify(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "church_event",
        link: admin_church_events_path
      )
    end
  end
end
