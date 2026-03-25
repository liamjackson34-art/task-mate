<script setup>
import { ref, onMounted, onUnmounted, computed } from "vue"
import { useRouter } from "vue-router"
import { onAuthStateChanged } from "firebase/auth"
import { collection, onSnapshot, query, where } from "firebase/firestore"
import { auth, db } from "../api/firebase"

const router = useRouter()

const currentUser = ref(null)
const notifications = ref([])

let unsubscribeAuth = null
let unsubscribeProjects = null

const getDateStringFromDate = (date) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, "0")
  const day = String(date.getDate()).padStart(2, "0")
  return `${year}-${month}-${day}`
}

const getTodayDateString = () => {
  return getDateStringFromDate(new Date())
}

const getTomorrowDateString = () => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return getDateStringFromDate(tomorrow)
}

const formatDate = (dateString) => {
  if (!dateString) {
    return ""
  }

  const [year, month, day] = dateString.split("-").map(Number)
  const date = new Date(year, month - 1, day)

  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric"
  })
}

const hasNotifications = computed(() => notifications.value.length > 0)

const activeNotification = computed(() => {
  if (notifications.value.length > 0) {
    return notifications.value[0]
  }

  return {
    id: "default",
    title: "Notifications",
    message: "No new notifications",
    type: "idle",
    projectId: null
  }
})

const buildNotifications = (projects) => {
  const today = getTodayDateString()
  const tomorrow = getTomorrowDateString()
  const nextNotifications = []

  projects.forEach((project) => {
    const dueDate = project.dueDate || ""

    if (!dueDate) {
      return
    }

    if (dueDate === tomorrow) {
      nextNotifications.push({
        id: `due-tomorrow-${project.id}-${dueDate}`,
        title: "Due tomorrow",
        message: `${project.name} is due on ${formatDate(dueDate)}.`,
        type: "warning",
        projectId: project.id
      })
    } else if (dueDate === today) {
      nextNotifications.push({
        id: `due-today-${project.id}-${dueDate}`,
        title: "Due today",
        message: `${project.name} is due today.`,
        type: "danger",
        projectId: project.id
      })
    } else if (dueDate < today) {
      nextNotifications.push({
        id: `overdue-${project.id}-${dueDate}`,
        title: "Project overdue",
        message: `${project.name} was due on ${formatDate(dueDate)}.`,
        type: "secondary",
        projectId: project.id
      })
    }
  })

  const order = {
    danger: 1,
    warning: 2,
    secondary: 3
  }

  nextNotifications.sort((a, b) => {
    return (order[a.type] || 99) - (order[b.type] || 99)
  })

  notifications.value = nextNotifications
}

const openProject = () => {
  if (!activeNotification.value.projectId) {
    return
  }

  router.push(`/tasks/${activeNotification.value.projectId}`)
}

const dismissCurrentNotification = () => {
  if (notifications.value.length > 0) {
    notifications.value.shift()
  }
}

const watchProjects = (uid) => {
  if (unsubscribeProjects) {
    unsubscribeProjects()
    unsubscribeProjects = null
  }

  const projectsRef = collection(db, "projects")
  const projectsQuery = query(projectsRef, where("members", "array-contains", uid))

  unsubscribeProjects = onSnapshot(
    projectsQuery,
    (snapshot) => {
      const loadedProjects = snapshot.docs.map((projectDoc) => ({
        id: projectDoc.id,
        ...projectDoc.data()
      }))

      buildNotifications(loadedProjects)
    },
    (error) => {
      console.error("Error loading notifications:", error)
    }
  )
}

onMounted(() => {
  unsubscribeAuth = onAuthStateChanged(auth, (user) => {
    currentUser.value = user
    notifications.value = []

    if (unsubscribeProjects) {
      unsubscribeProjects()
      unsubscribeProjects = null
    }

    if (user) {
      watchProjects(user.uid)
    }
  })
})

onUnmounted(() => {
  if (unsubscribeAuth) {
    unsubscribeAuth()
  }

  if (unsubscribeProjects) {
    unsubscribeProjects()
  }
})
</script>

<template>
  <div
    class="notification-dock"
    :class="[
      `notification-${activeNotification.type}`,
      hasNotifications ? 'notification-expanded' : 'notification-collapsed'
    ]"
  >
    <div class="notification-header">
      <div class="notification-text-block">
        <h6 class="notification-title mb-0">
          {{ activeNotification.title }}
        </h6>

        <small v-if="hasNotifications" class="notification-count">
          {{ notifications.length }} active
        </small>
      </div>

      <span class="notification-indicator"></span>
    </div>

    <p v-if="hasNotifications" class="notification-message mb-0">
      {{ activeNotification.message }}
    </p>

    <div v-if="hasNotifications" class="notification-actions">
      <button
        v-if="activeNotification.projectId"
        class="btn btn-sm btn-light"
        @click="openProject"
      >
        Open Project
      </button>

      <button
        class="btn btn-sm btn-outline-light"
        @click="dismissCurrentNotification"
      >
        Dismiss
      </button>
    </div>
  </div>
</template>

<style scoped>
.notification-dock {
  position: fixed;
  left: 1rem;
  bottom: 1rem;
  z-index: 2000;
  border-radius: 18px;
  color: #ffffff;
  box-shadow: 0 16px 32px rgba(0, 0, 0, 0.18);
  transition: all 0.25s ease;
  overflow: hidden;
}

.notification-collapsed {
  width: 210px;
  min-height: 58px;
  padding: 0.8rem 0.9rem;
}

.notification-expanded {
  width: min(360px, calc(100vw - 2rem));
  min-height: 120px;
  padding: 1rem;
}

.notification-idle {
  background: #0d6efd;
}

.notification-warning {
  background: #f59f00;
}

.notification-danger {
  background: #dc3545;
}

.notification-secondary {
  background: #6c757d;
}

.notification-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.notification-text-block {
  min-width: 0;
}

.notification-title {
  font-weight: 700;
  line-height: 1.2;
}

.notification-count {
  display: inline-block;
  margin-top: 0.2rem;
  opacity: 0.9;
}

.notification-indicator {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.92);
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.notification-message {
  line-height: 1.45;
  margin-top: 0.7rem;
  min-height: 42px;
}

.notification-actions {
  display: flex;
  gap: 0.5rem;
  margin-top: 0.85rem;
  flex-wrap: wrap;
}

@media (max-width: 576px) {
  .notification-collapsed {
    width: 180px;
  }

  .notification-expanded {
    width: min(320px, calc(100vw - 1.5rem));
  }
}
</style>