module Admin
  class OfficialLettersController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_official_letter, only: %i[show edit update destroy]

    def index
      @year = params[:year].presence&.to_i
      @status_filter = params[:status].presence_in(OfficialLetter.statuses.keys)
      @query = params[:q].presence

      letters = OfficialLetter.includes(:church_resolution).latest
      letters = letters.where(status: @status_filter) if @status_filter
      letters = letters.where("EXTRACT(YEAR FROM letter_date) = ?", @year) if @year
      letters = search_letters(letters, @query) if @query

      @pagy, @official_letters = pagy(letters, limit: 10)
      @year_options = OfficialLetter.where.not(letter_date: nil).pluck(:letter_date).map(&:year).uniq.sort.reverse
    end

    def show
      respond_to do |format|
        format.html
        format.pdf do
          pdf = OfficialLetterPdf.new(@official_letter)

          send_data pdf.render,
                    filename: "#{pdf_filename(@official_letter)}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end
      end
    end

    def new
      @official_letter = OfficialLetter.new(
        status: :draft,
        letter_date: Date.current,
        salutation: "Rawngbawlpui duhtak,",
        closing_line: "Lawmthu nen,",
        header_president_name: User.active.role_president.first&.name,
        header_secretary_name: User.active.role_secretary.first&.name,
        header_email: "admin@tokyomizochurch.org",
        header_website: "tokyomizochurch.org"
      )
      @official_letter.church_resolution_id = params[:church_resolution_id] if params[:church_resolution_id].present?
      load_options
    end

    def create
      @official_letter = OfficialLetter.new(official_letter_params)
      @official_letter.created_by = current_user

      if @official_letter.save
        notify("New Official Letter", "#{current_user.name} in letter #{@official_letter.reference_number}: #{@official_letter.subject} a siam.")
        redirect_to admin_official_letter_path(@official_letter), notice: "Official letter siam fel a ni."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_options
    end

    def update
      if @official_letter.update(official_letter_params)
        notify("Official Letter Updated", "#{current_user.name} in letter #{@official_letter.reference_number} a siam tha.")
        redirect_to admin_official_letter_path(@official_letter), notice: "Official letter siamthat fel a ni."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @official_letter.destroy
      redirect_to admin_official_letters_path, notice: "Official letter delete fel a ni."
    end

    private

    def set_official_letter
      @official_letter = OfficialLetter.find(params[:id])
    end

    def pdf_filename(official_letter)
      [ official_letter.reference_number, official_letter.subject ].compact.join("-").parameterize
    end

    def load_options
      @church_resolutions = ChurchResolution.latest
    end

    def search_letters(letters, query)
      pattern = "%#{query}%"
      letters.where(
        "recipient_name ILIKE :q OR subject ILIKE :q OR reference_number ILIKE :q",
        q: pattern
      )
    end

    def official_letter_params
      params.require(:official_letter).permit(
        :letter_date,
        :header_president_name,
        :header_secretary_name,
        :header_president_phone,
        :header_secretary_phone,
        :header_email,
        :header_website,
        :recipient_name,
        :recipient_organization,
        :recipient_address,
        :subject,
        :body,
        :salutation,
        :closing_line,
        :signatory_name,
        :signatory_role,
        :status,
        :church_resolution_id
      )
    end

    def notify(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "official_letter",
        link: admin_official_letters_path
      )
    end
  end
end
