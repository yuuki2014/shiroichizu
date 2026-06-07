require "rails_helper"

RSpec.describe Post, type: :model do
  describe "バリデーション" do
    context "有効になる場合" do
      it "有効なfactoryなら保存できる" do
        post = create(:post)

        expect(post).to be_persisted
      end

      it "bodyが300文字以下なら有効" do
        post = create(:post, body: "a" * described_class::MAX_BODY_LENGTH)

        expect(post).to be_valid
      end

      it "bodyが空でもincoming_images_presentがtrueなら有効" do
        post = create(:post, body: "", incoming_images_present: true)

        expect(post).to be_valid
      end

      it "visibilityがinherit_tripなら有効" do
        post = create(:post, visibility: :inherit_trip)

        expect(post).to be_valid
        expect(post).to be_visibility_inherit_trip
      end

      it "visibilityがpublicなら有効" do
        post = create(:post, visibility: :public)

        expect(post).to be_valid
        expect(post).to be_visibility_public
      end

      it "visibilityがfollowerなら有効" do
        post = create(:post, visibility: :follower)

        expect(post).to be_valid
        expect(post).to be_visibility_follower
      end

      it "visibilityがprivateなら有効" do
        post = create(:post, visibility: :private)

        expect(post).to be_valid
        expect(post).to be_visibility_private
      end

      it "latitudeが-90の場合は有効" do
        post = create(:post, latitude: -90)

        expect(post).to be_valid
      end

      it "latitudeが90の場合は有効" do
        post = create(:post, latitude: 90)

        expect(post).to be_valid
      end

      it "longitudeが-180の場合は有効" do
        post = create(:post, longitude: -180)

        expect(post).to be_valid
      end

      it "longitudeが180の場合は有効" do
        post = create(:post, longitude: 180)

        expect(post).to be_valid
      end
    end

    context "無効になる場合" do
      let(:user) { create(:user) }

      it "userがない場合は無効" do
        post = build(:post, user: nil)

        expect(post).to be_invalid
      end

      it "latitudeがnilの場合は無効" do
        post = build(:post, latitude: nil, user: user)

        expect(post).to be_invalid
      end

      it "longitudeがnilの場合は無効" do
        post = build(:post, longitude: nil, user: user)

        expect(post).to be_invalid
      end

      it "visibilityがnilの場合は無効" do
        post = build(:post, visibility: nil, user: user)

        expect(post).to be_invalid
      end

      it "visibilityが空文字の場合は無効" do
        post = build(:post, visibility: "", user: user)

        expect(post).to be_invalid
      end

      it "定義されていないvisibilityだとArgumentErrorになる" do
        expect {
          build(:post, visibility: "aaaaa", user: user)
        }.to raise_error(ArgumentError, /is not a valid visibility/)
      end

      it "visited_atがnilの場合は無効" do
        post = build(:post, visited_at: nil, user: user)

        expect(post).to be_invalid
      end

      it "visited_atが未来の場合は無効" do
        post = build(:post, visited_at: 1.hour.from_now, user: user)

        expect(post).to be_invalid
      end

      it "bodyが301文字以上の場合は無効" do
        post = build(:post, body: "a" * (described_class::MAX_BODY_LENGTH + 1), user: user)

        expect(post).to be_invalid
      end

      it "bodyが空で画像もない場合は無効" do
        post = build(:post, body: "", incoming_images_present: false, user: user)

        expect(post).to be_invalid
      end

      it "bodyが半角スペースだけで画像もない場合は無効" do
        post = build(:post, body: " " * 10, incoming_images_present: false, user: user)

        expect(post).to be_invalid
      end

      it "bodyが全角スペースだけで画像もない場合は無効" do
        post = build(:post, body: "　" * 10, incoming_images_present: false, user: user)

        expect(post).to be_invalid
      end

      it "latitudeが-90未満の場合は無効" do
        post = build(:post, latitude: -90.000001, user: user)

        expect(post).to be_invalid
      end

      it "latitudeが90を超える場合は無効" do
        post = build(:post, latitude: 90.000001, user: user)

        expect(post).to be_invalid
      end

      it "longitudeが-180未満の場合は無効" do
        post = build(:post, longitude: -180.000001, user: user)

        expect(post).to be_invalid
      end

      it "longitudeが180を超える場合は無効" do
        post = build(:post, longitude: 180.000001, user: user)

        expect(post).to be_invalid
      end
    end
  end

  describe "enum" do
    it "visibilityのenum定義が期待通りになっている" do
      expect(described_class.visibilities).to eq({
        "inherit_trip" => 0,
        "public" => 10,
        "follower" => 20,
        "private" => 30
      })
    end
  end

  describe "#visible_to?" do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    context "投稿作成者本人の場合" do
      it "非公開投稿でも閲覧できる" do
        trip = create(:trip, status: :private, user: owner)
        post = create(:post, visibility: :private, trip: trip, user: owner)

        expect(post.visible_to?(owner)).to be true
      end
    end

    context "公開投稿の場合" do
      it "未ログインユーザーでも閲覧できる" do
        trip = create(:trip, status: :private, user: owner)
        post = create(:post, visibility: :public, trip: trip, user: owner)

        expect(post.visible_to?(nil)).to be true
      end

      it "他人でも閲覧できる" do
        trip = create(:trip, status: :private, user: owner)
        post = create(:post, visibility: :public, trip: trip, user: owner)

        expect(post.visible_to?(other_user)).to be true
      end
    end

    context "地図に合わせる投稿の場合" do
      it "公開地図に紐づく場合は未ログインユーザーでも閲覧できる" do
        trip = create(:trip, status: :public, user: owner)
        post = create(:post, visibility: :inherit_trip, trip: trip, user: owner)

        expect(post.visible_to?(nil)).to be true
      end

      it "限定公開地図に紐づく場合は未ログインユーザーでも閲覧できる" do
        trip = create(:trip, status: :unlisted, user: owner)
        post = create(:post, visibility: :inherit_trip, trip: trip, user: owner)

        expect(post.visible_to?(nil)).to be true
      end

      it "非公開地図に紐づく場合は他人には閲覧できない" do
        trip = create(:trip, status: :private, user: owner)
        post = create(:post, visibility: :inherit_trip, trip: trip, user: owner)

        expect(post.visible_to?(other_user)).to be false
      end

      it "tripがnilの地図に合わせる投稿は他人には閲覧できない" do
        user = create(:user)
        post = create(:post, visibility: :inherit_trip, trip: nil, user: user)

        expect(post.visible_to?(nil)).to be false
      end
    end

    context "非公開投稿の場合" do
      it "他人には閲覧できない" do
        trip = create(:trip, status: :public, user: owner)
        post = create(:post, visibility: :private, trip: trip, user: owner)

        expect(post.visible_to?(other_user)).to be false
      end

      it "未ログインユーザーには閲覧できない" do
        trip = create(:trip, status: :public, user: owner)
        post = create(:post, visibility: :private, trip: trip, user: owner)

        expect(post.visible_to?(nil)).to be false
      end
    end
  end

  describe ".explore_visible" do
    let(:owner) { create(:user) }

    let!(:public_trip) { create(:trip, status: :public, user: owner) }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner) }
    let!(:private_trip) { create(:trip, status: :private, user: owner) }

    let!(:public_trip_public_post) do
      create(:post, visibility: :public, trip: public_trip, user: owner)
    end

    let!(:public_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: public_trip, user: owner)
    end

    let!(:unlisted_trip_public_post) do
      create(:post, visibility: :public, trip: unlisted_trip, user: owner)
    end

    let!(:unlisted_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: unlisted_trip, user: owner)
    end

    let!(:private_trip_public_post) do
      create(:post, visibility: :public, trip: private_trip, user: owner)
    end

    let!(:private_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: private_trip, user: owner)
    end

    let!(:private_post) do
      create(:post, visibility: :private, trip: public_trip, user: owner)
    end

    it "公開投稿と公開地図に紐づく地図に合わせる投稿だけを返す" do
      posts = described_class.explore_visible

      aggregate_failures do
        expect(posts).to include(public_trip_public_post)
        expect(posts).to include(unlisted_trip_public_post)
        expect(posts).to include(private_trip_public_post)

        expect(posts).to include(public_trip_inherit_post)
        expect(posts).not_to include(unlisted_trip_inherit_post)
        expect(posts).not_to include(private_trip_inherit_post)

        expect(posts).not_to include(private_post)
      end
    end
  end

  describe ".visible_to" do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    let!(:public_trip) { create(:trip, status: :public, user: owner) }
    let!(:unlisted_trip) { create(:trip, status: :unlisted, user: owner) }
    let!(:private_trip) { create(:trip, status: :private, user: owner) }

    let!(:owner_private_post) do
      create(:post, visibility: :private, trip: private_trip, user: owner)
    end

    let!(:public_post) do
      create(:post, visibility: :public, trip: private_trip, user: owner)
    end

    let!(:public_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: public_trip, user: owner)
    end

    let!(:unlisted_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: unlisted_trip, user: owner)
    end

    let!(:private_trip_inherit_post) do
      create(:post, visibility: :inherit_trip, trip: private_trip, user: owner)
    end

    it "未ログインユーザーには公開投稿と公開・限定公開地図に紐づく地図に合わせる投稿だけを返す" do
      posts = described_class.visible_to(nil)

      aggregate_failures do
        expect(posts).to include(public_post)
        expect(posts).to include(public_trip_inherit_post)
        expect(posts).to include(unlisted_trip_inherit_post)
        expect(posts).not_to include(private_trip_inherit_post)
        expect(posts).not_to include(owner_private_post)
      end
    end

    it "投稿作成者には自分の投稿も返す" do
      posts = described_class.visible_to(owner)

      aggregate_failures do
        expect(posts).to include(owner_private_post)
        expect(posts).to include(public_post)
        expect(posts).to include(public_trip_inherit_post)
        expect(posts).to include(unlisted_trip_inherit_post)
        expect(posts).to include(private_trip_inherit_post)
      end
    end

    it "他人には公開投稿と公開・限定公開地図に紐づく地図に合わせる投稿だけを返す" do
      posts = described_class.visible_to(other_user)

      aggregate_failures do
        expect(posts).to include(public_post)
        expect(posts).to include(public_trip_inherit_post)
        expect(posts).to include(unlisted_trip_inherit_post)
        expect(posts).not_to include(private_trip_inherit_post)
        expect(posts).not_to include(owner_private_post)
      end
    end
  end

  describe "UUIDの自動生成" do
    it "作成時にpublic_uidが自動生成される" do
      post = create(:post)

      expect(post.reload.public_uid).to be_present
    end

    it "public_uidはUUID形式で生成される" do
      post = create(:post)

      expect(post.reload.public_uid).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end

    it "投稿ごとに異なるpublic_uidが生成される" do
      first_post = create(:post)
      second_post = create(:post)

      expect(first_post.reload.public_uid).not_to eq(second_post.reload.public_uid)
    end
  end

  describe "#to_param" do
    it "public_uidを返す" do
      post = create(:post)

      expect(post.to_param).to eq(post.reload.public_uid)
    end
  end

  describe "関連付け" do
    it "userに紐づいている" do
      user = create(:user)
      trip = create(:trip, user: user)
      post = create(:post, user: user, trip: trip)

      expect(post.user).to eq(user)
    end

    it "tripに紐づいている" do
      trip = create(:trip)
      post = create(:post, trip: trip, user: trip.user)

      expect(post.trip).to eq(trip)
    end

    it "tripがnilでも保存できる" do
      user = create(:user)
      post = build(:post, user: user, trip: nil)

      expect(post).to be_valid
    end
  end
end
