# Colours for finance charts. Income/expense are a validated CVD-safe pair
# (blue/orange, adjacent ΔE 19 under protanopia); the green/red money text
# elsewhere always carries a +/− sign, so meaning never rests on colour.
module ChartsHelper
  CHART_COLORS = {
    income: "#3a6ea5",
    expense: "#d8743f",
    context: "#b3bcc8"
  }.freeze

  def chart_color(key)
    CHART_COLORS.fetch(key)
  end
end
