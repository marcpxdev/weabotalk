import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bell", "count", "container"]

  connect() {
    // Toggle notification dropdown
    this.bellTarget.addEventListener('click', this.toggleNotificationDropdown.bind(this))

    // Handle escape key to close dropdown
    this.handleEscapeKey()

    // Start polling
    this.startPolling()
  }

  disconnect() {
    // Clean up event listeners
    this.bellTarget.removeEventListener('click', this.toggleNotificationDropdown)
    document.removeEventListener('click', this.handleOutsideClick.bind(this))

    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
    }
  }

  toggleNotificationDropdown() {
    this.containerTarget.classList.toggle('show')

    // Close on mobile after selection
    if (window.innerWidth < 768) {
      setTimeout(() => {
        this.containerTarget.classList.remove('show')
      }, 2000)
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.containerTarget.classList.remove('show')
    }
  }

  startPolling() {
    // Initial data load
    this.loadNotifications()

    // Set up polling
    this.pollingInterval = setInterval(() => {
      this.loadNotifications()
    }, 5000) // Poll every 5 seconds
  }

  loadNotifications() {
    fetch('/notifications/polling', {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      this.updateNotificationCount(data.notifications_count)
      this.renderNotifications(data.notifications)
    })
    .catch(error => {
      console.error('Error loading notifications:', error)
    })
  }

  updateNotificationCount(count) {
    if (this.countTarget) {
      const previousCount = parseInt(this.countTarget.textContent) || 0

      if (count !== previousCount) {
        this.countTarget.textContent = count

        // Add animation
        this.countTarget.classList.add('count-update')
        setTimeout(() => {
          this.countTarget.classList.remove('count-update')
        }, 1000)

        // Update bell icon
        if (count > 0) {
          this.bellTarget.classList.add('has-notifications')
          this.bellTarget.setAttribute('aria-label', `${count} unread notifications`)
        } else {
          this.bellTarget.classList.remove('has-notifications')
          this.bellTarget.setAttribute('aria-label', 'No notifications')
        }
      }
    }
  }

  renderNotifications(notifications) {
    if (!this.containerTarget) return

    this.containerTarget.innerHTML = ''

    if (notifications.length === 0) {
      this.containerTarget.innerHTML = `
        <div class="empty-notifications">
          <div class="empty-icon">🔔</div>
          <p>No new notifications</p>
        </div>
      "
      return
    }

    // Render recent notifications
    const recentNotifications = notifications.slice(0, 5)
    recentNotifications.forEach(notification => {
      const notificationElement = this.createNotificationElement(notification)
      this.containerTarget.appendChild(notificationElement)
    })

    // Add "View all" link if there are more notifications
    if (notifications.length > 5) {
      const viewAllLink = document.createElement('a')
      viewAllLink.href = '/notifications'
      viewAllLink.className = 'view-all-notifications'
      viewAllLink.textContent = `View all ${notifications.length} notifications`
      this.containerTarget.appendChild(viewAllLink)
    }
  }

  createNotificationElement(notification) {
    const element = document.createElement('div')
    element.className = 'notification-item'
    element.setAttribute('data-notification-id', notification.id)

    const isRead = notification.read || false
    if (isRead) {
      element.classList.add('read')
    }

    element.innerHTML = `
      <div class="notification-content">
        <div class="notification-avatar">
          <img src="${notification.user_avatar_url || '/placeholder-avatar.png'}" alt="" />
        </div>
        <div class="notification-info">
          <div class="notification-message">${this.escapeHtml(notification.message)}</div>
          <div class="notification-time">${this.formatTimeAgo(notification.created_at)}</div>
        </div>
      </div>
      <div class="notification-actions">
        ${!isRead ? `<button class="btn-mark-read" data-notification-id="${notification.id}">Mark as read</button>` : ''}
      </div>
    "

    // Add event listener for mark as read
    const markReadButton = element.querySelector('.btn-mark-read')
    if (markReadButton) {
      markReadButton.addEventListener('click', (e) => {
        e.preventDefault()
        this.markNotificationAsRead(notification.id, element)
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
    })
  }

  handleEscapeKey() {
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        this.containerTarget.classList.remove('show')
      }
    })
  }

  updateNotificationBadge(count) {
    // Custom badge implementation for bell
    let badge = this.element.querySelector('.notification-badge')
    if (!badge) {
      badge = document.createElement('span')
      badge.className = 'notification-badge'
      this.bellTarget.appendChild(badge)
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
      return 'now'
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