require 'rails_helper'

RSpec.describe "Trips", type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /trips/:id" do
    shared_examples "誰でも閲覧できる地図" do
      it "未ログインユーザーが閲覧できる" do
        get trip_path(trip)

        expect(response).to have_http_status(:ok)
      end

      it "ログイン中の本人が閲覧できる" do
        sign_in owner

        get trip_path(trip)

        expect(response).to have_http_status(:ok)
      end

      it "ログイン中の他人が閲覧できる" do
        sign_in other_user

        get trip_path(trip)

        expect(response).to have_http_status(:ok)
      end
    end

    context "公開地図の場合" do
      let(:trip) { create(:trip, status: :public, user: owner) }

      it_behaves_like "誰でも閲覧できる地図"
    end

    context "限定公開地図の場合" do
      let(:trip) { create(:trip, status: :unlisted, user: owner) }

      it_behaves_like "誰でも閲覧できる地図"
    end

    context "非公開地図の場合" do
      let(:trip) { create(:trip, status: :private, user: owner) }

      it "未ログインユーザーは閲覧できない" do
        get trip_path(trip)

        expect(response).to redirect_to(trips_path)
      end

      it "ログイン中の他人は閲覧できない" do
        sign_in other_user

        get trip_path(trip)

        expect(response).to redirect_to(trips_path)
      end

      it "ログイン中の本人は閲覧できる" do
        sign_in owner

        get trip_path(trip)

        expect(response).to have_http_status(:ok)
      end
    end

    context "地図が存在しない場合" do
      it "地図一覧にリダイレクトされる" do
        get trip_path("not-found-public-uid")

        expect(response).to redirect_to(trips_path)
      end

      it "JSONでも取得できない" do
        get trip_path("not-found-public-uid", format: :json)

        expect(response).to redirect_to(trips_path)
      end
    end
  end

  describe "GET /explore/trips" do
    let!(:public_trip) { create(:trip, status: :public, user: owner, title: "public-trip-title-0000001") }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner, title: "unlisted-trip-title-0000001") }
    let!(:private_trip) { create(:trip, status: :private, user: owner, title: "private-trip-title-0000001") }

    shared_examples "公開地図だけが一覧に表示される" do
      it "公開地図は一覧に表示され、限定公開・非公開地図は表示されない" do
        get explore_trips_path

        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(public_trip.title)
          expect(response.body).not_to include(unlisted_trip.title)
          expect(response.body).not_to include(private_trip.title)
        end
      end
    end

    context "未ログインユーザーの場合" do
      it_behaves_like "公開地図だけが一覧に表示される"
    end

    context "地図作成者がログイン中の場合" do
      before do
        sign_in owner
      end

      it_behaves_like "公開地図だけが一覧に表示される"
    end

    context "地図作成者以外がログイン中の場合" do
      before do
        sign_in other_user
      end

      it_behaves_like "公開地図だけが一覧に表示される"
    end
  end

  describe "GET /trips" do
    let!(:public_trip) { create(:trip, status: :public, user: owner, title: "public-trip-title-0000001") }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner, title: "unlisted-trip-title-0000001") }
    let!(:private_trip) { create(:trip, status: :private, user: owner, title: "private-trip-title-0000001") }

    shared_examples "全ての公開設定の地図が一覧に表示される" do
      it "公開・限定公開・非公開地図が全て表示される" do
        get trips_path

        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(public_trip.title)
          expect(response.body).to include(unlisted_trip.title)
          expect(response.body).to include(private_trip.title)
        end
      end
    end

    shared_examples "全ての公開設定の地図が一覧に表示されない" do
      it "公開・限定公開・非公開地図が全て表示されない" do
        get trips_path

        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include(public_trip.title)
          expect(response.body).not_to include(unlisted_trip.title)
          expect(response.body).not_to include(private_trip.title)
        end
      end
    end

    context "未ログインユーザーの場合" do
      it_behaves_like "全ての公開設定の地図が一覧に表示されない"
    end

    context "地図作成者がログイン中の場合" do
      before do
        sign_in owner
      end

      it_behaves_like "全ての公開設定の地図が一覧に表示される"
    end

    context "地図作成者以外がログイン中の場合" do
      before do
        sign_in other_user
      end

      it_behaves_like "全ての公開設定の地図が一覧に表示されない"
    end
  end

  describe "GET /trips/:id.json" do
    shared_examples "地図が公開・限定公開の場合に表示する投稿" do
      it "未ログインユーザーには公開投稿と地図に合わせる投稿だけをGeoJSONで返す" do
        get trip_path(trip, format: :json)

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        public_uids = json["features"].map { |feature| feature["properties"]["public_uid"] }

        aggregate_failures do
          expect(public_uids).to include(public_post.public_uid)
          expect(public_uids).to include(inherit_post.public_uid)
          expect(public_uids).not_to include(private_post.public_uid)
        end
      end

      it "ログイン中の地図作成者には全ての投稿をGeoJSONで返す" do
        sign_in owner

        get trip_path(trip, format: :json)

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        public_uids = json["features"].map { |feature| feature["properties"]["public_uid"] }

        aggregate_failures do
          expect(public_uids).to include(public_post.public_uid)
          expect(public_uids).to include(inherit_post.public_uid)
          expect(public_uids).to include(private_post.public_uid)
        end
      end

      it "ログイン中の他人には公開投稿と地図に合わせる投稿だけをGeoJSONで返す" do
        sign_in other_user

        get trip_path(trip, format: :json)

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        public_uids = json["features"].map { |feature| feature["properties"]["public_uid"] }

        aggregate_failures do
          expect(public_uids).to include(public_post.public_uid)
          expect(public_uids).to include(inherit_post.public_uid)
          expect(public_uids).not_to include(private_post.public_uid)
        end
      end
    end

    context "公開地図の場合" do
      let(:trip) { create(:trip, status: :public, user: owner) }
      let!(:public_post) { create(:post, visibility: :public, trip: trip, user: owner) }
      let!(:inherit_post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner) }
      let!(:private_post) { create(:post, visibility: :private, trip: trip, user: owner) }

      it_behaves_like "地図が公開・限定公開の場合に表示する投稿"
    end

    context "限定公開地図の場合" do
      let(:trip) { create(:trip, status: :unlisted, user: owner) }
      let!(:public_post) { create(:post, visibility: :public, trip: trip, user: owner) }
      let!(:inherit_post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner) }
      let!(:private_post) { create(:post, visibility: :private, trip: trip, user: owner) }

      it_behaves_like "地図が公開・限定公開の場合に表示する投稿"
    end

    context "非公開地図の場合" do
      let(:trip) { create(:trip, status: :private, user: owner) }
      let!(:public_post) { create(:post, visibility: :public, trip: trip, user: owner) }
      let!(:inherit_post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner) }
      let!(:private_post) { create(:post, visibility: :private, trip: trip, user: owner) }

      it "ログイン中の本人には全ての投稿をGeoJSONで返す" do
        sign_in owner

        get trip_path(trip, format: :json)

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        public_uids = json["features"].map { |feature| feature["properties"]["public_uid"] }

        aggregate_failures do
          expect(public_uids).to include(public_post.public_uid)
          expect(public_uids).to include(inherit_post.public_uid)
          expect(public_uids).to include(private_post.public_uid)
        end
      end

      it "ログイン中の他人はJSONを取得できない" do
        sign_in other_user

        get trip_path(trip, format: :json)

        expect(response).to redirect_to(trips_path)
      end

      it "未ログインの人はJSONを取得できない" do
        get trip_path(trip, format: :json)

        expect(response).to redirect_to(trips_path)
      end
    end
  end
end
