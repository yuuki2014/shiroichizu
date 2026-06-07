puts "Start images migration"

Post.joins(:images_attachments).distinct.find_each do |post|
  created_blobs = []

  begin
    new_blobs = []

    post.images.each do |image|
      old_blob = image.blob
      old_key  = old_blob.key

      if old_key.start_with?("posts/")
        puts "skip post=#{post.id} already migrated key=#{old_key}"
        next
      end

      ext = File.extname(old_blob.filename.to_s).downcase

      old_blob.open do |file|
        new_blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: old_blob.filename.to_s,
          content_type: old_blob.content_type,
          key: "posts/#{post.id}/images/#{SecureRandom.uuid}#{ext}",
          service_name: "cloudflare"
        )

        new_blobs << new_blob
        created_blobs << new_blob
        puts "copied post=#{post.id} old_key=#{old_key} new_key=#{new_blob.key} count=#{new_blobs.size}"
      end
    end

    if new_blobs.any?
      post.images.attach(new_blobs)
      post.reload
      puts "attached post=#{post.id} attached_count=#{new_blobs.size} total_count=#{post.images.count}"
    end
  rescue => e
    puts "failed post=#{post.id} error=#{e.class} #{e.message}"

    created_blobs.each do |blob|
      begin
        blob.purge
        puts "purged orphan blob key=#{blob.key}"
      rescue => purge_error
        puts "failed purge orphan blob key=#{blob.key} error=#{purge_error.class} #{purge_error.message}"
      end
    end
  end
end

puts "Done"
