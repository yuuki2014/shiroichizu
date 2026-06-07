class MyMapsController < ApplicationController
  def show
    if user_signed_in?
      @first_footprint = current_user&.footprints.first
      @visited_geohashes = current_user&.cumulative_geohashes || []
      @posts = current_user&.posts || []
    else
      flash[:alert] = "この機能はゲストか会員しか使えません"
      redirect_to new_user_session_path
    end
  end
end
