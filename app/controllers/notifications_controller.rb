# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_user!

  # GET /notifications
  def index
    @pagy, @notifications = pagy(current_user.notifications.recent.includes(:notifiable), items: 20)
  end

  # PATCH /notifications/:id/mark-as-read
  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream { render :mark_as_read }
      format.json { render json: { status: "success" } }
      format.html { redirect_to notifications_path, notice: "Notification marked as read." }
    end
  end

  # PATCH /notifications/mark-all-as-read
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    respond_to do |format|
      format.turbo_stream { redirect_to notifications_path, notice: "All notifications marked as read." }
      format.json { render json: { status: "success" } }
      format.html { redirect_to notifications_path, notice: "All notifications marked as read." }
    end
  end

  # DELETE /notifications/:id
  def destroy
    @notification = current_user.notifications.find(params[:id])
    @notification.destroy

    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.json { render json: { status: "success" } }
      format.html { redirect_to notifications_path, notice: "Notification deleted." }
    end
  end

  # POST /notifications/polling/refresh
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

  def avatar_url_for_notification(notification)
    if notification.user && notification.user.profile && notification.user.profile.avatar_url.present?
      notification.user.profile.avatar_url
    else
      asset_url('default-avatar.png')
    end
  end

  def notification_actor_username(notification)
    if notification.notifiable.respond_to?(:user) && notification.notifiable.user&.profile&.username
      notification.notifiable.user.profile.username
    else
      "user"
    end
  end

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

  def post_url(post)
    post_path(post)
  end

  def profile_url(profile)
    profile_path(profile.username)
  end

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