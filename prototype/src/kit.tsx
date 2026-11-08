import {Component, createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode} from "react"

export type IconName =
  | "lock"
  | "camera"
  | "map"
  | "pencil"
  | "paperclip"
  | "tag"
  | "refresh"
  | "handover"
  | "bell"
  | "arrow"
  | "back"
  | "calendar"
  | "card"
  | "chart"
  | "chat"
  | "check"
  | "chevron"
  | "clock"
  | "close"
  | "copy"
  | "door"
  | "earnings"
  | "event"
  | "events"
  | "eye"
  | "eyeOff"
  | "guests"
  | "home"
  | "inventory"
  | "lead"
  | "moon"
  | "more"
  | "orders"
  | "overview"
  | "payments"
  | "person"
  | "plus"
  | "reports"
  | "scan"
  | "search"
  | "send"
  | "server"
  | "settings"
  | "share"
  | "sparkle"
  | "star"
  | "sun"
  | "team"
  | "ticket"
  | "tonight"
  | "trash"
  | "venue"
  | "venues"
  | "vip"
  | "warning"
  | "wifi"

const paths: Record<IconName, ReactNode> = {
  arrow: <path d="M5 12h14m-5-5 5 5-5 5" />,
  back: <path d="m15 18-6-6 6-6" />,
  calendar: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="3" />
      <path d="M7 3v4m10-4v4M3 10h18" />
    </>
  ),
  card: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="3" />
      <path d="M3 10h18M7 15h3" />
    </>
  ),
  chart: (
    <>
      <path d="M4 20V10m6 10V4m6 16v-7m4 7H2" />
    </>
  ),
  chat: <path d="M4 5h16v11H9l-5 4z" />,
  check: <path d="m5 12 4 4L19 6" />,
  chevron: <path d="m9 18 6-6-6-6" />,
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </>
  ),
  close: <path d="m6 6 12 12M18 6 6 18" />,
  copy: (
    <>
      <rect x="8" y="8" width="12" height="12" rx="2" />
      <path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3" />
    </>
  ),
  door: (
    <>
      <path d="M5 21V4l12-2v19M5 21h14" />
      <circle cx="13.5" cy="12" r=".5" />
    </>
  ),
  earnings: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M15 8.5c-.7-.5-1.6-.8-2.6-.8-1.5 0-2.7.7-2.7 1.8 0 2.8 5.6 1.2 5.6 4.3 0 1.2-1.2 2-2.9 2-1.1 0-2.2-.3-3-.9M12 5.5v13" />
    </>
  ),
  event: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="3" />
      <path d="M7 3v4m10-4v4M3 10h18" />
    </>
  ),
  events: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="3" />
      <path d="M7 3v4m10-4v4M3 10h18" />
    </>
  ),
  eye: (
    <>
      <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z" />
      <circle cx="12" cy="12" r="2.5" />
    </>
  ),
  eyeOff: (
    <>
      <path d="m3 3 18 18M10.7 6.1A10.7 10.7 0 0 1 12 6c6.5 0 10 6 10 6a16 16 0 0 1-2.1 2.8M6.5 6.5C3.6 8.3 2 12 2 12s3.5 6 10 6a10 10 0 0 0 3.5-.6" />
    </>
  ),
  guests: (
    <>
      <circle cx="9" cy="8" r="3" />
      <circle cx="17" cy="9" r="2.5" />
      <path d="M3 20a6 6 0 0 1 12 0M14 15a5 5 0 0 1 7 4.5" />
    </>
  ),
  home: (
    <>
      <path d="m3 11 9-7 9 7" />
      <path d="M5 10v10h14V10M9 20v-6h6v6" />
    </>
  ),
  inventory: (
    <>
      <path d="m4 7 8-4 8 4-8 4zM4 7v10l8 4 8-4V7M12 11v10" />
    </>
  ),
  lead: (
    <>
      <circle cx="9" cy="8" r="3" />
      <circle cx="17" cy="9" r="2.5" />
      <path d="M3 20a6 6 0 0 1 12 0M14 15a5 5 0 0 1 7 4.5" />
    </>
  ),
  map: <path d="M12 21s-6-5.2-6-10a6 6 0 0 1 12 0c0 4.8-6 10-6 10ZM12 13a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />,
  camera: <path d="M4 8h3l2-3h6l2 3h3v11H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z" />,
  pencil: <path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4ZM13.5 6.5l4 4" />,
  paperclip: <path d="m20 11-8.5 8.5a5 5 0 0 1-7-7L13 4a3.3 3.3 0 0 1 4.7 4.7L9.4 17a1.7 1.7 0 0 1-2.4-2.4L14.5 7" />,
  tag: <path d="M3 12V4h8l10 10-8 8L3 12ZM7.5 8.5h.01" />,
  lock: (
    <>
      <rect x="5" y="11" width="14" height="10" rx="2.5" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </>
  ),
  refresh: <path d="M20 11a8 8 0 0 0-14.6-4.5M4 4v4h4M4 13a8 8 0 0 0 14.6 4.5M20 20v-4h-4" />,
  handover: <path d="M4 8h13l-3-3M20 16H7l3 3" />,
  bell: <path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15L6 16ZM10 20.5a2.2 2.2 0 0 0 4 0" />,
  moon: <path d="M20.5 15.2A8.5 8.5 0 0 1 8.8 3.5 8.5 8.5 0 1 0 20.5 15.2Z" />,
  more: <path d="M5 7h14M5 12h14M5 17h14" />,
  orders: (
    <>
      <path d="M6 3h12l2 5-2 13H6L4 8z" />
      <path d="M4 8h16M9 12h6" />
    </>
  ),
  overview: (
    <>
      <path d="M3 11.5 12 4l9 7.5" />
      <path d="M5.5 10v10h13V10M9.5 20v-6h5v6" />
    </>
  ),
  payments: (
    <>
      <rect x="3" y="6" width="18" height="13" rx="3" />
      <path d="M7 15h4m6-5h.01" />
    </>
  ),
  person: (
    <>
      <circle cx="12" cy="8" r="4" />
      <path d="M4.5 21a7.5 7.5 0 0 1 15 0" />
    </>
  ),
  plus: <path d="M12 5v14M5 12h14" />,
  reports: (
    <>
      <path d="M5 3h10l4 4v14H5z" />
      <path d="M14 3v5h5M8 16l2-3 2 2 3-4M8 18h8" />
    </>
  ),
  scan: (
    <>
      <path d="M4 8V4h4m8 0h4v4m0 8v4h-4M8 20H4v-4" />
      <path d="M7 12h10" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-4-4" />
    </>
  ),
  send: <path d="m4 12 16-8-6 16-2-6z" />,
  server: (
    <>
      <path d="M4 12h16M7 12a5 5 0 0 1 10 0M12 7V4M3 20h18" />
    </>
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M19 5l-2 2M7 17l-2 2" />
    </>
  ),
  share: (
    <>
      <circle cx="18" cy="5" r="3" />
      <circle cx="6" cy="12" r="3" />
      <circle cx="18" cy="19" r="3" />
      <path d="m8.7 10.7 6.6-4.4m-6.6 7 6.6 4.4" />
    </>
  ),
  sparkle: (
    <>
      <path d="m12 3 1.2 3.8L17 8l-3.8 1.2L12 13l-1.2-3.8L7 8l3.8-1.2zM5 15l.7 2.3L8 18l-2.3.7L5 21l-.7-2.3L2 18l2.3-.7zM19 14l.7 2.3 2.3.7-2.3.7L19 20l-.7-2.3L16 17l2.3-.7z" />
    </>
  ),
  star: <path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" />,
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </>
  ),
  team: (
    <>
      <circle cx="8" cy="8" r="3" />
      <circle cx="16" cy="8" r="3" />
      <path d="M2 20a6 6 0 0 1 12 0m-3.5-5a6 6 0 0 1 11.5 2.5" />
    </>
  ),
  ticket: (
    <>
      <path d="M4 6h16v4a2 2 0 0 0 0 4v4H4v-4a2 2 0 0 0 0-4z" />
      <path d="M12 7v2m0 3v2m0 3v1" />
    </>
  ),
  tonight: (
    <path d="M20.5 15.2A8.5 8.5 0 0 1 8.8 3.5 8.5 8.5 0 1 0 20.5 15.2Z" />
  ),
  trash: <path d="M4 7h16M9 7V4h6v3m-8 0 1 13h8l1-13" />,
  venue: (
    <>
      <path d="M4 21V7h7v14M11 21V3h9v18M2 21h20" />
      <path d="M7 10h1m6-3h2m-2 4h2" />
    </>
  ),
  venues: (
    <>
      <path d="M4 21V7h7v14M11 21V3h9v18M2 21h20" />
      <path d="M7 10h1m-1 4h1m6-7h2m-2 4h2m-2 4h2" />
    </>
  ),
  vip: (
    <path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" />
  ),
  warning: (
    <>
      <path d="M12 3 2.5 20h19z" />
      <path d="M12 9v4m0 3h.01" />
    </>
  ),
  wifi: (
    <>
      <path d="M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0" />
      <path d="M12 19h.01" />
    </>
  ),
}

export function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  return (
    <svg className="icon" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {paths[name]}
    </svg>
  )
}

export type Theme = "dark" | "light"
export type Appearance = "dark" | "light" | "system"

export const safeStorage = {
  get(key: string) {
    try {
      return window.localStorage.getItem(key)
    } catch {
      return null
    }
  },
  set(key: string, value: string) {
    try {
      window.localStorage.setItem(key, value)
    } catch {
      /* storage unavailable */
    }
  },
}

type SheetSpec = { eyebrow?: string; title: string; body: (close: () => void) => ReactNode }

type UI = {
  toast: (message: string, undo?: () => void) => void
  sheet: (spec: SheetSpec) => void
  close: () => void
  copy: (text: string, label?: string) => void
}

const UIContext = createContext<UI | null>(null)

export function useUI() {
  const ui = useContext(UIContext)
  if (!ui) throw new Error("useUI outside UIProvider")
  return ui
}

export function UIProvider({ children }: { children: ReactNode }) {
  const [message, setMessage] = useState<string | null>(null)
  const [undoFn, setUndoFn] = useState<(() => void) | null>(null)
  const [spec, setSpec] = useState<SheetSpec | null>(null)
  const [online, setOnline] = useState(() => (typeof navigator === "undefined" ? true : navigator.onLine !== false))
  const [backOnline, setBackOnline] = useState(false)
  const timer = useRef<number | null>(null)
  const toast = useCallback((m: string, undo?: () => void) => {
    setMessage(m)
    setUndoFn(() => undo ?? null)
    if (timer.current) window.clearTimeout(timer.current)
    // Undo toasts stay longer so there's time to reach the button.
    timer.current = window.setTimeout(() => (setMessage(null), setUndoFn(null)), undo ? 6000 : 2600)
  }, [])
  useEffect(() => {
    let t: number | undefined
    const off = () => (setOnline(false), setBackOnline(false))
    const on = () => {
      setOnline(true)
      setBackOnline(true)
      t = window.setTimeout(() => setBackOnline(false), 2500)
    }
    window.addEventListener("offline", off)
    window.addEventListener("online", on)
    return () => (window.removeEventListener("offline", off), window.removeEventListener("online", on), window.clearTimeout(t))
  }, [])
  const copy = useCallback(
    (text: string, label = "Copied") => {
      const fail = () => toast("Copying isn't available here. Select the text instead.")
      try {
        if (navigator.clipboard) navigator.clipboard.writeText(text).then(() => toast(label), fail)
        else fail()
      } catch {
        fail()
      }
    },
    [toast],
  )
  useEffect(() => {
    if (!spec) return
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setSpec(null)
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [spec])
  const close = () => setSpec(null)
  return (
    <UIContext.Provider value={{ toast, sheet: setSpec, close, copy }}>
      {children}
      {spec && (
        <div className="sheet-wrap" onClick={close}>
          <div className="sheet card" role="dialog" aria-modal="true" aria-label={spec.title} onClick={(e) => e.stopPropagation()}>
            <div className="sheet-handle" />
            <div className="sheet-head">
              <div>
                {spec.eyebrow && <span>{spec.eyebrow}</span>}
                <h2>{spec.title}</h2>
              </div>
              <button className="icon-button" aria-label="Close" onClick={close}>
                <Icon name="close" size={18} />
              </button>
            </div>
            <div className="sheet-body">
              <ErrorBoundary resetKey={spec.title}>{spec.body(close)}</ErrorBoundary>
            </div>
          </div>
        </div>
      )}
      {(!online || backOnline) && (
        <div className={`net-banner ${online ? "ok" : ""}`} role="status" aria-live="polite">
          <Icon name={online ? "check" : "warning"} size={15} />
          {online ? "Back online. All changes synced." : "You're offline. Changes will sync when you're back."}
        </div>
      )}
      {message && (
        <div className={`toast ${undoFn ? "has-undo" : ""}`} role="status" aria-live="polite">
          <span>{message}</span>
          {undoFn && (
            <button
              type="button"
              onClick={() => {
                undoFn()
                setUndoFn(null)
                setMessage("Undone")
                if (timer.current) window.clearTimeout(timer.current)
                timer.current = window.setTimeout(() => setMessage(null), 1600)
              }}
            >
              Undo
            </button>
          )}
        </div>
      )}
    </UIContext.Provider>
  )
}

export function ThemeToggle({ theme, onToggle }: { theme: Theme; onToggle: () => void }) {
  return (
    <button type="button" className="theme-icon" onClick={onToggle} aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"} title={theme === "dark" ? "Light mode" : "Dark mode"}>
      <Icon name={theme === "dark" ? "sun" : "moon"} size={22} />
    </button>
  )
}

export type Msg = { mine: boolean; text: string; time: string; who?: string }

// The demo night is frozen at 9:42 PM; new activity counts forward from there.
const DEMO_START = Date.now()
export const clock = () => {
  const mins = 21 * 60 + 42 + Math.floor((Date.now() - DEMO_START) / 60000)
  const h = Math.floor(mins / 60) % 24
  const m = String(mins % 60).padStart(2, "0")
  return `${h % 12 || 12}:${m} ${h >= 12 ? "PM" : "AM"}`
}

/** A working chat thread: type, press Enter or Send, and get a short demo reply. */
export function Thread({ initial, placeholder, reply, replyFrom }: { initial: Msg[]; placeholder: string; reply?: string; replyFrom?: string }) {
  const [messages, setMessages] = useState<Msg[]>(initial)
  const [text, setText] = useState("")
  const end = useRef<HTMLDivElement>(null)
  const timer = useRef<number | null>(null)
  useEffect(() => {
    end.current?.scrollIntoView({ block: "nearest" })
  }, [messages.length])
  useEffect(() => () => {
    if (timer.current) window.clearTimeout(timer.current)
  }, [])
  const send = () => {
    const t = text.trim()
    if (!t) return
    setMessages((m) => [...m, { mine: true, text: t, time: clock() }])
    setText("")
    if (reply) {
      if (timer.current) window.clearTimeout(timer.current)
      timer.current = window.setTimeout(() => setMessages((m) => [...m, { mine: false, text: reply, time: clock(), who: replyFrom }]), 1300)
    }
  }
  return (
    <div className="thread">
      <div className="conversation">
        {messages.map((m, i) => (
          <div className={`bubble ${m.mine ? "mine" : "theirs"}`} key={i}>
            {m.who && !m.mine && <b className="bubble-who">{m.who}</b>}
            {m.text}
            <small>{m.time}</small>
          </div>
        ))}
        <div ref={end} />
      </div>
      <form noValidate
        className="composer"
        onSubmit={(e) => {
          e.preventDefault()
          send()
        }}
      >
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder={placeholder} aria-label={placeholder} />
        <button type="submit" aria-label="Send" disabled={!text.trim()}>
          <Icon name="send" />
        </button>
      </form>
    </div>
  )
}

/** Simple list of options inside a sheet. */
export function Options({ items, close }: { items: { label: string; detail?: string; icon?: IconName; danger?: boolean; onSelect: () => void }[]; close: () => void }) {
  return (
    <div className="sheet-options">
      {items.map((o) => (
        <button
          key={o.label}
          className={o.danger ? "danger" : ""}
          onClick={() => {
            close()
            o.onSelect()
          }}
        >
          {o.icon && (
            <span className="row-icon">
              <Icon name={o.icon} size={18} />
            </span>
          )}
          <span>
            <strong>{o.label}</strong>
            {o.detail && <small>{o.detail}</small>}
          </span>
          <Icon name="chevron" size={16} />
        </button>
      ))}
    </div>
  )
}

/** Key/value lines (uses the existing report-lines style). */
export function Lines({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <div className="report-lines card">
      {rows.map(([k, v]) => (
        <div key={k}>
          <span>{k}</span>
          <strong>{v}</strong>
        </div>
      ))}
    </div>
  )
}

/** A small form inside a sheet: fields + submit, with required-field checking. */
export function QuickForm({
  fields,
  submit,
  onSubmit,
}: {
  fields: { id: string; label: string; value?: string; placeholder?: string; type?: string; options?: string[]; required?: boolean }[]
  submit: string
  onSubmit: (values: Record<string, string>) => void
}) {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(fields.map((f) => [f.id, f.value ?? (f.options ? f.options[0] : "")])))
  const [tried, setTried] = useState(false)
  const missing = fields.filter((f) => f.required && !values[f.id]?.trim())
  return (
    <form noValidate
      className="form-stack sheet-form"
      onSubmit={(e) => {
        e.preventDefault()
        setTried(true)
        if (missing.length === 0) onSubmit(values)
      }}
    >
      {fields.map((f) => (
        <label className="field" key={f.id}>
          <span>{f.label}</span>
          {f.options ? (
            <select value={values[f.id]} onChange={(e) => setValues({ ...values, [f.id]: e.target.value })}>
              {f.options.map((o) => (
                <option key={o}>{o}</option>
              ))}
            </select>
          ) : (
            <input type={f.type ?? "text"} value={values[f.id]} placeholder={f.placeholder} onChange={(e) => setValues({ ...values, [f.id]: e.target.value })} />
          )}
          {tried && f.required && !values[f.id]?.trim() && <em className="field-error">{f.label} is required.</em>}
        </label>
      ))}
      <button className="primary-action full-action" type="submit">
        {submit}
      </button>
    </form>
  )
}

/** Animated sun/moon switch between light and dark. */
export function ThemeSwitch({ dark, onChange, size = "md" }: { dark: boolean; onChange: (dark: boolean) => void; size?: "sm" | "md" }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={dark}
      aria-label={dark ? "Dark mode on. Switch to light mode" : "Light mode on. Switch to dark mode"}
      className={`theme-switch ${size} ${dark ? "is-dark" : "is-light"}`}
      onClick={() => onChange(!dark)}
    >
      <span className="ts-night" aria-hidden="true">
        <i className="ts-star s1" />
        <i className="ts-star s2" />
        <i className="ts-star s3" />
        <i className="ts-star s4" />
        <i className="ts-star s5" />
      </span>
      <span className="ts-clouds" aria-hidden="true">
        <i />
        <i />
        <i />
      </span>
      <span className="ts-knob" aria-hidden="true">
        <i className="ts-crater c1" />
        <i className="ts-crater c2" />
        <i className="ts-crater c3" />
      </span>
    </button>
  )
}

/** Catches render errors so a screen never goes blank. */
export class ErrorBoundary extends Component<{ children: ReactNode; resetKey?: string }, { error: Error | null; key?: string }> {
  state: { error: Error | null; key?: string } = { error: null, key: this.props.resetKey }
  static getDerivedStateFromError(error: Error) {
    return { error }
  }
  static getDerivedStateFromProps(props: { resetKey?: string }, state: { error: Error | null; key?: string }) {
    return props.resetKey !== state.key ? { error: null, key: props.resetKey } : null
  }
  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="state-block" role="alert">
        <Icon name="warning" size={26} />
        <h2>This screen didn't load</h2>
        <p>Your work is saved. Try again, or go back.</p>
        <button className="primary-action" onClick={() => this.setState({ error: null })}>
          Retry
        </button>
      </div>
    )
  }
}

/** State saved in this browser, so edits survive closing and reopening the app.
    Falls back to memory only when storage is blocked or full. */
export function usePersisted<T>(key: string, initial: T): [T, (v: T | ((p: T) => T)) => void, boolean] {
  const [value, setValue] = useState<T>(() => {
    const raw = safeStorage.get(key)
    if (!raw) return initial
    try {
      const parsed = JSON.parse(raw)
      return (Array.isArray(initial) || typeof initial !== "object" ? parsed : { ...initial, ...parsed }) as T
    } catch {
      return initial
    }
  })
  const [saved, setSaved] = useState(true)
  const set = (v: T | ((p: T) => T)) =>
    setValue((prev) => {
      const next = typeof v === "function" ? (v as (p: T) => T)(prev) : v
      try {
        window.localStorage.setItem(key, JSON.stringify(next))
        setSaved(true)
      } catch {
        setSaved(false)
      }
      return next
    })
  return [value, set, saved]
}

/** Shrink an uploaded image so it can be stored and shown quickly. */
export function compressImage(file: File, max = 900, quality = 0.8): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader()
    r.onerror = () => reject(new Error("read"))
    r.onload = () => {
      const img = new Image()
      img.onerror = () => reject(new Error("decode"))
      img.onload = () => {
        const s = Math.min(1, max / Math.max(img.width, img.height))
        const c = document.createElement("canvas")
        c.width = Math.round(img.width * s)
        c.height = Math.round(img.height * s)
        c.getContext("2d")!.drawImage(img, 0, 0, c.width, c.height)
        resolve(c.toDataURL("image/jpeg", quality))
      }
      img.src = String(r.result)
    }
    r.readAsDataURL(file)
  })
}
