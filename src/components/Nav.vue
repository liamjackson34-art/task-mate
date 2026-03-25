<script setup>
// Imports
import { ref, computed } from "vue"
import { useRouter } from "vue-router"
import {
  signOut,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  updateProfile
} from "firebase/auth"
import { doc, setDoc, serverTimestamp } from "firebase/firestore"
import { auth, db } from "../api/firebase"
import { useUser } from "../composables/useUser"

const { currentUser, displayName, avatarUrl, loading } = useUser()
const router = useRouter()

// Navbar / modal states
const showDropdown = ref(false)
const showLoginModal = ref(false)
const showRegisterModal = ref(false)

// Login state
const loginEmail = ref("")
const loginPassword = ref("")
const loginError = ref("")
const loginLoading = ref(false)

// Register state
const firstName = ref("")
const surname = ref("")
const registerEmail = ref("")
const registerPassword = ref("")
const confirmPassword = ref("")
const registerError = ref("")
const registerLoading = ref(false)

// Modal controls
const openLogin = () => {
  showLoginModal.value = true
  showRegisterModal.value = false
}
const openRegister = () => {
  showRegisterModal.value = true
  showLoginModal.value = false
}
const closeModals = () => {
  showLoginModal.value = false
  showRegisterModal.value = false
}

// Navbar computed
const ProjectRoute = computed(() => currentUser.value ? "/projects" : "/")
const initials = computed(() => {
  const name = displayName.value.trim()
  if (!name) return (currentUser.value?.email?.[0] || "T").toUpperCase()
  const parts = name.split(" ").filter(Boolean)
  return parts.length === 1 ? parts[0].slice(0, 2).toUpperCase() : (parts[0][0] + parts[1][0]).toUpperCase()
})

// Navbar functions
const toggleDropdown = () => (showDropdown.value = !showDropdown.value)
const closeDropdown = () => (showDropdown.value = false)
const go = (path) => { closeDropdown(); router.push(path) }
const logout = async () => { closeDropdown(); await signOut(auth); router.push("/") }
const goHome = () => router.push("/home")

// ✅ Form handlers

// Login function
const login = async () => {
  loginError.value = ""
  loginLoading.value = true
  try {
    await signInWithEmailAndPassword(auth, loginEmail.value, loginPassword.value)
    closeModals()
  } catch (err) {
    switch (err.code) {
      case "auth/invalid-credential":
      case "auth/wrong-password":
      case "auth/user-not-found":
        loginError.value = "Invalid email or password."
        break
      case "auth/invalid-email":
        loginError.value = "Please enter a valid email address."
        break
      case "auth/too-many-requests":
        loginError.value = "Too many attempts. Please try again later."
        break
      default:
        loginError.value = err.message
    }
  } finally {
    loginLoading.value = false
  }
}

// Register function
const register = async () => {
  registerError.value = ""
  if (!firstName.value.trim() || !surname.value.trim()) {
    registerError.value = "First and last name are required."
    return
  }
  if (registerPassword.value !== confirmPassword.value) {
    registerError.value = "Passwords do not match"
    return
  }
  registerLoading.value = true
  try {
    const cleanEmail = registerEmail.value.trim().toLowerCase()
    const userCredential = await createUserWithEmailAndPassword(auth, cleanEmail, registerPassword.value)
    const user = userCredential.user
    const fullName = `${firstName.value.trim()} ${surname.value.trim()}`
    
    await updateProfile(user, { displayName: fullName })

    // Firestore user document
    await setDoc(doc(db, "users", user.uid), {
      uid: user.uid,
      email: cleanEmail,
      firstName: firstName.value.trim(),
      surname: surname.value.trim(),
      displayName: fullName,
      avatarUrl: "",
      theme: "light",
      defaultVisibility: "private",
      friends: [],
      createdAt: serverTimestamp()
    })

    closeModals()
  } catch (err) {
    switch (err.code) {
      case "auth/email-already-in-use":
        registerError.value = "That email is already in use."
        break
      case "auth/invalid-email":
        registerError.value = "Please enter a valid email address."
        break
      case "auth/weak-password":
        registerError.value = "Password should be at least 6 characters."
        break
      default:
        registerError.value = err.message
    }
  } finally {
    registerLoading.value = false
  }
}

const email = computed(() => currentUser.value?.email || "")
</script>

<template>
  <nav class="navbar navbar-expand-lg navbar-light bg-light px-3">
    <div class="container-fluid d-flex justify-content-between align-items-center">

      <!-- 🔹 Left: Logo only -->
      <router-link :to="goHome" class="d-flex align-items-center gap-2 text-decoration-none">
        <div @click="goHome" class="d-flex align-items-center gap-2 text-decoration-none" style="cursor:pointer">
          <img src="/taskmate-logo.png" class="nav-logo" />
          <div class="d-flex flex-column">
            <span class="fw-bold nav-title">TaskMate</span>
          </div>
        </div>
      </router-link>

      <!-- 🔹 Right side -->
      <div class="d-flex gap-2 align-items-center">
        <button class="btn btn-primary btn-sm" @click="go('/about')">About us</button>
        <template v-if="!loading">

          <!-- 🔹 Logged OUT -->
          <template v-if="!currentUser">
            <button class="btn btn-success" @click="openRegister">Register</button>
            <button class="btn btn-primary" @click="openLogin">Login</button>
          </template>

          <!-- 🔹 Logged IN -->
          <template v-else>
            <button class="btn btn-primary btn-sm" @click="go(ProjectRoute)">My projects</button>

            <!-- Profile image or initials as dropdown trigger -->
            <div class="position-relative">
              <img
                v-if="avatarUrl"
                :src="avatarUrl"
                class="nav-avatar"
                @click.stop="toggleDropdown"
              />
              <div
                v-else
                class="nav-avatar-fallback"
                @click.stop="toggleDropdown"
              >
                {{ initials }}
              </div>

              <div v-if="showDropdown" class="dropdown-menu-custom" @click.stop>
              <!-- User Info -->
                <div class="dropdown-user-info mb-2">
                  <strong>{{ displayName }}</strong><br />
                  <small class="text-muted">{{ currentUser.email }}</small>
                </div>

                <hr>

                <button @click="go('/friends')">Friends</button>
                <button @click="go('/settings')">Settings</button>
                
                <hr />
                <button @click="logout" class="text-danger">Logout</button>
              </div>
            </div>
          </template>

        </template>

      </div>
    </div>
  </nav>

<!-- 🔹Login Modal Popup -->

  <div v-if="showLoginModal" class="modal-backdrop-custom" @click="closeModals">
    <div class="modal-card" @click.stop>
      <h4 class="mb-3">Login</h4>

      <form @submit.prevent="login">
        <input v-model="loginEmail" type="email" class="form-control mb-2" placeholder="Email" required />
        <input v-model="loginPassword" type="password" class="form-control mb-2" placeholder="Password" required />

        <div v-if="loginError" class="alert alert-danger">
          {{ loginError }}
        </div>

        <button class="btn btn-primary w-100" :disabled="loginLoading">
          {{ loginLoading ? "Logging in..." : "Login" }}
        </button>
      </form>

      <p class="mt-3 text-center">
        No account?
        <a href="#" @click.prevent="openRegister">Register</a>
      </p>
    </div>
  </div>

<!-- 🔹Register Modal Popup -->

  <div v-if="showRegisterModal" class="modal-backdrop-custom" @click="closeModals">
    <div class="modal-card" @click.stop>
      <h4 class="mb-3">Register</h4>

      <form @submit.prevent="register">
        <input v-model="firstName" class="form-control mb-2" placeholder="First Name" required />
        <input v-model="surname" class="form-control mb-2" placeholder="Surname" required />
        <input v-model="registerEmail" type="email" class="form-control mb-2" placeholder="Email" required />
        <input v-model="registerPassword" type="password" class="form-control mb-2" placeholder="Password" required />
        <input v-model="confirmPassword" type="password" class="form-control mb-2" placeholder="Confirm Password" required />

        <div v-if="registerError" class="alert alert-danger">
          {{ registerError }}
        </div>

        <button class="btn btn-success w-100" :disabled="registerLoading">
          {{ registerLoading ? "Creating..." : "Create Account" }}
        </button>
      </form>

      <p class="mt-3 text-center">
        Already have an account?
        <a href="#" @click.prevent="openLogin">Login</a>
      </p>
    </div>
  </div>

</template>

//Scoped CSS

  <style scoped>
  .nav-avatar-wrapper {
    cursor: pointer;
  }

  .nav-avatar,
  .nav-avatar-fallback,
  .nav-logo {
    width: 44px;
    height: 44px;
  }

  .nav-avatar {
    border-radius: 50%;
    object-fit: cover;
    border: 2px solid #dee2e6;
    cursor: pointer;
  }

  .nav-avatar-fallback {
    border-radius: 50%;
    background: #0d6efd;
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    border: 2px solid #dee2e6;
    cursor: pointer;
  }

  .dropdown-menu-custom {
    position: absolute;
    right: 0;
    top: 42px;
    background: white;
    border: 1px solid #ddd;
    border-radius: 10px;
    padding: 0.5rem;
    width: 160px;
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.15);
    z-index: 1200;
  }

  .dropdown-menu-custom button {
    width: 100%;
    border: none;
    background: none;
    padding: 0.5rem;
    text-align: left;
  }

  .dropdown-menu-custom button:hover {
    background: #f1f1f1;
  }

  .modal-backdrop-custom {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
  }

  .modal-card {
    background: white;
    padding: 2rem;
    border-radius: 12px;
    width: 100%;
    max-width: 400px;
  }
  </style>