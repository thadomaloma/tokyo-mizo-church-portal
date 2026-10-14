# frozen_string_literal: true

module Admin
  module Dashboard
    class MonthlyFinanceChart < Phlex::HTML
      def initialize(months:, income_total: nil, expense_total: nil, subtitle: "Kum kal mek chhunga finance kal dan.")
        @months = months
        @income_total = income_total
        @expense_total = expense_total
        @subtitle = subtitle
      end

      def view_template
        section(class: "card card-pad") do
          header
          chart_panel
        end
      end

      private

      def header
        div(class: "flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between") do
          div do
            h2(class: "card-title") { "Sum lut leh sum chhuak" }
            p(class: "card-note mt-0.5") { @subtitle }
          end

          return if @income_total.nil? || @expense_total.nil?

          div(class: "grid grid-cols-2 gap-2 sm:min-w-64") do
            total_card(label: "Income", amount: @income_total, tone: :income)
            total_card(label: "Expense", amount: @expense_total, tone: :expense)
          end
        end
      end

      def total_card(label:, amount:, tone:)
        div(class: total_card_classes(tone)) do
          p(class: total_label_classes(tone)) { label }
          p(class: total_amount_classes(tone)) { yen(amount) }
        end
      end

      def chart_panel
        div(class: "mt-4") do
          legend
          chart
        end
      end

      def legend
        div(class: "flex items-center gap-4") do
          legend_item(label: "Sum lut", color: "bg-emerald-600")
          legend_item(label: "Sum chhuak", color: "bg-rose-600")
        end
      end

      def legend_item(label:, color:)
        div(class: "inline-flex items-center gap-2 text-sm font-medium text-slate-600") do
          span(class: "h-2.5 w-2.5 rounded-full #{color}")
          plain label
        end
      end

      def chart
        div(class: "mt-4 min-h-64") do
          raw view_context.column_chart(
            chart_series,
            height: "260px",
            colors: [ "#059669", "#e11d48" ],
            thousands: ",",
            prefix: "¥",
            legend: false,
            dataset: {
              borderRadius: 8,
              barPercentage: 0.72,
              categoryPercentage: 0.62
            },
            library: chart_options
          )
        end
      end

      def total_card_classes(tone)
        case tone
        when :income then "rounded-2xl border border-emerald-100 bg-emerald-50 p-3 shadow-sm"
        else "rounded-2xl border border-rose-100 bg-rose-50 p-3 shadow-sm"
        end
      end

      def total_label_classes(tone)
        case tone
        when :income then "text-[11px] font-semibold uppercase tracking-wide text-emerald-700"
        else "text-[11px] font-semibold uppercase tracking-wide text-rose-700"
        end
      end

      def total_amount_classes(tone)
        case tone
        when :income then "mt-1 truncate text-lg font-semibold text-emerald-700"
        else "mt-1 truncate text-lg font-semibold text-rose-700"
        end
      end

      def chart_series
        [
          { name: "Sum lut", data: month_data(:income) },
          { name: "Sum chhuak", data: month_data(:expense) }
        ]
      end

      def month_data(key)
        @months.to_h { |month| [ month[:label], month[key].to_i ] }
      end

      def chart_options
        {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            tooltip: {
              backgroundColor: "#0b1f33",
              titleColor: "#ffffff",
              bodyColor: "#ffffff",
              padding: 12,
              displayColors: true
            }
          },
          scales: {
            x: {
              grid: { display: false },
              ticks: { color: "#64748b", font: { weight: "700" } }
            },
            y: {
              beginAtZero: true,
              grid: { color: "#e2e8f0" },
              ticks: {
                color: "#64748b"
              }
            }
          }
        }
      end

      def yen(amount)
        "¥#{amount.to_i.to_fs(:delimited)}"
      end
    end
  end
end
