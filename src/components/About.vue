<template>
  <section class="taskmate-page container">
    <div class="taskmate-card-md">
      <div class="card yellow-sticker-card p-4 p-md-5 text-center">
        <div class="mb-4">
          <img
            src="/taskmate-logo.png"
            alt="TaskMate logo"
            class="about-logo img-fluid"
          />
        </div>

        <h1 class="display-6 fw-bold mb-3">About TaskMate</h1>

        <p class="lead text-dark mb-3">
          TaskMate is a task and project management web application built with Vue 3,
          Vue Router, Bootstrap, and Firebase.
        </p>

        <p class="mb-0">
          It is designed to help users organise projects, manage tasks, and track
          progress in a simple and clear way.
        </p>
      </div>
    </div>
  </section>
</template>

<style scoped>
.about-logo {
  max-width: 280px;
  width: 100%;
  height: auto;
}
</style>