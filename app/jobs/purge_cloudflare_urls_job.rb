class PurgeCloudflareUrlsJob < ApplicationJob
  queue_as :default

  def perform(urls)
    urls = Array(urls).compact_blank.uniq
    return if urls.blank?

    conn = Faraday.new(url: "https://api.cloudflare.com")

    response = conn.post("/client/v4/zones/#{ENV.fetch("CLOUDFLARE_ZONE_ID")}/purge_cache") do |req|
      req.headers["Authorization"] = "Bearer #{ENV.fetch("CLOUDFLARE_CACHE_PURGE_API_TOKEN")}"
      req.headers["Content-Type"] = "application/json"
      req.body = { files: urls }.to_json
    end

    Rails.logger.info("Cloudflare purge response: #{response.status} #{response.body}")

    unless response.success?
      Rails.logger.error("Cloudflare purge failed: #{response.status} #{response.body}")
    end
  rescue => e
    Rails.logger.error("Cloudflare purge error: #{e.class} #{e.message}")
    raise
  end
end
