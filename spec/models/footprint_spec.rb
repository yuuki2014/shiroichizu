require "rails_helper"

RSpec.describe Footprint, type: :model do
  describe "バリデーション" do
    context "有効になる場合" do
      it "有効なfactoryなら保存できる" do
        footprint = create(:footprint)

        expect(footprint).to be_persisted
      end

      it "latitudeが-90の場合は有効" do
        trip = create(:trip)
        footprint = build(:footprint, trip: trip, latitude: -90)

        expect(footprint).to be_valid
      end

      it "latitudeが90の場合は有効" do
        trip = create(:trip)
        footprint = build(:footprint, trip: trip, latitude: 90)

        expect(footprint).to be_valid
      end

      it "longitudeが-180の場合は有効" do
        trip = create(:trip)
        footprint = build(:footprint, trip: trip, longitude: -180)

        expect(footprint).to be_valid
      end

      it "longitudeが180の場合は有効" do
        trip = create(:trip)
        footprint = build(:footprint, trip: trip, longitude: 180)

        expect(footprint).to be_valid
      end
    end

    context "無効になる場合" do
      let(:trip) { create(:trip) }

      it "tripがない場合は無効" do
        footprint = build(:footprint, trip: nil)

        expect(footprint).to be_invalid
      end

      it "latitudeがnilの場合は無効" do
        footprint = build(:footprint, trip: trip, latitude: nil)

        expect(footprint).to be_invalid
      end

      it "longitudeがnilの場合は無効" do
        footprint = build(:footprint, trip: trip, longitude: nil)

        expect(footprint).to be_invalid
      end

      it "recorded_atがnilの場合は無効" do
        footprint = build(:footprint, trip: trip, recorded_at: nil)

        expect(footprint).to be_invalid
      end

      it "latitudeが-90未満の場合は無効" do
        footprint = build(:footprint, trip: trip, latitude: -90.000001)

        expect(footprint).to be_invalid
      end

      it "latitudeが90を超える場合は無効" do
        footprint = build(:footprint, trip: trip, latitude: 90.000001)

        expect(footprint).to be_invalid
      end

      it "longitudeが-180未満の場合は無効" do
        footprint = build(:footprint, trip: trip, longitude: -180.000001)

        expect(footprint).to be_invalid
      end

      it "longitudeが180を超える場合は無効" do
        footprint = build(:footprint, trip: trip, longitude: 180.000001)

        expect(footprint).to be_invalid
      end
    end
  end

  describe "デフォルト値" do
    it "recorded_atのデフォルト値が設定される" do
      footprint = described_class.new

      expect(footprint.recorded_at).to be_present
    end
  end

  describe "geohashの自動生成" do
    it "保存時にgeohashが自動生成される" do
      footprint = create(:footprint, latitude: 35.681236, longitude: 139.767125)

      expect(footprint.geohash).to be_present
    end

    it "geohashは指定した精度で生成される" do
      footprint = create(:footprint)

      expect(footprint.geohash.length).to eq(described_class::GEOHASH_PRECISION)
    end

    it "latitudeとlongitudeから期待されるgeohashが生成される" do
      latitude = 35.681236
      longitude = 139.767125
      footprint = create(:footprint, latitude: latitude, longitude: longitude)

      expect(footprint.geohash).to eq(
        GeoHash.encode(latitude, longitude, described_class::GEOHASH_PRECISION)
      )
    end

    it "latitudeがnilの場合はgeohashが生成されず無効になる" do
      trip = create(:trip)
      footprint = build(:footprint, trip: trip, latitude: nil)

      expect(footprint).to be_invalid
      expect(footprint.geohash).to be_nil
    end

    it "longitudeがnilの場合はgeohashが生成されず無効になる" do
      trip = create(:trip)
      footprint = build(:footprint, trip: trip, longitude: nil)

      expect(footprint).to be_invalid
      expect(footprint.geohash).to be_nil
    end
  end

  describe "関連付け" do
    it "tripに紐づいている" do
      trip = create(:trip)
      footprint = create(:footprint, trip: trip)

      expect(footprint.trip).to eq(trip)
    end
  end
end
