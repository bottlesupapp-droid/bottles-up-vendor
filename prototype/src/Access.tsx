import { useState } from "react"
import { Icon, ThemeToggle, type Appearance, type IconName } from "./kit"

export type Role = "venue-owner" | "venue-manager" | "event-organizer" | "dj" | "door-staff" | "server" | "ambassador" | "event-lead"

export const roles: { id: Role; label: string; description: string; icon: IconName }[] = [
  { id: "venue-owner", label: "Venue Owner", description: "Business performance, venues, and payments", icon: "venue" },
  { id: "venue-manager", label: "Venue Manager", description: "Run an assigned venue and shift", icon: "home" },
  { id: "event-organizer", label: "Event Organizer", description: "Events, tickets, guests, and agreements", icon: "event" },
  { id: "dj", label: "DJ / Artist", description: "Booking requests, gigs, and prices", icon: "sparkle" },
  { id: "door-staff", label: "Door Staff", description: "Scan tickets and manage arrivals", icon: "door" },
  { id: "server", label: "Server", description: "Tables, orders, and guest service", icon: "server" },
  { id: "ambassador", label: "Ambassador", description: "Share events and track commission", icon: "share" },
  { id: "event-lead", label: "Event Lead", description: "Lead events, teams, and performance", icon: "lead" },
]

const roleCopy: Record<Role, { heading: string; text: string; assignment: string; option: string }> = {
  "venue-owner": { heading: "Owner sign in", text: "Manage your business, venues, and financial performance.", assignment: "Choose a business", option: "Northstar Hospitality · 2 venues" },
  "venue-manager": { heading: "Manager sign in", text: "Run tonight’s service at your assigned venue.", assignment: "Choose an assignment", option: "Nova Room · Manager" },
  "event-organizer": { heading: "Organizer sign in", text: "Create events and work with venues and your team.", assignment: "Choose an organization", option: "Midnight Social · 4 events" },
  dj: { heading: "Artist sign in", text: "Respond to booking requests and manage your gigs.", assignment: "Choose a profile", option: "Amara Vale · DJ" },
  "door-staff": { heading: "Door staff sign in", text: "Check in guests at your assigned entrance.", assignment: "Choose a shift", option: "Nova Room · Main entrance" },
  server: { heading: "Server sign in", text: "Manage your tables, orders, and service requests.", assignment: "Choose a shift", option: "Nova Room · Main floor" },
  ambassador: { heading: "Ambassador sign in", text: "Share assigned events and track your referrals.", assignment: "Choose a profile", option: "Alex Morgan · Midnight Social" },
  "event-lead": { heading: "Event Lead sign in", text: "Coordinate events, ambassadors, and results.", assignment: "Choose a team", option: "Neon Garden · Event team" },
}

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className={`access-logo ${compact ? "compact" : ""}`}>
      <img src="/bottlesup-logo.png" alt="BottlesUp" />
      <span>
        <strong>BottlesUp</strong>
        <small>Business</small>
      </span>
    </div>
  )
}

function AppearanceControl({ value, onChange }: { value: Appearance; onChange: (value: Appearance) => void }) {
  const systemDark = window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? true
  const dark = value === "dark" || (value === "system" && systemDark)
  return <ThemeToggle theme={dark ? "dark" : "light"} onToggle={() => onChange(dark ? "light" : "dark")} />
}

type AccessKind = "invitation" | "expired" | "pending"

function AccessState({ type, role, onBack, onEnter }: { type: AccessKind; role: Role; onBack: () => void; onEnter: () => void }) {
  const [phase, setPhase] = useState<"start" | "working" | "done">("start")
  const label = roles.find((r) => r.id === role)?.label
  const data = {
    invitation: ["You’re invited", `Join Nova Room as ${label}. Accepting signs you in with this invitation.`, "Accept invitation"],
    expired: ["Invitation expired", "Ask an owner or organizer to send a new invitation.", "Request a new invite"],
    pending: ["Access pending", "Your request is waiting for an administrator to approve it.", "Check again"],
  }[type]
  const result = {
    invitation: ["Invitation accepted", "Welcome to the team.", "Continue"],
    expired: ["Request sent", "We’ve asked the team owner to send you a new invitation. You’ll get an email.", "Back to sign in"],
    pending: ["Access approved", "An administrator approved your request just now.", "Continue"],
  }[type]
  const act = () => {
    if (phase === "done") return type === "expired" ? onBack() : onEnter()
    setPhase("working")
    window.setTimeout(() => setPhase("done"), 600)
  }
  const [title, text, button] = phase === "done" ? result : data
  return (
    <main className="auth-page">
      <button className="auth-back" onClick={onBack}>
        <Icon name="back" /> Back
      </button>
      <Logo />
      <div className="access-state">
        <span className={phase === "done" ? "invitation" : type}>
          <Icon name={phase === "done" ? "check" : type === "invitation" ? "ticket" : type === "expired" ? "warning" : "clock"} size={30} />
        </span>
        <h1>{title}</h1>
        <p>{text}</p>
        <button className="primary-action full-action" onClick={act} disabled={phase === "working"}>
          {phase === "working" ? <span className="spinner" /> : button}
        </button>
      </div>
    </main>
  )
}

export default function RoleAccess({ onAuthenticated, appearance, onAppearance }: { onAuthenticated: (role: Role) => void; appearance: Appearance; onAppearance: (value: Appearance) => void }) {
  const [selected, setSelected] = useState<Role | null>(null)
  const [step, setStep] = useState<"roles" | "signin" | "assignment" | "forgot">("roles")
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [show, setShow] = useState(false)
  const [errors, setErrors] = useState<{ email?: string; password?: string; form?: string }>({})
  const [loading, setLoading] = useState(false)
  const [resetSent, setResetSent] = useState(false)
  const [accessState, setAccessState] = useState<AccessKind | null>(null)
  const [armReset, setArmReset] = useState(false)

  if (selected && accessState) return <AccessState type={accessState} role={selected} onBack={() => setAccessState(null)} onEnter={() => onAuthenticated(selected)} />

  if (step === "roles")
    return (
      <main className="role-welcome">
        <div className="welcome-top">
          <Logo />
          <span className="welcome-tools">
            <span className="demo-label">DEMO MODE</span>
            <AppearanceControl value={appearance} onChange={onAppearance} />
          </span>
        </div>
        <div className="welcome-copy">
          <span>WELCOME</span>
          <h1>How are you working tonight?</h1>
          <p>Choose a role to explore its tools and demo account.</p>
        </div>
        <div className="role-grid">
          {roles.map((role) => (
            <button
              className="role-choice card"
              key={role.id}
              onClick={() => {
                setSelected(role.id)
                setErrors({})
                setStep("signin")
              }}
            >
              <span>
                <Icon name={role.icon} />
              </span>
              <span>
                <strong>{role.label}</strong>
                <small>{role.description}</small>
              </span>
              <Icon name="arrow" size={18} />
            </button>
          ))}
        </div>
      </main>
    )

  const copy = roleCopy[selected ?? "venue-owner"]
  const roleLabel = roles.find((r) => r.id === selected)?.label ?? ""

  if (step === "assignment" && selected)
    return (
      <main className="auth-page">
        <button className="auth-back" onClick={() => setStep("signin")}>
          <Icon name="back" /> Back
        </button>
        <div className="auth-top">
          <Logo compact />
          <span className="demo-label">DEMO MODE</span>
        </div>
        <div className="auth-heading">
          <span>ASSIGNED ACCESS</span>
          <h1>{copy.assignment}</h1>
          <p>Only businesses, events, and roles assigned to your account appear here.</p>
        </div>
        <button className="assignment-card card" onClick={() => onAuthenticated(selected)}>
          <span className="assignment-mark">{copy.option.split(" ")[0].slice(0, 2).toUpperCase()}</span>
          <span>
            <strong>{copy.option}</strong>
            <small>Demo assignment · Ready</small>
          </span>
          <Icon name="arrow" />
        </button>
      </main>
    )

  if (step === "forgot")
    return (
      <main className="auth-page">
        <button
          className="auth-back"
          onClick={() => {
            setStep("signin")
            setResetSent(false)
          }}
        >
          <Icon name="back" /> Sign in
        </button>
        <div className="auth-heading">
          <span>{roleLabel.toUpperCase()}</span>
          <h1>Reset your password</h1>
          <p>{resetSent ? `If ${email} has an account, a reset link is on its way. It expires in 30 minutes.` : "Enter the email you sign in with and we’ll send a reset link."}</p>
        </div>
        {!resetSent && (
          <form noValidate
            className="auth-form"
            onSubmit={(e) => {
              e.preventDefault()
              if (!/^\S+@\S+\.\S+$/.test(email)) return setErrors({ email: "Enter a valid email address." })
              setErrors({})
              setResetSent(true)
            }}
          >
            <label className="field">
              <span>Email</span>
              <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" placeholder="name@example.com" autoComplete="email" />
              {errors.email && <em className="field-error">{errors.email}</em>}
            </label>
            <button className="primary-action full-action auth-submit" type="submit">
              Send reset link
            </button>
          </form>
        )}
      </main>
    )

  const submit = (demo = false) => {
    const next: { email?: string; password?: string; form?: string } = {}
    if (!demo) {
      if (!email) next.email = "Enter your email address."
      else if (!/^\S+@\S+\.\S+$/.test(email)) next.email = "Enter a valid email address."
      if (!password) next.password = "Enter your password."
      if (email.includes("error")) next.form = "We couldn’t sign you in. Check your details and try again."
    }
    setErrors(next)
    if (Object.keys(next).length) return
    setLoading(true)
    window.setTimeout(() => {
      setLoading(false)
      setStep("assignment")
    }, 450)
  }
  return (
    <main className="auth-page">
      <button
        className="auth-back"
        onClick={() => {
          setStep("roles")
          setSelected(null)
          setErrors({})
        }}
      >
        <Icon name="back" /> Roles
      </button>
      <div className="auth-top">
        <Logo compact />
        <span className="demo-label">DEMO MODE</span>
      </div>
      <div className="auth-heading">
        <span>{roleLabel.toUpperCase()}</span>
        <h1>{copy.heading}</h1>
        <p>{copy.text}</p>
      </div>
      {errors.form && (
        <div className="auth-error" role="alert">
          <Icon name="warning" />
          {errors.form}
        </div>
      )}
      <form noValidate
        className="auth-form"
        onSubmit={(e) => {
          e.preventDefault()
          submit(false)
        }}
      >
        <label className="field">
          <span>Email</span>
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" placeholder="name@example.com" autoComplete="email" />
          {errors.email && <em className="field-error">{errors.email}</em>}
        </label>
        <label className="field">
          <span>Password</span>
          <div className="password-field">
            <input value={password} onChange={(e) => setPassword(e.target.value)} type={show ? "text" : "password"} placeholder="Enter password" autoComplete="current-password" />
            <button type="button" onClick={() => setShow(!show)} aria-label={show ? "Hide password" : "Show password"}>
              <Icon name={show ? "eyeOff" : "eye"} />
            </button>
          </div>
          {errors.password && <em className="field-error">{errors.password}</em>}
        </label>
        <button
          type="button"
          className="forgot-button"
          onClick={() => {
            setErrors({})
            setStep("forgot")
          }}
        >
          Forgot password?
        </button>
        <button className="primary-action full-action auth-submit" type="submit" disabled={loading}>
          {loading ? <span className="spinner" /> : "Sign in"}
        </button>
        <div className="auth-divider">
          <span>or</span>
        </div>
        <button type="button" className="demo-button" onClick={() => submit(true)} disabled={loading}>
          Use demo account
        </button>
      </form>
      <div className="access-links">
        <button onClick={() => setAccessState("invitation")}>Accept invitation</button>
        <button onClick={() => setAccessState("expired")}>Expired invite</button>
        <button onClick={() => setAccessState("pending")}>Access pending</button>
        <button
          className={armReset ? "reset-armed" : ""}
          onClick={() => {
            // Two taps: the first explains, the second resets. (Pop-up confirms are blocked in some viewers.)
            if (!armReset) return setArmReset(true)
            try {
              Object.keys(window.localStorage)
                .filter((k) => k.startsWith("bu-"))
                .forEach((k) => window.localStorage.removeItem(k))
            } catch {
              /* storage blocked */
            }
            window.location.reload()
          }}
        >
          {armReset ? "Tap again to erase saved demo data" : "Reset demo data"}
        </button>
      </div>
    </main>
  )
}
