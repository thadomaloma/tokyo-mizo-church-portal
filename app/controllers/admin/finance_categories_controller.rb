module Admin
  class FinanceCategoriesController < BaseController
    before_action :require_finance_admin!
    before_action :set_finance_category, only: [ :edit, :update, :destroy ]

    def index
      @finance_categories = FinanceCategory.order(:category_type, :name)
    end

    def new
      @finance_category = FinanceCategory.new
    end

    def create
      @finance_category = FinanceCategory.new(finance_category_params)

      if @finance_category.save
        redirect_to admin_finance_categories_path, notice: "Finance category was created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @finance_category.update(finance_category_params)
        redirect_to admin_finance_categories_path, notice: "Finance category was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @finance_category.destroy
        redirect_to admin_finance_categories_path, notice: "Finance category was deleted."
      else
        message =
          @finance_category.errors.full_messages.to_sentence.presence ||
          "Finance category cannot be deleted because it is used by finance entries."

        redirect_to admin_finance_categories_path, alert: message
      end
    end

    private

    def set_finance_category
      @finance_category = FinanceCategory.find(params[:id])
    end

    def finance_category_params
      params.require(:finance_category).permit(:name, :category_type)
    end
  end
end
