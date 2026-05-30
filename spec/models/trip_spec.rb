require 'rails_helper'

RSpec.describe Trip, type: :model do
  describe "バリデーションチェック" do
    it "設定したバリデーションが機能しているか" do
      trip = create(:trip)
    end
  end
end
