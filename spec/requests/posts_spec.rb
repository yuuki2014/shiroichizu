require 'rails_helper'

RSpec.describe "Posts", type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:turbo_stream_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

  describe "GET /posts/:id/preview" do
    shared_examples "誰でも閲覧できる投稿" do
      it "未ログインユーザーが閲覧できる" do
        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("投稿本文")
        expect(response.body).not_to include("投稿が見つかりません")
      end

      it "ログイン中の本人が閲覧できる" do
        sign_in owner

        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("投稿本文")
        expect(response.body).not_to include("投稿が見つかりません")
      end

      it "ログイン中の他人が閲覧できる" do
        sign_in other_user

        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("投稿本文")
        expect(response.body).not_to include("投稿が見つかりません")
      end
    end

    shared_examples "作成者本人のみが閲覧できる投稿" do
      it "未ログインユーザーには投稿が存在しないように表示される" do
        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("投稿本文")
        expect(response.body).to include("投稿が見つかりません")
      end

      it "ログイン中の本人が閲覧できる" do
        sign_in owner

        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("投稿本文")
        expect(response.body).not_to include("投稿が見つかりません")
      end

      it "ログイン中の他人には投稿が存在しないように表示される" do
        sign_in other_user

        get preview_post_path(post), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("投稿本文")
        expect(response.body).to include("投稿が見つかりません")
      end
    end

    context "公開地図の場合" do
      let(:trip) { create(:trip, status: :public, user: owner) }

      context "公開投稿の場合" do
        let(:post) { create(:post, visibility: :public, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "誰でも閲覧できる投稿"
      end

      context "地図に合わせる投稿の場合" do
        let(:post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "誰でも閲覧できる投稿"
      end

      context "非公開投稿の場合" do
        let(:post) { create(:post, visibility: :private, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "作成者本人のみが閲覧できる投稿"
      end
    end

    context "限定公開地図の場合" do
      let(:trip) { create(:trip, status: :unlisted, user: owner) }

      context "公開投稿の場合" do
        let(:post) { create(:post, visibility: :public, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "誰でも閲覧できる投稿"
      end

      context "地図に合わせる投稿の場合" do
        let(:post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "誰でも閲覧できる投稿"
      end

      context "非公開投稿の場合" do
        let(:post) { create(:post, visibility: :private, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "作成者本人のみが閲覧できる投稿"
      end
    end

    context "非公開地図の場合" do
      let(:trip) { create(:trip, status: :private, user: owner) }

      context "公開投稿の場合" do
        let(:post) { create(:post, visibility: :public, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "誰でも閲覧できる投稿"
      end

      context "地図に合わせる投稿の場合" do
        let(:post) { create(:post, visibility: :inherit_trip, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "作成者本人のみが閲覧できる投稿"
      end

      context "非公開投稿の場合" do
        let(:post) { create(:post, visibility: :private, trip: trip, user: owner, body: "投稿本文") }
        it_behaves_like "作成者本人のみが閲覧できる投稿"
      end
    end

    context "投稿が存在しない場合" do
      it "投稿が見つかりませんと表示される" do
        get preview_post_path("not-found-public-uid"), headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("投稿本文")
        expect(response.body).to include("投稿が見つかりません")
      end
    end
  end

  describe "GET /explore/posts" do
    let!(:public_trip) { create(:trip, status: :public, user: owner, title: "public-trip-title-0000001") }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner, title: "unlisted-trip-title-0000001") }
    let!(:private_trip) { create(:trip, status: :private, user: owner, title: "private-trip-title-0000001") }
    let!(:public_trip_public_post) { create(:post, visibility: :public, trip: public_trip, user: owner, body: "公開地図の公開投稿-0001") }
    let!(:public_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: public_trip, user: owner, body: "公開地図の地図に合わせる投稿-0002") }
    let!(:public_trip_private_post) { create(:post, visibility: :private, trip: public_trip, user: owner, body: "公開地図の非公開投稿-0003") }
    let!(:unlisted_trip_public_post) { create(:post, visibility: :public, trip: unlisted_trip, user: owner, body: "限定公開地図の公開投稿-0004") }
    let!(:unlisted_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: unlisted_trip, user: owner, body: "限定公開地図の地図に合わせる投稿-0005") }
    let!(:unlisted_trip_private_post) { create(:post, visibility: :private, trip: unlisted_trip, user: owner, body: "限定公開地図の非公開投稿-0006") }
    let!(:private_trip_public_post) { create(:post, visibility: :public, trip: private_trip, user: owner, body: "非公開地図の公開投稿-0007") }
    let!(:private_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: private_trip, user: owner, body: "非公開地図の地図に合わせる投稿-0008") }
    let!(:private_trip_private_post) { create(:post, visibility: :private, trip: private_trip, user: owner, body: "非公開地図の非公開投稿-0009") }

    shared_examples "正しい組み合わせの公開設定の投稿のみが表示される" do
      it "公開投稿と公開地図+地図に合わせる投稿は一覧に表示され、限定公開地図+地図に合わせる投稿・非公開地図+地図に合わせる投稿・非公開投稿は表示されない" do
        get explore_posts_path

        aggregate_failures do
          # ページが正しく閲覧できるかチェック
          expect(response).to have_http_status(:ok)

          # 公開投稿が表示されているのかチェック
          expect(response.body).to include(public_trip_public_post.body)
          expect(response.body).to include(unlisted_trip_public_post.body)
          expect(response.body).to include(private_trip_public_post.body)

          # 地図に合わせる投稿の表示をチェック
          expect(response.body).to include(public_trip_inherit_post.body)
          expect(response.body).not_to include(unlisted_trip_inherit_post.body)
          expect(response.body).not_to include(private_trip_inherit_post.body)

          # 非公開投稿が表示されていないのかチェック
          expect(response.body).not_to include(public_trip_private_post.body)
          expect(response.body).not_to include(unlisted_trip_private_post.body)
          expect(response.body).not_to include(private_trip_private_post.body)
        end
      end
    end

    context "未ログインユーザーの場合" do
      it_behaves_like "正しい組み合わせの公開設定の投稿のみが表示される"
    end

    context "投稿作成者がログイン中の場合" do
      before do
        sign_in owner
      end

      it_behaves_like "正しい組み合わせの公開設定の投稿のみが表示される"
    end

    context "投稿作成者以外がログイン中の場合" do
      before do
        sign_in other_user
      end

      it_behaves_like "正しい組み合わせの公開設定の投稿のみが表示される"
    end
  end

  describe "GET /posts" do
    let!(:public_trip) { create(:trip, status: :public, user: owner, title: "public-trip-title-0000001") }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner, title: "unlisted-trip-title-0000001") }
    let!(:private_trip) { create(:trip, status: :private, user: owner, title: "private-trip-title-0000001") }
    let!(:public_trip_public_post) { create(:post, visibility: :public, trip: public_trip, user: owner, body: "公開地図の公開投稿-0001") }
    let!(:public_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: public_trip, user: owner, body: "公開地図の地図に合わせる投稿-0002") }
    let!(:public_trip_private_post) { create(:post, visibility: :private, trip: public_trip, user: owner, body: "公開地図の非公開投稿-0003") }
    let!(:unlisted_trip_public_post) { create(:post, visibility: :public, trip: unlisted_trip, user: owner, body: "限定公開地図の公開投稿-0004") }
    let!(:unlisted_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: unlisted_trip, user: owner, body: "限定公開地図の地図に合わせる投稿-0005") }
    let!(:unlisted_trip_private_post) { create(:post, visibility: :private, trip: unlisted_trip, user: owner, body: "限定公開地図の非公開投稿-0006") }
    let!(:private_trip_public_post) { create(:post, visibility: :public, trip: private_trip, user: owner, body: "非公開地図の公開投稿-0007") }
    let!(:private_trip_inherit_post) { create(:post, visibility: :inherit_trip, trip: private_trip, user: owner, body: "非公開地図の地図に合わせる投稿-0008") }
    let!(:private_trip_private_post) { create(:post, visibility: :private, trip: private_trip, user: owner, body: "非公開地図の非公開投稿-0009") }

    shared_examples "全ての公開設定の投稿が表示される" do
      it "作成者自身の投稿が、どの公開設定の組み合わせでも表示される" do
        get posts_path

        aggregate_failures do
          # ページが正しく閲覧できるかチェック
          expect(response).to have_http_status(:ok)

          # 公開投稿が表示されているのかチェック
          expect(response.body).to include(public_trip_public_post.body)
          expect(response.body).to include(unlisted_trip_public_post.body)
          expect(response.body).to include(private_trip_public_post.body)

          # 地図に合わせる投稿の表示をチェック
          expect(response.body).to include(public_trip_inherit_post.body)
          expect(response.body).to include(unlisted_trip_inherit_post.body)
          expect(response.body).to include(private_trip_inherit_post.body)

          # 非公開投稿が表示されていないのかチェック
          expect(response.body).to include(public_trip_private_post.body)
          expect(response.body).to include(unlisted_trip_private_post.body)
          expect(response.body).to include(private_trip_private_post.body)
        end
      end
    end

    shared_examples "全ての公開設定の投稿が表示されない" do
      it "他人の投稿が、どの公開設定の組み合わせでも表示されない" do
        get posts_path

        aggregate_failures do
          # ページが正しく閲覧できるかチェック
          expect(response).to have_http_status(:ok)

          # 公開投稿が表示されているのかチェック
          expect(response.body).not_to include(public_trip_public_post.body)
          expect(response.body).not_to include(unlisted_trip_public_post.body)
          expect(response.body).not_to include(private_trip_public_post.body)

          # 地図に合わせる投稿の表示をチェック
          expect(response.body).not_to include(public_trip_inherit_post.body)
          expect(response.body).not_to include(unlisted_trip_inherit_post.body)
          expect(response.body).not_to include(private_trip_inherit_post.body)

          # 非公開投稿が表示されていないのかチェック
          expect(response.body).not_to include(public_trip_private_post.body)
          expect(response.body).not_to include(unlisted_trip_private_post.body)
          expect(response.body).not_to include(private_trip_private_post.body)
        end
      end
    end

    context "未ログインユーザーの場合" do
      it_behaves_like "全ての公開設定の投稿が表示されない"
    end

    context "投稿作成者がログイン中の場合" do
      before do
        sign_in owner
      end

      it_behaves_like "全ての公開設定の投稿が表示される"
    end

    context "投稿作成者以外がログイン中の場合" do
      before do
        sign_in other_user
      end

      it_behaves_like "全ての公開設定の投稿が表示されない"
    end
  end
end
