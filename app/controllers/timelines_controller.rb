class TimelinesController < ApplicationController
  
  def index
  end
  
  def show
    @object = find_timeline_object
    timeline_not_found! unless @object.valid_for_timeline?
  end
  
  
  private
  
  def find_timeline_object
    artsy.send("find_#{params[:type]}", params[:slug])
  end
  
  def timeline_not_found!
    flash.now[:error] = "We couldn't find any dates for that selection! Please try again."
    render :index, status: 404
  end
  
end
