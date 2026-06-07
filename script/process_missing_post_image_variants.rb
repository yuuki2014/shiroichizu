# variantが作られていないものを探す

# Post.includes(images_attachments: :blob).find_each do |post|
#   post.images.each do |image|
#     next unless image.blob.key.start_with?("posts/")

#     [:map_icon, :thumb].each do |variant_name|
#       variant = image.variant(variant_name)

#       unless ActiveStorage::Blob.service.exist?(variant.key)
#         puts "missing post=#{post.id} variant=#{variant_name} key=#{variant.key}"
#       end
#     end
#   end
# end


puts "Start missing variants processing"

Post.includes(images_attachments: :blob).find_each do |post|
  post.images.each do |image|
    blob = image.blob

    next unless blob.key.start_with?("posts/")

    [ :map_icon, :thumb ].each do |variant_name|
      begin
        variant = image.variant(variant_name)

        if ActiveStorage::Blob.service.exist?(variant.key)
          puts "skip exists post=#{post.id} variant=#{variant_name} key=#{variant.key}"
          next
        end

        puts "process missing post=#{post.id} variant=#{variant_name} source=#{blob.key}"
        variant.processed

        if ActiveStorage::Blob.service.exist?(variant.key)
          puts "created post=#{post.id} variant=#{variant_name} key=#{variant.key}"
        else
          puts "failed_missing_after_processed post=#{post.id} variant=#{variant_name} key=#{variant.key}"
        end
      rescue => e
        puts "failed post=#{post.id} blob=#{blob.id} variant=#{variant_name} error=#{e.class} #{e.message}"
      end
    end
  end
end

puts "Done"
