import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "member",
    "presentInput",
    "absentInput",
    "presentPreview",
    "absentPreview",
    "presentCount",
    "absentCount"
  ]

  connect() {
    this.sync()
  }

  sync() {
    const members = this.memberTargets.map((input) => ({
      checked: input.checked,
      name: input.dataset.name,
      role: input.dataset.role
    }))

    const present = members.filter((member) => member.checked)
    const absent = members.filter((member) => !member.checked)

    this.presentInputTarget.value = this.memberList(present)
    this.absentInputTarget.value = this.memberList(absent)

    if (this.hasPresentPreviewTarget) {
      this.presentPreviewTarget.textContent = this.previewText(present)
    }

    if (this.hasAbsentPreviewTarget) {
      this.absentPreviewTarget.textContent = this.previewText(absent)
    }

    if (this.hasPresentCountTarget) {
      this.presentCountTarget.textContent = present.length
    }

    if (this.hasAbsentCountTarget) {
      this.absentCountTarget.textContent = absent.length
    }
  }

  memberList(members) {
    return members
      .map((member, index) => `${index + 1}. ${member.name} - ${member.role}`)
      .join("\n")
  }

  previewText(members) {
    if (members.length === 0) {
      return "No members selected."
    }

    return members.map((member) => member.name).join(", ")
  }
}
