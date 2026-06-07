class TripsController < ApplicationController
  def new
  end

  def show
    @trip = Trip.includes(:footprints).find_by(public_uid: params[:id])

    if @trip.present?
      if @trip.user_id == current_user&.id || @trip.visibility_unlisted? || @trip.visibility_public?

        respond_to do |format|
          format.html do
            @first_footprint = @trip.footprints.first
            @visited_geohashes =  @trip.footprints.distinct.pluck(:geohash)
            render
          end

          format.json do
            posts_scope = @trip.user_id == current_user&.id ? @trip.posts : @trip.posts.where(visibility: %i[ public inherit_trip ])
            @posts = posts_scope.includes(images_attachments: :blob)

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
        flash[:alert] = "地図が見つかりませんでした"
        redirect_to trips_path
      end
    else
      flash[:alert] = "地図が見つかりませんでした"
      redirect_to trips_path
    end
  end

  def index
    if user_signed_in?
      @trips = current_user.trips.order(started_at: :desc)
      @posts_counts = Post.where(trip_id: @trips.select(:id)).group(:trip_id).count
      @geohash_counts = Footprint.where(trip_id: @trips.select(:id)).group(:trip_id).distinct.count(:geohash)
    else
      # flash[:alert] = "この機能はゲストか会員しか使えません"
      # redirect_to root_path
    end
  end

  def edit_title
    @trip = current_user&.trips&.find_by(public_uid: params[:id])

    if @trip.nil?
      respond_modal("shared/flash_message", flash_message: { alert: "権限がありません" })
      return
    end

    respond_modal
  end

  def update_title
    @trip = current_user&.trips&.find_by(public_uid: params[:id])

    if @trip.nil?
      respond_modal("shared/flash_message", flash_message: { alert: "権限がありません" })
      return
    end

    if @trip.update(title: trip_param_title[:title])
      respond_modal(flash_message: { notice: "タイトルを更新しました" })
    else
      respond_modal("shared/flash_and_error", locals: { object: @trip }, flash_message: { alert: "タイトルの更新に失敗しました" })
    end
  end

  def edit_status
    @trip = current_user&.trips&.find_by(public_uid: params[:id])

    if @trip.nil?
      respond_modal("shared/flash_message", flash_message: { alert: "権限がありません" })
      return
    end

    respond_modal
  end

  def update_status
    @trip = current_user.trips.find_by(public_uid: params[:id])

    # x に投稿ボタンを押して、公開設定が「自分だけ」以外の時はreturnする
    return if params.dig(:trip, :x) && !@trip.visibility_private?

    if @trip.nil?
      respond_modal("shared/flash_message", flash_message: { alert: "不正な Trip Id が検出されました" })
      return
    end

    if @trip.update(trip_param_status)
      respond_modal(flash_message: { notice: "公開設定を更新しました" })
    else
      respond_modal("shared/flash_message", flash_message: { alert: "公開設定の更新に失敗しました" })
    end
  rescue ArgumentError => e
    Rails.logger.warn "不正なEnum値によるエラー: #{e.message}"

    respond_modal("shared/flash_message", flash_message: { alert: "公開設定に不正な値が指定されました" })
  end

  def confirm_destroy
    @trip = current_user&.trips&.find_by(public_uid: params[:id])

    unless @trip
      respond_modal("shared/flash_message", flash_message: { alert: "削除できません" })
      return
    end

    respond_modal
  end

  def destroy
    @trip = current_user.trips.find_by(public_uid: params[:id])

    if @trip.nil?
      respond_modal("shared/flash_message", flash_message: { alert: "この地図は削除できません" })
      return
    end

    @trip_dom_id = helpers.dom_id(@trip)

    is_current_trip_page = request.referer.to_s.include?(@trip.public_uid)

    if @trip.destroy
      if is_current_trip_page
        redirect_to trips_path, notice: "地図を削除しました", status: :see_other
      else
        respond_modal(flash_message: { notice: "地図を削除しました" })
      end
    else
      respond_modal("shared/flash_and_error", locals: { object: @trip }, flash_message: { alert: "地図の削除に失敗しました" })
    end
  end

  private

  def trip_param_status
    params.require(:trip).permit(:status)
  end

  def trip_param_title
    params.require(:trip).permit(:title)
  end
end
