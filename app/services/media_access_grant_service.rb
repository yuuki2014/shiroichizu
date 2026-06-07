class MediaAccessGrantService
  ALGORITHM = "HS256".freeze
  COOKIE_KEY = :media_access_grant
  TTL_SECONDS = 30.minutes.to_i

  def self.call(posts:, cookies:)
    required_post_ids = Array(posts).map(&:id).uniq.sort
    return if required_post_ids.empty?

    existing_post_ids = load_existing_post_ids(cookies)

    if existing_post_ids.present? && (required_post_ids - existing_post_ids).empty?
      return
    end

    now = Time.current.to_i
    exp = now + TTL_SECONDS

    token = build_jwt(post_ids: required_post_ids, exp: exp, now: now)

    cookies[COOKIE_KEY] = {
      value: token,
      path: "/",
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: Time.at(exp)
    }.tap do |options|
      options[:domain] = ".shiroichizu.app" if Rails.env.production?
    end

    nil
  end

  def self.load_existing_post_ids(cookies)
    token = cookies[COOKIE_KEY]
    return [] if token.blank?

    payload, _header = JWT.decode(token, ENV.fetch("MEDIA_JWT_SECRET"), true, algorithm: ALGORITHM)
    post_ids = payload["post_ids"] || payload[:post_ids]
    return [] if post_ids.blank?

    Array(post_ids).uniq.sort
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.info("Media grant cookie invalid: #{e.class} #{e.message}")
    []
  end

  def self.build_jwt(post_ids:, exp:, now:)
    payload = {
      "v" => 1,
      "post_ids" => post_ids,
      "exp" => exp,
      "iat" => now
    }

    JWT.encode(payload, ENV.fetch("MEDIA_JWT_SECRET"), ALGORITHM)
  end
end
