# frozen_string_literal: true

class Notifications::PollingController < ApplicationController
  # Rate limiting to prevent abuse
  rate_limit to: 30, within: 1.minute, only: :index

  # GET /notifications/polling
  # Returns unread notifications and count for current user
  def index
    # Implement caching to reduce database load
    cache_key = ["notifications", current_user.id, :unread, Time.current.minute]

    if Rails.cache.exist?(cache_key)
      @notifications = Rails.cache.read(cache_key)
      @notifications_count = Rails.cache.read(["notifications_count", current_user.id, :unread])
    else
      # Fetch unread notifications with efficient queries
      @notifications = current_user.notifications.unread.includes([
        :notifiable,
        { notifiable: [:user, :post, :comment] },
        :user,
        { user: :profile }
      ]).order(created_at: :desc).limit(50)

      @notifications_count = current_user.notifications.unread.count

      # Cache the results
      Rails.cache.write(cache_key, @notifications, expires_in: 1.minute)
      Rails.cache.write(["notifications_count", current_user.id, :unread],
                       @notifications_count, expires_in: 1.minute)
    end

    # Format response for optimal client performance
    render json: {
      notifications: format_notifications(@notifications),
      notifications_count: @notifications_count,
      last_checked_at: Time.current.iso8601,
      polling_interval: 5000 # Client should poll every 5 seconds
    }
  end

  # POST /notifications/polling/refresh
  # Manually refresh notifications (admin/maintenance)
  def refresh
    # Clear cache for current user
    Rails.cache.delete(["notifications", current_user.id, :unread, Time.current.minute])
    Rails.cache.delete(["notifications_count", current_user.id, :unread])

    # Fetch fresh data
    @notifications = current_user.notifications.unread.recent.includes([:notifiable, :user])
    @notifications_count = current_user.notifications.unread.count

    # Return fresh data
    render json: {
      notifications: format_notifications(@notifications),
      notifications_count: @notifications_count,
      last_checked_at: Time.current.iso8601,
      refresh_requested: true
    }
  end

  private

  # Format notifications for API response
  def format_notifications(notifications)
    notifications.map do |notification|
      {
        id: notification.id,
        notification_type: notification.notification_type,
        message: format_notification_message(notification),
        notifiable_type: notification.notifiable_type,
        notifiable_id: notification.notifiable_id,
        read: notification.read_at.present?,
        created_at: notification.created_at.iso8601,
        time_ago: time_ago_in_words(notification.created_at),
        user_avatar_url: avatar_url_for_notification(notification),
        actor_username: notification_actor_username(notification),
        priority: notification_priority(notification),
        action_url: notification_action_url(notification)
      }
    end
  end

  # Format notification message based on type
  def format_notification_message(notification)
    case notification.notification_type
    when 'comment_created'
      "#{notification.notifiable.user.profile.username} commented on your post"
    when 'like_created'
      "#{notification.notifiable.user.profile.username} liked your post"
    when 'reaction_created'
      "#{notification.notifiable.user.profile.username} reacted to your post with #{reaction_emoji(notification.notifiable.reaction_type)}"
    when 'new_follower'
      "#{notification.notifiable.user.profile.username} started following you"
    else
      notification.notification_type.titleize
    end
  end

  # Format time ago in human-readable format
  def time_ago_in_words(timestamp)
    distance_in_words = ActiveSupport::Duration.new(Time.current - timestamp).to_i
    case distance_in_words
    when 0..59
      "just now"
    when 60..119
      "1 minute ago"
    when 120..1439
      "#{distance_in_words / 60} minutes ago"
    when 1440..2519
      "1 hour ago"
    when 2520..43199
      "#{(distance_in_words / 3600).to_i} hours ago"
    when 43200..86399
      "1 day ago"
    else
      "#{(distance_in_words / 86400).to_i} days ago"
    end
  end

  # Get avatar URL for notification
  def avatar_url_for_notification(notification)
    if notification.user && notification.user.profile && notification.user.profile.avatar_url.present?
      notification.user.profile.avatar_url
    else
      asset_url('default-avatar.png')
    end
  end

  # Get actor username for notification
  def notification_actor_username(notification)
    if notification.notifiable.respond_to?(:user) && notification.notifiable.user&.profile&.username
      notification.notifiable.user.profile.username
    else
      "user"
    end
  end

  # Determine notification priority
  def notification_priority(notification)
    case notification.notification_type
    when 'new_follower'
      'high'
    when 'comment_created'
      'medium'
    else
      'low'
    end
  end

  # Get action URL for notification
  def notification_action_url(notification)
    case notification.notifiable_type
    when 'Comment'
      post_url(notification.notifiable.post)
    when 'Like'
      post_url(notification.notifiable.post)
    when 'Reaction'
      post_url(notification.notifiable.post)
    when 'Follow'
      profile_url(notification.notifiable.user.profile)
    else
      '#'
    end
  end

  # Helper URLs
  def post_url(post)
    post_path(post)
  end

  def profile_url(profile)
    profile_path(profile.username)
  end

  # Reaction emoji helper
  def reaction_emoji(reaction_type)
    emojis = {
      '😍' => '😍',
      '😂' => '😂',
      '😢' => '😢',
      '😡' => '😡',
      '👍' => '👍',
      '🔥' => '🔥',
      '💯' => '💯',
      '❤️' => '❤️',
      '🎉' => '🎉'
    }
    emojis[reaction_type] || reaction_type
  end
end