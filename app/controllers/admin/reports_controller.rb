module Admin
  class ReportsController < BaseController
    before_action :require_finance_access!, only: :finance

    # Reports open on this month's treasurer statement; the custom-period
    # ledger with PDF/Excel export lives at #finance.
    def index
      redirect_to admin_finance_period_path(Date.current.year, Date.current.month,
                                            finance_unit_id: params[:finance_unit_id].presence)
    end

    def finance
      configure_finance_report_scope
      @period_year = selected_finance_year
      @start_month = selected_finance_month(:start_month, 1)
      @end_month = selected_finance_month(:end_month, Date.current.month)
      @start_month, @end_month = [ @start_month, @end_month ].minmax
      @period_label = finance_period_label(@period_year, @start_month, @end_month)
      @period_caption = finance_period_caption(@period_year, @start_month, @end_month)
      @month_options = finance_month_options
      @year_options = finance_year_options
      @ledger_type = selected_ledger_type
      @ledger_type_label = @ledger_type == "all" ? "All Transactions" : "#{@ledger_type.humanize} Transactions"

      period_transactions = finance_transactions_for_period(@period_year, @start_month, @end_month)
      transactions = filter_transactions_by_type(period_transactions)
      @income = transactions.income.sum(:amount)
      @expense = transactions.expense.sum(:amount)
      @balance = @income - @expense

      respond_to do |format|
        format.html do
          @pagy, @ledger_transactions = pagy(transactions, limit: 12)
          load_period_overview(period_transactions)
        end

        format.pdf do
          report_transactions = transactions.to_a
          pdf = FinanceReportPdf.new(
            transactions: report_transactions,
            income: @income,
            expense: @expense,
            balance: @balance,
            period_label: @period_label,
            period_year: @period_year,
            start_month: @start_month,
            end_month: @end_month,
            ledger_type_label: @ledger_type_label,
            finance_unit_label: @finance_unit_label,
            account_balances: closing_account_balances
          )

          send_data pdf.render,
                    filename: "tokyo_mizo_church_#{finance_unit_filename}_finance_report_#{@ledger_type}_#{finance_period_filename}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end

        format.xlsx do
          @transactions = transactions.to_a
          @finance_report_data = FinanceReportData.new(
            transactions: @transactions,
            income: @income,
            expense: @expense,
            balance: @balance,
            period_year: @period_year,
            start_month: @start_month,
            end_month: @end_month,
            account_balances: closing_account_balances
          )

          response.headers[
            "Content-Disposition"
          ] = "attachment; filename=tokyo_mizo_church_#{finance_unit_filename}_finance_report_#{@ledger_type}_#{finance_period_filename}.xlsx"
        end
      end
    end

    private

    # Sumvon-style overview for the on-screen report: change against the
    # previous period of the same length, and where the money went.
    def load_period_overview(period_transactions)
      period_start = Date.new(@period_year, @start_month, 1)
      month_count = @end_month - @start_month + 1
      previous = @finance_scope.income_or_expense
                               .where(transaction_date: (period_start << month_count)...period_start)
      @previous_income = previous.income.sum(:amount)
      @previous_expense = previous.expense.sum(:amount)
      @previous_period_label = finance_period_label((period_start << month_count).year,
                                                    (period_start << month_count).month,
                                                    (period_start - 1).month)

      rows = period_transactions.reorder(nil).pluck(:transaction_type, :transaction_date, :amount)
      @monthly_cash_flow = (@start_month..@end_month).map do |month|
        in_month = rows.select { |_, date, _| date.month == month }
        {
          label: Date::ABBR_MONTHNAMES[month],
          income: in_month.sum { |type, _, amount| type == "income" ? amount : 0 },
          expense: in_month.sum { |type, _, amount| type == "expense" ? amount : 0 }
        }
      end

      totals = period_transactions.expense.reorder(nil).group(:finance_category_id).sum(:amount)
      names = FinanceCategory.where(id: totals.keys).pluck(:id, :name).to_h
      @expense_by_category = totals.map { |id, amount| [ names.fetch(id, "No Category"), amount ] }
                                   .sort_by { |_, amount| -amount }
    end

    # Real Cash and Bank balances (transfers included) at the end of the
    # selected period, across every unit the report covers.
    def closing_account_balances
      period_end = Date.new(@period_year, @end_month, -1)
      units = @finance_unit ? [ @finance_unit ] : available_finance_units.to_a
      summaries = units.map { |unit| FinanceSummary.new(unit) }

      FinanceTransaction::LOCATIONS.to_h do |location|
        [ location, summaries.sum { |summary| summary.account_balance(location, on: period_end) } ]
      end
    end

    def selected_finance_year
      year = params[:year].to_i

      return year if year.positive?

      Date.current.year
    end

    def selected_finance_month(param_name, fallback)
      month = params[param_name].to_i

      return month if month.between?(1, 12)

      fallback
    end

    def finance_month_options
      Date::MONTHNAMES.each_with_index.filter_map do |month_name, index|
        [ month_name, index ] if index.positive?
      end
    end

    def finance_year_options
      transaction_years = @finance_scope
                            .where.not(transaction_date: nil)
                            .distinct
                            .pluck(:transaction_date)
                            .map(&:year)

      (transaction_years + [ Date.current.year ]).uniq.sort.reverse
    end

    def finance_period_label(year, start_month, end_month)
      start_name = Date::MONTHNAMES[start_month]
      end_name = Date::MONTHNAMES[end_month]

      return "#{start_name} #{year}" if start_month == end_month

      "#{start_name} - #{end_name} #{year}"
    end

    def finance_period_caption(year, start_month, end_month)
      label = finance_period_label(year, start_month, end_month)
      return label if start_month == end_month

      "#{label}, up to #{Date::MONTHNAMES[end_month]}"
    end

    def selected_ledger_type
      type = params[:ledger_type].to_s

      %w[all income expense].include?(type) ? type : "all"
    end

    def filter_transactions_by_type(transactions)
      case @ledger_type
      when "income" then transactions.income
      when "expense" then transactions.expense
      else transactions
      end
    end

    def finance_period_filename
      "#{@period_year}_#{@start_month.to_s.rjust(2, "0")}_to_#{@end_month.to_s.rjust(2, "0")}_#{Date.current}"
    end

    def finance_transactions_for_period(year, start_month, end_month)
      period_start = Date.new(year, start_month, 1)
      period_end = Date.new(year, end_month, -1)

      transactions = @finance_scope
                       .income_or_expense
                       .includes(:finance_category, :finance_unit, :recorded_by)
                       .order(transaction_date: :desc, created_at: :desc)

      transactions.where(transaction_date: period_start..period_end)
    end

    def configure_finance_report_scope
      if params[:finance_unit_id] == "all" && current_user.super_admin?
        @finance_unit = nil
        @finance_unit_selector = "all"
        @finance_unit_label = "Consolidated Finance"
        @finance_scope = FinanceTransaction.where(finance_unit: available_finance_units)
      else
        @finance_unit = current_finance_unit
        @finance_unit_selector = @finance_unit.id
        @finance_unit_label = @finance_unit.name
        @finance_scope = @finance_unit.finance_transactions
      end
    end

    def finance_unit_filename
      @finance_unit&.slug || "consolidated-finance"
    end
  end
end
