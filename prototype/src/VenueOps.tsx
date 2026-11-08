import { createContext, useContext, useState, type ReactNode } from "react"
import { useGuests } from "./Guests"
import { usePersisted, Icon, Lines, useUI } from "./kit"
import { EventBuilder, StatusChip, type Ev } from "./OrgTools"
import { occurrences, type Repeat } from "./EventParts"
import { EVENT_DATES, eventLabel } from "./Pickers"
import { MenuEditor, PageEditor, TablesEditor } from "./VenueEdit"
import { ArrivedDetail, ExpectedDetail, SalesDetail } from "./OwnerStats"

/* Venue operations shared by owners and assigned managers: venue events (one-time and
   recurring, with separate tickets, guest list, tables, staff and report per date),
   VIP clients, venue page/tables/menu editing and reports. Demo data. */

export const VENUE = "Nova Room"
export type Who = "owner" | "manager"

/* ---------------- Venue events ---------------- */

type Override = { cancelled?: boolean; start?: string; name?: string }
type VEvent = Ev & { overrides?: Record<string, Override> }
const weekly = (days: string[]): Repeat => ({ mode: days.length > 1 ? "custom" : "weekly", days, every: 1, until: "" })
const SEED: VEvent[] = [
  { id: "vf", name: "Nova Fridays", date: eventLabel(EVENT_DATES[6].key), long: "", venue: VENUE, status: "Published", sold: 0, capacity: 320, gross: "$0", art: 1, venueStatus: "Your venue", series: "s-fri", repeat: weekly(["Fri"]), dateKey: EVENT_DATES[6].key, start: "10:00 PM", end: "3:00 AM", logo: "org", overrides: { "2024-10-11": { cancelled: true } } },
  { id: "vs", name: "Nova Saturdays", date: eventLabel(EVENT_DATES[7].key), long: "", venue: VENUE, status: "Published", sold: 0, capacity: 320, gross: "$0", art: 0, venueStatus: "Your venue", series: "s-sat", repeat: weekly(["Sat"]), dateKey: EVENT_DATES[14].key, start: "10:00 PM", end: "3:00 AM", logo: "org" },
  { id: "vn", name: "Neon Garden", date: eventLabel(EVENT_DATES[7].key), long: "", venue: VENUE, status: "Published", sold: 184, capacity: 300, gross: "$6.8k", art: 0, venueStatus: "Partner event · Midnight Social", repeat: { mode: "once", days: [], every: 1, until: "" }, dateKey: EVENT_DATES[7].key, start: "9:00 PM", end: "2:00 AM" },
  { id: "vss", name: "Summer Signal", date: eventLabel("2024-10-11"), long: "", venue: VENUE, status: "Published", sold: 12, capacity: 300, gross: "$420", art: 3, venueStatus: "Partner event · Midnight Social", repeat: { mode: "once", days: [], every: 1, until: "" }, dateKey: "2024-10-11", start: "9:00 PM", end: "2:00 AM" },
  { id: "va", name: "EONICS: Afterglow", date: eventLabel(EVENT_DATES[0].key), long: "", venue: VENUE, status: "Published", sold: 214, capacity: 300, gross: "$7.5k", art: 2, venueStatus: "Partner event · EONICS Music", repeat: { mode: "once", days: [], every: 1, until: "" }, dateKey: EVENT_DATES[0].key, start: "10:00 PM", end: "3:00 AM" },
]

type EvApi = { list: VEvent[]; setList: (fn: (l: VEvent[]) => VEvent[]) => void }
const EvCtx = createContext<EvApi | null>(null)
const useVenueEvents = () => {
  const c = useContext(EvCtx)
  if (!c) throw new Error("useVenueEvents outside VenueOpsProvider")
  return c
}

/** Stats for one date. Each occurrence has its own tickets, guest list, tables, staff and report. */
function occStats(ev: VEvent, key: string) {
  const n = EVENT_DATES.findIndex((d) => d.key === key)
  const soon = Math.max(0, 1 - n / 30)
  return {
    sold: ev.repeat?.mode === "once" ? ev.sold : Math.round(ev.capacity * 0.6 * soon),
    guestList: Math.round(40 * soon) + 4,
    tables: `${Math.round(14 * soon)} of 18`,
    staff: n < 8 ? "12 of 14 scheduled" : "Not scheduled yet",
  }
}

export function VenueEvents({ who, onClose, startCreate }: { who: Who; onClose: () => void; startCreate?: boolean }) {
  const ve = useVenueEvents()
  const ui = useUI()
  const [view, setView] = useState<{ s: "list" } | { s: "event"; id: string } | { s: "date"; id: string; key: string } | { s: "build"; id: string | null; scope?: "one" | "future"; key?: string; copy?: boolean }>(startCreate ? { s: "build", id: null } : { s: "list" })
  const save = (e: Ev, scope?: "one" | "future", key?: string) =>
    ve.setList((l) => {
      if (scope === "one" && key) return l.map((x) => (x.id === e.id ? { ...x, overrides: { ...x.overrides, [key]: { start: e.start, name: e.name !== x.name ? e.name : undefined } } } : x))
      if (scope === "future" && key) {
        const old = l.find((x) => x.id === e.id)!
        const until = EVENT_DATES[EVENT_DATES.findIndex((d) => d.key === key) - 1]?.key ?? key
        return [...l.map((x) => (x.id === e.id ? { ...x, repeat: { ...old.repeat!, until } } : x)), { ...e, id: "ve" + Date.now(), dateKey: key, series: "s" + Date.now() }]
      }
      return l.some((x) => x.id === e.id) ? l.map((x) => (x.id === e.id ? { ...x, ...e } : x)) : [...l, e]
    })

  if (view.s === "build") {
    const base = view.id ? ve.list.find((x) => x.id === view.id) ?? null : null
    const event = base ? (view.copy ? { ...base, id: "ve" + Date.now(), name: `${base.name} (copy)`, status: "Draft", sold: 0, series: undefined } : view.key ? { ...base, dateKey: view.key } : base) : null
    return (
      <div className="gc" role="dialog" aria-modal="true" aria-label="Create event">
        <div className="gc-body vo-builder">
          {view.scope && <p className="srv-notice">{view.scope === "one" ? `Editing only ${eventLabel(view.key!)}. Other dates stay the same.` : `Editing ${eventLabel(view.key!)} and every date after it.`}</p>}
          <EventBuilder
            key={(event?.id ?? "new") + (view.scope ?? "")}
            event={event}
            venueLocked={VENUE}
            orgName={VENUE}
            onBack={() => setView(view.id && !view.copy ? { s: "event", id: view.id } : { s: "list" })}
            onSave={(e) => {
              save(view.copy ? { ...e, id: event!.id } : e, view.scope, view.key)
              if (view.scope) ui.toast(view.scope === "one" ? "Saved for this date only" : "Saved for this and future dates")
              if (view.id && !view.copy) window.setTimeout(() => setView({ s: "event", id: view.id! }), 0)
            }}
          />
        </div>
      </div>
    )
  }

  if (view.s === "date") {
    const ev = ve.list.find((x) => x.id === view.id)!
    const o = ev.overrides?.[view.key] ?? {}
    const st = occStats(ev, view.key)
    const recurring = ev.repeat?.mode !== "once"
    return (
      <div className="gc" role="dialog" aria-modal="true" aria-label="Event date">
        <div className="gc-top">
          <button className="icon-button" aria-label="Back" onClick={() => setView({ s: "event", id: ev.id })}>
            <Icon name="back" size={18} />
          </button>
          <div>
            <span>{VENUE.toUpperCase()} · {eventLabel(view.key).toUpperCase()}</span>
            <h1>{o.name ?? ev.name}</h1>
          </div>
        </div>
        <div className="gc-body">
          {o.cancelled && <p className="srv-notice">This date is cancelled. Ticket holders were refunded.</p>}
          <p className="srv-muted os-note">
            {o.start ?? ev.start} – {ev.end} · each date has its own tickets, guest list, tables, staff and report.
          </p>
          <Lines
            rows={[
              ["Tickets", `${st.sold} of ${ev.capacity} sold`],
              ["Guest list", `${st.guestList} names`],
              ["Tables", `${st.tables} booked`],
              ["Staff", st.staff],
              ["Report", st.sold ? "Available after the night" : "No sales yet"],
            ]}
          />
          <div className="vo-actions">
            {recurring ? (
              <>
                <button className="secondary-action" onClick={() => setView({ s: "build", id: ev.id, scope: "one", key: view.key })}>
                  <Icon name="pencil" size={15} /> Edit this date
                </button>
                <button className="secondary-action" onClick={() => setView({ s: "build", id: ev.id, scope: "future", key: view.key })}>
                  Edit this and future dates
                </button>
              </>
            ) : (
              <button className="secondary-action" onClick={() => setView({ s: "build", id: ev.id })}>
                <Icon name="pencil" size={15} /> Edit event
              </button>
            )}
            <button className="secondary-action" onClick={() => ui.toast("Opening the guest list for this date")}>
              Guest list
            </button>
            <button className="secondary-action" onClick={() => ui.toast("Staffing for this date is in Team")}>
              Staff
            </button>
            {!o.cancelled && (
              <button
                className="text-action danger"
                onClick={() =>
                  ui.sheet({
                    eyebrow: eventLabel(view.key).toUpperCase(),
                    title: recurring ? "Cancel this date?" : "Cancel this event?",
                    body: (close) => (
                      <div className="srv-sheet">
                        <p className="srv-muted">{st.sold ? `${st.sold} ticket holders will be refunded and notified.` : "No tickets sold yet."} {recurring ? "Other dates in the series aren't affected." : ""}</p>
                        <button
                          className="danger-action"
                          onClick={() => {
                            ve.setList((l) => l.map((x) => (x.id === ev.id ? { ...x, overrides: { ...x.overrides, [view.key]: { ...o, cancelled: true } } } : x)))
                            ui.toast("Date cancelled")
                            close()
                          }}
                        >
                          Cancel {recurring ? "this date" : "event"}
                        </button>
                      </div>
                    ),
                  })
                }
              >
                Cancel {recurring ? "this date" : "event"}
              </button>
            )}
          </div>
        </div>
      </div>
    )
  }

  if (view.s === "event") {
    const ev = ve.list.find((x) => x.id === view.id)!
    const dates = occurrences(ev.dateKey ?? EVENT_DATES[0].key, ev.repeat ?? { mode: "once", days: [], every: 1, until: "" })
    return (
      <div className="gc" role="dialog" aria-modal="true" aria-label={ev.name}>
        <div className="gc-top">
          <button className="icon-button" aria-label="Back" onClick={() => setView({ s: "list" })}>
            <Icon name="back" size={18} />
          </button>
          <div>
            <span>{ev.repeat?.mode === "once" ? "ONE-TIME EVENT" : "RECURRING SERIES"}</span>
            <h1>{ev.name}</h1>
          </div>
        </div>
        <div className="gc-body">
          <div className="pub-status">
            <div>
              <small>Event</small>
              <StatusChip s={ev.status} />
            </div>
            <div>
              <small>Venue</small>
              <span className="srv-chip tone-green">{ev.venueStatus}</span>
            </div>
          </div>
          <p className="srv-muted os-note">
            {ev.start} – {ev.end} · {ev.repeat?.mode === "once" ? eventLabel(ev.dateKey!) : `${ev.repeat?.mode === "weekly" ? "Every week" : `Every ${ev.repeat?.days.join(", ")}`}${ev.repeat?.until ? ` until ${eventLabel(ev.repeat.until)}` : ", no end date"}`}
          </p>
          <div className="vo-actions">
            {!ev.venueStatus?.startsWith("Partner") && (
              <button className="secondary-action" onClick={() => setView({ s: "build", id: ev.id })}>
                <Icon name="pencil" size={15} /> Edit {ev.repeat?.mode === "once" ? "event" : "series"}
              </button>
            )}
            <button className="secondary-action" onClick={() => setView({ s: "build", id: ev.id, copy: true })}>
              Duplicate
            </button>
          </div>
          {ev.venueStatus?.startsWith("Partner") && <p className="srv-muted">Run by the organizer. You manage tables, staff and the door for it.</p>}
          <section className="srv-section">
            <h2>
              Dates <span>{dates.length}</span>
            </h2>
            <div className="srv-list">
              {dates.map((d) => {
                const o = ev.overrides?.[d.key]
                const st = occStats(ev, d.key)
                return (
                  <button key={d.key} className="srv-table" onClick={() => setView({ s: "date", id: ev.id, key: d.key })}>
                    <span className="vo-date">
                      <b>{d.date.getDate()}</b>
                      <small>{d.label.split(",")[0]}</small>
                    </span>
                    <span className="srv-main">
                      <strong>{o?.name ?? ev.name}</strong>
                      <small>
                        {d.label} · {o?.start ?? ev.start}
                      </small>
                      <small>
                        {st.sold} tickets · {st.tables} tables
                      </small>
                    </span>
                    {o?.cancelled ? <span className="srv-chip tone-red">Cancelled</span> : o?.start || o?.name ? <span className="srv-chip tone-blue">Edited</span> : <Icon name="chevron" size={16} />}
                  </button>
                )
              })}
            </div>
          </section>
        </div>
      </div>
    )
  }

  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Venue events">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close events" onClick={onClose}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>{VENUE.toUpperCase()} · {who === "owner" ? "OWNER" : "MANAGER"}</span>
          <h1>Events</h1>
        </div>
      </div>
      <div className="gc-body">
        <button className="primary-action full-action vo-create" onClick={() => setView({ s: "build", id: null })}>
          <Icon name="plus" size={16} /> Create event
        </button>
        <p className="srv-muted os-note">Your own nights at {VENUE}, including weekly programming, plus partner events from organizers.</p>
        <div className="srv-list">
          {ve.list.map((e) => {
            const dates = occurrences(e.dateKey ?? EVENT_DATES[0].key, e.repeat ?? { mode: "once", days: [], every: 1, until: "" }, 3)
            return (
              <button key={e.id} className="srv-table" onClick={() => setView({ s: "event", id: e.id })}>
                <span className={`ot-thumb art-${e.art}`} />
                <span className="srv-main">
                  <strong>{e.name}</strong>
                  <small>{e.repeat?.mode === "once" ? `${eventLabel(e.dateKey!)} · ${e.start}` : `${e.repeat?.mode === "weekly" ? "Weekly" : e.repeat?.days.join(", ")} · next ${dates[0]?.label ?? "—"}`}</small>
                  <span className="srv-tags">
                    <StatusChip s={e.status} />
                    {e.repeat?.mode !== "once" && <span className="srv-chip tone-blue">Repeats</span>}
                    {e.venueStatus?.startsWith("Partner") && <span className="srv-chip tone-gray">Partner</span>}
                  </span>
                </span>
                <Icon name="chevron" size={16} />
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}

/* ---------------- VIP clients ---------------- */

export type Perk = { id: string; kind: string; detail: string; limit: number; used: number; expires: string }
export type Vip = { id: string; name: string; email: string; phone: string; username?: string; linked: boolean; host: string; tier: string; prefs: string; notes: string; since: string; visits: { date: string; what: string; spend: number }[]; perks: Perk[] }

const SEED_VIPS: Vip[] = [
  { id: "v1", name: "Jordan Ellis", email: "jordan.ellis@example.com", phone: "(416) 555-0182", username: "jordanafterdark", linked: true, host: "Jordan Blake", tier: "Gold", prefs: "Halo Booth · Don Julio 1942 · Afro house", notes: "Celebrating 30th tonight. Likes the sign at midnight.", since: "Mar 2023", visits: [{ date: "Sat, Aug 24", what: "Halo Booth · 6 guests", spend: 1169 }, { date: "Sat, Jul 20", what: "Arc Table · 8 guests", spend: 1840 }, { date: "Fri, Jun 14", what: "Halo Booth · 6 guests", spend: 1210 }], perks: [{ id: "p1", kind: "Priority entry", detail: "Skip the line with up to 6 guests", limit: 12, used: 7, expires: "2024-12-31" }, { id: "p2", kind: "Birthday benefit", detail: "Complimentary champagne on birthday visit", limit: 1, used: 0, expires: "2024-08-31" }, { id: "p3", kind: "Guest passes", detail: "Free guest-list spots", limit: 4, used: 4, expires: "2024-08-01" }] },
  { id: "v2", name: "Marcus Hill", email: "marcus@example.com", phone: "(647) 555-0144", linked: false, host: "Riley Chen", tier: "Silver", prefs: "VIP Booth · Dom Pérignon", notes: "Prefers to be greeted at the VIP entrance.", since: "Jan 2024", visits: [{ date: "Sat, Aug 24", what: "VIP Booth · 8 guests", spend: 0 }], perks: [{ id: "p4", kind: "Preferred table", detail: "VIP Booth held until 11 PM", limit: 6, used: 2, expires: "2024-11-30" }] },
  { id: "v3", name: "Priya Shah", email: "priya.shah@example.com", phone: "(416) 555-0199", username: "priyashah", linked: true, host: "Unassigned", tier: "Member", prefs: "Arc Table · birthday cakes", notes: "", since: "Aug 2024", visits: [], perks: [] },
]
const ACCOUNTS: Record<string, { name: string; username: string }> = { jordanafterdark: { name: "Jordan Ellis", username: "jordanafterdark" }, "maya.chen": { name: "Maya Chen", username: "maya.chen" }, "maya@example.com": { name: "Maya Chen", username: "maya.chen" }, "(416) 555-0101": { name: "Noah Reid", username: "noahreid" } }
const PERKS = ["Priority entry", "Preferred table", "Guest passes", "Birthday benefit", "Special offer", "Complimentary item"]
const HOSTS = ["Unassigned", "Jordan Blake", "Riley Chen", "Sam Patel"]

type VipApi = { vips: Vip[]; setVips: (fn: (l: Vip[]) => Vip[]) => void }
const VipCtx = createContext<VipApi | null>(null)
const useVips = () => {
  const c = useContext(VipCtx)
  if (!c) throw new Error("useVips outside VenueOpsProvider")
  return c
}

const perkState = (p: Perk) => (p.expires < EVENT_DATES[0].key ? "Expired" : p.used >= p.limit ? "Redeemed" : "Available")

function AddVip({ close, onAdd }: { close: () => void; onAdd: (v: Vip) => void }) {
  const [q, setQ] = useState("")
  const [name, setName] = useState("")
  const [checked, setChecked] = useState(false)
  const key = q.trim().toLowerCase().replace(/^@/, "")
  const match = checked ? ACCOUNTS[key] ?? ACCOUNTS[q.trim()] : undefined
  const isEmail = /\S+@\S+\.\S+/.test(q)
  const isPhone = /[\d()\- ]{7,}/.test(q) && !isEmail
  const valid = q.trim().length >= 3
  const make = (linked: boolean): Vip => ({ id: "v" + Date.now(), name: linked && match ? match.name : name.trim() || q.trim(), email: isEmail ? q.trim() : "", phone: isPhone ? q.trim() : "", username: linked && match ? match.username : !isEmail && !isPhone ? key : undefined, linked, host: "Unassigned", tier: "Member", prefs: "", notes: "", since: "Aug 2024", visits: [], perks: [] })
  return (
    <div className="form-stack ve-form">
      <label className="field">
        <span>Email, phone or BottlesUp username</span>
        <input value={q} onChange={(e) => (setQ(e.target.value), setChecked(false))} placeholder="e.g. maya.chen or maya@example.com" />
      </label>
      <button className="secondary-action full-action" disabled={!valid} onClick={() => setChecked(true)}>
        Look up
      </button>
      {checked &&
        (match ? (
          <div className="vip-match">
            <span className="srv-avatar">{match.name.split(" ").map((x) => x[0]).join("")}</span>
            <span className="srv-main">
              <strong>{match.name}</strong>
              <small>@{match.username} · BottlesUp account found</small>
            </span>
            <button className="primary-action" onClick={() => (onAdd(make(true)), close())}>
              Link account
            </button>
          </div>
        ) : (
          <>
            <p className="srv-muted">No BottlesUp account found. You can still save them as a contact.</p>
            <label className="field">
              <span>Name</span>
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name" />
            </label>
            <button className="primary-action full-action" disabled={!name.trim()} onClick={() => (onAdd(make(false)), close())}>
              Save contact
            </button>
          </>
        ))}
      <small className="srv-muted">Account lookup is simulated in the demo. Try maya.chen or jordanafterdark.</small>
    </div>
  )
}

function PerkForm({ close, onSave }: { close: () => void; onSave: (p: Perk) => void }) {
  const [p, setP] = useState<Perk>({ id: "p" + Date.now(), kind: PERKS[0], detail: "", limit: 1, used: 0, expires: EVENT_DATES[45].key })
  return (
    <div className="form-stack ve-form">
      <div className="field">
        <span>Perk</span>
        <div className="cp-chips">
          {PERKS.map((k) => (
            <button key={k} aria-pressed={p.kind === k} className={p.kind === k ? "on" : ""} onClick={() => setP({ ...p, kind: k })}>
              {k}
            </button>
          ))}
        </div>
      </div>
      <label className="field">
        <span>Details</span>
        <input value={p.detail} onChange={(e) => setP({ ...p, detail: e.target.value })} placeholder="e.g. Bottle of Moët on arrival" />
      </label>
      <div className="form-row">
        <label className="field">
          <span>Uses allowed</span>
          <input type="number" min={1} value={p.limit} onChange={(e) => setP({ ...p, limit: Math.max(1, parseInt(e.target.value) || 1) })} />
        </label>
        <label className="field">
          <span>Expires</span>
          <select value={p.expires} onChange={(e) => setP({ ...p, expires: e.target.value })}>
            {EVENT_DATES.map((d) => (
              <option key={d.key} value={d.key}>
                {d.label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <button className="primary-action full-action" onClick={() => (onSave({ ...p, detail: p.detail.trim() || p.kind }), close())}>
        Add perk
      </button>
    </div>
  )
}

export function VipClients({ who, onClose }: { who: Who; onClose: () => void }) {
  const { vips, setVips } = useVips()
  const ui = useUI()
  const g = useGuests()
  const [q, setQ] = useState("")
  const [open, setOpen] = useState<string | null>(null)
  const term = q.trim().toLowerCase()
  const shown = vips.filter((v) => !term || `${v.name} ${v.email} ${v.phone} ${v.username ?? ""}`.toLowerCase().includes(term))
  const v = vips.find((x) => x.id === open)
  const patch = (p: Partial<Vip>) => setVips((l) => l.map((x) => (x.id === open ? { ...x, ...p } : x)))
  if (v)
    return (
      <div className="gc" role="dialog" aria-modal="true" aria-label={v.name}>
        <div className="gc-top">
          <button className="icon-button" aria-label="Back to VIP clients" onClick={() => setOpen(null)}>
            <Icon name="back" size={18} />
          </button>
          <div>
            <span>VIP CLIENT · {v.tier.toUpperCase()}</span>
            <h1>{v.name}</h1>
          </div>
        </div>
        <div className="gc-body">
          <div className="vip-head">
            <span className="srv-avatar">{v.name.split(" ").map((x) => x[0]).join("")}</span>
            <span className="srv-main">
              <strong>{v.linked ? `@${v.username} · BottlesUp account` : "Contact only · no BottlesUp account"}</strong>
              <small>VIP since {v.since}</small>
            </span>
          </div>
          <div className="vo-actions">
            {v.linked && (
              <button
                className="primary-action"
                onClick={() => {
                  const id = "t-vip-" + v.id
                  g.setThreads((l) => (l.some((t) => t.id === id) ? l : [{ id, area: "Customers", guest: v.name, context: "VIP client", scope: VENUE, unread: 0, msgs: [] }, ...l]))
                  onClose()
                  g.openTo("Customers", id)
                }}
              >
                <Icon name="chat" size={15} /> Message
              </button>
            )}
            {v.phone && (
              <button className="secondary-action" onClick={() => ui.toast(`Opening your phone to text ${v.phone}`)}>
                Text
              </button>
            )}
            {v.email && (
              <button className="secondary-action" onClick={() => ui.toast(`Opening email to ${v.email}`)}>
                Email
              </button>
            )}
          </div>
          <section className="srv-section">
            <h2>
              Contact <span className="vip-private"><Icon name="lock" size={11} /> Staff only</span>
            </h2>
            <Lines rows={[["Email", v.email || "Not saved"], ["Phone", v.phone || "Not saved"]]} />
          </section>
          <section className="srv-section">
            <h2>Host and preferences</h2>
            <label className="field">
              <span>Assigned host</span>
              <select value={v.host} onChange={(e) => (patch({ host: e.target.value }), ui.toast(`Host: ${e.target.value}`))}>
                {HOSTS.map((h) => (
                  <option key={h}>{h}</option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Preferences</span>
              <input value={v.prefs} onChange={(e) => patch({ prefs: e.target.value })} placeholder="Tables, bottles, music" />
            </label>
            <label className="field">
              <span>
                Internal notes <span className="vip-private"><Icon name="lock" size={11} /> Never shown to the client</span>
              </span>
              <textarea value={v.notes} onChange={(e) => patch({ notes: e.target.value })} />
            </label>
          </section>
          <section className="srv-section">
            <div className="ds-sec-head">
              <h2>Perks</h2>
              <button className="text-action" onClick={() => ui.sheet({ eyebrow: v.name.toUpperCase(), title: "Add a perk", body: (close) => <PerkForm close={close} onSave={(p) => (patch({ perks: [...v.perks, p] }), ui.toast(`${p.kind} added`))} /> })}>
                + Add perk
              </button>
            </div>
            {v.perks.length === 0 ? (
              <p className="srv-muted pad">No perks yet.</p>
            ) : (
              <div className="srv-list">
                {v.perks.map((p) => {
                  const st = perkState(p)
                  return (
                    <div key={p.id} className="srv-req static">
                      <span className="srv-main">
                        <strong>{p.kind}</strong>
                        <small>{p.detail}</small>
                        <small>
                          {p.used}/{p.limit} used · expires {eventLabel(p.expires)}
                        </small>
                      </span>
                      <span className="vip-perk-side">
                        <span className={`srv-chip tone-${st === "Available" ? "green" : st === "Redeemed" ? "blue" : "gray"}`}>{st}</span>
                        {st === "Available" && (
                          <button className="text-action" onClick={() => { const before = v.perks; patch({ perks: v.perks.map((x) => (x.id === p.id ? { ...x, used: x.used + 1 } : x)) }); ui.toast(`${p.kind} redeemed`, () => patch({ perks: before })) }}>
                            Redeem
                          </button>
                        )}
                      </span>
                    </div>
                  )
                })}
              </div>
            )}
          </section>
          <section className="srv-section">
            <h2>Booking history</h2>
            {v.visits.length === 0 ? (
              <p className="srv-muted pad">No bookings yet.</p>
            ) : (
              <Lines rows={v.visits.map((x) => [x.date, `${x.what}${x.spend ? ` · $${x.spend.toLocaleString()}` : ""}`] as [string, string])} />
            )}
          </section>
          <p className="srv-muted os-note">Visible to {who === "owner" ? "you and managers you assign" : "owners and assigned managers"} only. Demo data.</p>
        </div>
      </div>
    )
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="VIP clients">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close VIP clients" onClick={onClose}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>{VENUE.toUpperCase()} · PRIVATE</span>
          <h1>VIP clients</h1>
        </div>
        <button className="icon-button ib-new" aria-label="Add VIP client" onClick={() => ui.sheet({ eyebrow: "NEW VIP CLIENT", title: "Add a VIP", body: (close) => <AddVip close={close} onAdd={(n) => (setVips((l) => [n, ...l]), ui.toast(n.linked ? `${n.name} linked to their BottlesUp account` : `${n.name} saved as a contact`))} /> })}>
          <Icon name="plus" size={18} />
        </button>
      </div>
      <div className="gc-body">
        <label className="search-field msg-search">
          <Icon name="search" size={16} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, email or phone" aria-label="Search VIP clients" />
        </label>
        {shown.length === 0 ? (
          <div className="state-block">
            <Icon name="star" size={26} />
            <h2>{term ? "No matches" : "No VIP clients yet"}</h2>
            <p>{term ? "Try a different name, email or phone." : "Add your best guests to track perks and preferences."}</p>
          </div>
        ) : (
          <div className="srv-list">
            {shown.map((x) => {
              const avail = x.perks.filter((p) => perkState(p) === "Available").length
              return (
                <button key={x.id} className="srv-table" onClick={() => setOpen(x.id)}>
                  <span className="srv-avatar">{x.name.split(" ").map((p) => p[0]).join("")}</span>
                  <span className="srv-main">
                    <strong>{x.name}</strong>
                    <small>
                      {x.tier} · host {x.host} · {x.visits.length} visit{x.visits.length === 1 ? "" : "s"}
                    </small>
                    <span className="srv-tags">
                      {x.linked ? <span className="srv-chip tone-green">BottlesUp</span> : <span className="srv-chip tone-gray">Contact</span>}
                      {avail > 0 && <span className="srv-chip tone-orange">{avail} perk{avail === 1 ? "" : "s"}</span>}
                    </span>
                  </span>
                  <Icon name="chevron" size={16} />
                </button>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

/* ---------------- Venue tools & reports for managers ---------------- */

export function VenueTools({ onClose, start = "Page" }: { onClose: () => void; start?: string }) {
  const [tab, setTab] = useState(start)
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Venue setup">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close" onClick={onClose}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>{VENUE.toUpperCase()}</span>
          <h1>Venue setup</h1>
        </div>
      </div>
      <div className="srv-filters gc-tabs" role="tablist">
        {["Page", "Tables", "Menu & signs"].map((t) => (
          <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>
            {t}
          </button>
        ))}
      </div>
      <div className="gc-body">{tab === "Page" ? <PageEditor /> : tab === "Tables" ? <TablesEditor /> : <MenuEditor />}</div>
    </div>
  )
}

export function VenueReports({ onClose }: { onClose: () => void }) {
  const [tab, setTab] = useState<"Sales" | "Expected" | "Arrived">("Sales")
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Venue reports">
      <div className="gc-body vo-reports">
        {tab === "Sales" ? <SalesDetail backLabel="Done" onBack={onClose} openPayouts={() => setTab("Sales")} /> : tab === "Expected" ? <ExpectedDetail backLabel="Done" onBack={onClose} /> : <ArrivedDetail backLabel="Done" onBack={onClose} />}
        <div className="srv-filters vo-report-tabs" role="tablist">
          {(["Sales", "Expected", "Arrived"] as const).map((t) => (
            <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>
              {t}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}

/* ---------------- Provider and launcher ---------------- */

type Panel = null | { kind: "events"; create?: boolean } | { kind: "vip" } | { kind: "tools"; start?: string } | { kind: "reports" }
type OpsApi = { panel: Panel; openPanel: (p: Panel) => void }
const OpsCtx = createContext<OpsApi | null>(null)
export const useVenueOps = () => {
  const c = useContext(OpsCtx)
  if (!c) throw new Error("useVenueOps outside VenueOpsProvider")
  return c
}

export function VenueOpsProvider({ children }: { children: ReactNode }) {
  const [list, setList] = usePersisted<VEvent[]>("bu-biz-ops-list", SEED)
  const [vips, setVips] = usePersisted<Vip[]>("bu-biz-ops-vips", SEED_VIPS)
  const [panel, openPanel] = useState<Panel>(null)
  return (
    <EvCtx.Provider value={{ list, setList: (fn) => setList(fn) }}>
      <VipCtx.Provider value={{ vips, setVips: (fn) => setVips(fn) }}>
        <OpsCtx.Provider value={{ panel, openPanel }}>{children}</OpsCtx.Provider>
      </VipCtx.Provider>
    </EvCtx.Provider>
  )
}

/** Renders whichever venue panel is open, over the current screen. */
export function VenuePanels({ who }: { who: Who }) {
  const { panel, openPanel } = useVenueOps()
  if (!panel) return null
  const close = () => openPanel(null)
  if (panel.kind === "events") return <VenueEvents who={who} onClose={close} startCreate={panel.create} />
  if (panel.kind === "vip") return <VipClients who={who} onClose={close} />
  if (panel.kind === "tools") return <VenueTools onClose={close} start={panel.start} />
  return <VenueReports onClose={close} />
}
