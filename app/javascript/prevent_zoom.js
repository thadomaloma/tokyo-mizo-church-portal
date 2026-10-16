// Keeps the app at 100% zoom on phones and desktops.
// The viewport meta tag stops pinch zoom on Android; iOS Safari ignores it,
// so pinch gestures are cancelled here. On desktops, Ctrl/Cmd + scroll,
// trackpad pinch and Ctrl/Cmd + plus, minus or 0 are cancelled.
const ZOOM_KEYS = new Set(["+", "=", "-", "_", "0"])

document.addEventListener("gesturestart", (event) => event.preventDefault(), { passive: false })
document.addEventListener("gesturechange", (event) => event.preventDefault(), { passive: false })

document.addEventListener("touchmove", (event) => {
  if (event.touches.length > 1) event.preventDefault()
}, { passive: false })

document.addEventListener("wheel", (event) => {
  if (event.ctrlKey || event.metaKey) event.preventDefault()
}, { passive: false })

document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && ZOOM_KEYS.has(event.key)) event.preventDefault()
})
