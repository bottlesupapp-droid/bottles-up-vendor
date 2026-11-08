import { useState, type ReactNode } from "react"
import { usePersisted, Icon, Lines, Options, QuickForm, ThemeToggle, useUI, type Appearance, type IconName, type Theme } from "./kit"
import { BookingRequestForm, DEFAULT_ADDONS, DEFAULT_PACKAGES, DjProfileEditor, DjPublicProfile, ServicesEditor, eventLabel, useDj, type DjAddon, type DjPkg } from "./DjStudio"
import { Inbox, inboxUnread, useInbox, useStartThread } from "./Inbox"
import { Empty, RowList, Segmented, SettingsBody, SupportBody, type Row } from "./shared"

/* Prices match the consumer app's booking flow, so a request sent there reads the same here. */
type Pkg = DjPkg
type AddonId = string
const EXTRA_HOUR = 250
const TRAVEL = 150
const FEE = 0.1 // BottlesUp service fee, taken from the artist's subtotal

type Status = "New" | "Countered" | "Awaiting deposit" | "Confirmed" | "Declined"
type Req = {
  id: string
  ref: string
  client: string
  clientType: string
  clientNote: string
  pkg: string
  date: string
  dayKey: string
  start: string
  end: string
  venue: string
  eventType: string
  guests: number
  extraHours: number
  addons: AddonId[]
  travel: boolean
  message: string
  received: string
  status: Status
  override?: number
  reason?: string
}

const INITIAL: Req[] = [
  { id: "r1", ref: "BK-7559", client: "Jordan Ellis", clientType: "Guest · BottlesUp app", clientNote: "First booking · 42 nights out on BottlesUp", pkg: "private", date: "Sat, Sep 7", dayKey: "2024-09-07", start: "9:00 PM", end: "1:00 AM", venue: "Private loft · Liberty Village", eventType: "Birthday after-party", guests: 40, extraHours: 1, addons: ["gear"], travel: false, message: "30th birthday after-party for about 40 people. Afro house and amapiano all night, please!", received: "12 min ago", status: "New" },
  { id: "r2", ref: "BK-7531", client: "Midnight Social", clientType: "Organizer", clientNote: "Booked you 2 times · 4.9 rating from artists", pkg: "club", date: "Fri, Oct 11", dayKey: "2024-10-11", start: "10:00 PM", end: "2:00 AM", venue: "Sky Room · Harbour Avenue", eventType: "Club night", guests: 220, extraHours: 0, addons: ["lights"], travel: false, message: "Rooftop Frequencies afterparty. Headline slot after midnight.", received: "2 h ago", status: "New" },
  { id: "r3", ref: "BK-7490", client: "Priya Shah", clientType: "Guest · BottlesUp app", clientNote: "New to BottlesUp", pkg: "private", date: "Fri, Aug 30", dayKey: "2024-08-30", start: "8:00 PM", end: "11:00 PM", venue: "42 Queen St W, Toronto", eventType: "Private party", guests: 60, extraHours: 0, addons: ["mc"], travel: false, message: "Engagement party. Some Bollywood mixed in would be amazing.", received: "Yesterday", status: "New" },
  { id: "r4", ref: "BK-7402", client: "Sky Room", clientType: "Venue", clientNote: "Booked you 5 times", pkg: "warmup", date: "Fri, Sep 20", dayKey: "2024-09-20", start: "9:00 PM", end: "11:00 PM", venue: "Sky Room · Harbour Avenue", eventType: "Club night", guests: 180, extraHours: 0, addons: [], travel: false, message: "Opening for our resident.", received: "Aug 2", status: "Confirmed" },
  { id: "r5", ref: "BK-7388", client: "Northwind Agency", clientType: "Corporate", clientNote: "New to BottlesUp", pkg: "private", date: "Thu, Sep 12", dayKey: "2024-09-12", start: "7:00 PM", end: "10:00 PM", venue: "Mississauga Convention Ctr", eventType: "Corporate event", guests: 300, extraHours: 0, addons: ["gear"], travel: true, message: "Staff party, clean versions only.", received: "Jul 30", status: "Declined", reason: "Not my style of event" },
]

// Gigs already on the calendar (same dates the consumer app shows as booked).
const FIXED_GIGS: Record<string, string> = {
  "2024-08-17": "Private set · Liberty Village",
  "2024-08-24": "EONICS: Afterglow · Nova Room",
  "2024-08-31": "Neon Garden · Nova Room",
  "2024-09-14": "EONICS × Amara Vale · Nova Room",
  "2024-09-21": "Nova Room residency",
  "2024-10-05": "Nova Room residency",
}

const money = (n: number) => "$" + n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const money0 = (n: number) => "$" + n.toLocaleString("en-US", { maximumFractionDigits: 0 })

function quote(r: Req, pkgs: Pkg[], addons: DjAddon[]) {
  const p = pkgs.find((x) => x.id === r.pkg) ?? DEFAULT_PACKAGES.find((x) => x.id === r.pkg) ?? DEFAULT_PACKAGES[0]
  const lines: [string, number][] = [[`${p.name} · ${p.hours} h`, p.price]]
  if (r.extraHours) lines.push([`Extra time · ${r.extraHours} h`, r.extraHours * EXTRA_HOUR])
  for (const id of r.addons) {
    const a = addons.find((x) => x.id === id) ?? DEFAULT_ADDONS.find((x) => x.id === id)
    if (a) lines.push([a.name, a.price])
  }
  if (r.travel) lines.push(["Travel outside Toronto", TRAVEL])
  let subtotal = lines.reduce((s, [, v]) => s + v, 0)
  if (r.override !== undefined) {
    lines.push(["Your counter-offer adjustment", r.override - subtotal])
    subtotal = r.override
  }
  const tax = Math.round(subtotal * 13) / 100
  const total = subtotal + tax
  const deposit = Math.round(total * 30) / 100
  const fee = Math.round(subtotal * FEE * 100) / 100
  return { lines, subtotal, tax, total, deposit, fee, payout: subtotal - fee, pkgName: p.name }
}

const setHours = (r: Req, pkgs: Pkg[]) => (pkgs.find((x) => x.id === r.pkg)?.hours ?? 0) + r.extraHours
const STATUS_LABEL: Record<Status, string> = { New: "New", Countered: "Awaiting client", "Awaiting deposit": "Awaiting deposit", Confirmed: "Confirmed", Declined: "Declined" }
const GROUP: Record<Status, string> = { New: "New", Countered: "Awaiting Client", "Awaiting deposit": "Awaiting Client", Confirmed: "Confirmed", Declined: "Past" }

const STATUS_CLASS: Record<Status, string> = { New: "pending", Countered: "pending-approval", "Awaiting deposit": "pending", Confirmed: "accepted", Declined: "draft" }

function Badge({ s }: { s: Status }) {
  return <em className={`status-badge ${STATUS_CLASS[s]}`}>{STATUS_LABEL[s]}</em>
}

function Title({ eyebrow, title, action }: { eyebrow: string; title: string; action?: ReactNode }) {
  return (
    <div className="page-title">
      <div>
        <span>{eyebrow}</span>
        <h1>{title}</h1>
      </div>
      {action}
    </div>
  )
}

function DeclineBody({ onDecline, close }: { onDecline: (reason: string) => void; close: () => void }) {
  const reasons = ["Already booked that night", "Outside my genre", "Budget too low", "Travel too far", "Other"]
  const [pick, setPick] = useState(reasons[0])
  const [note, setNote] = useState("")
  return (
    <div className="form-stack">
      <div className="choice-list card">
        {reasons.map((r) => (
          <label className="choice" key={r}>
            <input type="radio" name="decline" checked={pick === r} onChange={() => setPick(r)} />
            <span>
              <strong>{r}</strong>
            </span>
          </label>
        ))}
      </div>
      <label className="field">
        <span>Note to the client (optional)</span>
        <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Thanks for thinking of me…" />
      </label>
      <button
        className="danger-button solid"
        onClick={() => {
          onDecline(pick)
          close()
        }}
      >
        Decline request
      </button>
    </div>
  )
}

function RequestDetail({ r, pkgs, addons, conflicts, onBack, update, onChat }: { r: Req; pkgs: Pkg[]; addons: DjAddon[]; conflicts: string | null; onBack: () => void; update: (patch: Partial<Req>) => void; onChat: (r: Req) => void }) {
  const ui = useUI()
  const q = quote(r, pkgs, addons)
  const accept = () =>
    ui.sheet({
      eyebrow: `${r.ref} · ${r.client.toUpperCase()}`,
      title: "Accept this booking?",
      body: (close) => (
        <>
          <Lines
            rows={[
              ["Date", `${r.date} · ${r.start}–${r.end}`],
              ["Client pays now", `${money(q.deposit)} deposit (30%)`],
              ["Balance", `${money(q.total - q.deposit)} · 7 days before`],
              ["You receive", `${money(q.payout)} after the 10% fee`],
            ]}
          />
          <p className="list-count">The date is held on your calendar. It becomes confirmed when the client pays the deposit.</p>
          <button
            className="primary-action full-action"
            onClick={() => {
              update({ status: "Awaiting deposit" })
              ui.toast(`Accepted. ${r.client} has been asked to pay the deposit.`)
              close()
            }}
          >
            Accept booking
          </button>
        </>
      ),
    })
  const counter = () =>
    ui.sheet({
      eyebrow: r.ref,
      title: "Counter-offer",
      body: (close) => (
        <QuickForm
          submit="Send counter-offer"
          fields={[
            { id: "price", label: "Your price before HST", value: String(q.subtotal), type: "number", required: true },
            { id: "start", label: "Start time", options: [r.start, "9:00 PM", "10:00 PM", "11:00 PM", "12:00 AM"].filter((v, i, a) => a.indexOf(v) === i) },
            { id: "note", label: "Note", placeholder: "e.g. Happy to do it with my own equipment included" },
          ]}
          onSubmit={(v) => {
            const price = Math.max(100, Math.round(parseFloat(v.price) || q.subtotal))
            update({ status: "Countered", override: price, start: v.start })
            ui.toast(`Counter-offer sent: ${money0(price)} + HST`)
            close()
          }}
        />
      ),
    })
  const chat = () => onChat(r)
  return (
    <>
      <div className="detail-heading">
        <button className="back-button" aria-label="Go back" onClick={onBack}>
          <Icon name="back" />
        </button>
        <div>
          <span>
            {r.ref} · RECEIVED {r.received.toUpperCase()}
          </span>
          <h1>{q.pkgName}</h1>
        </div>
        <Badge s={r.status} />
      </div>

      <div className="dj-client card">
        <span className="member-avatar">{r.client.slice(0, 2).toUpperCase()}</span>
        <span>
          <strong>{r.client}</strong>
          <small>
            {r.clientType} · {r.clientNote}
          </small>
        </span>
        <button className="icon-button" aria-label={`Message ${r.client}`} onClick={chat}>
          <Icon name="chat" />
        </button>
      </div>

      {r.message && <p className="dj-message">“{r.message}”</p>}

      {conflicts && r.status !== "Declined" && r.status !== "Confirmed" && (
        <div className="auth-error" role="alert">
          <Icon name="warning" /> You already have “{conflicts}” on {r.date}.
        </div>
      )}

      <section>
        <div className="section-heading">
          <div>
            <span>EVENT</span>
            <h2>Details</h2>
          </div>
        </div>
        <Lines
          rows={[
            ["Date", r.date],
            ["Set time", `${r.start} – ${r.end}`],
            ["Where", r.venue],
            ["Event", `${r.eventType} · ${r.guests} guests`],
            ["Add-ons", r.addons.length ? r.addons.map((a) => addons.find((x) => x.id === a)?.name ?? a).join(", ") : "None"],
          ]}
        />
      </section>

      <section>
        <div className="section-heading">
          <div>
            <span>EQUIPMENT</span>
            <h2>What's needed</h2>
          </div>
        </div>
        <Lines
          rows={[
            ["Decks and mixer", r.addons.includes("gear") ? "You bring your setup (+ add-on)" : "Venue provides · rider: 2 × CDJ-3000, DJM-A9"],
            ["Lighting", r.addons.includes("lights") ? "You bring the lighting package" : "Venue lighting"],
            ["Host / MC", r.addons.includes("mc") ? "Included" : "Not requested"],
            ["Travel", r.travel ? "Outside Toronto · travel fee applies" : "Within Toronto"],
          ]}
        />
      </section>

      <section>
        <div className="section-heading">
          <div>
            <span>PRICE</span>
            <h2>What the client pays</h2>
          </div>
        </div>
        <Lines
          rows={[
            ...q.lines.map(([k, v]) => [k, (v < 0 ? "−" : "") + money(Math.abs(v))] as [string, string]),
            ["Subtotal", money(q.subtotal)],
            ["HST (13%)", money(q.tax)],
            ["Client total", money(q.total)],
            ["Deposit to confirm (30%)", money(q.deposit)],
          ]}
        />
        <div className="dj-payout card">
          <span>
            <small>YOU RECEIVE</small>
            <strong>{money(q.payout)}</strong>
          </span>
          <small>
            {money(q.subtotal)} minus the 10% BottlesUp fee ({money(q.fee)}). HST is collected and remitted separately.
          </small>
        </div>
      </section>

      <section>
        <div className="section-heading">
          <div>
            <span>TERMS</span>
            <h2>Booking terms</h2>
          </div>
        </div>
        <Lines
          rows={[
            ["Deposit", "30% to confirm, held by BottlesUp"],
            ["Balance", "Due 7 days before the gig"],
            ["Client cancels", "Over 14 days: full refund · under 14 days: deposit kept"],
            ["You cancel", "Client refunded in full"],
            ["Payout", "2 business days after the gig"],
          ]}
        />
      </section>

      {r.status === "New" || r.status === "Countered" ? (
        <>
          {r.status === "Countered" && <p className="list-count">Counter-offer sent. Waiting for {r.client} to reply.</p>}
          <div className="dual-actions">
            <button className="secondary-action" onClick={counter}>
              {r.status === "Countered" ? "Change offer" : "Counter-offer"}
            </button>
            <button className="primary-action" onClick={accept}>
              Accept
            </button>
          </div>
          <button
            className="danger-button"
            onClick={() =>
              ui.sheet({
                eyebrow: r.ref,
                title: "Decline request",
                body: (close) => (
                  <DeclineBody
                    close={close}
                    onDecline={(reason) => {
                      update({ status: "Declined", reason })
                      ui.toast(`Declined. ${r.client} has been told.`)
                    }}
                  />
                ),
              })
            }
          >
            Decline
          </button>
        </>
      ) : r.status === "Awaiting deposit" ? (
        <>
          <div className="complete-banner">
            <Icon name="clock" size={17} /> Accepted · waiting for the {money(q.deposit)} deposit
          </div>
          <div className="dual-actions">
            <button className="secondary-action" onClick={chat}>
              Message client
            </button>
            <button
              className="primary-action"
              onClick={() => {
                update({ status: "Confirmed" })
                ui.toast("Deposit received. Gig confirmed.")
              }}
            >
              Mark deposit paid
            </button>
          </div>
          <p className="list-count">Demo shortcut. In the live app this updates on its own when the client pays.</p>
        </>
      ) : r.status === "Confirmed" ? (
        <>
          <div className="complete-banner">
            <Icon name="check" size={17} /> Confirmed · deposit paid
          </div>
          <div className="dual-actions">
            <button className="secondary-action" onClick={chat}>
              Message client
            </button>
            <button className="secondary-action" onClick={() => ui.copy(`Amara Vale · ${r.date} · ${r.start}–${r.end} · ${r.venue}`, "Gig details copied")}>
              Copy gig details
            </button>
          </div>
        </>
      ) : (
        <p className="list-count">Declined{r.reason ? ` · ${r.reason}` : ""}. The client can send a new request.</p>
      )}
    </>
  )
}

function CalendarTab({ reqs, blocked, setBlocked, open }: { reqs: Req[]; blocked: string[]; setBlocked: (b: string[]) => void; open: (id: string) => void }) {
  const ui = useUI()
  const [m, setM] = useState(1)
  const first = new Date(2024, 7 + m, 1)
  const offset = first.getDay()
  const days = new Date(2024, 8 + m, 0).getDate()
  const k = (d: number) => `2024-${String(8 + m).padStart(2, "0")}-${String(d).padStart(2, "0")}`
  const held = (key: string) => reqs.find((r) => r.dayKey === key && (r.status === "Awaiting deposit" || r.status === "Confirmed"))
  const pending = (key: string) => reqs.find((r) => r.dayKey === key && (r.status === "New" || r.status === "Countered"))
  const tap = (key: string, label: string) => {
    const gig = FIXED_GIGS[key]
    const h = held(key)
    const p = pending(key)
    if (h || p) return open((h ?? p)!.id)
    if (gig) return ui.sheet({ eyebrow: label.toUpperCase(), title: "Booked", body: () => <Lines rows={[["Gig", gig], ["Status", "Confirmed"]]} /> })
    const isBlocked = blocked.includes(key)
    ui.sheet({
      eyebrow: label.toUpperCase(),
      title: isBlocked ? "Blocked" : "Open for bookings",
      body: (close) => (
        <button
          className={isBlocked ? "primary-action full-action" : "secondary-action full-action"}
          onClick={() => {
            setBlocked(isBlocked ? blocked.filter((b) => b !== key) : [...blocked, key])
            ui.toast(isBlocked ? `${label} is open again` : `${label} blocked. Guests can't request it.`)
            close()
          }}
        >
          {isBlocked ? "Open this date" : "Block this date"}
        </button>
      ),
    })
  }
  const upcoming = [...Object.entries(FIXED_GIGS).filter(([key]) => key >= "2024-08-24").map(([key, t]) => ({ key, t, id: "" })), ...reqs.filter((r) => r.status === "Confirmed" || r.status === "Awaiting deposit").map((r) => ({ key: r.dayKey, t: `${r.client} · ${r.status === "Confirmed" ? "Confirmed" : "Held"}`, id: r.id }))].sort((a, b) => a.key.localeCompare(b.key))
  return (
    <>
      <Title eyebrow="AMARA VALE" title="Calendar" />
      <div className="calendar-card card">
        <div className="calendar-head">
          <button aria-label="Previous month" disabled={m === 0} onClick={() => setM(m - 1)}>
            <Icon name="back" />
          </button>
          <strong>{first.toLocaleDateString("en-US", { month: "long", year: "numeric" })}</strong>
          <button aria-label="Next month" disabled={m === 2} onClick={() => setM(m + 1)}>
            <Icon name="chevron" />
          </button>
        </div>
        <div className="calendar-grid">
          {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => (
            <span className="weekday" key={i}>
              {d}
            </span>
          ))}
          {Array.from({ length: offset }, (_, i) => (
            <span key={"e" + i} />
          ))}
          {Array.from({ length: days }, (_, i) => {
            const key = k(i + 1)
            const label = new Date(2024, 7 + m, i + 1).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })
            const cls = FIXED_GIGS[key] || held(key)?.status === "Confirmed" ? "gig" : held(key) ? "held" : pending(key) ? "req" : blocked.includes(key) ? "blocked" : ""
            return (
              <button key={i} className={`dj-day ${cls}`} onClick={() => tap(key, label)} aria-label={`${label}${cls ? ", " + cls : ""}`}>
                {i + 1}
              </button>
            )
          })}
        </div>
        <div className="dj-legend">
          <span>
            <i className="gig" /> Booked
          </span>
          <span>
            <i className="held" /> Held
          </span>
          <span>
            <i className="req" /> Request
          </span>
          <span>
            <i className="blocked" /> Blocked
          </span>
        </div>
      </div>
      <section>
        <div className="section-heading">
          <div>
            <span>COMING UP</span>
            <h2>Your gigs</h2>
          </div>
        </div>
        <RowList rows={upcoming.map((g) => ({ icon: "calendar", title: new Date(g.key + "T12:00").toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }), desc: g.t, onOpen: g.id ? () => open(g.id) : undefined }) as Row)} />
      </section>
    </>
  )
}

export default function DjApp({ theme, onTheme, appearance, onAppearance, onSwitch }: { theme: Theme; onTheme: () => void; appearance: Appearance; onAppearance: (a: Appearance) => void; onSwitch: () => void }) {
  const ui = useUI()
  const [tab, setTab] = useState("requests")
  const [reqs, setReqs] = usePersisted<Req[]>("bu-biz-dj-reqs", INITIAL)
  const [openId, setOpenId] = useState<string | null>(null)
  const [filter, setFilter] = useState<string>("New")
  const dj = useDj()
  const pkgs = dj.pkgs
  const addons = dj.addons
  const ib = useInbox()
  const startThread = useStartThread("dj")
  const [overlay, setOverlay] = useState<null | "edit" | "public" | "book" | "inbox">(null)
  const [inboxOpen, setInboxOpen] = useState<{ start: "Inquiries" | "Team"; id: string | null }>({ start: "Inquiries", id: null })
  const openInbox = (start: "Inquiries" | "Team" = "Inquiries", id: string | null = null) => {
    setInboxOpen({ start, id })
    setOverlay("inbox")
  }
  const chatFor = (r: Req) => {
    const existing = ib.threads.dj.find((t) => t.card?.title.startsWith(r.ref))
    const id = existing?.id ?? startThread({ id: "bk-" + r.ref, area: "Customers", guest: r.client, context: `Booking ${r.ref} · ${r.date}`, scope: "Bookings", card: { kind: "Booking", title: `${r.ref} · ${pkgs.find((p) => p.id === r.pkg)?.name ?? "Booking"}`, detail: `${r.venue} · ${r.start} – ${r.end} · ${r.status}` }, first: r.message || undefined })
    openInbox("Inquiries", id)
  }
  const unread = inboxUnread(ib.threads.dj)
  const [accepting, setAccepting] = useState(true)
  const [blocked, setBlocked] = useState<string[]>([])
  const update = (id: string, patch: Partial<Req>) => setReqs((list) => list.map((r) => (r.id === id ? { ...r, ...patch } : r)))
  const open = (id: string) => {
    setOpenId(id)
    setTab("requests")
    window.scrollTo({ top: 0 })
  }
  const go = (t: string) => {
    setOpenId(null)
    setTab(t)
    window.scrollTo({ top: 0 })
  }
  const counts: Record<string, number> = { New: 0, "Awaiting Client": 0, Confirmed: 0, Past: 0 }
  for (const r of reqs) counts[GROUP[r.status]]++
  const conflictFor = (r: Req) => FIXED_GIGS[r.dayKey] ?? reqs.find((x) => x.id !== r.id && x.dayKey === r.dayKey && (x.status === "Confirmed" || x.status === "Awaiting deposit"))?.client ?? null
  const confirmed = reqs.filter((r) => r.status === "Confirmed")
  const held = reqs.filter((r) => r.status === "Awaiting deposit")

  let body: ReactNode
  const current = reqs.find((r) => r.id === openId)
  if (current) body = <RequestDetail r={current} pkgs={pkgs} addons={addons} conflicts={conflictFor(current)} onBack={() => setOpenId(null)} update={(p) => update(current.id, p)} onChat={chatFor} />
  else if (tab === "requests") {
    const shown = reqs.filter((r) => GROUP[r.status] === filter)
    body = (
      <>
        <Title eyebrow="AMARA VALE · DJ" title="Requests" />
        <div className="dj-compact">
          <p>
            <b>{counts.New}</b> new · <b>{counts["Awaiting Client"]}</b> awaiting client
          </p>
          <label className="dj-avail">
            <span>{accepting ? "Accepting bookings" : "Bookings paused"}</span>
            <input
              type="checkbox"
              role="switch"
              aria-label="Accepting bookings"
              checked={accepting}
              onChange={() => {
                setAccepting(!accepting)
                ui.toast(accepting ? "Bookings paused. Your profile shows “Not taking bookings”." : "You're accepting bookings again")
              }}
            />
            <i />
          </label>
        </div>
        <div className="srv-filters" role="tablist" aria-label="Request status">
          {(["New", "Awaiting Client", "Confirmed", "Past"] as const).map((f) => (
            <button key={f} role="tab" aria-selected={filter === f} className={filter === f ? "on" : ""} onClick={() => setFilter(f)}>
              {f}
              {(f === "New" || f === "Awaiting Client") && counts[f] > 0 && <span>{counts[f]}</span>}
            </button>
          ))}
        </div>
        {shown.length === 0 ? (
          <Empty icon="calendar" title={filter === "New" ? "You're all caught up" : `Nothing in ${filter}`} text={filter === "New" ? "New requests from guests, organizers and venues appear here." : "Requests move here as they progress."} />
        ) : (
          <div className="srv-list">
            {shown.map((r) => {
              const q = quote(r, pkgs, addons)
              const clash = conflictFor(r) && r.status === "New"
              return (
                <button className="srv-table dj-row" key={r.id} onClick={() => open(r.id)}>
                  <span className="srv-avatar">{r.client.slice(0, 2).toUpperCase()}</span>
                  <span className="srv-main">
                    <strong>{r.client}</strong>
                    <small>
                      {r.eventType} · {r.date} · {r.venue.split(" · ")[0]}
                    </small>
                    <small>
                      {setHours(r, pkgs)} h set · offered {money0(q.subtotal)} + HST
                    </small>
                    <span className="srv-tags">
                      <Badge s={r.status} />
                      {clash && <em className="status-badge draft">Date conflict</em>}
                    </span>
                  </span>
                  <Icon name="chevron" size={16} />
                </button>
              )
            })}
          </div>
        )}
      </>
    )
  } else if (tab === "calendar") body = <CalendarTab reqs={reqs} blocked={blocked} setBlocked={setBlocked} open={open} />
  else if (tab === "services")
    body = (
      <>
        <Title eyebrow="SHOWN ON YOUR PUBLIC PROFILE" title="Services" />
        <ServicesEditor />
      </>
    )
  else if (tab === "earnings") {
    const sum = (list: Req[]) => list.reduce((s, r) => s + quote(r, pkgs, addons).payout, 0)
    body = (
      <>
        <Title eyebrow="PRIVATE · DEMO DATA" title="Earnings" />
        <div className="dj-earn">
          <span>Available for payout</span>
          <strong>{money(2640)}</strong>
          <small>Next payout Mon, Aug 26 · bank ending 8812</small>
        </div>
        <section className="srv-section">
          <h2>Payment status</h2>
          <div className="srv-list">
            {[
              ...confirmed.map((r) => ({ id: r.id, who: r.client, when: r.date, amt: quote(r, pkgs, addons).payout, label: "Deposit held", tone: "blue" })),
              ...held.map((r) => ({ id: r.id, who: r.client, when: r.date, amt: quote(r, pkgs, addons).payout, label: "Waiting for deposit", tone: "gray" })),
              { id: "", who: "Nova Room residency", when: "Aug 17", amt: 1110, label: "Payout pending", tone: "amber" },
              { id: "", who: "Sky Room warm-up", when: "Aug 10", amt: 450, label: "Paid out", tone: "green" },
              { id: "", who: "Private set · Liberty Village", when: "Aug 3", amt: 1080, label: "Paid out", tone: "green" },
            ].map((x, i) => (
              <button key={i} className="srv-table" disabled={!x.id} onClick={() => x.id && open(x.id)}>
                <span className="srv-main">
                  <strong>{x.who}</strong>
                  <small>
                    {x.when} · you receive {money(x.amt)}
                  </small>
                </span>
                <span className={`srv-chip tone-${x.tone}`}>{x.label}</span>
              </button>
            ))}
          </div>
        </section>
        <p className="status-explainer">Deposits are held by BottlesUp until the gig happens. You're paid 2 business days after each gig, after the 10% fee. Only you can see this page.</p>
      </>
    )
  } else
    body = (
      <>
        <Title eyebrow="DJ / ARTIST" title="More" />
        <section className="srv-section">
          <h2>Public profile</h2>
          <div className="ds-visibility">
            <span>
              <strong>Profile visibility</strong>
              <small>{dj.profile.visibility === "Public" ? "Anyone can find and book you" : "Hidden from search and visitors. Existing bookings are not affected."}</small>
            </span>
            <div className="cp-chips">
              {(["Public", "Private"] as const).map((v) => (
                <button key={v} aria-pressed={dj.profile.visibility === v} className={dj.profile.visibility === v ? "on" : ""} onClick={() => (dj.setProfile((p) => ({ ...p, visibility: v })), ui.toast(v === "Public" ? "Your profile is public" : "Your profile is private"))}>
                  {v}
                </button>
              ))}
            </div>
          </div>
          <RowList
            rows={[
              { icon: "person", title: "View public profile", desc: "See it the way visitors do", onOpen: () => setOverlay("public") },
              { icon: "pencil", title: "Edit profile", desc: "Photos, bio, genres, links and booking preferences", onOpen: () => setOverlay("edit") },
            ]}
          />
        </section>
        <section className="srv-section">
          <h2>Private</h2>
          <RowList
            rows={[
              { icon: "chat", title: "Messages", desc: unread ? `${unread} unread · inquiries and team` : "Inquiries and team chats", badge: unread ? String(unread) : undefined, onOpen: () => openInbox() },
              { icon: "chart", title: "Analytics", desc: "Profile views, requests and booking rate", onOpen: () => ui.sheet({ eyebrow: "PRIVATE · DEMO DATA", title: "Last 30 days", body: () => <DjAnalytics /> }) },
              { icon: "ticket", title: "Rider", desc: "Shared with clients after you accept", onOpen: () => ui.sheet({ eyebrow: "SHARED AFTER ACCEPTING", title: "Rider", body: () => <Lines rows={[["Decks", "2 × Pioneer CDJ-3000"], ["Mixer", "Pioneer DJM-A9"], ["Monitor", "1 booth monitor, own control"], ["Hospitality", "Water, 2 guest-list spots"], ["Load-in", "60 min before set"]]} /> }) },
              { icon: "settings", title: "Account settings", desc: "Follow system appearance, notifications, payouts", onOpen: () => ui.sheet({ eyebrow: "ACCOUNT", title: "Settings", body: () => <SettingsBody appearance={appearance} onAppearance={onAppearance} onSignOut={onSwitch} /> }) },
              { icon: "chat", title: "Support", desc: "Help with bookings and payouts", onOpen: () => ui.sheet({ eyebrow: "HELP", title: "Support", body: () => <SupportBody /> }) },
            ]}
          />
        </section>
        <button className="signout-button" onClick={onSwitch}>
          Sign out of demo
        </button>
      </>
    )

  const tabs: { id: string; label: string; icon: IconName }[] = [
    { id: "requests", label: "Requests", icon: "ticket" },
    { id: "calendar", label: "Calendar", icon: "calendar" },
    { id: "services", label: "Services", icon: "card" },
    { id: "earnings", label: "Earnings", icon: "earnings" },
    { id: "more", label: "More", icon: "more" },
  ]
  return (
    <div className={`app-shell theme-${theme}`}>
      <div className="topbar">
        <button className="workspace-switch" onClick={onSwitch} aria-label="Switch role">
          <span className="brand-mark">
            <img src="/bottlesup-logo.png" alt="" />
          </span>
          <span>
            <strong>BottlesUp</strong>
            <small>Amara Vale · DJ</small>
          </span>
          <Icon name="arrow" size={15} />
        </button>
        <div className="top-actions">
          <button className="icon-button gc-btn" aria-label={`Messages${unread ? `, ${unread} unread` : ""}`} onClick={() => openInbox()}>
            <Icon name="chat" size={18} />
            {unread > 0 && <i className="nav-badge">{unread}</i>}
          </button>
          <ThemeToggle theme={theme} onToggle={onTheme} />
          <button className="avatar dj-head-avatar" aria-label="Your profile" onClick={() => ui.sheet({ eyebrow: "@" + dj.profile.username.toUpperCase(), title: dj.profile.stageName, body: (close) => <Options close={close} items={[{ label: "View public profile", detail: "See it the way visitors do", icon: "person", onSelect: () => setOverlay("public") }, { label: "Edit profile", detail: "Photos, bio, genres and links", icon: "pencil", onSelect: () => setOverlay("edit") }]} /> })}>
            {dj.profile.photo ? <img src={dj.profile.photo} alt="" /> : <Icon name="person" size={18} />}
          </button>
        </div>
      </div>
      <main className="page-content">{body}</main>
      {overlay === "edit" && <DjProfileEditor onClose={() => setOverlay(null)} />}
      {overlay === "public" && (
        <DjPublicProfile
          onBack={() => setOverlay(null)}
          onMessage={() => {
            ui.toast("Visitors' messages arrive in Messages → Inquiries")
            openInbox("Inquiries")
          }}
          onRequest={() => setOverlay("book")}
        />
      )}
      {overlay === "book" && (
        <BookingRequestForm
          onBack={() => setOverlay("public")}
          onSubmit={(n) => {
            const ref = "BK-" + String(7600 + reqs.length)
            const req: Req = { id: "r" + Date.now(), ref, client: n.client, clientType: "Guest · BottlesUp app", clientNote: "Sent from your public profile", pkg: n.pkg, date: eventLabel(n.dateKey), dayKey: n.dateKey, start: n.start, end: n.end, venue: n.venue, eventType: n.eventType, guests: 0, extraHours: 0, addons: n.addons, travel: false, message: n.message, received: "Just now", status: "New" }
            setReqs((l) => [req, ...l])
            startThread({ id: "bk-" + ref, area: "Customers", guest: n.client, context: `Booking ${ref} · ${req.date}`, scope: "Bookings", card: { kind: "Booking", title: `${ref} · ${pkgs.find((p) => p.id === n.pkg)?.name ?? "Booking"}`, detail: `${n.venue} · ${n.start} – ${n.end} · New request` }, first: n.message || `Booking request for ${req.date}` })
            setOverlay(null)
            setFilter("New")
            setTab("requests")
            setOpenId(null)
          }}
        />
      )}
      {overlay === "inbox" && <Inbox acc="dj" start={inboxOpen.start} openId={inboxOpen.id} onClose={() => setOverlay(null)} contacts={["Midnight Social", "Nova Room", "Sky Room", "Jamie Fox"]} events={["Neon Garden", "EONICS: Afterglow", "Nova Room residency"]} />}
      <nav className="bottom-nav role-nav tabs-5">
        {tabs.map((t) => (
          <button key={t.id} className={tab === t.id && !openId ? "active" : ""} aria-current={tab === t.id ? "page" : undefined} onClick={() => go(t.id)}>
            <span className="nav-icon">
              <Icon name={t.icon} />
              {t.id === "requests" && counts.New > 0 && <i className="nav-badge">{counts.New}</i>}
            </span>
            <span>{t.label}</span>
          </button>
        ))}
      </nav>
    </div>
  )
}


function DjAnalytics() {
  const bars: [string, number][] = [["Wk 1", 120], ["Wk 2", 180], ["Wk 3", 150], ["Wk 4", 240]]
  const max = Math.max(...bars.map(([, v]) => v))
  return (
    <div className="srv-sheet">
      <div className="dj-chart" role="img" aria-label="Profile views per week: 120, 180, 150, 240">
        {bars.map(([k, v]) => (
          <span key={k}>
            <i style={{ height: `${(v / max) * 100}%` }} />
            <small>{k}</small>
          </span>
        ))}
      </div>
      <p className="srv-muted">Profile views rose in week 4 after your Sky Room reel.</p>
      <Lines rows={[["Profile views", "690"], ["Booking requests", "9"], ["Accepted", "5 of 9 (56%)"], ["Avg. reply time", "3 h"]]} />
    </div>
  )
}
