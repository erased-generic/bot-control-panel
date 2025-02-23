module TokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :verify_access_token
  end

  private

  def verify_access_token
    valid_token = Rails.application.credentials.control_panel_token
    provided_token = params[:token]

    unless valid_token.present? && provided_token == valid_token
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
