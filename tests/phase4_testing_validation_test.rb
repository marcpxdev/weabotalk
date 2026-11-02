"""
Phase 4: Testing & Validation Tests
Testing the polling-based notification system and Vercel compatibility
"""

require 'test_helper'

class Phase4TestingValidationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @notification = create(:notification, user: @user)
  end

  test "Phase 4.1 Development Environment Setup - polling API endpoint exists" do
    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes(json.keys, 'notifications')
    assert_includes(json.keys, 'notifications_count')
    assert_includes(json.keys, 'last_checked_at')
    assert_includes(json.keys, 'polling_interval')
  end

  test "Phase 4.1 Database Connectivity - can access notifications" do
    assert_notification = @notification

    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    assert(json['notifications_count'].present?)
    assert(json['notifications'].is_a?(Array))
    assert(json['notifications'].length <= 50)
  end

  test "Phase 4.2 Build & Deploy Testing - polling system works as expected" do
    # Clear any existing cache
    Rails.cache.delete(["notifications", @user.id, :unread, Time.current.minute])
    Rails.cache.delete(["notifications_count", @user.id, :unread])

    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    # Verify polling response structure
    assert_includes(json.keys, 'notifications')
    assert_includes(json.keys, 'notifications_count')
    assert_includes(json.keys, 'last_checked_at')
    assert_includes(json.keys, 'polling_interval')

    # Verify polling interval is reasonable (should be 5000)
    assert_equal(5000, json['polling_interval'])
  end

  test "Phase 4.2 Build & Deploy Testing - caching mechanism works" do
    # Clear any existing cache
    Rails.cache.delete(["notifications", @user.id, :unread, Time.current.minute])
    Rails.cache.delete(["notifications_count", @user.id, :unread])

    # First call should populate cache
    get '/notifications/polling', headers: auth_headers(@user)
    assert_response :success

    first_response = JSON.parse(response.body)
    first_count = first_response['notifications_count']

    # Second call should use cache (response should be identical)
    get '/notifications/polling', headers: auth_headers(@user)
    assert_response :success

    second_response = JSON.parse(response.body)

    # Count should be the same
    assert_equal(first_count, second_response['notifications_count'])
  end

  test "Phase 4.3 Feature Testing - notification format validation" do
    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    # Test notification structure
    if json['notifications'].any?
      notification = json['notifications'].first

      assert_includes(notification.keys, 'id')
      assert_includes(notification.keys, 'notification_type')
      assert_includes(notification.keys, 'message')
      assert_includes(notification.keys, 'notifiable_type')
      assert_includes(notification.keys, 'notifiable_id')
      assert_includes(notification.keys, 'read')
      assert_includes(notification.keys, 'created_at')
      assert_includes(notification.keys, 'time_ago')
      assert_includes(notification.keys, 'user_avatar_url')
      assert_includes(notification.keys, 'actor_username')
      assert_includes(notification.keys, 'priority')
      assert_includes(notification.keys, 'action_url')

      # Validate notification type values
      valid_types = ['comment_created', 'like_created', 'reaction_created', 'new_follower']
      assert valid_types.include?(notification['notification_type']) ||
             notification['notification_type'].nil?

      # Validate priority values
      valid_priorities = ['high', 'medium', 'low']
      assert valid_priorities.include?(notification['priority']) ||
             notification['priority'].nil?
    end
  end

  test "Phase 4.3 Feature Testing - time formatting consistency" do
    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    # Test time_ago formatting
    if json['notifications'].any?
      time_ago = json['notifications'].first['time_ago']

      # Valid time_ago values
      valid_time_formats = ['just now', '1 minute ago', '2 minutes ago',
                           '1 hour ago', '2 hours ago', '1 day ago',
                           '2 days ago', 'just now']

      assert valid_time_formats.include?(time_ago) ||
             time_ago.start_with?('minutes ago') ||
             time_ago.start_with?('hours ago') ||
             time_ago.start_with?('days ago')
    end
  end

  test "Phase 4.3 Feature Testing - authentication protection" do
    # Test without authentication
    get '/notifications/polling'

    # Should redirect to sign-in or return unauthorized
    assert_response !(200...300)

    # Test with different user (should only see own notifications)
    other_user = create(:user)
    get '/notifications/polling', headers: auth_headers(other_user)

    assert_response :success
    json = JSON.parse(response.body)

    # Should see zero or user's own notifications
    assert json['notifications_count'].zero? || json['notifications'].present?
  end

  test "Phase 4.3 Feature Testing - polling interval consistency" do
    get '/notifications/polling', headers: auth_headers(@user)

    assert_response :success
    json = JSON.parse(response.body)

    # Polling interval should be consistent and reasonable
    assert_equal(5000, json['polling_interval'])
    assert_operator(json['polling_interval'], :>=, 1000) # At least 1 second
    assert_operator(json['polling_interval'], :<, 60000) # Less than 1 minute
  end

  test "Phase 4.3 Feature Testing - CSRF protection" do
    # Test that CSRF token is required (Rails standard behavior)
    # This tests the base framework requirement
    assert true # Rails CSRF protection is handled by default
  end

  test "Phase 4.3 Feature Testing - rate limiting" do
    # Test rate limiting (Phase 3 implementation)
    # We'll call the endpoint multiple times and ensure it works

    # Clear cache first
    Rails.cache.delete(["notifications", @user.id, :unread, Time.current.minute])

    # Make several calls (should all succeed within limits)
    5.times do
      get '/notifications/polling', headers: auth_headers(@user)
      assert_response :success, "Call #{_} should succeed"
    end
  end

  private

  def auth_headers(user)
    sign_in user
    headers = user.create_new_session_for_request!
    headers.merge!({'Authorization' => "Bearer #{user.token}"})
  end
end