module Admin
  # Income/expense report for any run of months, on screen or exported as
  # PDF or Excel. The monthly treasurer statement lives in FinancePeriods.
  class FinanceReportsController < BaseController
    LEDGER_TYPES = %w[all income expense].freeze

    before_action :require_finance_access!
    before_action :set_scope
    before_action :set_period

    def show
      @ledger_type = params[:ledger_type].presence_in(LEDGER_TYPES) || "all"
      @ledger_type_label = @ledger_type == "all" ? "All Transactions" : "#{@ledger_type.humanize} Transactions"

      period_transactions = @finance_scope.income_or_expense.where(transaction_date: @period.range)
                                          .includes(:finance_category, :finance_unit, :recorded_by).latest
      transactions = @ledger_type == "all" ? period_transactions : period_transactions.where(transaction_type: @ledger_type)
      @income = transactions.income.sum(:amount)
      @expense = transactions.expense.sum(:amount)
      @balance = @income - @expense

      respond_to do |format|
        format.html do
          @pagy, @ledger_transactions = pagy(transactions, limit: 12)
          load_overview(period_transactions)
        end
        format.pdf do
          send_data FinanceReportPdf.new(transactions: transactions.to_a, **report_arguments).render,
                    filename: "#{export_basename}.pdf", type: "application/pdf", disposition: "attachment"
        end
        format.xlsx do
          @transactions = transactions.to_a
          @finance_report_data = FinanceReportData.new(transactions: @transactions, **report_arguments.slice(
            :income, :expense, :balance, :period_year, :start_month, :end_month, :account_balances
          ))
          response.headers["Content-Disposition"] = "attachment; filename=#{export_basename}.xlsx"
        end
      end
    end

    private

    def set_scope
      if params[:finance_unit_id] == "all" && current_user.super_admin?
        @finance_unit = nil
        @finance_unit_selector = "all"
        @finance_unit_label = "Consolidated Finance"
        @bank_label = "Bank"
        @finance_scope = FinanceTransaction.where(finance_unit: available_finance_units)
      else
        @finance_unit = current_finance_unit
        @finance_unit_selector = @finance_unit.id
        @finance_unit_label = @finance_unit.name
        @bank_label = @finance_unit.account_label("bank")
        @finance_scope = @finance_unit.finance_transactions
      end
    end

    def set_period
      @period = ReportPeriod.from_params(params)
      @period_year, @start_month, @end_month = @period.year, @period.start_month, @period.end_month
      @period_label = @period.label
      @period_caption = @period.caption
      @month_options = (1..12).map { |month| [ Date::MONTHNAMES[month], month ] }
      @year_options = (@finance_scope.distinct.pluck(:transaction_date).map(&:year) + [ Date.current.year ]).uniq.sort.reverse
    end

    def report_arguments
      {
        income: @income, expense: @expense, balance: @balance, period_label: @period.label,
        period_year: @period.year, start_month: @period.start_month, end_month: @period.end_month,
        ledger_type_label: @ledger_type_label, finance_unit_label: @finance_unit_label, bank_label: @bank_label,
        account_balances: closing_account_balances
      }
    end

    # Change against the previous period of the same length, monthly cash
    # flow, and where the money went.
    def load_overview(period_transactions)
      previous = @finance_scope.income_or_expense.where(transaction_date: @period.previous_range)
      @previous_income = previous.income.sum(:amount)
      @previous_expense = previous.expense.sum(:amount)
      @previous_period_label = @period.previous_label

      rows = period_transactions.reorder(nil).pluck(:transaction_type, :transaction_date, :amount)
      @monthly_cash_flow = @period.months.map do |month|
        in_month = rows.select { |_, date, _| date.month == month.month }
        {
          label: month.strftime("%b"),
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
    # period, across every unit the report covers.
    def closing_account_balances
      units = @finance_unit ? [ @finance_unit ] : available_finance_units.to_a
      summaries = units.map { |unit| FinanceSummary.new(unit) }

      FinanceTransaction::LOCATIONS.to_h do |location|
        [ location, summaries.sum { |summary| summary.account_balance(location, on: @period.end_date) } ]
      end
    end

    def export_basename
      "tokyo_mizo_church_#{@finance_unit&.slug || 'consolidated-finance'}_finance_report_#{@ledger_type}_#{@period.filename}"
    end
  end
end
