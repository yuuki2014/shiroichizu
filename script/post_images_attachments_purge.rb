puts "start post images attachments purge"

Post.joins(:images_attachments).includes(images_attachments: :blob).distinct.find_each do |post|
  new_attachments = post.images_attachments.select { |a| a.blob.key.start_with?("posts/") }
  old_attachments = post.images_attachments.reject { |a| a.blob.key.start_with?("posts/") }

  if new_attachments.any?
    old_attachments.each do |attachment|
      puts "purging old attachment post=#{post.id} key=#{attachment.blob.key}"
      attachment.purge_later
    end
  else
    puts "skip post=#{post.id} (not migrated yet)"
  end
end

puts "Done"
