class PostImageAttachService
  def self.call(post:, files:)
    blobs = []

    Array(files).each do |file|
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file.tempfile,
          filename: file.original_filename,
          content_type: file.content_type,
          key: post_image_key(post, file),
          service_name: "cloudflare"
        )

        blobs << blob
      rescue => e
        Rails.logger.warn(
          "[PostImageAttachService] upload failed post=#{post.id} filename=#{file.original_filename} error=#{e.class}: #{e.message}"
        )
      end
    end

    begin
      post.images.attach(blobs) if blobs.any?
    rescue => e
      blobs.each(&:purge_later)
      raise e
    end

    blobs
  end

  def self.post_image_key(post, file)
    ext = File.extname(file.original_filename.to_s).downcase
    "posts/#{post.id}/images/#{SecureRandom.uuid}#{ext}"
  end
end
