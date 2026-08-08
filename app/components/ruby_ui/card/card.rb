# frozen_string_literal: true

module RubyUI
  class Card < Base
    def view_template(&)
      div(**attrs, &)
    end

    private

    def default_attrs
      {
        class: "rounded-2xl border border-slate-200/90 bg-white shadow-[0_14px_40px_rgba(15,23,42,0.055)]"
      }
    end
  end
end
