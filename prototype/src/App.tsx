import { useEffect, useState } from "react"
import RoleAccess, { type Role } from "./Access"
import { UIProvider, safeStorage, type Appearance, type Theme } from "./kit"
import OrganizerApp from "./Organizer"
import OwnerApp from "./Owner"
import { RoleExperience } from "./Roles"
import DjApp from "./Dj"
import { StoreProvider } from "./store"
import { ServerProvider } from "./Server"
import { GuestProvider } from "./Guests"
import { VenueProvider } from "./VenueEdit"
import { DjProvider } from "./DjStudio"
import { InboxProvider } from "./Inbox"
import { VenueOpsProvider } from "./VenueOps"
import { ErrorBoundary } from "./kit"
import { DeviceFrame } from "./device"
import { LaunchScreen } from "./Launch"

export default function App() {
  const [role, setRole] = useState<Role | null>(null)
  const [launching, setLaunching] = useState(true)
  useEffect(() => {
    const t = window.setTimeout(() => setLaunching(false), 2100)
    return () => window.clearTimeout(t)
  }, [])
  const [appearance, setAppearance] = useState<Appearance>(() => {
    const saved = safeStorage.get("bottlesup-appearance")
    return saved === "light" || saved === "system" || saved === "dark" ? saved : "dark"
  })
  const [systemDark, setSystemDark] = useState(() => window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? true)
  useEffect(() => {
    const media = window.matchMedia?.("(prefers-color-scheme: dark)")
    if (!media) return
    const update = (e: MediaQueryListEvent) => setSystemDark(e.matches)
    media.addEventListener("change", update)
    return () => media.removeEventListener("change", update)
  }, [])
  const choose = (next: Appearance) => {
    safeStorage.set("bottlesup-appearance", next)
    setAppearance(next)
  }
  const theme: Theme = appearance === "system" ? (systemDark ? "dark" : "light") : appearance
  // The header button flips between light and dark directly.
  const toggle = () => choose(theme === "dark" ? "light" : "dark")
  const leave = () => {
    setRole(null)
    window.scrollTo({ top: 0 })
  }
  // Escape works like the top-left Back/Close button of the front-most full-screen panel.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || document.querySelector(".sheet-wrap")) return
      const panels = document.querySelectorAll(".gc")
      const top = panels[panels.length - 1]
      if (!top) return
      const btn = top.querySelector<HTMLButtonElement>('.gc-top .icon-button, .chat-head .icon-button, .ds-public-bar button, .srv-back')
      if (btn) {
        e.preventDefault()
        btn.click()
      }
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [])
  const shared = { theme, onTheme: toggle, appearance, onAppearance: choose, onSwitch: leave }
  return (
    <StoreProvider>
      <ServerProvider>
      <GuestProvider>
      <VenueProvider>
      <DjProvider>
      <InboxProvider>
      <VenueOpsProvider>
      <DeviceFrame dark={theme === "dark"} surface={launching ? (theme === "dark" ? "#0b0b0b" : "#f9fafb") : undefined}>
      <div className={`theme-root theme-${theme}`}>
        <UIProvider>
          <ErrorBoundary resetKey={role ?? "access"}>
          {launching ? (
            <LaunchScreen dark={theme === "dark"} />
          ) : !role ? (
            <div className={`app-shell theme-${theme}`}>
              <RoleAccess
                onAuthenticated={(r) => {
                  setRole(r)
                  window.scrollTo({ top: 0 })
                }}
                appearance={appearance}
                onAppearance={choose}
              />
            </div>
          ) : role === "venue-owner" ? (
            <OwnerApp {...shared} />
          ) : role === "dj" ? (
            <DjApp {...shared} />
          ) : role === "event-organizer" ? (
            <OrganizerApp {...shared} />
          ) : (
            <RoleExperience role={role} {...shared} />
          )}
          </ErrorBoundary>
        </UIProvider>
      </div>
      </DeviceFrame>
      </VenueOpsProvider>
      </InboxProvider>
      </DjProvider>
      </VenueProvider>
      </GuestProvider>
      </ServerProvider>
    </StoreProvider>
  )
}
