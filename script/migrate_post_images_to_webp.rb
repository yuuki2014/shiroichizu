# scripts/migrate_post_images_to_webp.rb

puts "Start webp migration"

Post.includes(images_attachments: :blob).find_each do |post|
  created_blobs = []

  begin
    post.images.each do |image|
      old_blob = image.blob
      old_key = old_blob.key

      next if old_key.start_with?("posts/")

      old_blob.open do |file|
        webp_file = ImageProcessing::Vips
          .source(file)
          .resize_to_limit(1600, 1600)
          .convert("webp")
          .saver(quality: 85)
          .call

        new_blob = ActiveStorage::Blob.create_and_upload!(
          io: webp_file,
          filename: "#{File.basename(old_blob.filename.to_s, ".*")}.webp",
          content_type: "image/webp",
          key: "posts/#{post.id}/images/#{SecureRandom.uuid}.webp",
          service_name: "cloudflare"
        )

        created_blobs << new_blob

        ActiveStorage::Attachment.create!(
          name: "images",
          record: post,
          blob: new_blob
        )
        puts "converted post=#{post.id} old_key=#{old_key} new_key=#{new_blob.key}"

        # begin
        #   attachment.variant(:map_icon).processed
        #   attachment.variant(:thumb).processed

        #   puts "variants processed post=#{post.id} key=#{new_blob.key}"
        # rescue => e
        #   puts "variant failed post=#{post.id} key=#{new_blob.key} error=#{e.class} #{e.message}"
        #   raise
        # end
      ensure
        webp_file&.close
        webp_file&.unlink
      end
    end
  rescue => e
    puts "failed post=#{post.id} error=#{e.class} #{e.message}"

    created_blobs.each do |blob|
      blob.purge
      puts "purged created blob key=#{blob.key}"
    rescue => purge_error
      puts "failed purge key=#{blob.key} error=#{purge_error.class} #{purge_error.message}"
    end
  end
end

puts "Done"
