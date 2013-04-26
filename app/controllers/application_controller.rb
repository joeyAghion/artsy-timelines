class ApplicationController < ActionController::Base
  protect_from_forgery
  
  helper_method :artsy
  
  
  protected
  
  def artsy
    @artsy ||= Artsy::Client.new xapp_token: Figaro.env.artsy_xapp_token
  end
  
  def not_found!
    raise ActionController::RoutingError.new("Not Found")
  end
end
