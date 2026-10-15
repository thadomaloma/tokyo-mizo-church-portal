# Parses a form's { category_id => "12,000" } hash of whole-yen amounts.
# Blank boxes are skipped; anything that is not a whole number is kept as
# :invalid so the caller can report it instead of silently dropping it.
module YenAmounts
  def self.parse(raw)
    raw.to_h.each_with_object({}) do |(key, value), amounts|
      cleaned = value.to_s.delete(",").strip
      next if cleaned.blank?

      amounts[key.to_i] = cleaned.match?(/\A\d+\z/) ? cleaned.to_i : :invalid
    end
  end

  def self.invalid?(amounts)
    amounts.value?(:invalid)
  end
end
