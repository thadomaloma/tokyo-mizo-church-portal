module Admin
  # Activity: the change log of every finance unit the user can see.
  class ActivitiesController < BaseController
    before_action :require_finance_access!

    def index
      @unit_filter = available_finance_units.find_by(id: params[:unit].presence)
      @kind_filter = params[:kind].presence_in(ActivityFeed::KINDS.keys)
      @feed = ActivityFeed.new(finance_units: @unit_filter ? [ @unit_filter ] : available_finance_units,
                               user_id: params[:user_id].presence, kind: @kind_filter)
      @people = @feed.people
      @user_filter = @people.find { |person| person.id.to_s == params[:user_id] }

      @pagy, @events = pagy(@feed.events, limit: 25)
      redirect_past_last_page?(@pagy)
    end
  end
end
