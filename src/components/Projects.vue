<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue"
import { useRouter } from "vue-router"
import { onAuthStateChanged } from "firebase/auth"
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
  addDoc
} from "firebase/firestore"
import { auth, db } from "../api/firebase"

const router = useRouter()

/* ------------------- Auth & Projects ------------------- */
const currentUser = ref(null)
const projects = ref([])
const loadingProjects = ref(true)
const errorMessage = ref("")
const successMessage = ref("")
const searchTerm = ref("")
const savingDueDateFor = ref("")
const dueDateInputs = ref({})

// Modal states
const showCreateProjectForm = ref(false)
const showProjectSettingsModal = ref(false)
const activeProject = ref(null)
const showDeleteConfirmModal = ref(false)
const projectToDelete = ref(null)

/* ------------------- Create Project Form ------------------- */
const projectName = ref("")
const projectMode = ref("solo")
const dueDate = ref("")
const creatingProject = ref(false)
const createErrorMessage = ref("")
const createSuccessMessage = ref("")

const getTodayDateString = () => {
  const today = new Date()
  const year = today.getFullYear()
  const month = String(today.getMonth() + 1).padStart(2, "0")
  const day = String(today.getDate()).padStart(2, "0")
  return `${year}-${month}-${day}`
}

const resetForm = () => {
  projectName.value = ""
  projectMode.value = "solo"
  dueDate.value = ""
}

const generateJoinCode = () => {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  let code = "TM-"
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return code
}

const createProject = async () => {
  createErrorMessage.value = ""
  createSuccessMessage.value = ""

  if (!currentUser.value) {
    createErrorMessage.value = "You must be logged in to create a project."
    return
  }

  if (!projectName.value.trim()) {
    createErrorMessage.value = "Project name is required."
    return
  }

  if (dueDate.value && dueDate.value < getTodayDateString()) {
    createErrorMessage.value = "Due date cannot be in the past."
    return
  }

  creatingProject.value = true

  try {
    const isGroup = projectMode.value === "group"
    const joinCode = isGroup ? generateJoinCode() : null

    const userRef = doc(db, "users", currentUser.value.uid)
    const userSnap = await getDoc(userRef)
    const userData = userSnap.exists() ? userSnap.data() : {}
    const userDefaultVisibility = userData?.defaultVisibility || "private"

    await addDoc(collection(db, "projects"), {
      name: projectName.value.trim(),
      ownerId: currentUser.value.uid,
      members: [currentUser.value.uid],
      projectType: projectMode.value,
      visibility: userDefaultVisibility,
      joinCode,
      dueDate: dueDate.value || "",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    })

    createSuccessMessage.value = isGroup
      ? "Group project created successfully."
      : "Project created successfully."

    resetForm()
    showCreateProjectForm.value = false
  } catch (error) {
    console.error("Error creating project:", error)
    createErrorMessage.value = "Failed to create project."
  } finally {
    creatingProject.value = false
  }
}

/* ------------------- Load & Filter Projects ------------------- */
let unsubscribeAuth = null
let unsubscribeProjects = null

const loadProjectsForUser = (uid) => {
  if (unsubscribeProjects) {
    unsubscribeProjects()
    unsubscribeProjects = null
  }

  loadingProjects.value = true
  errorMessage.value = ""

  const projectsRef = collection(db, "projects")
  const projectsQuery = query(projectsRef, where("members", "array-contains", uid))

  unsubscribeProjects = onSnapshot(
    projectsQuery,
    (snapshot) => {
      const loadedProjects = snapshot.docs.map((projectDoc) => ({
        id: projectDoc.id,
        ...projectDoc.data()
      }))

      loadedProjects.sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))

      projects.value = loadedProjects

      dueDateInputs.value = loadedProjects.reduce((acc, project) => {
        acc[project.id] = project.dueDate || ""
        return acc
      }, {})

      loadingProjects.value = false
    },
    (error) => {
      console.error("Error loading projects:", error)
      errorMessage.value = "Failed to load projects."
      loadingProjects.value = false
    }
  )
}

const filteredProjects = computed(() => {
  const term = searchTerm.value.trim().toLowerCase()
  if (!term) return projects.value
  return projects.value.filter((p) => (p.name || "").toLowerCase().includes(term))
})

/* ------------------- Project Actions ------------------- */
const openProject = (projectId) => router.push(`/tasks/${projectId}`)

const removeProject = async (project) => {
  errorMessage.value = ""
  successMessage.value = ""

  if (!currentUser.value || project.ownerId !== currentUser.value.uid) {
    errorMessage.value = "Only the project owner can remove this project."
    return
  }

  try {
    await deleteDoc(doc(db, "projects", project.id))
    successMessage.value = "Project removed successfully."
  } catch (error) {
    console.error("Error removing project:", error)
    errorMessage.value = "Failed to remove project."
  }
}

const saveDueDate = async (project) => {
  errorMessage.value = ""
  successMessage.value = ""

  if (!currentUser.value || project.ownerId !== currentUser.value.uid) {
    errorMessage.value = "Only the project owner can change the due date."
    return
  }

  const newDueDate = dueDateInputs.value[project.id] || ""

  if (newDueDate && newDueDate < getTodayDateString()) {
    errorMessage.value = "Due date cannot be in the past."
    return
  }

  savingDueDateFor.value = project.id

  try {
    await updateDoc(doc(db, "projects", project.id), {
      dueDate: newDueDate,
      updatedAt: serverTimestamp()
    })

    successMessage.value = newDueDate
      ? "Due date updated successfully."
      : "Due date removed successfully"
  } catch (error) {
    console.error("Error updating due date:", error)
    errorMessage.value = "Failed to update due date."
  } finally {
    savingDueDateFor.value = ""
  }
}

/* ------------------- Modals ------------------- */
const openProjectSettings = (project) => {
  activeProject.value = project
  showProjectSettingsModal.value = true
  dueDateInputs.value[project.id] = project.dueDate || ""
}

// Only opens confirmation modal
const requestRemoveProject = (project) => {
  projectToDelete.value = project
  showDeleteConfirmModal.value = true
}

// Confirm deletion and only close modal on success
const confirmDeleteProject = async () => {
  if (!projectToDelete.value) return

  await removeProject(projectToDelete.value)

  if (!errorMessage.value) {
    showDeleteConfirmModal.value = false
    showProjectSettingsModal.value = false
  }

  projectToDelete.value = null
}

/* ------------------- Helpers ------------------- */
const memberCount = (project) => Array.isArray(project.members) ? project.members.length : 0
const projectTypeLabel = (project) => project.projectType === "group" ? "Group Project" : "My Project"
const isOwner = (project) => currentUser.value && project.ownerId === currentUser.value.uid

const dueDateStatus = (project) => {
  if (!project.dueDate) return { text: "No due date", className: "bg-light text-dark" }

  const today = getTodayDateString()
  if (project.dueDate < today) return { text: "Overdue", className: "bg-danger" }
  if (project.dueDate === today) return { text: "Due today", className: "bg-warning text-dark" }

  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  const tomorrowString = `${tomorrow.getFullYear()}-${String(tomorrow.getMonth() + 1).padStart(2, "0")}-${String(tomorrow.getDate()).padStart(2, "0")}`
  if (project.dueDate === tomorrowString) return { text: "Due tomorrow", className: "bg-info text-dark" }

  return { text: "Scheduled", className: "bg-success" }
}

/* ------------------- Lifecycle ------------------- */
onMounted(() => {
  unsubscribeAuth = onAuthStateChanged(auth, (user) => {
    currentUser.value = user

    if (!user) {
      projects.value = []
      loadingProjects.value = false
      if (unsubscribeProjects) unsubscribeProjects()
      return
    }

    loadProjectsForUser(user.uid)
  })
})

onUnmounted(() => {
  if (unsubscribeAuth) unsubscribeAuth()
  if (unsubscribeProjects) unsubscribeProjects()
})
</script>

<template>
  <section class="taskmate-page container">
    <div class="taskmate-card-md">
      <div class="card yellow-sticker-card p-4 p-md-5">
        <!-- Header & Add Button -->
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-3 mb-4">
          <div>
            <h2 class="fw-bold mb-1">My Projects</h2>
            <p class="text-muted mb-0 small">Search, open, and manage your projects</p>
          </div>
          <button class="btn btn-success btn-sm" @click="showCreateProjectForm = true">
            Add Project
          </button>
        </div>

        <!-- Error / Success -->
        <div v-if="errorMessage" class="alert alert-danger">{{ errorMessage }}</div>
        <div v-if="successMessage" class="alert alert-success">{{ successMessage }}</div>

        <!-- Search -->
        <div class="mb-3">
          <label for="searchTerm" class="form-label fw-semibold">Search Project</label>
          <input id="searchTerm" v-model="searchTerm" type="text" class="form-control" placeholder="Search by project name" />
        </div>

        <!-- Projects List -->
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h4 class="fw-bold mb-0">Created Projects</h4>
          <span class="badge bg-primary rounded-pill">{{ filteredProjects.length }}</span>
        </div>

        <div v-if="loadingProjects" class="text-center py-4 text-muted">Loading projects...</div>
        <div v-else-if="filteredProjects.length === 0" class="text-center py-4 text-muted">No matching projects found.</div>
        <div v-else class="row g-3">
          <div v-for="project in filteredProjects" :key="project.id" class="col-12">
            <div class="project-card">
              <div class="d-flex justify-content-between align-items-start gap-2 mb-2 flex-wrap">
                <div>
                  <h5 class="fw-bold mb-1">{{ project.name }}</h5>
                  <p class="text-muted small mb-1">Visibility: <strong>{{ project.visibility || "private" }}</strong></p>
                  <p class="text-muted small mb-1">Due date: <strong>{{ project.dueDate || "No due date" }}</strong></p>
                </div>
                <div class="d-flex gap-2 flex-wrap justify-content-end align-items-center">
                  <span class="badge rounded-pill" :class="project.projectType === 'group' ? 'bg-success' : 'bg-secondary'">{{ projectTypeLabel(project) }}</span>
                  <span class="badge rounded-pill" :class="dueDateStatus(project).className">{{ dueDateStatus(project).text }}</span>
                  <button v-if="isOwner(project)" class="btn btn-outline-secondary btn-sm" @click="openProjectSettings(project)">⚙️</button>
                </div>
              </div>
              <p class="text-muted small mb-3">Members: {{ memberCount(project) }}</p>

              <div class="d-flex gap-2 flex-wrap">
                <button class="btn btn-primary btn-sm flex-fill" @click="openProject(project.id)">Open Project</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Project Modal -->
    <div v-if="showCreateProjectForm" class="modal-backdrop">
      <div class="modal-container">
        <div class="modal-header">
          <h5 class="modal-title">Create Project</h5>
          <button class="btn-close" @click="showCreateProjectForm = false"></button>
        </div>
        <div class="modal-body">
          <div v-if="createErrorMessage" class="alert alert-danger">{{ createErrorMessage }}</div>
          <div v-if="createSuccessMessage" class="alert alert-success">{{ createSuccessMessage }}</div>

          <form @submit.prevent="createProject">
            <div class="mb-3">
              <label for="projectNameModal" class="form-label">Project Name</label>
              <input id="projectNameModal" v-model="projectName" type="text" class="form-control" placeholder="Enter project name" required />
            </div>

            <div class="mb-3">
              <label for="projectModeModal" class="form-label">Project Type</label>
              <select id="projectModeModal" v-model="projectMode" class="form-select">
                <option value="solo">My Project</option>
                <option value="group">Group Project</option>
              </select>
            </div>

            <div class="mb-3">
              <label for="dueDateModal" class="form-label">Due Date</label>
              <input id="dueDateModal" v-model="dueDate" type="date" class="form-control" :min="getTodayDateString()" />
            </div>

            <div class="d-flex gap-2">
              <button type="button" class="btn btn-outline-secondary w-50" @click="showCreateProjectForm = false">Cancel</button>
              <button type="submit" class="btn btn-success w-50" :disabled="creatingProject">{{ creatingProject ? "Creating..." : "Create Project" }}</button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Project Settings Modal -->
    <div v-if="showProjectSettingsModal" class="modal-backdrop">
      <div class="modal-container">
        <div class="modal-header">
          <h5 class="modal-title">Project Settings</h5>
          <button class="btn-close" @click="showProjectSettingsModal = false"></button>
        </div>
        <div class="modal-body">
          <div v-if="errorMessage" class="alert alert-danger">{{ errorMessage }}</div>
          <div v-if="successMessage" class="alert alert-success">{{ successMessage }}</div>

          <div class="mb-3">
            <label :for="`modal-due-date-${activeProject?.id}`" class="form-label fw-semibold mb-2">Change Due Date</label>
            <input :id="`modal-due-date-${activeProject?.id}`" type="date" class="form-control"
                   v-model="dueDateInputs[activeProject?.id]"
                   :min="getTodayDateString()" />
          </div>

          <div class="d-flex gap-2 mt-3">
            <button class="btn btn-outline-secondary w-50" @click="showProjectSettingsModal = false">Cancel</button>
            <button class="btn btn-primary w-50" :disabled="savingDueDateFor === activeProject?.id" @click="saveDueDate(activeProject)">
              {{ savingDueDateFor === activeProject?.id ? "Saving..." : "Save Due Date" }}
            </button>
          </div>

          <hr class="my-3" />

          <button class="btn btn-outline-danger w-100" @click="requestRemoveProject(activeProject)">Delete Project</button>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div v-if="showDeleteConfirmModal" class="modal-backdrop">
      <div class="modal-container" style="animation: fadeIn 0.2s ease;">
        <div class="modal-header">
          <h5 class="modal-title text-danger">⚠️ Confirm Delete</h5>
          <button class="btn-close" @click="showDeleteConfirmModal = false"></button>
        </div>
        <div class="modal-body">
          <p>Are you sure you want to delete the project <strong>{{ projectToDelete?.name }}</strong>?</p>
          <div class="d-flex gap-2 mt-3">
            <button class="btn btn-outline-secondary w-50" @click="showDeleteConfirmModal = false">Cancel</button>
            <button class="btn btn-danger w-50" @click="confirmDeleteProject">Yes, Delete</button>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.project-card {
  background: #ffffff;
  border: 1px solid #e9ecef;
  border-radius: 16px;
  padding: 1rem;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.project-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.08);
}

/* Modal Styles */
.modal-backdrop {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1050;
}

.modal-container {
  background: #fff;
  padding: 2rem;
  border-radius: 12px;
  width: 100%;
  max-width: 500px;
  animation: fadeIn 0.2s ease;
}

.btn-close {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
}

/* Fade animation */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>