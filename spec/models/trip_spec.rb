require "rails_helper"

RSpec.describe Trip, type: :model do
  describe "バリデーション" do
    context "有効になる場合" do
      it "有効なfactoryなら保存できる" do
        trip = create(:trip)

        expect(trip).to be_valid
      end

      it "titleが100文字以下なら有効" do
        trip = create(:trip, title: "a" * described_class::TITLE_MAX_LENGTH)

        expect(trip).to be_valid
      end

      it "statusがprivateなら有効" do
        trip = create(:trip, status: :private)

        expect(trip).to be_valid
        expect(trip).to be_visibility_private
      end

      it "statusがunlistedなら有効" do
        trip = create(:trip, status: :unlisted)

        expect(trip).to be_valid
        expect(trip).to be_visibility_unlisted
      end

      it "statusがpublicなら有効" do
        trip = create(:trip, status: :public)

        expect(trip).to be_valid
        expect(trip).to be_visibility_public
      end
    end

    context "無効になる場合" do
      let(:user) { create(:user) }

      it "userがない場合は無効" do
        trip = build(:trip, user: nil)

        expect(trip).to be_invalid
      end

      it "activity_timeがnilの場合は無効" do
        trip = build(:trip, activity_time: nil, user: user)

        expect(trip).to be_invalid
      end

      it "total_distanceがnilの場合は無効" do
        trip = build(:trip, total_distance: nil, user: user)

        expect(trip).to be_invalid
      end

      it "statusがnilの場合は無効" do
        trip = build(:trip, status: nil, user: user)

        expect(trip).to be_invalid
      end

      it "statusが空文字の場合は無効" do
        trip = build(:trip, status: "", user: user)

        expect(trip).to be_invalid
      end

      it "定義されていないstatusだとArgumentErrorになる" do
        expect {
          build(:trip, status: "aaaaa", user: user)
        }.to raise_error(ArgumentError, /is not a valid status/)
      end

      it "started_atがnilの場合は無効" do
        trip = build(:trip, started_at: nil, user: user)

        expect(trip).to be_invalid
      end

      it "titleがnilの場合は無効" do
        trip = build(:trip, title: nil, user: user)

        expect(trip).to be_invalid
      end

      it "titleが空文字の場合は無効" do
        trip = build(:trip, title: "", user: user)

        expect(trip).to be_invalid
      end

      it "titleが101文字以上の場合は無効" do
        trip = build(:trip, title: "a" * (described_class::TITLE_MAX_LENGTH + 1), user: user)

        expect(trip).to be_invalid
      end

      it "titleに改行が含まれる場合は無効" do
        trip = build(:trip, title: "テスト\n地図", user: user)

        expect(trip).to be_invalid
      end
    end
  end

  describe "デフォルト値" do
    it "titleのデフォルト値が名無しの地図になっている" do
      trip = described_class.new

      expect(trip.title).to eq("名無しの地図")
    end

    it "started_atのデフォルト値が設定される" do
      trip = described_class.new

      expect(trip.started_at).to be_present
    end
  end

  describe "enum" do
    it "statusのenum定義が期待通りになっている" do
      expect(described_class.statuses).to eq({
        "private" => 0,
        "unlisted" => 10,
        "public" => 20
      })
    end
  end

  describe "UUIDの自動生成" do
    it "作成時にpublic_uidが自動生成される" do
      trip = create(:trip)

      expect(trip.reload.public_uid).to be_present
    end

    it "public_uidはUUID形式で生成される" do
      trip = create(:trip)

      expect(trip.reload.public_uid).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end

    it "地図ごとに異なるpublic_uidが生成される" do
      first_trip = create(:trip)
      second_trip = create(:trip)

      expect(first_trip.reload.public_uid).not_to eq(second_trip.reload.public_uid)
    end
  end

  describe "#to_param" do
    it "public_uidを返す" do
      trip = create(:trip)

      expect(trip.to_param).to eq(trip.reload.public_uid)
    end
  end

  describe "関連付け" do
    it "ユーザーに紐づいている" do
      user = create(:user)
      trip = create(:trip, user: user)

      expect(trip.user).to eq(user)
    end

    it "tripを削除すると紐づくfootprintsも削除される" do
      trip = create(:trip)
      create(:footprint, trip: trip)

      expect {
        trip.destroy
      }.to change(Footprint, :count).by(-1)
    end

    it "tripを削除すると紐づくpostsも削除される" do
      trip = create(:trip)
      create(:post, trip: trip, user: trip.user)

      expect {
        trip.destroy
      }.to change(Post, :count).by(-1)
    end
  end
end
