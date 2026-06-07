require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_email_verification_url
    assert_response :success
  end

  test "should create email verification" do
    post email_verification_url
    assert_response :redirect
  end
end
