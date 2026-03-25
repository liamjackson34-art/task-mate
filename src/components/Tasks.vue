<script setup>
import { ref, onMounted, onUnmounted, computed } from "vue"
import { useRoute } from "vue-router"
import {
  addDoc,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where
} from "firebase/firestore"
import { db } from "../api/firebase"
import { useUser } from "../composables/useUser"

const route = useRoute()
const projectId = route.params.id

const { currentUser } = useUser()

// Reactive state
const project = ref(null)
const tasks = ref([])
const steps = ref([])
const memberDetails = ref([])

const loadingProject = ref(true)
const loadingTasks = ref(false)
const loadingSteps = ref(false)
const loadingAction = ref(false)

const taskTitle = ref("")
const taskDescription = ref("")
const selectedTask = ref(null)
const stepTitle = ref("")
const stepDescription = ref("")
const stepError = ref("")

const memberEmail = ref("")

// Modal state
const showAddTaskModal = ref(false)
const showAddStepModal = ref(false)
const showAddMemberModal = ref(false)

// Messages
const projectError = ref("")
const taskError = ref("")
const successMessage = ref("")
const memberError = ref("")
const memberSuccess = ref("")

let unsubscribeTasks = null
let unsubscribeSteps = null

// --------------------
// ✅ COMPUTED (FIXED)
// --------------------
const memberCount = computed(() =>
  Array.isArray(project.value?.members) ? project.value.members.length : 0
)

const isGroupProject = computed(() => project.value?.projectType === "group")

const isOwner = computed(() =>
  currentUser.value &&
  project.value &&
  currentUser.value.uid === project.value.ownerId
)

// 🔥 FIX: only count valid steps linked to tasks
const validSteps = computed(() =>
  steps.value.filter(step =>
    tasks.value.some(task => task.id === step.taskId)
  )
)

const completedSteps = computed(() =>
  validSteps.value.filter(step => step.completed === true).length
)

const totalSteps = computed(() =>
  validSteps.value.length
)

const progressPercent = computed(() =>
  totalSteps.value === 0
    ? 0
    : Math.round((completedSteps.value / totalSteps.value) * 100)
)

// --------------------
// Modal helpers
// --------------------
const getModalZIndex = (modal) => {
  const order = ["showAddMemberModal", "selectedTask", "showAddStepModal", "showAddTaskModal"]
  return 1050 + order.indexOf(modal) * 10
}

const openModal = (modal, payload = null) => {
  switch (modal) {
    case "showAddTaskModal":
      resetTaskForm()
      showAddTaskModal.value = true
      break
    case "selectedTask":
      selectedTask.value = payload
      resetStepForm()
      break
    case "showAddStepModal":
      resetStepForm()
      showAddStepModal.value = true
      break
    case "showAddMemberModal":
      resetMemberForm()
      showAddMemberModal.value = true
      break
  }
}

const closeModal = (modal) => {
  switch (modal) {
    case "showAddTaskModal":
      showAddTaskModal.value = false
      resetTaskForm()
      break
    case "selectedTask":
      selectedTask.value = null
      resetStepForm()
      break
    case "showAddStepModal":
      showAddStepModal.value = false
      resetStepForm()
      break
    case "showAddMemberModal":
      showAddMemberModal.value = false
      resetMemberForm()
      break
  }
}

// --------------------
// Forms
// --------------------
const resetStepForm = () => {
  stepTitle.value = ""
  stepDescription.value = ""
  stepError.value = ""
}
const resetTaskForm = () => {
  taskTitle.value = ""
  taskDescription.value = ""
  taskError.value = ""
}
const resetMemberForm = () => {
  memberEmail.value = ""
  memberError.value = ""
  memberSuccess.value = ""
}

// --------------------
// Load project
// --------------------
const loadMemberDetails = async (memberIds = []) => {
  memberDetails.value = []
  if (!memberIds.length) return
  try {
    const loadedMembers = await Promise.all(
      memberIds.map(async (uid) => {
        const userSnap = await getDoc(doc(db, "users", uid))
        if (userSnap.exists()) {
          const data = userSnap.data()
          return { uid, email: data.email || uid, displayName: data.displayName || "" }
        }
        return { uid, email: uid, displayName: "" }
      })
    )
    memberDetails.value = loadedMembers
  } catch (error) {
    console.error(error)
  }
}

const loadProject = async () => {
  loadingProject.value = true
  try {
    const projectSnap = await getDoc(doc(db, "projects", projectId))
    if (!projectSnap.exists()) {
      projectError.value = "Project not found."
      return
    }
    project.value = { id: projectSnap.id, ...projectSnap.data() }
    await loadMemberDetails(project.value.members || [])
  } catch (error) {
    projectError.value = "Failed to load project."
  } finally {
    loadingProject.value = false
  }
}

// --------------------
// 🔥 STEP TOGGLE (FIXED)
// --------------------
const toggleStepComplete = async (step) => {
  try {
    const newStatus = !step.completed

    await updateDoc(doc(db, "steps", step.id), {
      completed: newStatus
    })

    const taskSteps = steps.value
      .filter(s => s.taskId === step.taskId)
      .map(s => s.id === step.id ? { ...s, completed: newStatus } : s)

    const allCompleted =
      taskSteps.length > 0 &&
      taskSteps.every(s => s.completed === true)

    await updateDoc(doc(db, "tasks", step.taskId), {
      completed: allCompleted
    })

  } catch (error) {
    console.error(error)
  }
}

// --------------------
// Load data
// --------------------
const loadTasks = () => {
  const q = query(collection(db, "tasks"), where("projectId", "==", projectId))
  unsubscribeTasks = onSnapshot(q, (snapshot) => {
    tasks.value = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
  })
}

const loadSteps = () => {
  const q = query(collection(db, "steps"), where("projectId", "==", projectId))
  unsubscribeSteps = onSnapshot(q, (snapshot) => {
    steps.value = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
  })
}

const getStepsForTask = (taskId) =>
  steps.value.filter(step => step.taskId === taskId)

// --------------------
// CRUD
// --------------------
const addTask = async () => {
  if (!taskTitle.value.trim()) return

  await addDoc(collection(db, "tasks"), {
    projectId,
    title: taskTitle.value.trim(),
    description: taskDescription.value.trim(),
    completed: false,
    ownerId: currentUser.value.uid,
    createdAt: serverTimestamp()
  })

  closeModal("showAddTaskModal")
}

const addStep = async () => {
  if (!stepTitle.value.trim() || !selectedTask.value) return

  await addDoc(collection(db, "steps"), {
    projectId,
    taskId: selectedTask.value.id,
    title: stepTitle.value.trim(),
    description: stepDescription.value.trim(),
    completed: false,
    ownerId: currentUser.value.uid,
    createdAt: serverTimestamp()
  })

  closeModal("showAddStepModal")
}

// --------------------
// 🔥 TASK TOGGLE (FIXED)
// --------------------
const toggleTaskCompletion = async (task) => {
  try {
    const newStatus = !task.completed

    await updateDoc(doc(db, "tasks", task.id), {
      completed: newStatus
    })

    const relatedSteps = steps.value.filter(s => s.taskId === task.id)

    await Promise.all(
      relatedSteps.map(step =>
        updateDoc(doc(db, "steps", step.id), {
          completed: newStatus
        })
      )
    )

  } catch (error) {
    console.error(error)
  }
}

const deleteTask = async (taskId) => {
  await deleteDoc(doc(db, "tasks", taskId))
}

// --------------------
// Lifecycle
// --------------------
onMounted(async () => {
  await loadProject()
  loadTasks()
  loadSteps()
})

onUnmounted(() => {
  if (unsubscribeTasks) unsubscribeTasks()
  if (unsubscribeSteps) unsubscribeSteps()
})
</script>

<template>
  <section class="container-fluid py-4">
    <div class="taskmate-card-lg mx-auto w-100">
      <div class="card yellow-sticker-card p-4 p-md-5">

        <!-- Loading / Error -->
        <div v-if="loadingProject" class="text-center py-5 text-muted">Loading project...</div>
        <div v-else-if="projectError" class="alert alert-danger">{{ projectError }}</div>

        <div v-else-if="project">

          <!-- Header -->
          <div class="mb-4">
            <h2 class="fw-bold mb-1">{{ project.name }}</h2>
            <p class="text-muted mb-1">Members: {{ memberCount }}</p>
            <p class="text-muted small mb-1">{{ isGroupProject ? "Group Project" : "My Project" }}</p>
          </div>

          <!-- Success Message -->
          <div v-if="successMessage" class="alert alert-success">{{ successMessage }}</div>

          <!-- Progress -->
          <div class="card p-4 border-0 shadow-sm mb-4">
            <div class="d-flex justify-content-between mb-3">
              <h4 class="fw-bold mb-0">Project Progress</h4>
              <span class="badge bg-primary rounded-pill">{{ completedSteps }}/{{ totalSteps }}</span>
            </div>
            <div class="progress">
              <div class="progress-bar bg-success" :style="{ width: progressPercent + '%' }">{{ progressPercent }}%</div>
            </div>
          </div>

          <!-- Add Task Button -->
          <div class="d-grid mb-4">
            <button class="btn btn-success" @click="openModal('showAddTaskModal')">Add Task</button>
          </div>

          <!-- Task Grid -->
          <div class="card p-4 border-0 shadow-sm mb-4">
            <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
              <div v-for="task in tasks" :key="task.id" class="col">
                <div class="task-card p-3 shadow-sm h-100 d-flex flex-column w-100" :class="{ completed: task.completed }">
                  <div class="flex-grow-1" @click="openModal('selectedTask', task)">
                    <h5 class="fw-bold mb-1">{{ task.title }}</h5>
                    <p class="text-muted small mb-1">{{ task.description || "No description" }}</p>
                    <p class="text-muted small mb-3">Steps: {{ getStepsForTask(task.id).length }}</p>
                  </div>

                  <div class="task-footer mt-auto">
                    <span class="badge rounded-pill" :class="task.completed ? 'bg-success' : 'bg-warning text-dark'">
                      {{ task.completed ? "Completed" : "Pending" }}
                    </span>

                    <div class="task-actions">
                      <input type="checkbox" :checked="task.completed" @click.stop="toggleTaskCompletion(task)" class="custom-checkbox" />
                      <button class="btn btn-sm btn-outline-danger" @click.stop="deleteTask(task.id)">🗑</button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </div>

    <!-- ADD TASK MODAL -->
    <div v-if="showAddTaskModal" class="task-modal-backdrop" 
         :style="{ zIndex: getModalZIndex('showAddTaskModal') }" 
         @click.self="closeModal('showAddTaskModal')">
      <div class="task-modal-card">
        <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
          <h4 class="fw-bold mb-1">Add Task</h4>
          <button class="btn-close" @click="closeModal('showAddTaskModal')"></button>
        </div>
        <div v-if="taskError" class="alert alert-danger">{{ taskError }}</div>
        <div class="mb-3">
          <label class="form-label">Task Title</label>
          <input v-model="taskTitle" type="text" class="form-control" placeholder="Enter task title" />
        </div>
        <div class="mb-3">
          <label class="form-label">Task Description</label>
          <textarea v-model="taskDescription" class="form-control" rows="3" placeholder="Enter task description"></textarea>
        </div>
        <button class="btn btn-success w-100" @click="addTask">Add Task</button>
      </div>
    </div>

    <!-- TASK DETAILS MODAL -->
    <div v-if="selectedTask" class="task-modal-backdrop" 
         :style="{ zIndex: getModalZIndex('selectedTask') }" 
         @click.self="closeModal('selectedTask')">
      <div class="task-modal-card">
        <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
          <div>
            <h4 class="fw-bold mb-1">{{ selectedTask.title }}</h4>
            <p class="text-muted small mb-0">{{ selectedTask.description || "No description provided." }}</p>
          </div>
          <button class="btn-close" @click="closeModal('selectedTask')"></button>
        </div>

        <!-- Add Step Button -->
        <div class="mb-3">
          <button class="btn btn-success w-100" @click="openModal('showAddStepModal')">Add Step</button>
        </div>

        <!-- Steps List -->
        <div class="card p-3 border-0 shadow-sm">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h5 class="fw-bold mb-0">Task Steps</h5>
            <span class="badge bg-secondary rounded-pill">{{ getStepsForTask(selectedTask.id).length }}</span>
          </div>

          <div v-if="loadingSteps" class="text-center py-3 text-muted">Loading steps...</div>
          <div v-else-if="getStepsForTask(selectedTask.id).length === 0" class="text-center py-3 text-muted">No steps yet for this task.</div>

          <div v-else class="d-grid gap-2">
            <div v-for="step in getStepsForTask(selectedTask.id)" :key="step.id" class="step-card">
              <div class="d-flex justify-content-between align-items-start gap-3 flex-wrap">
                <div>
                  <h6 class="fw-bold mb-1">{{ step.title }}</h6>
                  <p class="text-muted small mb-0">{{ step.description || "No description provided." }}</p>
                </div>
                <span class="badge rounded-pill" :class="step.completed ? 'bg-success' : 'bg-warning text-dark'">
                  {{ step.completed ? "Completed" : "Pending" }}
                </span>
              </div>
              <div class="d-flex gap-2 mt-3 flex-wrap">
                <button class="btn btn-outline-primary btn-sm flex-fill" @click="toggleStepComplete(step)">
                  {{ step.completed ? "Mark as Pending" : "Mark as Completed" }}
                </button>
                <button class="btn btn-outline-danger btn-sm flex-fill" @click="removeStep(step)">Remove Step</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ADD STEP MODAL -->
    <div v-if="showAddStepModal" class="task-modal-backdrop" 
         :style="{ zIndex: getModalZIndex('showAddStepModal') }" 
         @click.self="closeModal('showAddStepModal')">
      <div class="task-modal-card">
        <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
          <h4 class="fw-bold mb-1">Add Step</h4>
          <button class="btn-close" @click="closeModal('showAddStepModal')"></button>
        </div>
        <div class="mb-3">
          <label class="form-label">Step Title</label>
          <input v-model="stepTitle" type="text" class="form-control" placeholder="Enter step title" />
        </div>
        <div class="mb-3">
          <label class="form-label">Step Description</label>
          <textarea v-model="stepDescription" class="form-control" rows="2" placeholder="Enter step description"></textarea>
        </div>
        <button class="btn btn-success w-100" @click="addStep">Add Step</button>
      </div>
    </div>

    <!-- ADD MEMBER MODAL (example with stackable modal) -->
    <div v-if="showAddMemberModal" class="task-modal-backdrop" 
         :style="{ zIndex: getModalZIndex('showAddMemberModal') }" 
         @click.self="closeModal('showAddMemberModal')">
      <div class="task-modal-card">
        <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
          <div>
            <h4 class="fw-bold mb-1">Add Member</h4>
            <p class="text-muted small mb-0">Add any registered TaskMate user by email.</p>
          </div>
          <button class="btn-close" @click="closeModal('showAddMemberModal')"></button>
        </div>
        <div v-if="memberError" class="alert alert-danger">{{ memberError }}</div>
        <div v-if="memberSuccess" class="alert alert-success">{{ memberSuccess }}</div>
        <div class="mb-3">
          <label class="form-label">TaskMate Account Email</label>
          <input v-model="memberEmail" type="email" class="form-control" placeholder="Enter member email" />
        </div>
        <div class="d-flex gap-2">
          <button class="btn btn-outline-secondary w-50" @click="closeModal('showAddMemberModal')">Cancel</button>
          <button class="btn btn-success w-50" @click="addMemberByAccount">Add Member</button>
        </div>
      </div>
    </div>

  </section>
</template>

<style scoped>
/* Task Card */
.task-card {
  background: #fff;
  border: 1px solid #e9ecef;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.25s ease;
  width: 100%;
  box-sizing: border-box;
  z-index: 1;
}
.task-card:hover {
  transform: scale(1.03);
  box-shadow: 0 12px 28px rgba(0,0,0,0.15);
  z-index: 10;
}
.task-card.completed {
  background: #f8f9fa;
  opacity: 0.75;
}
.task-card.completed h5 {
  text-decoration: line-through;
  color: #6c757d;
}

/* Footer layout */
.task-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: auto;
  gap: 8px;
}
.task-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0;
  transform: translateX(8px);
  transition: all 0.25s ease;
}
.task-card:hover .task-actions {
  opacity: 1;
  transform: translateX(0);
}
.custom-checkbox {
  width: 1.4rem;
  height: 1.4rem;
  border-radius: 6px;
  border: 2px solid #ced4da;
  cursor: pointer;
  transition: all 0.2s ease;
}
.custom-checkbox:hover {
  border-color: #198754;
  box-shadow: 0 0 0 3px rgba(25,135,84,0.2);
}
.custom-checkbox:checked {
  background-color: #198754;
  border-color: #198754;
  transform: scale(1.05);
}
.task-actions .btn {
  padding: 2px 6px;
  font-size: 0.8rem;
}

/* Grid fixes */
.row-cols-1.row-cols-md-2.row-cols-lg-3 > .col {
  display: flex;
}
.row-cols-1.row-cols-md-2.row-cols-lg-3 > .col > .task-card {
  flex: 1;
  transition: all 0.25s ease;
}

/* Modal backdrop & card */
.task-modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0,0,0,0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 9999;
  overflow-y: auto;
  padding: 1rem;
}
.task-modal-card {
  background: #fff;
  border-radius: 12px;
  max-width: 600px;
  width: 100%;
  box-shadow: 0 12px 24px rgba(0,0,0,0.2);
  padding: 1.5rem;
  position: relative;
}
.task-modal-card .btn-close {
  position: absolute;
  top: 1rem;
  right: 1rem;
  border: none;
  background: transparent;
  font-size: 1.2rem;
  cursor: pointer;
}

/* Add Step Modal: higher z-index for stacking */
.add-step-modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0,0,0,0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 10001; /* higher than task modal */
  overflow-y: auto;
  padding: 1rem;
}
.add-step-modal-backdrop .task-modal-card {
  box-shadow: 0 16px 32px rgba(0,0,0,0.25);
}
</style>