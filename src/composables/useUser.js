import { ref, onMounted, onUnmounted } from "vue"
import { onAuthStateChanged } from "firebase/auth"
import { doc, onSnapshot } from "firebase/firestore"
import { auth, db } from "../api/firebase"

const currentUser = ref(null)
const displayName = ref("")
const avatarUrl = ref("")
const loading = ref(true)

let unsubscribeAuth = null
let unsubscribeUserDoc = null

export function useUser() {
  onMounted(() => {
    unsubscribeAuth = onAuthStateChanged(auth, (user) => {
      currentUser.value = user
      loading.value = false

      avatarUrl.value = ""
      displayName.value = user?.displayName || ""

      if (unsubscribeUserDoc) {
        unsubscribeUserDoc()
        unsubscribeUserDoc = null
      }

      if (user) {
        const userRef = doc(db, "users", user.uid)

        unsubscribeUserDoc = onSnapshot(userRef, (snap) => {
          if (snap.exists()) {
            const data = snap.data()
            avatarUrl.value = data.avatarUrl || ""
            displayName.value =
              data.displayName ||
              user.displayName ||
              user.email ||
              "TaskMate User"
          }
        })
      }
    })
  })

  onUnmounted(() => {
    if (unsubscribeAuth) unsubscribeAuth()
    if (unsubscribeUserDoc) unsubscribeUserDoc()
  })

  return {
    currentUser,
    displayName,
    avatarUrl,
    loading
  }
}