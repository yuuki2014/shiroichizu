require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'Postの検証' do
    context "バリデーションチェック" do
      it "正しく保存されるか" do
        post = create(:post)
      end
    end
  end
end
