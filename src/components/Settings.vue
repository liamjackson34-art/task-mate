<script setup>
import { ref, watch } from "vue"
import { useRouter } from "vue-router"
import {
  updateProfile,
  updateEmail,
  updatePassword,
  deleteUser,
  EmailAuthProvider,
  reauthenticateWithCredential,
  signOut
} from "firebase/auth"
import { doc, updateDoc, deleteDoc } from "firebase/firestore"
import { ref as storageRef, uploadBytes, getDownloadURL } from "firebase/storage"
import { auth, db, storage } from "../api/firebase"
import { useUser } from "../composables/useUser"

// --- Router ---
const router = useRouter()

// --- User State ---
const { currentUser, displayName, avatarUrl, loading } = useUser()

// --- Editable Fields ---
const newDisplayName = ref("")
const avatarFile = ref(null)
const newEmail = ref("")
const newPassword = ref("")
const modalCurrentPassword = ref("")

// --- Modal State ---
const showEmailModal = ref(false)
const showPasswordModal = ref(false)
const showDeleteConfirm = ref(false)

// --- Loading & Messages ---
const saving = ref(false)
const errorMessage = ref("")
const successMessage = ref("")

const clearMessages = () => {
  errorMessage.value = ""
  successMessage.value = ""
}

// --- Sync initial values ---
watch(displayName, val => newDisplayName.value = val, { immediate: true })
watch(currentUser, user => newEmail.value = user?.email || "", { immediate: true })

// --- Body scroll lock when modal open ---
watch([showEmailModal, showPasswordModal, showDeleteConfirm], ([e, p, d]) => {
  if (e || p || d) document.body.style.overflow = "hidden"
  else document.body.style.overflow = "auto"
})

// --- File change ---
const onFileChange = (e) => {
  avatarFile.value = e.target.files[0]
}

// --- Save display name & avatar ---
const saveProfile = async () => {
  clearMessages()
  if (!currentUser.value) return

  saving.value = true
  try {
    const user = currentUser.value

    if (newDisplayName.value && newDisplayName.value !== displayName.value) {
      await updateProfile(user, { displayName: newDisplayName.value })
      await updateDoc(doc(db, "users", user.uid), { displayName: newDisplayName.value })
    }

    if (avatarFile.value) {
      const fileRef = storageRef(storage, `avatars/${user.uid}`)
      await uploadBytes(fileRef, avatarFile.value)
      const url = await getDownloadURL(fileRef)
      await updateProfile(user, { photoURL: url })
      await updateDoc(doc(db, "users", user.uid), { avatarUrl: url })
    }

    successMessage.value = "Profile updated successfully."
  } catch (err) {
    console.error(err)
    errorMessage.value = err.message || "Failed to update profile."
  } finally {
    saving.value = false
  }
}

// --- Change Email ---
const changeEmail = async () => {
  clearMessages()
  saving.value = true
  try {
    const user = currentUser.value
    if (!modalCurrentPassword.value) throw new Error("Enter current password for verification")
    const credential = EmailAuthProvider.credential(user.email, modalCurrentPassword.value)
    await reauthenticateWithCredential(user, credential)
    await updateEmail(user, newEmail.value)
    successMessage.value = "Email updated successfully."
    showEmailModal.value = false
    modalCurrentPassword.value = ""
  } catch (err) {
    console.error(err)
    errorMessage.value = err.message || "Failed to update email."
  } finally {
    saving.value = false
  }
}

// --- Change Password ---
const changePassword = async () => {
  clearMessages()
  saving.value = true
  try {
    const user = currentUser.value
    if (!modalCurrentPassword.value) throw new Error("Enter current password for verification")
    const credential = EmailAuthProvider.credential(user.email, modalCurrentPassword.value)
    await reauthenticateWithCredential(user, credential)
    await updatePassword(user, newPassword.value)
    successMessage.value = "Password updated successfully."
    showPasswordModal.value = false
    modalCurrentPassword.value = ""
    newPassword.value = ""
  } catch (err) {
    console.error(err)
    errorMessage.value = err.message || "Failed to update password."
  } finally {
    saving.value = false
  }
}

// --- Delete Account ---
const deleteAccount = async () => {
  clearMessages()
  saving.value = true
  try {
    const user = currentUser.value
    await deleteDoc(doc(db, "users", user.uid))
    await deleteUser(user)
    await signOut(auth)
    router.push("/register")
  } catch (err) {
    console.error(err)
    errorMessage.value = err.message || "Failed to delete account."
  } finally {
    saving.value = false
    showDeleteConfirm.value = false
  }
}
</script>

<template>
  <section class="container-fluid py-4">
    <div class="taskmate-card-lg mx-auto w-100">
      <div class="card yellow-sticker-card p-4 p-md-5">

        <h2 class="fw-bold mb-4">Settings</h2>

        <!-- Messages -->
        <div v-if="errorMessage" class="alert alert-danger">{{ errorMessage }}</div>
        <div v-if="successMessage" class="alert alert-success">{{ successMessage }}</div>

        <!-- Avatar -->
        <div class="mb-4 text-center">
          <img v-if="avatarUrl" :src="avatarUrl" class="avatar" />
          <div v-else class="avatar placeholder">?</div>
          <input type="file" @change="onFileChange" class="mt-2" />
        </div>

        <!-- Display Name -->
        <div class="mb-3">
          <label class="form-label">Display Name</label>
          <input v-model="newDisplayName" class="form-control" />
        </div>

        <!-- Action Buttons -->
        <div class="d-flex justify-content-between gap-2 mt-4 flex-wrap-nowrap">
          <button class="btn btn-primary" :disabled="saving" @click="saveProfile">
            {{ saving ? "Saving..." : "Save Profile" }}
          </button>

          <button class="btn btn-secondary" @click="showEmailModal = true">Change Email</button>
          <button class="btn btn-secondary" @click="showPasswordModal = true">Change Password</button>
          <button class="btn btn-danger" @click="showDeleteConfirm = true">Delete Account</button>
        </div>

      </div>
    </div>

    <!-- Email Modal -->
    <div v-if="showEmailModal" class="task-modal-backdrop">
      <div class="task-modal-card">
        <h4 class="fw-bold mb-3">Change Email</h4>
        <input v-model="newEmail" type="email" class="form-control mb-2" placeholder="New Email" />
        <input v-model="modalCurrentPassword" type="password" class="form-control mb-2" placeholder="Current Password" />
        <div class="d-flex justify-content-end gap-2 mt-3">
          <button class="btn btn-secondary" @click="showEmailModal = false">Cancel</button>
          <button class="btn btn-primary" :disabled="saving" @click="changeEmail">Save</button>
        </div>
      </div>
    </div>

    <!-- Password Modal -->
    <div v-if="showPasswordModal" class="task-modal-backdrop">
      <div class="task-modal-card">
        <h4 class="fw-bold mb-3">Change Password</h4>
        <input v-model="newPassword" type="password" class="form-control mb-2" placeholder="New Password" />
        <input v-model="modalCurrentPassword" type="password" class="form-control mb-2" placeholder="Current Password" />
        <div class="d-flex justify-content-end gap-2 mt-3">
          <button class="btn btn-secondary" @click="showPasswordModal = false">Cancel</button>
          <button class="btn btn-primary" :disabled="saving" @click="changePassword">Save</button>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div v-if="showDeleteConfirm" class="task-modal-backdrop">
      <div class="task-modal-card">
        <h4 class="fw-bold mb-3">Confirm Delete</h4>
        <p>Are you sure you want to delete your account? This action cannot be undone.</p>
        <div class="d-flex justify-content-end gap-2 mt-3">
          <button class="btn btn-secondary" @click="showDeleteConfirm = false">Cancel</button>
          <button class="btn btn-danger" :disabled="saving" @click="deleteAccount">Delete</button>
        </div>
      </div>
    </div>

  </section>
</template>

<style scoped>
/* Avatar */
.avatar {
  width: 90px;
  height: 90px;
  border-radius: 50%;
  object-fit: cover;
}

.placeholder {
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: #ddd;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: bold;
}

/* Modal Backdrop */
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
  padding: 1rem;
  overflow-y: auto;
}

/* Modal Card */
.task-modal-card {
  background: #fff;
  border-radius: 12px;
  max-width: 500px;
  width: 100%;
  padding: 1.5rem;
  box-shadow: 0 12px 24px rgba(0,0,0,0.2);
  position: relative;
}

.flex-wrap-nowrap {
  flex-wrap: nowrap !important;
}
</style>