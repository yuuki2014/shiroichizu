class ProcessPostImagesJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return unless post

    post.images.each do |image|
      ProcessSingleImageJob.perform_later(image.id)
    end
  end
end
