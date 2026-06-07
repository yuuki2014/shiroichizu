class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  before_validation :normalize_email

  # active storage設定
  has_one_attached :avatar, service: :cloudflare_public
  # has_one_attached :avatar, service: Rails.env.production? ? :cloudflare_public : :local

  attr_accessor :remove_avatar

  # enum 定義
  # ゲスト:0, 一般会員:10, 管理者:99
  enum :role, { guest: 0, general: 10, admin: 99 }
  # 非公開:0, 限定公開:10, 公開:20
  enum :map_privacy, { private: 0, limited: 10, public: 20 }, prefix: :map

  # バリデーション定義
  # UUIDは保存の直前にDBが生成してくれるので、ここでは設定しない
  validate :password_must_be_ascii_printable
  validate :email_must_be_ascii
  validates :nickname,
    presence: true,
    length: { maximum: 20 },
    format: { without: /\R/, message: "に改行は使えません" }
  validates :role, :map_privacy, presence: true

  # アソシエーション定義
  # 作成した地図
  has_many :trips, dependent: :destroy
  # trips を経由して footprints を取得
  has_many :footprints, through: :trips
  has_many :posts, dependent: :destroy

  # Devise の機能をオーバーライド
  # ゲスト以外の時だけメールアドレスを必須にする
  def email_required?
    !guest? # ゲストなら false (いらない)、それ以外なら true (いる)
  end

  def remember_expires_at
    time = Time.current

    case role
    when "guest"
      time + 180.day
    when "general"
      time + 365.day
    when "admin"
      time + 1.day
    else
      time + 2.weeks
    end
  end

  # guestユーザー作成
  def self.create_guest
    guest_password = SecureRandom.urlsafe_base64

    create!(
      nickname: "ゲスト",
      role: "guest",
      map_privacy: "private",
      email: nil,
      password: guest_password,
    )
  end

  # 現在、しようしていないと思われるので、後で確認後削除
  # 認証が完了した瞬間に自動で呼ばれるメソッド(Devise)
  def after_confirmation
    # デフォルトの処理を実行
    super

    # 認証時にゲストの場合はroleとユーザー名を更新
    if role == "guest"
      updates = { role: :general }

      if nickname.blank? || nickname == "ゲスト"
        updates[:nickname] = "ユーザー"
      end

      # バリデーションを無視して強制更新
      update_columns(updates)
    end
  end

  def cumulative_geohashes
    footprints.distinct.pluck(:geohash)
  end

  # User モデルの :id を public_uidに
  def to_param
    public_uid
  end

  # 会員用にデータを更新
  def promote_to_general(email:, password:, password_confirmation:)
    assign_attributes(
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      role: :general,
      nickname: "ユーザー"
    )

    save
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  def password_must_be_ascii_printable
    return if password.blank?

    unless password.match?(/\A[\x21-\x7E]+\z/)
      errors.add(:password, "は半角英数字・記号で入力してください")
    end
  end

  def email_must_be_ascii
    return if email.blank?
    return if email.ascii_only?

    errors.add(:email, "は半角文字で入力してください")
  end
end
