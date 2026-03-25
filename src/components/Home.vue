<script setup>
import { ref, onMounted, computed, watch } from "vue"
import { useRouter } from "vue-router"
import { useUser } from "../composables/useUser"
import { doc, getDoc } from "firebase/firestore"
import { db } from "../api/firebase"

const welcomeMessage = ref("")
const router = useRouter()

// User state
const { currentUser, displayName, loading } = useUser()

// User-specific data
const userProjects = ref([])
const showCTA = ref(true)

onMounted(async () => {
  welcomeMessage.value = "Helping You Stay on Track"

  // If user logged in, fetch projects
  if (currentUser.value) {
    await fetchUserProjects(currentUser.value.uid)
  }
})

// Watch for login/logout changes
watch(currentUser, async (newUser) => {
  if (newUser) {
    await fetchUserProjects(newUser.uid)
  } else {
    userProjects.value = []
    showCTA.value = true
  }
})

// Fetch projects from user doc
const fetchUserProjects = async (uid) => {
  const userRef = doc(db, "users", uid)
  const snap = await getDoc(userRef)
  if (snap.exists()) {
    const data = snap.data()
    userProjects.value = data.projects || []
    showCTA.value = userProjects.value.length === 0
  }
}

// CTA button
const ctaText = computed(() => (currentUser.value ? "Go to My Projects" : "Get Started"))
const ctaLink = computed(() => (currentUser.value ? "/projects" : "/register"))
const handleCTA = () => router.push(ctaLink.value)
</script>

<template>
  <section class="taskmate-page container">
    <div class="taskmate-card-md">
      <div class="card yellow-sticker-card p-4 p-md-5 text-center">

        <p class="lead text-dark mb-4">
          {{ welcomeMessage }}
        </p>

        <!-- Personalized greeting -->
        <p v-if="currentUser && !loading" class="mb-4">
          Welcome back, {{ displayName || "TaskMate User" }}!
        </p>

        <!-- CTA button only if needed -->
        <button v-if="!currentUser || showCTA" @click="handleCTA" class="btn btn-success btn-lg px-4">
          {{ ctaText }}
        </button>

        <!-- Optional message if logged-in user has projects -->
        <p v-else-if="currentUser && userProjects.length > 0">
          You have {{ userProjects.length }} active project{{ userProjects.length > 1 ? "s" : "" }}.
          <router-link to="/projects">Go to your projects</router-link>
        </p>

      </div>
    </div>
  </section>
</template>

<style scoped>
/* Keep existing styles */
</style>