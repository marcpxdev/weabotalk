import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "count", "status"]

  connect() {
    this.pollingInterval = null
    this.lastPollTime = Date.now()
    this.isPolling = false

    // Initialize polling
    this.startPolling()

    // Set up visibility change listener
    this.handleVisibilityChange()
  }

  disconnect() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
    }
    this.isPolling = false
  }

  startPolling() {
    if (this.isPolling) return

    this.isPolling = true
    this.updateStatus("Connecting...")

    // Initial poll
    this.pollNotifications()

    // Set up regular polling
    this.pollingInterval = setInterval(() => {
      this.pollNotifications()
    }, 5000) // Poll every 5 seconds

    this.updateStatus("Polling active")
  }

  pollNotifications() {
    if (!this.isPolling) return

    const startTime = Date.now()

    fetch('/notifications/polling', {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      credentials: 'same-origin'
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      this.updateNotificationCount(data.notifications_count)
      this.checkForNewNotifications(data.notifications)
      this.lastPollTime = Date.now()

      // Update status with timing info
      const pollTime = Date.now() - startTime
      this.updateStatus(`Polling (${pollTime}ms)`)
    })
    .catch(error => {
      console.error('Notification polling error:', error)
      this.updateStatus("Polling error - retrying...")

      // Exponential backoff on error
      setTimeout(() => {
        this.startPolling()
      }, 5000) // Wait 5 seconds before retry
    })
  }

  updateNotificationCount(count) {
    if (this.countTarget) {
      const previousCount = parseInt(this.countTarget.textContent) || 0

      if (count !== previousCount) {
        this.countTarget.textContent = count

        // Animate count change
        this.countTarget.classList.add('count-changed')
        setTimeout(() => {
          this.countTarget.classList.remove('count-changed')
        }, 2000)

        // Update bell icon
        if (count > 0) {
          this.element.classList.add('has-notifications')
          this.updateNotificationBadge(count)
        } else {
          this.element.classList.remove('has-notifications')
        }
      }
    }
  }

  checkForNewNotifications(notifications) {
    // Filter out already seen notifications
    const newNotifications = notifications.filter(notification => {
      const notificationId = `notification-${notification.id}`
      return !this.element.querySelector(`[data-notification-id="${notificationId}"]`)
    })

    if (newNotifications.length > 0) {
      this.showNotificationToast(newNotifications)
      this.addNotificationsToDOM(newNotifications)
    }
  }

  showNotificationToast(notifications) {
    const toastContainer = this.createToastContainer()

    notifications.forEach((notification, index) => {
      setTimeout(() => {
        const toast = this.createToast(notification)
        toastContainer.appendChild(toast)

        // Animate in
        setTimeout(() => {
          toast.classList.add('show')
        }, 10)

        // Remove after 4 seconds
        setTimeout(() => {
          toast.classList.remove('show')
          setTimeout(() => {
            if (toastContainer.contains(toast)) {
              toastContainer.removeChild(toast)
            }
          }, 500)
        }, 4000)
      }, index * 100) // Stagger toasts
    })

    document.body.appendChild(toastContainer)
  }

  createToastContainer() {
    const container = document.createElement('div')
    container.className = 'notification-toast-container'
    container.setAttribute('aria-live', 'polite')
    container.setAttribute('aria-label', 'New notifications')
    return container
  }

  createToast(notification) {
    const toast = document.createElement('div')
    toast.className = 'notification-toast'
    toast.setAttribute('role', 'alert')
    toast.innerHTML = `
      <div class="toast-content">
        <div class="toast-icon">🔔</div>
        <div class="toast-message">
          <p>${this.escapeHtml(notification.message)}</p>
          <small>${this.formatTimeAgo(notification.created_at)}</small>
        </div>
        ${notification.action_url ? `<a href="${notification.action_url}" class="toast-action">View</a>` : ''}
      </div>
    `
    return toast
  }

  addNotificationsToDOM(notifications) {
    if (!this.containerTarget) return

    notifications.forEach(notification => {
      const notificationElement = this.createNotificationElement(notification)
      this.containerTarget.insertBefore(notificationElement, this.containerTarget.firstElementChild)
    })
  }

  createNotificationElement(notification) {
    const element = document.createElement('div')
    element.className = 'notification-item new-notification'
    element.setAttribute('data-notification-id', `notification-${notification.id}`)
    element.innerHTML = `
      <div class="notification-header">
        <div class="notification-avatar">
          <img src="${notification.user_avatar_url || '/placeholder-avatar.png'}" alt="User avatar" />
        </div>
        <div class="notification-meta">
          <span class="notification-username">${this.escapeHtml(notification.actor_username || 'User')}</span>
          <span class="notification-time">${this.formatTimeAgo(notification.created_at)}</span>
        </div>
        <div class="notification-priority ${notification.priority}">${notification.priority}</div>
      </div>
      <div class="notification-body">
        <p class="notification-message">${this.escapeHtml(notification.message)}</p>
      </div>
      <div class="notification-footer">
        ${notification.action_url ? `<a href="${notification.action_url}" class="btn-notification-action">View Details</a>` : ''}
        <button class="btn-mark-read" data-notification-id="${notification.id}">Mark as read</button>
      </div>
    `

    // Add event listeners
    const markReadButton = element.querySelector('.btn-mark-read')
    if (markReadButton) {
      markReadButton.addEventListener('click', (e) => {
        e.preventDefault()
        this.markNotificationAsRead(notification.id, element)
      })
    }

    const viewAction = element.querySelector('.btn-notification-action')
    if (viewAction) {
      viewAction.addEventListener('click', (e) => {
        e.preventDefault()
        // Track notification action
        this.trackNotificationAction('view', notification.id)
      })
    }

    return element
  }

  markNotificationAsRead(notificationId, element) {
    fetch(`/notifications/${notificationId}/mark-as-read`, {
      method: 'PATCH',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCsrfToken()
      },
      body: JSON.stringify({ read: true })
    })
    .then(response => response.json())
    .then(() => {
      element.classList.add('read')
      element.querySelector('.btn-mark-read').textContent = 'Read'
      element.querySelector('.btn-mark-read').disabled = true

      // Update count
      const currentCount = parseInt(this.countTarget.textContent) || 0
      this.countTarget.textContent = Math.max(0, currentCount - 1)
    })
    .catch(error => {
      console.error('Error marking notification as read:', error)
      // Revert UI change on error
      element.classList.remove('read')
    })
  }

  trackNotificationAction(action, notificationId) {
    // Analytics tracking
    if (window.gtag) {
      gtag('event', 'notification_action', {
        'event_category': 'Notifications',
        'event_label': action,
        'notification_id': notificationId
      })
    }
  }

  updateStatus(message) {
    if (this.statusTarget) {
      this.statusTarget.textContent = message
    }
  }

  handleVisibilityChange() {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        // Pause polling when tab is not visible
        this.isPolling = false
        if (this.pollingInterval) {
          clearInterval(this.pollingInterval)
        }
      } else {
        // Resume polling when tab becomes visible
        this.startPolling()
      }
    })
  }

  updateNotificationBadge(count) {
    // Custom badge implementation
    let badge = this.element.querySelector('.notification-badge')
    if (!badge) {
      badge = document.createElement('span')
      badge.className = 'notification-badge'
      this.element.appendChild(badge)
    }
    badge.textContent = count > 99 ? '99+' : count.toString()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  formatTimeAgo(isoString) {
    const date = new Date(isoString)
    const now = new Date()
    const diffInSeconds = Math.floor((now - date) / 1000)

    if (diffInSeconds < 60) {
      return 'just now'
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60)
      return `${minutes}m"
    } else if (diffInSeconds < 86400) {
      const hours = Math.floor(diffInSeconds / 3600)
      return `${hours}h"
    } else {
      const days = Math.floor(diffInSeconds / 86400)
      return `${days}d"
    }
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
  }
}