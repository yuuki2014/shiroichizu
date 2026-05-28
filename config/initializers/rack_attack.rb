class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  class << self
    def client_ip(req)
      req.get_header("HTTP_CF_CONNECTING_IP").presence ||
        req.get_header("HTTP_X_FORWARDED_FOR").to_s.split(",").first&.strip.presence ||
        req.get_header("HTTP_FLY_CLIENT_IP").presence ||
        req.ip
    end
  end

  # IPごとのリクエスト制限
  throttle("req/ip", limit: 1000, period: 5.minutes) do |req|
    next if req.path.start_with?("/assets", "/packs", "/vite", "/up", "/cable")

    client_ip(req)
  end

  # ログイン制限
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      client_ip(req)
    end
  end

  # 怪しいパス遮断
  blocklist("block suspicious paths") do |req|
    path = req.path.downcase

    path.include?("wp-admin") ||
    path.include?("wp-login") ||
    path.include?("phpmyadmin") ||
    path.include?("adminer") ||
    path.include?(".env") ||
    path.include?("/.git") ||
    path.include?("/config") ||
    path.include?("/vendor") ||
    path.include?("/secrets") ||
    path.include?("/keys") ||
    path.include?("/scripts") ||
    path.include?("/.aws") ||
    path.include?("/.ssh") ||
    path.include?("/.gnupg") ||
    path.include?("/.private") ||
    path.include?("/.backup") ||
    path.include?("/.old") ||
    path.include?("/.archive") ||
    path.include?("/.hidden") ||
    path.include?("/.secret") ||
    path.end_with?(".php")
  end

  self.blocklisted_responder = lambda do |_request|
    [
      403,
      { "Content-Type" => "text/plain; charset=utf-8" },
      [ "Forbidden" ]
    ]
  end

  # 制限がかかった時に返す設定
  self.throttled_responder = lambda do |request|
    headers = {
      "Retry-After" => "60"
    }

    accept = request.get_header("HTTP_ACCEPT").to_s

    if request.path == "/users/sign_in" && request.post? && accept.include?("text/vnd.turbo-stream.html")
      body = <<~HTML
        <turbo-stream action="prepend" target="flash">
          <template>
            <div data-controller="flash"
              class="flash-message alert pointer-events-auto px-4 py-2 rounded-xl min-w-[180px] text-center text-white text-sm font-medium shadow-lg select-none opacity-0 -translate-y-2 transition-all duration-300 bg-red-500">
              ログイン試行回数が多すぎます。少し待ってからもう一度お試しください。
            </div>
          </template>
        </turbo-stream>
      HTML
      [ 429, headers.merge("Content-Type" => "text/vnd.turbo-stream.html; charset=utf-8"), [ body ] ]
    else
      body = File.read(Rails.root.join("public/429.html"))
      [ 429, headers.merge("Content-Type" => "text/html; charset=utf-8"), [ body ] ]
    end
  end
end
