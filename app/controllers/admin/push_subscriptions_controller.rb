module Admin
  class PushSubscriptionsController < BaseController
    def create
      subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
      subscription.assign_attributes(
        user: current_user,
        p256dh: subscription_params[:p256dh],
        auth_key: subscription_params[:auth_key],
        user_agent: request.user_agent.to_s.truncate(255),
        last_used_at: Time.current
      )

      if subscription.save
        head :created
      else
        render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      current_user.push_subscriptions.where(endpoint: params[:endpoint]).destroy_all

      head :no_content
    end

    private

    def subscription_params
      params.require(:subscription).permit(:endpoint, :p256dh, :auth_key)
    end
  end
end
