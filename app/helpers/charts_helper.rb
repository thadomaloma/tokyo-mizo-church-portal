# Colours for finance charts. Income/expense are a validated CVD-safe pair
# (indigo/orange, a blue-orange pair that stays apart under protanopia
# and deuteranopia); the green/red money text
# elsewhere always carries a +/− sign, so meaning never rests on colour.
module ChartsHelper
  CHART_COLORS = {
    income: "#4f46e5",
    expense: "#ea7a2f",
    context: "#c4c5d8"
  }.freeze

  def chart_color(key)
    CHART_COLORS.fetch(key)
  end
end
