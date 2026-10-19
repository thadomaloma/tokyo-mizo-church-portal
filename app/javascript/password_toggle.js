// Show/hide buttons on password fields ([data-password-toggle] inside a
// [data-password-wrapper]). One listener on the document covers every page,
// including pages Turbo swaps in later.
function setHidden(element, hidden) {
  if (element) element.classList.toggle("hidden", hidden)
}

function togglePasswordVisibility(button) {
  const wrapper = button.closest("[data-password-wrapper]")
  const input = wrapper?.querySelector("[data-password-input]")
  if (!input) return

  const isVisible = input.getAttribute("type") === "text"
  input.setAttribute("type", isVisible ? "password" : "text")

  const label = isVisible ? "Show password" : "Hide password"
  button.setAttribute("aria-label", label)
  button.setAttribute("title", label)

  setHidden(wrapper.querySelector("[data-password-show-icon]"), !isVisible)
  setHidden(wrapper.querySelector("[data-password-hide-icon]"), isVisible)
}

document.addEventListener("click", (event) => {
  const button = event.target.closest?.("[data-password-toggle]")
  if (!button || event.defaultPrevented) return

  event.preventDefault()
  togglePasswordVisibility(button)
})
