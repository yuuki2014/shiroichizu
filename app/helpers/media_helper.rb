module MediaHelper
  def media_image_url(key)
    # if !ActiveStorage::Blob.service.exist?(key) && key.start_with?("variants/")
    #   ActiveStorage::Blob.fi
    # end
    "#{ENV.fetch("MEDIA_BASE_URL")}/#{key}"
  end
end
