export function initSeatingGuide(root) {
  if (!root || root.dataset.guideReady) return
  root.dataset.guideReady = "true"
  root.classList.add("guide-enhanced")
  const groups = [...root.querySelectorAll("[data-guide-group]")]
  const tables = [...root.querySelectorAll("[data-guide-table]")]
  const status = root.querySelector("#guide-selection-status")
  let selected = null

  function select(button) {
    selected = button?.dataset.guideGroup || null
    groups.forEach(group => group.setAttribute("aria-pressed", String(group === button)))
    const matched = []
    tables.forEach(table => {
      const matches = !!selected && table.dataset.groupIds.split(" ").includes(selected)
      table.classList.toggle("is-highlighted", matches)
      table.classList.toggle("is-muted", !!selected && !matches)
      if (matches) matched.push(table.dataset.guideTable)
    })
    status.textContent = button
      ? `${button.dataset.groupName} · โต๊ะ ${matched.join(", ")}`
      : "แผนผังทุกโต๊ะ · ทางเข้าด้านซ้ายและขวาล่าง"
  }

  groups.forEach(button => button.addEventListener("click", () => {
    select(selected === button.dataset.guideGroup ? null : button)
    if (selected) {
      const map = root.querySelector("#guide-map-card")
      map.focus({preventScroll: true})
      map.scrollIntoView({block: "start", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"})
    }
  }))
  root.querySelector("[data-guide-reset]").addEventListener("click", () => select(null))
}
