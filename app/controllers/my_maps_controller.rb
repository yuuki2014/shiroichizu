class MyMapsController < ApplicationController
  def show
    if user_signed_in?
      respond_to do |format|
        format.html do
          @first_footprint = current_user&.footprints.first
          @visited_geohashes = current_user&.cumulative_geohashes || []
          @posts = current_user&.posts || []
        end

        format.json do
          @posts = current_user.posts.includes(images_attachments: :blob)

          features = @posts&.map do |post|
            {
              type: "Feature",
              geometry: {
                type: "Point",
                coordinates: [ post.longitude, post.latitude ]
              },
              properties: {
                public_uid: post.public_uid,
                icon_url: post.images.attached? ? helpers.media_image_url(post.images.first.variant(:map_icon).key) : "",
                is_icon_loaded: false
              }
            }
          end

          MediaAccessGrantService.call(posts: @posts, cookies: cookies)
          render json: {
            type: "FeatureCollection",
            features: features
          }
        end
      end
    else
      flash[:alert] = "この機能はゲストか会員しか使えません"
      redirect_to new_user_session_path
    end
  end
end
