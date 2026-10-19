// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "Chart.bundle"
import "@hotwired/turbo-rails"
import "controllers"
import "prevent_zoom"
import "password_toggle"

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch(() => {})
  })
}
