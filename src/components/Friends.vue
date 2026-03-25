<script setup>
import { ref, onMounted, onUnmounted } from "vue"
import { onAuthStateChanged } from "firebase/auth"
import {
  arrayUnion,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where
} from "firebase/firestore"
import { auth, db } from "../api/firebase"

const currentUser = ref(null)
const addFriendEmail = ref("")
const friends = ref([])
const loadingFriends = ref(true)
const addingFriend = ref(false)
const errorMessage = ref("")
const successMessage = ref("")

let unsubscribeAuth = null

const clearMessages = () => {
  errorMessage.value = ""
  successMessage.value = ""
}

const loadFriends = async () => {
  clearMessages()
  loadingFriends.value = true
  friends.value = []

  if (!currentUser.value) {
    loadingFriends.value = false
    return
  }

  try {
    const currentUserRef = doc(db, "users", currentUser.value.uid)
    const currentUserSnap = await getDoc(currentUserRef)

    if (!currentUserSnap.exists()) {
      await setDoc(
        currentUserRef,
        {
          uid: currentUser.value.uid,
          email: currentUser.value.email || "",
          displayName: currentUser.value.displayName || "",
          friends: []
        },
        { merge: true }
      )

      loadingFriends.value = false
      return
    }

    const friendIds = currentUserSnap.data().friends || []

    if (!friendIds.length) {
      loadingFriends.value = false
      return
    }

    const friendDocs = await Promise.all(
      friendIds.map(async (friendId) => {
        const friendRef = doc(db, "users", friendId)
        const friendSnap = await getDoc(friendRef)

        if (!friendSnap.exists()) {
          return null
        }

        return friendSnap.data()
      })
    )

    friends.value = friendDocs.filter(Boolean)
  } catch (error) {
    console.error("Error loading friends:", error)
    errorMessage.value = "Failed to load friends."
  } finally {
    loadingFriends.value = false
  }
}

const addFriend = async () => {
  clearMessages()

  const cleanEmail = addFriendEmail.value.trim().toLowerCase()

  if (!currentUser.value) {
    errorMessage.value = "You must be logged in."
    return
  }

  if (!cleanEmail) {
    errorMessage.value = "Please enter a friend's email."
    return
  }

  if (cleanEmail === (currentUser.value.email || "").toLowerCase()) {
    errorMessage.value = "You cannot add yourself."
    return
  }

  addingFriend.value = true

  try {
    const currentUserRef = doc(db, "users", currentUser.value.uid)

    await setDoc(
      currentUserRef,
      {
        uid: currentUser.value.uid,
        email: currentUser.value.email || "",
        displayName: currentUser.value.displayName || "",
        friends: []
      },
      { merge: true }
    )

    const usersRef = collection(db, "users")
    const userQuery = query(usersRef, where("email", "==", cleanEmail))
    const userSnapshot = await getDocs(userQuery)

    if (userSnapshot.empty) {
      errorMessage.value = "No user found with that email."
      addingFriend.value = false
      return
    }

    const friendDoc = userSnapshot.docs[0]
    const friendData = friendDoc.data()
    const friendId = friendDoc.id

    if (friendId === currentUser.value.uid) {
      errorMessage.value = "You cannot add yourself."
      addingFriend.value = false
      return
    }

    const currentUserSnap = await getDoc(currentUserRef)
    const currentFriends = currentUserSnap.exists()
      ? currentUserSnap.data().friends || []
      : []

    if (currentFriends.includes(friendId)) {
      errorMessage.value = "This user is already in your friends list."
      addingFriend.value = false
      return
    }

    const friendRef = doc(db, "users", friendId)

    await setDoc(
      friendRef,
      {
        uid: friendData.uid || friendId,
        email: friendData.email || cleanEmail,
        displayName: friendData.displayName || ""
      },
      { merge: true }
    )

    await updateDoc(currentUserRef, {
      friends: arrayUnion(friendId)
    })

    await updateDoc(friendRef, {
      friends: arrayUnion(currentUser.value.uid)
    })

    successMessage.value = "Friend added successfully."
    addFriendEmail.value = ""

    await loadFriends()
  } catch (error) {
    console.error("Error adding friend:", error)
    errorMessage.value = "Failed to add friend."
  } finally {
    addingFriend.value = false
  }
}

onMounted(() => {
  unsubscribeAuth = onAuthStateChanged(auth, async (user) => {
    currentUser.value = user

    if (user) {
      await loadFriends()
    } else {
      friends.value = []
      loadingFriends.value = false
    }
  })
})

onUnmounted(() => {
  if (unsubscribeAuth) {
    unsubscribeAuth()
  }
})
</script>

<template>
  <section class="taskmate-page container">
    <div class="taskmate-card-md">
      <div class="card yellow-sticker-card p-4 p-md-5">
        <div class="mb-4">
          <h2 class="fw-bold mb-1">Friends</h2>
          <p class="text-muted mb-0 small">
            Add a friend by email and see your current friend list
          </p>
        </div>

        <div v-if="errorMessage" class="alert alert-danger">
          {{ errorMessage }}
        </div>

        <div v-if="successMessage" class="alert alert-success">
          {{ successMessage }}
        </div>

        <div class="card border-0 shadow-sm p-4 mb-4">
          <h5 class="fw-bold mb-3">Add Friend</h5>

          <div class="row g-2 align-items-end">
            <div class="col-12 col-md-8">
              <label for="friendEmail" class="form-label">Friend Email</label>
              <input
                id="friendEmail"
                v-model="addFriendEmail"
                type="email"
                class="form-control"
                placeholder="Enter friend's email"
                @keyup.enter="addFriend"
              />
            </div>

            <div class="col-12 col-md-4">
              <button
                class="btn btn-primary w-100"
                :disabled="addingFriend"
                @click="addFriend"
              >
                {{ addingFriend ? "Adding..." : "Add Friend" }}
              </button>
            </div>
          </div>
        </div>

        <div class="card border-0 shadow-sm p-4">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h5 class="fw-bold mb-0">My Friends</h5>
            <span class="badge bg-primary rounded-pill">
              {{ friends.length }}
            </span>
          </div>

          <div v-if="loadingFriends" class="text-muted text-center py-4">
            Loading friends...
          </div>

          <div v-else-if="friends.length === 0" class="text-muted text-center py-4">
            No friends yet
          </div>

          <div v-else class="row g-3">
            <div
              v-for="friend in friends"
              :key="friend.uid"
              class="col-12"
            >
              <div class="friend-card">
                <div class="friend-avatar">
                  {{ (friend.displayName || friend.email || "F").charAt(0).toUpperCase() }}
                </div>

                <div class="friend-info">
                  <div class="friend-name">
                    {{ friend.displayName || "TaskMate User" }}
                  </div>
                  <div class="friend-email">
                    {{ friend.email || "No email available" }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  </section>
</template>

<style scoped>
.friend-card {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  padding: 1rem;
  border: 1px solid #e9ecef;
  border-radius: 16px;
  background: #ffffff;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.friend-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.08);
}

.friend-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #0d6efd;
  color: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 1rem;
  flex-shrink: 0;
}

.friend-info {
  min-width: 0;
}

.friend-name {
  font-weight: 700;
  color: #212529;
}

.friend-email {
  color: #6c757d;
  font-size: 0.92rem;
  word-break: break-word;
}
</style>