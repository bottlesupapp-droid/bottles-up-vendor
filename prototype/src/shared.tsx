import { useState } from "react"
import { NIGHT, SERVERS, bookingGuests, usd, type Booking } from "./data"
import { Icon, Lines, Options, QuickForm, Thread, useUI, type Appearance, type IconName } from "./kit"
import { useStore } from "./store"
import { BookingExtras } from "./Guests"

export function Segmented({ items, active, onChange }: { items: string[]; active: string; onChange: (item: string) => void }) {
  return (
    <div className="segmented">
      {items.map((item) => (
        <button key={item} className={active === item ? "active" : ""} aria-pressed={active === item} onClick={() => onChange(item)}>
          {item}
        </button>
      ))}
    </div>
  )
}

export function SearchBox({ value, onChange, placeholder = "Search by name or code" }: { value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <label className="search-field">
      <Icon name="search" size={17} />
      <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} aria-label={placeholder} />
      {value && (
        <button type="button" className="clear-search" aria-label="Clear search" onClick={() => onChange("")}>
          <Icon name="close" size={15} />
        </button>
      )}
    </label>
  )
}

export function Empty({ icon, title, text }: { icon: IconName; title: string; text: string }) {
  return (
    <div className="empty-state">
      <Icon name={icon} size={30} />
      <h2>{title}</h2>
      <p>{text}</p>
    </div>
  )
}

export type Row = { icon: IconName; title: string; desc: string; badge?: string; onOpen?: () => void; tone?: "warning" }

export function RowList({ rows }: { rows: Row[] }) {
  return (
    <div className="role-list card">
      {rows.map((r) => (
        <button className="list-row" key={r.title} onClick={r.onOpen} disabled={!r.onOpen}>
          <span className={`row-icon ${r.tone ?? ""}`}>
            <Icon name={r.icon} />
          </span>
          <span>
            <strong>{r.title}</strong>
            <small>{r.desc}</small>
          </span>
          {r.badge && <b>{r.badge}</b>}
          {r.onOpen && <Icon name="arrow" size={16} />}
        </button>
      ))}
    </div>
  )
}

/** Booking detail: mark arrived, assign a server. Works for owner and manager. */
function BookingSheetBody({ id, close }: { id: string; close: () => void }) {
  const { bookings, setBookings, setArrived } = useStore()
  const ui = useUI()
  const b = bookings.find((x) => x.id === id)!
  const [server, setServer] = useState(b.server ?? SERVERS[0])
  return (
    <>
      <Lines
        rows={[
          ["Time", b.time],
          ["Table", b.table],
          ["Guests", String(b.guests)],
          ["Payment", b.payment],
          ["Status", b.status],
          ["Server", b.server ?? "Not assigned"],
        ]}
      />
      <label className="field">
        <span>Assign server</span>
        <select value={server} onChange={(e) => setServer(e.target.value)}>
          {SERVERS.map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
      </label>
      <div className="dual-actions">
        <button
          className="secondary-action"
          onClick={() => {
            setBookings((list) => list.map((x) => (x.id === id ? { ...x, server } : x)))
            ui.toast(`${server} is serving ${b.table}`)
            close()
          }}
        >
          Save server
        </button>
        <button
          className="primary-action"
          disabled={b.status === "Arrived"}
          onClick={() => {
            setBookings((list) => list.map((x) => (x.id === id ? { ...x, status: "Arrived", server } : x)))
            setArrived((n) => n + b.guests)
            ui.toast(`${b.name}'s party checked in`)
            close()
          }}
        >
          {b.status === "Arrived" ? "Already arrived" : "Mark arrived"}
        </button>
      </div>
      <BookingExtras id={id} close={close} />
    </>
  )
}

export function useBookingSheet() {
  const ui = useUI()
  const { bookings } = useStore()
  return (id: string) => {
    const b = bookings.find((x) => x.id === id)!
    ui.sheet({ eyebrow: "BOOKING", title: `${b.name} · ${b.time}`, body: (close) => <BookingSheetBody id={id} close={close} /> })
  }
}

export function BookingList({ initialFilter = "All", limit }: { initialFilter?: string; limit?: number }) {
  const { bookings } = useStore()
  const open = useBookingSheet()
  const [filter, setFilter] = useState(initialFilter)
  const [q, setQ] = useState("")
  const shown = bookings
    .filter((b) => filter === "All" || (filter === "Arrived" ? b.status === "Arrived" : b.status === "Confirmed"))
    .filter((b) => !q.trim() || `${b.name} ${b.table}`.toLowerCase().includes(q.trim().toLowerCase()))
    .sort((a, b) => (a.status === b.status ? 0 : a.status === "Confirmed" ? -1 : 1))
  const list = limit ? shown.slice(0, limit) : shown
  return (
    <>
      <SearchBox value={q} onChange={setQ} placeholder="Search name or table" />
      <Segmented items={["Upcoming", "Arrived", "All"]} active={filter === "Confirmed" ? "Upcoming" : filter} onChange={(f) => setFilter(f === "Upcoming" ? "Confirmed" : f)} />
      <p className="list-count">
        {shown.length} of {bookings.length} bookings · {bookingGuests(shown)} guests
      </p>
      {list.length === 0 ? (
        <Empty icon="search" title="No matching bookings" text="Try another name, table or filter." />
      ) : (
        <div className="booking-list card">
          {list.map((b) => (
            <button className="booking-row" key={b.id} onClick={() => open(b.id)}>
              <span className="booking-time">{b.time}</span>
              <span>
                <strong>{b.name}</strong>
                <small>
                  {b.table} · {b.guests} guests{b.server ? ` · ${b.server}` : " · No server"}
                </small>
                <em className={b.payment.startsWith("Balance") ? "due" : ""}>
                  {b.status === "Arrived" ? "Arrived · " : ""}
                  {b.payment}
                </em>
              </span>
              <Icon name="chevron" />
            </button>
          ))}
        </div>
      )}
    </>
  )
}

/** Assign servers to arrived tables that don't have one. */
export function AssignServersBody({ close }: { close: () => void }) {
  const { bookings, setBookings } = useStore()
  const ui = useUI()
  const open = bookings.filter((b) => b.status === "Arrived" && !b.server)
  const [picks, setPicks] = useState<Record<string, string>>(() => Object.fromEntries(open.map((b) => [b.id, SERVERS[0]])))
  if (open.length === 0) return <Empty icon="check" title="Every table has a server" text="New bookings will appear here if they need one." />
  return (
    <div className="form-stack">
      {open.map((b) => (
        <label className="field" key={b.id}>
          <span>
            {b.table} · {b.name} · {b.guests} guests
          </span>
          <select value={picks[b.id]} onChange={(e) => setPicks({ ...picks, [b.id]: e.target.value })}>
            {SERVERS.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
      ))}
      <button
        className="primary-action full-action"
        onClick={() => {
          setBookings((list) => list.map((b) => (picks[b.id] ? { ...b, server: picks[b.id] } : b)))
          ui.toast(`${open.length} table${open.length === 1 ? "" : "s"} assigned`)
          close()
        }}
      >
        Assign {open.length} table{open.length === 1 ? "" : "s"}
      </button>
    </div>
  )
}

export function useUnassigned() {
  return useStore().bookings.filter((b) => b.status === "Arrived" && !b.server).length
}

/** Flagged payment review. */
export function PaymentReviewBody({ close }: { close: () => void }) {
  const { txns, setTxns } = useStore()
  const ui = useUI()
  const flagged = txns.filter((t) => t.flagged)
  if (flagged.length === 0) return <Empty icon="check" title="No payments to review" text="Flagged transactions will appear here." />
  return (
    <div className="form-stack">
      {flagged.map((t) => (
        <div key={t.id} className="review-card card">
          <strong>
            {t.label} · {usd(t.amount)}
          </strong>
          <small>
            {t.method} · {t.time}
          </small>
          <p>{t.flagged}</p>
          <div className="dual-actions">
            <button
              className="secondary-action"
              onClick={() => {
                setTxns((list) => list.map((x) => (x.id === t.id ? { ...x, flagged: undefined, method: `${x.method} · Refunded` } : x)))
                ui.toast(`${t.label} refunded`)
                close()
              }}
            >
              Refund
            </button>
            <button
              className="primary-action"
              onClick={() => {
                setTxns((list) => list.map((x) => (x.id === t.id ? { ...x, flagged: undefined } : x)))
                ui.toast(`${t.label} approved`)
                close()
              }}
            >
              Approve
            </button>
          </div>
        </div>
      ))}
    </div>
  )
}

export function useFlagged() {
  return useStore().txns.filter((t) => t.flagged).length
}

/** Add a walk-in party to a table (owner / manager). */
export function TableWalkInBody({ close }: { close: () => void }) {
  const { setBookings, setArrived, bookings } = useStore()
  const ui = useUI()
  const free = ["Table 6 · 4 seats", "Bar · Standing"].filter((t) => !bookings.some((b) => t.startsWith(b.table + " ")))
  return (
    <QuickForm
      submit="Add walk-in"
      fields={[
        { id: "name", label: "Guest name", placeholder: "Enter a name", required: true },
        { id: "size", label: "Party size", value: "4", type: "number", required: true },
        { id: "table", label: "Assign a table", options: free.length ? free : ["Bar · Standing"] },
        { id: "notes", label: "Notes (optional)", placeholder: "Celebration, preferences, accessibility…" },
      ]}
      onSubmit={(v) => {
        const guests = Math.max(1, parseInt(v.size) || 1)
        const table = v.table.split(" · ")[0]
        setBookings((list) => [...list, { id: "w" + Date.now(), name: v.name.trim(), time: NIGHT.now, table, guests, payment: "Pay at venue", status: "Arrived", server: null }])
        setArrived((n) => n + guests)
        ui.toast(`${v.name.trim()}'s party added to ${table}`)
        close()
      }}
    />
  )
}

export function InviteBody({ roles, onInvite, close }: { roles: string[]; onInvite: (email: string, role: string) => void; close: () => void }) {
  return (
    <QuickForm
      submit="Send invitation"
      fields={[
        { id: "email", label: "Email address", placeholder: "name@example.com", type: "email", required: true },
        { id: "role", label: "Role", options: roles },
      ]}
      onSubmit={(v) => {
        onInvite(v.email.trim(), v.role)
        close()
      }}
    />
  )
}

export function MemberBody({ name, role, status, onRemove, close }: { name: string; role: string; status: string; onRemove?: () => void; close: () => void }) {
  const ui = useUI()
  const [confirm, setConfirm] = useState(false)
  return (
    <>
      <Lines
        rows={[
          ["Name", name],
          ["Role", role],
          ["Status", status],
        ]}
      />
      <div className="dual-actions">
        <button
          className="secondary-action"
          onClick={() => {
            ui.sheet({ eyebrow: role.toUpperCase(), title: name, body: () => <Thread initial={[]} placeholder={`Message ${name.split(" ")[0]}…`} reply="Got it, thanks." replyFrom={name} /> })
          }}
        >
          Message
        </button>
        {onRemove &&
          (confirm ? (
            <button
              className="danger-button"
              onClick={() => {
                onRemove()
                ui.toast(`${name} removed`)
                close()
              }}
            >
              Confirm remove
            </button>
          ) : (
            <button className="secondary-action" onClick={() => setConfirm(true)}>
              Remove
            </button>
          ))}
      </div>
    </>
  )
}

export function SupportBody() {
  const ui = useUI()
  return (
    <Options
      close={() => {}}
      items={[
        { label: "Chat with support", detail: "Typical reply under 5 minutes", icon: "chat", onSelect: () => ui.sheet({ eyebrow: "SUPPORT", title: "BottlesUp support", body: () => <Thread initial={[{ mine: false, text: "Hi! How can we help tonight?", time: "Now", who: "Support" }]} placeholder="Describe the issue…" reply="Thanks. A specialist is looking into it and will reply here." replyFrom="Support" /> }) },
        { label: "Request a call", detail: "We'll call the number on your account", icon: "person", onSelect: () => ui.toast("Call requested. Support will call within 15 minutes.") },
        { label: "Help articles", detail: "Bookings, payments, check-in and payouts", icon: "reports", onSelect: () => ui.sheet({ eyebrow: "HELP", title: "Popular articles", body: () => <Lines rows={[["Checking in a guest", "2 min read"], ["Refunding a payment", "3 min read"], ["Closing the night", "4 min read"], ["Inviting your team", "2 min read"]]} /> }) },
      ]}
    />
  )
}

export function ShiftBody({ place, hours }: { place: string; hours: string }) {
  return (
    <Lines
      rows={[
        ["Location", place],
        ["Shift", hours],
        ["Break", "11:30 PM · 30 minutes"],
        ["Manager on duty", "Jordan Blake"],
        ["Date", NIGHT.dayLabel],
      ]}
    />
  )
}

export function SettingsBody({ appearance, onAppearance, onSignOut }: { appearance: Appearance; onAppearance: (a: Appearance) => void; onSignOut: () => void }) {
  const [notify, setNotify] = useState({ Bookings: true, Shifts: true, Invitations: true, Orders: false })
  return (
    <div className="form-stack">
      <div className="settings-group">
        <span>DISPLAY</span>
        <AppearanceCard appearance={appearance} onAppearance={onAppearance} />
      </div>
      <div className="settings-group">
        <span>NOTIFICATIONS</span>
        {(Object.keys(notify) as (keyof typeof notify)[]).map((k) => (
          <label className="setting-row card" key={k}>
            <span>
              <strong>{k}</strong>
              <small>{notify[k] ? "On" : "Off"}</small>
            </span>
            <input type="checkbox" checked={notify[k]} onChange={() => setNotify({ ...notify, [k]: !notify[k] })} />
            <i />
          </label>
        ))}
      </div>
      <button className="signout-button" onClick={onSignOut}>
        Sign out of demo
      </button>
    </div>
  )
}

export function OfflineBody() {
  const [state, setState] = useState<"offline" | "retrying" | "online">("offline")
  return (
    <div className={`offline-demo ${state}`}>
      <Icon name={state === "online" ? "check" : "wifi"} size={30} />
      <h2>{state === "online" ? "Back online" : state === "retrying" ? "Reconnecting…" : "You're offline"}</h2>
      <p>{state === "online" ? "Everything is synced." : "Scans and orders are saved on this device and sync when you reconnect."}</p>
      {state !== "online" && (
        <button
          className="primary-action full-action"
          disabled={state === "retrying"}
          onClick={() => {
            setState("retrying")
            window.setTimeout(() => setState("online"), 900)
          }}
        >
          Try again
        </button>
      )}
    </div>
  )
}

export function AppearanceCard({ appearance, onAppearance }: { appearance: Appearance; onAppearance: (a: Appearance) => void }) {
  const systemDark = window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? true
  const dark = appearance === "dark" || (appearance === "system" && systemDark)
  return (
    <div className="appearance-card">
      <label className="appearance-row">
        <span className="appearance-row-label">
          <strong>Match this device</strong>
          <small>{appearance === "system" ? "On · following your phone" : "Off · use the sun and moon switch at the top"}</small>
        </span>
        <span className={appearance === "system" ? "toggle on" : "toggle"}>
          <input type="checkbox" className="sr-only" checked={appearance === "system"} onChange={() => onAppearance(appearance === "system" ? (dark ? "dark" : "light") : "system")} />
          <i />
        </span>
      </label>
    </div>
  )
}
