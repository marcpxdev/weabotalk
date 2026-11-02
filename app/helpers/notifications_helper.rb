module NotificationsHelper
  # Format notification type for display
  def notification_type_badge_class(notification_type)
    case notification_type
    when 'comment_created'
      'comment-badge'
    when 'like_created'
      'like-badge'
    when 'reaction_created'
      'reaction-badge'
    when 'new_follower'
      'friend-request-badge'
    else
      'default-badge'
    end
  end

  # Get emoji for reaction type
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

  # Check if notification is actionable
  def notification_actionable?(notification)
    case notification.notifiable_type
    when 'Comment', 'Like', 'Reaction'
      true
    else
      false
    end
  end
end