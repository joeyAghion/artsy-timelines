class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :check_hostname
  
  helper_method :artsy
  
  
  protected
  
  def check_hostname
    return unless Figaro.env.respond_to?(:hostname) && Figaro.env.hostname.present?
    redirect_to (request.protocol + Figaro.env.hostname + request.fullpath) if request.host_with_port != Figaro.env.hostname
  end
  
  def artsy
    @artsy ||= Artsy::Client.new xapp_token: Figaro.env.artsy_xapp_token
  end
  
  def not_found!
    raise ActionController::RoutingError.new("Not Found")
  end
end
