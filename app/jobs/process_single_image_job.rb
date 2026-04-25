class ProcessSingleImageJob < ApplicationJob
  queue_as :variants

  def perform(image_id)
    image = ActiveStorage::Attachment.find_by(id: image_id)
    return unless image

    image.variant(:map_icon).processed
    image.variant(:thumb).processed
  end
end
