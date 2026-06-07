class ProcessSingleImageJob < ApplicationJob
  queue_as :variants

  def perform(image_id)
    image = ActiveStorage::Attachment.find_by(id: image_id)
    return unless image

    post = image.record
    return unless post

    map_icon = image.variant(:map_icon).processed

    if post.is_a?(Post) && post.images.first&.id == image.id
      icon_url = "#{ENV.fetch("MEDIA_BASE_URL")}/#{map_icon.key}"

      Turbo::StreamsChannel.broadcast_append_to(
        [ post.user, :map_image_updates  ],
        target: "main-map",
        html: ApplicationController.render(
          partial: "posts/map_icon_ready",
          locals: {
            post: post,
            icon_url: icon_url
          }
        )
      )

      Turbo::StreamsChannel.broadcast_append_to(
        [ post.user, :map_image_updates ],
        target: "history-map",
        html: ApplicationController.render(
          partial: "posts/history_map_icon_ready",
          locals: {
            post: post,
            icon_url: icon_url
          }
        )
      )
    end
    image.variant(:thumb).processed
  end
end
