<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue"
import { onAuthStateChanged } from "firebase/auth"
import {
  addDoc,
  collection,
  doc,
  getDoc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc
} from "firebase/firestore"
import { auth, db } from "../api/firebase"

const currentUser = ref(null)
const friends = ref([])
const selectedFriend = ref(null)
const messages = ref([])
const newMessage = ref("")
const isOpen = ref(false)
const loadingFriends = ref(false)
const loadingMessages = ref(false)
const chatError = ref("")
const messagesContainer = ref(null)

let unsubscribeAuth = null
let unsubscribeMessages = null

const activeFriendName = computed(() => {
  if (!selectedFriend.value) {
    return "Friend Chat"
  }

  return (
    selectedFriend.value.displayName ||
    selectedFriend.value.firstName ||
    selectedFriend.value.email ||
    "Friend"
  )
})

const activeFriendInitial = computed(() => {
  const label =
    selectedFriend.value?.displayName ||
    selectedFriend.value?.email ||
    "F"

  return label.charAt(0).toUpperCase()
})

const getChatId = (uidA, uidB) => {
  return [uidA, uidB].sort().join("_")
}

const formatTime = (timestamp) => {
  if (!timestamp?.seconds) {
    return ""
  }

  const date = new Date(timestamp.seconds * 1000)

  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit"
  })
}

const scrollMessagesToBottom = async () => {
  await nextTick()

  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

const loadFriends = async (uid) => {
  loadingFriends.value = true
  chatError.value = ""

  try {
    const userSnap = await getDoc(doc(db, "users", uid))

    if (!userSnap.exists()) {
      friends.value = []
      loadingFriends.value = false
      return
    }

    const friendIds = userSnap.data().friends || []

    if (!friendIds.length) {
      friends.value = []
      loadingFriends.value = false
      return
    }

    const friendDocs = await Promise.all(
      friendIds.map(async (friendId) => {
        const snap = await getDoc(doc(db, "users", friendId))
        return snap.exists() ? snap.data() : null
      })
    )

    friends.value = friendDocs
      .filter(Boolean)
      .map((friend) => ({
        uid: friend.uid,
        email: friend.email || "",
        displayName: friend.displayName || "",
        firstName: friend.firstName || "",
        avatarUrl: friend.avatarUrl || ""
      }))
  } catch (error) {
    console.error("Error loading chat friends:", error)
    chatError.value = "Failed to load friends."
    friends.value = []
  } finally {
    loadingFriends.value = false
  }
}

const openChatWithFriend = (friend) => {
  selectedFriend.value = friend
  isOpen.value = true
}

const closeChat = () => {
  isOpen.value = false
}

const toggleChatWindow = () => {
  isOpen.value = !isOpen.value
}

const watchMessages = (friendUid) => {
  if (!currentUser.value) {
    return
  }

  if (unsubscribeMessages) {
    unsubscribeMessages()
    unsubscribeMessages = null
  }

  loadingMessages.value = true
  chatError.value = ""

  const chatId = getChatId(currentUser.value.uid, friendUid)
  const messagesRef = collection(db, "chats", chatId, "messages")
  const messagesQuery = query(messagesRef, orderBy("createdAt", "asc"))

  unsubscribeMessages = onSnapshot(
    messagesQuery,
    async (snapshot) => {
      messages.value = snapshot.docs.map((messageDoc) => ({
        id: messageDoc.id,
        ...messageDoc.data()
      }))

      loadingMessages.value = false
      await scrollMessagesToBottom()
    },
    (error) => {
      console.error("Error loading messages:", error)
      chatError.value = "Failed to load messages."
      loadingMessages.value = false
    }
  )
}

const sendMessage = async () => {
  chatError.value = ""

  if (!currentUser.value || !selectedFriend.value) {
    return
  }

  const cleanMessage = newMessage.value.trim()

  if (!cleanMessage) {
    return
  }

  try {
    const chatId = getChatId(currentUser.value.uid, selectedFriend.value.uid)

    await setDoc(
      doc(db, "chats", chatId),
      {
        participants: [currentUser.value.uid, selectedFriend.value.uid],
        updatedAt: serverTimestamp()
      },
      { merge: true }
    )

    await addDoc(collection(db, "chats", chatId, "messages"), {
      text: cleanMessage,
      senderId: currentUser.value.uid,
      senderName:
        currentUser.value.displayName ||
        currentUser.value.email ||
        "TaskMate User",
      receiverId: selectedFriend.value.uid,
      createdAt: serverTimestamp()
    })

    newMessage.value = ""
    await scrollMessagesToBottom()
  } catch (error) {
    console.error("Error sending message:", error)
    chatError.value = "Failed to send message."
  }
}

watch(selectedFriend, async (friend) => {
  messages.value = []

  if (!friend) {
    if (unsubscribeMessages) {
      unsubscribeMessages()
      unsubscribeMessages = null
    }
    return
  }

  watchMessages(friend.uid)
  await scrollMessagesToBottom()
})

onMounted(() => {
  unsubscribeAuth = onAuthStateChanged(auth, async (user) => {
    currentUser.value = user
    friends.value = []
    selectedFriend.value = null
    messages.value = []
    chatError.value = ""

    if (unsubscribeMessages) {
      unsubscribeMessages()
      unsubscribeMessages = null
    }

    if (user) {
      await loadFriends(user.uid)
    }
  })
})

onUnmounted(() => {
  if (unsubscribeAuth) {
    unsubscribeAuth()
  }

  if (unsubscribeMessages) {
    unsubscribeMessages()
  }
})
</script>

<template>
  <div class="chat-wrapper">
    <div v-if="isOpen" class="chat-window">
      <div class="chat-window-header">
        <div>
          <h6 class="chat-window-title mb-0">Friend Chat</h6>
          <small class="chat-window-subtitle">
            {{ selectedFriend ? `Talking to ${activeFriendName}` : "Choose a friend to start chatting" }}
          </small>
        </div>

        <button class="chat-close-btn" @click="closeChat">
          ×
        </button>
      </div>

      <div class="chat-window-body">
        <aside class="chat-sidebar">
          <div class="chat-sidebar-title">Friends</div>

          <div v-if="loadingFriends" class="chat-empty-state">
            Loading friends...
          </div>

          <div v-else-if="friends.length === 0" class="chat-empty-state">
            No friends yet
          </div>

          <button
            v-for="friend in friends"
            :key="friend.uid"
            class="friend-item-btn"
            :class="{ active: selectedFriend?.uid === friend.uid }"
            @click="openChatWithFriend(friend)"
          >
            <div v-if="friend.avatarUrl" class="friend-avatar-image-wrap">
              <img
                :src="friend.avatarUrl"
                alt="Friend avatar"
                class="friend-avatar-image"
              />
            </div>

            <div v-else class="friend-avatar-fallback">
              {{ (friend.displayName || friend.email || "F").charAt(0).toUpperCase() }}
            </div>

            <div class="friend-meta">
              <div class="friend-name">
                {{ friend.displayName || "TaskMate User" }}
              </div>
              <div class="friend-email">
                {{ friend.email }}
              </div>
            </div>
          </button>
        </aside>

        <section class="chat-panel">
          <div v-if="!selectedFriend" class="chat-panel-empty">
            Select a friend to start chatting
          </div>

          <template v-else>
            <div class="chat-panel-top">
              <div class="chat-panel-user">
                <div class="chat-panel-avatar">
                  {{ activeFriendInitial }}
                </div>

                <div>
                  <div class="chat-panel-name">
                    {{ activeFriendName }}
                  </div>
                  <div class="chat-panel-email">
                    {{ selectedFriend.email }}
                  </div>
                </div>
              </div>
            </div>

            <div ref="messagesContainer" class="chat-messages">
              <div v-if="loadingMessages" class="chat-empty-state">
                Loading messages...
              </div>

              <div v-else-if="messages.length === 0" class="chat-empty-state">
                No messages yet. Say hello.
              </div>

              <div
                v-for="message in messages"
                :key="message.id"
                class="message-row"
                :class="message.senderId === currentUser?.uid ? 'message-row-me' : 'message-row-them'"
              >
                <div
                  class="message-bubble"
                  :class="message.senderId === currentUser?.uid ? 'message-bubble-me' : 'message-bubble-them'"
                >
                  <div class="message-text">
                    {{ message.text }}
                  </div>
                  <div class="message-time">
                    {{ formatTime(message.createdAt) }}
                  </div>
                </div>
              </div>
            </div>

            <div class="chat-input-area">
              <input
                v-model="newMessage"
                type="text"
                class="form-control"
                placeholder="Type a message..."
                @keyup.enter="sendMessage"
              />

              <button
                class="btn btn-primary"
                @click="sendMessage"
              >
                Send
              </button>
            </div>
          </template>
        </section>
      </div>

      <div v-if="chatError" class="chat-error-bar">
        {{ chatError }}
      </div>
    </div>

    <button
      class="chat-launcher"
      @click="toggleChatWindow"
    >
      <span class="chat-launcher-icon">💬</span>
      <span class="chat-launcher-text">Friend Chat</span>
    </button>
  </div>
</template>

<style scoped>
.chat-wrapper {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 2100;
}

.chat-launcher {
  border: none;
  border-radius: 999px;
  background: #0d6efd;
  color: #ffffff;
  padding: 0.8rem 1rem;
  box-shadow: 0 14px 30px rgba(0, 0, 0, 0.18);
  display: flex;
  align-items: center;
  gap: 0.55rem;
  font-weight: 600;
}

.chat-launcher-icon {
  font-size: 1rem;
  line-height: 1;
}

.chat-window {
  width: min(860px, calc(100vw - 2rem));
  height: min(620px, calc(100vh - 7rem));
  background: #ffffff;
  border-radius: 22px;
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.2);
  overflow: hidden;
  margin-bottom: 0.8rem;
  display: flex;
  flex-direction: column;
  border: 1px solid #e9ecef;
}

.chat-window-header {
  background: #0d6efd;
  color: #ffffff;
  padding: 1rem 1.1rem;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.chat-window-title {
  font-weight: 700;
}

.chat-window-subtitle {
  opacity: 0.9;
}

.chat-close-btn {
  border: none;
  background: transparent;
  color: #ffffff;
  font-size: 1.4rem;
  line-height: 1;
  cursor: pointer;
}

.chat-window-body {
  flex: 1;
  display: grid;
  grid-template-columns: 280px 1fr;
  min-height: 0;
}

.chat-sidebar {
  border-right: 1px solid #e9ecef;
  background: #f8f9fa;
  padding: 1rem;
  overflow-y: auto;
}

.chat-sidebar-title {
  font-weight: 700;
  margin-bottom: 0.9rem;
  color: #212529;
}

.chat-empty-state {
  color: #6c757d;
  text-align: center;
  padding: 1rem 0.5rem;
}

.friend-item-btn {
  width: 100%;
  border: 1px solid #e9ecef;
  background: #ffffff;
  border-radius: 14px;
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  text-align: left;
  margin-bottom: 0.7rem;
  transition: 0.2s ease;
}

.friend-item-btn:hover {
  border-color: #b6d4fe;
  background: #f8fbff;
}

.friend-item-btn.active {
  border-color: #0d6efd;
  background: #eef5ff;
}

.friend-avatar-image-wrap {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
}

.friend-avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.friend-avatar-fallback {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  background: #0d6efd;
  color: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  flex-shrink: 0;
}

.friend-meta {
  min-width: 0;
}

.friend-name {
  font-weight: 600;
  color: #212529;
}

.friend-email {
  font-size: 0.82rem;
  color: #6c757d;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chat-panel {
  display: flex;
  flex-direction: column;
  min-width: 0;
  background: #ffffff;
}

.chat-panel-empty {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6c757d;
  text-align: center;
  padding: 1rem;
}

.chat-panel-top {
  border-bottom: 1px solid #e9ecef;
  padding: 0.9rem 1rem;
}

.chat-panel-user {
  display: flex;
  align-items: center;
  gap: 0.8rem;
}

.chat-panel-avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  background: #0d6efd;
  color: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
}

.chat-panel-name {
  font-weight: 700;
  color: #212529;
}

.chat-panel-email {
  font-size: 0.84rem;
  color: #6c757d;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  background: #f8f9fa;
  padding: 1rem;
}

.message-row {
  display: flex;
  margin-bottom: 0.75rem;
}

.message-row-me {
  justify-content: flex-end;
}

.message-row-them {
  justify-content: flex-start;
}

.message-bubble {
  max-width: min(72%, 460px);
  border-radius: 16px;
  padding: 0.7rem 0.9rem;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06);
}

.message-bubble-me {
  background: #0d6efd;
  color: #ffffff;
  border-bottom-right-radius: 6px;
}

.message-bubble-them {
  background: #ffffff;
  color: #212529;
  border: 1px solid #e9ecef;
  border-bottom-left-radius: 6px;
}

.message-text {
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.4;
}

.message-time {
  font-size: 0.74rem;
  margin-top: 0.35rem;
  opacity: 0.75;
  text-align: right;
}

.chat-input-area {
  border-top: 1px solid #e9ecef;
  padding: 0.9rem 1rem;
  display: flex;
  gap: 0.75rem;
  background: #ffffff;
}

.chat-error-bar {
  background: #dc3545;
  color: #ffffff;
  padding: 0.65rem 1rem;
  font-size: 0.9rem;
}

@media (max-width: 900px) {
  .chat-window {
    width: min(96vw, 700px);
    height: min(78vh, 620px);
  }

  .chat-window-body {
    grid-template-columns: 1fr;
  }

  .chat-sidebar {
    max-height: 180px;
    border-right: none;
    border-bottom: 1px solid #e9ecef;
  }
}

@media (max-width: 576px) {
  .chat-wrapper {
    right: 0.75rem;
    bottom: 0.75rem;
  }

  .chat-window {
    width: calc(100vw - 1rem);
    height: calc(100vh - 8rem);
  }

  .chat-launcher-text {
    display: none;
  }

  .message-bubble {
    max-width: 86%;
  }
}
</style>