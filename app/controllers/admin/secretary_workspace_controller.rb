module Admin
  class SecretaryWorkspaceController < BaseController
    RECENT_LIMIT = 5

    def show
      @recent_minutes = MeetingMinute.regular_records.latest.limit(RECENT_LIMIT)
      @pending_resolutions = ChurchResolution.includes(:assigned_to, :meeting_minute)
                                              .where(status: %i[pending in_progress])
                                              .latest
                                              .limit(RECENT_LIMIT)
      @overdue_resolutions = ChurchResolution.includes(:assigned_to).overdue.latest.limit(RECENT_LIMIT)
      @recent_letters = OfficialLetter.includes(:church_resolution).latest.limit(RECENT_LIMIT)
    end
  end
end
