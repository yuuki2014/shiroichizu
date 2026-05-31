require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    context "passwordのバリデーション" do
      context "有効になる場合" do
        it 'パスワードの文字数が8文字以上の場合は有効（8文字）' do
          user = build(:user, password: "a" * 8, password_confirmation: "a" * 8)
          expect(user).to be_valid
        end

        it 'パスワードの文字数が128文字以下の場合は有効（128文字）' do
          user = build(:user, password: "a" * 128, password_confirmation: "a" * 128)
          expect(user).to be_valid
        end

        it 'パスワードが半角英数字・記号の場合は有効' do
          user = build(:user, password: "password123!", password_confirmation: "password123!")

          expect(user).to be_valid
        end
      end

      context "無効になる場合" do
        it 'パスワードがnilの場合は無効' do
          user = build(:user, password: nil, password_confirmation: nil)
          expect(user).to be_invalid
        end

        it 'パスワードが空文字の場合は無効' do
          user = build(:user, password: "", password_confirmation: "")
          expect(user).to be_invalid
        end

        it 'パスワードが半角スペースの場合は無効（8文字）' do
          user = build(:user, password: " " * 8, password_confirmation: " " * 8)
          expect(user).to be_invalid
        end

        it 'パスワードが全角スペースの場合は無効（8文字）' do
          user = build(:user, password: "　" * 8, password_confirmation: "　" * 8)
          expect(user).to be_invalid
        end

        it 'パスワードの文字数が8文字未満の場合は無効（半角1文字）' do
          user = build(:user, password: "a" * 1, password_confirmation: "a" * 1)
          expect(user).to be_invalid
        end

        it 'パスワードの文字数が8文字未満の場合は無効（半角7文字）' do
          user = build(:user, password: "a" * 7, password_confirmation: "a" * 7)
          expect(user).to be_invalid
        end

        it 'パスワードが全角場合は無効（1文字）' do
          user = build(:user, password: "あ" * 1, password_confirmation: "あ" * 1)
          expect(user).to be_invalid
        end

        it 'パスワードが全角場合は無効（7文字）' do
          user = build(:user, password: "あ" * 7, password_confirmation: "あ" * 7)
          expect(user).to be_invalid
        end

        it 'パスワードが全角場合は無効（8文字）' do
          user = build(:user, password: "あ" * 8, password_confirmation: "あ" * 8)
          expect(user).to be_invalid
        end

        it 'パスワードが全角場合は無効（128文字）' do
          user = build(:user, password: "あ" * 128, password_confirmation: "あ" * 128)
          expect(user).to be_invalid
        end

        it 'パスワードが全角場合は無効（129文字）' do
          user = build(:user, password: "あ" * 129, password_confirmation: "あ" * 129)
          expect(user).to be_invalid
        end

        it 'パスワードの中に半角スペースが含まれる場合は無効' do
          user = build(:user, password: "pass word", password_confirmation: "pass word")

          expect(user).to be_invalid
        end

        it 'パスワードの前に半角スペースが含まれる場合は無効' do
          user = build(:user, password: " password", password_confirmation: " password")

          expect(user).to be_invalid
        end

        it 'パスワードの後ろに半角スペースが含まれる場合は無効' do
          user = build(:user, password: "password ", password_confirmation: "password ")

          expect(user).to be_invalid
        end

        it 'パスワードの中に全角スペースが含まれる場合は無効' do
          user = build(:user, password: "pass　word", password_confirmation: "pass　word")

          expect(user).to be_invalid
        end

        it 'パスワードの前に全角スペースが含まれる場合は無効' do
          user = build(:user, password: "　password", password_confirmation: "　password")

          expect(user).to be_invalid
        end

        it 'パスワードの後ろに全角スペースが含まれる場合は無効' do
          user = build(:user, password: "password　", password_confirmation: "password　")

          expect(user).to be_invalid
        end

        it 'パスワードに全角文字が含まれる場合は無効' do
          user = build(:user, password: "passあword", password_confirmation: "passあword")

          expect(user).to be_invalid
        end
      end
    end

    context "nicknameのバリデーション" do
      context "有効になる場合" do
        it "nicknameが存在する場合（半角1文字）" do
          user = build(:user, nickname: "a" * 1)
          expect(user).to be_valid
        end

        it "nicknameが存在する場合（全角1文字）" do
          user = build(:user, nickname: "あ" * 1)
          expect(user).to be_valid
        end

        it "nicknameが存在する場合（半角20文字）" do
          user = build(:user, nickname: "a" * 20)
          expect(user).to be_valid
        end

        it "nicknameが存在する場合（全角20文字）" do
          user = build(:user, nickname: "あ" * 20)
          expect(user).to be_valid
        end
      end

      context "無効になる場合" do
        it "nicknameがnilの場合" do
          user = build(:user, nickname: nil)
          expect(user).to be_invalid
        end

        it "nicknameが空文字の場合" do
          user = build(:user, nickname: "")
          expect(user).to be_invalid
        end

        it "nicknameが半角スペースだけの場合" do
          user = build(:user, nickname: " ")
          expect(user).to be_invalid
        end

        it "nicknameが全角スペースだけの場合" do
          user = build(:user, nickname: "　")
          expect(user).to be_invalid
        end

        it "nicknameが半角21文字以上の場合" do
          user = build(:user, nickname: "a" * 21)
          expect(user).to be_invalid
        end

        it "nicknameが全角21文字以上の場合" do
          user = build(:user, nickname: "あ" * 21)
          expect(user).to be_invalid
        end

        it "nicknameに改行が含まれている場合" do
          user = build(:user, nickname: "テスト\nテスト")
          expect(user).to be_invalid
        end
      end
    end

    context "roleのバリデーション" do
      context "有効になる場合" do
        it "guestだと有効" do
          user = build(:user, role: :guest)

          expect(user).to be_valid
          expect(user).to be_guest
        end

        it "generalだと有効" do
          user = build(:user, role: :general)

          expect(user).to be_valid
          expect(user).to be_general
        end

        it "adminだと有効" do
          user = build(:user, role: :admin)

          expect(user).to be_valid
          expect(user).to be_admin
        end
      end

      context "無効になる場合" do
        it "定義されていない文字列だとArgumentErrorになる" do
          expect {
            build(:user, role: "aaaaa")
          }.to raise_error(ArgumentError, /is not a valid role/)
        end

        it "空文字だと無効" do
          user = build(:user, role: "")

          expect(user).to be_invalid
        end

        it "nilだと無効" do
          user = build(:user, role: nil)

          expect(user).to be_invalid
        end
      end
    end

    context "map_privacyのバリデーション" do
      context "有効になる場合" do
        it "privateだと保存できる" do
          user = build(:user, map_privacy: :private)

          expect(user).to be_valid
          expect(user).to be_map_private
        end

        it "limitedだと保存できる" do
          user = build(:user, map_privacy: :limited)

          expect(user).to be_valid
          expect(user).to be_map_limited
        end

        it "publicだと保存できる" do
          user = build(:user, map_privacy: :public)

          expect(user).to be_valid
          expect(user).to be_map_public
        end
      end

      context "無効になる場合" do
        it "nilだと保存できない" do
          user = build(:user, map_privacy: nil)

          expect(user).to be_invalid
        end

        it "空だと保存できない" do
          user = build(:user, map_privacy: "")

          expect(user).to be_invalid
        end

        it "定義されていない文字列だとArgumentErrorになる" do
          expect {
            build(:user, map_privacy: "aaaaa")
          }.to raise_error(ArgumentError, /is not a valid map_privacy/)
        end
      end
    end

    context "emailのバリデーション" do
      context "有効になる場合" do
        it "emailがnilのguestユーザーは複数作成できる" do
          expect {
            create(:user, role: :guest, email: nil)
            create(:user, role: :guest, email: nil)
          }.to change(User, :count).by(2)
        end

        it "DBレベルではnilのemailは重複扱いされない" do
          create(:user, role: :guest, email: nil)

          expect {
            create(:user, role: :guest, email: nil)
          }.not_to raise_error
        end

        it "emailが半角の通常形式なら有効" do
          user = build(:user, email: "test@example.com")

          expect(user).to be_valid
        end

        it "guestの場合はemailがnilでも有効" do
          user = build(:user, role: :guest, email: nil)

          expect(user).to be_valid
        end
      end

      context "無効になる場合" do
        it "generalの場合はemailがnilだと無効" do
          user = build(:user, role: :general, email: nil)

          expect(user).to be_invalid
        end

        it "adminの場合はemailがnilだと無効" do
          user = build(:user, role: :admin, email: nil)

          expect(user).to be_invalid
        end

        it "emailの形式でない場合は無効" do
          user = build(:user, email: "invalid-email")

          expect(user).to be_invalid
        end

        it "emailに全角文字が入っている場合は無効" do
          user = build(:user, email: "あいう@えお.com")

          expect(user).to be_invalid
        end

        it "重複したemailは無効" do
          create(:user, email: "test@example.com")

          duplicate_user = build(:user, email: "test@example.com")

          expect(duplicate_user).to be_invalid
        end

        it "emailは小文字化・前後空白削除された上で重複チェックされる" do
          create(:user, email: "test@example.com")

          user = build(:user, email: " TEST@example.com ")

          expect(user).to be_invalid
        end

        it "DBレベルでもemailの重複を許可しない" do
          create(:user, email: "test@example.com")
          duplicate_user = build(:user, email: "test@example.com")

          expect {
            duplicate_user.save!(validate: false)
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end
  end

  describe ".create_guest" do
    subject(:user) { described_class.create_guest }

    it "DBに保存されている" do
      expect(user).to be_persisted
    end

    it "nicknameがゲストになっている" do
      expect(user.nickname).to eq("ゲスト")
    end

    it "roleがguestになっている" do
      expect(user).to be_guest
    end

    it "map_privacyがprivateになっている" do
      expect(user).to be_map_private
    end

    it "emailがnilになっている" do
      expect(user.email).to be_nil
    end
  end

  describe "#promote_to_general" do
    context "有効な場合" do
      subject(:user) { described_class.create_guest }

      before do
        user.promote_to_general(
          email: "test@example.com",
          password: "password",
          password_confirmation: "password"
        )
      end

      it "nicknameがユーザーになっている" do
        expect(user.nickname).to eq("ユーザー")
      end

      it "roleがgeneralになっている" do
        expect(user).to be_general
      end

      it "map_privacyがprivateのままになっている" do
        expect(user).to be_map_private
      end

      it "emailが正しく登録されている" do
        expect(user.email).to eq("test@example.com")
      end

      it "DB上でもgeneralとして保存されている" do
        expect(user.reload).to be_general
      end

      it "DB上でも本会員情報として保存されている" do
        user.reload

        aggregate_failures do
          expect(user).to be_general
          expect(user.nickname).to eq("ユーザー")
          expect(user.email).to eq("test@example.com")
          expect(user).to be_map_private
        end
      end
    end

    context "無効なパスワードの場合" do
      subject(:user) { described_class.create_guest }

      it "保存に失敗し、DB上ではguestのままになる" do
        result = user.promote_to_general(
          email: "test@example.com",
          password: "short",
          password_confirmation: "short"
        )

        aggregate_failures do
          expect(result).to be false
          expect(user.reload).to be_guest
          expect(user.email).to be_nil
        end
      end
    end
  end

  describe "UUIDの自動生成" do
    it "作成時にpublic_uidが自動生成される" do
      user = create(:user)

      expect(user.reload.public_uid).to be_present
    end

    it "作成時にmap_share_uuidが自動生成される" do
      user = create(:user)

      expect(user.reload.map_share_uuid).to be_present
    end

    it "public_uidはUUID形式で生成される" do
      user = create(:user)

      expect(user.reload.public_uid).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end

    it "map_share_uuidはUUID形式で生成される" do
      user = create(:user)

      expect(user.reload.map_share_uuid).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end

    it "ユーザーごとに異なるpublic_uidが生成される" do
      first_user = create(:user)
      second_user = create(:user)

      expect(first_user.reload.public_uid).not_to eq(second_user.reload.public_uid)
    end

    it "ユーザーごとに異なるmap_share_uuidが生成される" do
      first_user = create(:user)
      second_user = create(:user)

      expect(first_user.reload.map_share_uuid).not_to eq(second_user.reload.map_share_uuid)
    end

    it "DBレベルでpublic_uidの重複を許可しない" do
      user = create(:user)
      duplicate_user = build(:user)

      duplicate_user.public_uid = user.public_uid

      expect {
        duplicate_user.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "DBレベルでmap_share_uuidの重複を許可しない" do
      user = create(:user)
      duplicate_user = build(:user)

      duplicate_user.map_share_uuid = user.map_share_uuid

      expect {
        duplicate_user.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#to_param" do
    it "public_uidを返す" do
      user = create(:user)

      expect(user.to_param).to eq(user.reload.public_uid)
    end
  end

  describe "関連データの削除" do
    it "ユーザーを削除すると紐づく地図も削除される" do
      user = create(:user)
      create(:trip, user: user)

      expect {
        user.destroy
      }.to change(Trip, :count).by(-1)
    end

    it "ユーザーを削除すると紐づく投稿も削除される" do
      user = create(:user)
      trip = create(:trip, user: user)
      create(:post, user: user, trip: trip)

      expect {
        user.destroy
      }.to change(Post, :count).by(-1)
    end

    it "ユーザーを削除すると紐づく足跡も削除される" do
      user = create(:user)
      trip = create(:trip, user: user)
      create(:footprint, trip: trip)

      expect {
        user.destroy
      }.to change(Footprint, :count).by(-1)
    end
  end
end
