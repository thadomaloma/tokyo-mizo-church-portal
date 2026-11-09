module Admin
  # The year-end report PDF for one finance unit (see AnnualReport).
  class AnnualReportsController < BaseController
    before_action :require_finance_access!

    def show
      year = params[:year].to_i
      unless year.between?(2000, Date.current.year)
        redirect_to admin_finance_report_path(finance_unit_id: current_finance_unit.id), alert: "There is no report for #{year} yet."
        return
      end

      report = AnnualReport.new(current_finance_unit, year)
      send_data AnnualReportPdf.new(report).render,
                filename: "tokyo_mizo_church_#{current_finance_unit.slug}_annual_report_#{year}.pdf",
                type: "application/pdf", disposition: "attachment"
    end
  end
end
