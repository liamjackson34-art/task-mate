import { createRouter, createWebHistory } from "vue-router"
import { onAuthStateChanged } from "firebase/auth"
import { auth } from "../api/firebase"

// Import views
import Home from "../components/Home.vue"
import Projects from "../components/Projects.vue"
import Tasks from "../components/Tasks.vue"
import Settings from "../components/Settings.vue"
import About from "../components/About.vue"
import Friends from "../components/Friends.vue"

// Helper: get current user
function getCurrentUser() {
  return new Promise((resolve, reject) => {
    const unsubscribe = onAuthStateChanged(
      auth,
      (user) => {
        unsubscribe()
        resolve(user)
      },
      (error) => {
        unsubscribe()
        reject(error)
      }
    )
  })
}

// Routes definition
const routes = [
  {
    path: "/",
    name: "home",
    component: Home
  },
  {
    path: "/projects",
    name: "projects",
    component: Projects,
    meta: { requiresAuth: true }
  },
  {
    path: "/tasks/:id",
    name: "tasks",
    component: Tasks,
    meta: { requiresAuth: true }
  },
  {
    path: "/settings",
    name: "settings",
    component: Settings,
    meta: { requiresAuth: true }
  },
  {
    path: "/friends",
    name: "friends",
    component: Friends,
    meta: { requiresAuth: true }
  },
  {
    path: "/about",
    name: "about",
    component: About
  },
  // Catch-all redirect to home
  {
    path: "/:pathMatch(.*)*",
    redirect: "/"
  }
]

// Router instance
const router = createRouter({
  history: createWebHistory(),
  routes
})

// Global auth guard for protected routes
router.beforeEach(async (to, from, next) => {
  if (to.meta.requiresAuth) {
    try {
      const user = await getCurrentUser()
      if (user) {
        next()
      } else {
        // Redirect to home for login/register functionality
        next("/")
      }
    } catch (error) {
      console.error("Protected route guard error:", error)
      next("/")
    }
  } else {
    next()
  }
})

export default router