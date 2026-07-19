# frozen_string_literal: true

module Admin
  module Dashboard
    class MonthlyFinanceChart < Phlex::HTML
      def initialize(months:, income_total:, expense_total:)
        @months = months
        @income_total = income_total
        @expense_total = expense_total
      end

      def view_template
        section(class: "rounded-[1.75rem] border border-slate-200 bg-white p-5 shadow-sm lg:p-6") do
          header
          chart_panel
        end
      end

      private

      def header
        div(class: "flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between") do
          div do
            p(class: "text-xs font-black uppercase tracking-[0.22em] text-slate-400") { "Monthly Overview" }
            h2(class: "mt-2 text-xl font-black text-slate-950 lg:text-2xl") { "Income vs Expense" }
            p(class: "mt-1 text-sm text-slate-500") { "Last 6 months finance trend." }
          end

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
        div(class: "mt-5 rounded-[1.5rem] border border-slate-100 bg-slate-50/80 p-4") do
          legend
          chart
        end
      end

      def legend
        div(class: "flex items-center gap-4") do
          legend_item(label: "Income", color: "bg-emerald-500")
          legend_item(label: "Expense", color: "bg-rose-500")
        end
      end

      def legend_item(label:, color:)
        div(class: "inline-flex items-center gap-2 text-xs font-black text-slate-600") do
          span(class: "h-2.5 w-2.5 rounded-full #{color}")
          plain label
        end
      end

      def chart
        div(class: "mt-4 min-h-64") do
          raw view_context.column_chart(
            chart_series,
            height: "260px",
            colors: [ "#10b981", "#f43f5e" ],
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
        when :income then "rounded-2xl border border-emerald-100 bg-emerald-50 p-3"
        else "rounded-2xl border border-rose-100 bg-rose-50 p-3"
        end
      end

      def total_label_classes(tone)
        case tone
        when :income then "text-[11px] font-black uppercase tracking-wide text-emerald-700"
        else "text-[11px] font-black uppercase tracking-wide text-rose-700"
        end
      end

      def total_amount_classes(tone)
        case tone
        when :income then "mt-1 truncate text-lg font-black text-emerald-700"
        else "mt-1 truncate text-lg font-black text-rose-700"
        end
      end

      def chart_series
        [
          { name: "Income", data: month_data(:income) },
          { name: "Expense", data: month_data(:expense) }
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
              backgroundColor: "#0f172a",
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
