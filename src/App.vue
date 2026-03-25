<script setup>
import { useUser } from "./composables/useUser"
import Nav from "./components/Nav.vue"
import NotificationCenter from "./components/NotificationCenter.vue"
import GlobalChat from "./components/GlobalChat.vue"

const { currentUser } = useUser()
</script>

<template>
  <Nav />
  <router-view />
  <NotificationCenter v-if="currentUser" />
  <GlobalChat v-if="currentUser" />
</template>