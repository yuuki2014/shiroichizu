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

  # def self.read_from_kv(gid:)
  #   account_id = ENV.fetch("CLOUDFLARE_ACCOUNT_ID")
  #   namespace_id = ENV.fetch("CLOUDFLARE_KV_NAMESPACE_ID")
  #   api_token = ENV.fetch("CLOUDFLARE_KV_API_TOKEN")

  #   key = "grant:#{gid}"

  #   conn = Faraday.new(url: "https://api.cloudflare.com")
  #   response = conn.get("/client/v4/accounts/#{account_id}/storage/kv/namespaces/#{namespace_id}/values/#{CGI.escape(key)}") do |req|
  #     req.headers["Authorization"] = "Bearer #{api_token}"
  #   end

  #   return nil if response.status == 404

  #   unless response.success?
  #     Rails.logger.error("KV read failed: #{response.status} #{response.body}")
  #     return nil
  #   end

  #   JSON.parse(response.body)
  # end

  # def self.write_to_kv!(gid:, post_public_uids:, exp:)
  #   account_id = ENV.fetch("CLOUDFLARE_ACCOUNT_ID")
  #   namespace_id = ENV.fetch("CLOUDFLARE_KV_NAMESPACE_ID")
  #   api_token = ENV.fetch("CLOUDFLARE_KV_API_TOKEN")

  #   key = "grant:#{gid}"
  #   value = {
  #     post_public_uids: post_public_uids,
  #     exp: exp
  #   }.to_json

  #   conn = Faraday.new(url: "https://api.cloudflare.com")
  #   response = conn.put("/client/v4/accounts/#{account_id}/storage/kv/namespaces/#{namespace_id}/values/#{CGI.escape(key)}") do |req|
  #     req.headers["Authorization"] = "Bearer #{api_token}"
  #     req.headers["Content-Type"] = "text/plain"
  #     req.params["expiration_ttl"] = TTL_SECONDS
  #     req.body = value
  #   end

  #   unless response.success?
  #     Rails.logger.error("KV write failed: #{response.status} #{response.body}")
  #     raise "Cloudflare KV write failed"
  #   end
  # end
end
