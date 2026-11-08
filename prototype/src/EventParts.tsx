import { useState } from "react"
import { Icon, useUI } from "./kit"
import { EVENT_DATES, TimeSelect, eventLabel } from "./Pickers"

/* Building blocks for the event builder: Tickets & entry and repeating events. */

export type Tier = { id: string; name: string; kind: "Paid" | "Free RSVP"; price: number; qty: number; saleFrom: string; saleTo: string; condition: string; increase?: { on: string; price: number } }
export type Entry = { tiers: Tier[]; guestList: { on: boolean; cap: number; cutoff: string }; tables: boolean; deposit: number; minSpend: number; bottles: boolean }

export const DEFAULT_TIERS: Tier[] = [
  { id: "eb", name: "Early Bird", kind: "Paid", price: 25, qty: 100, saleFrom: EVENT_DATES[0].key, saleTo: EVENT_DATES[6].key, condition: "Entry before 11 PM", increase: undefined },
  { id: "ga", name: "General Admission", kind: "Paid", price: 35, qty: 250, saleFrom: EVENT_DATES[0].key, saleTo: EVENT_DATES[7].key, condition: "Entry before 11:30 PM", increase: { on: EVENT_DATES[5].key, price: 40 } },
  { id: "vip", name: "VIP", kind: "Paid", price: 80, qty: 40, saleFrom: EVENT_DATES[0].key, saleTo: EVENT_DATES[7].key, condition: "Priority entry, any time" },
]

function TierForm({ initial, close, onSave, onDelete, eventDate }: { initial?: Tier; close: () => void; onSave: (t: Tier) => void; onDelete?: () => void; eventDate?: string }) {
  const [t, setT] = useState<Tier>(initial ?? { id: "t" + Date.now(), name: "", kind: "Paid", price: 30, qty: 100, saleFrom: EVENT_DATES[0].key, saleTo: EVENT_DATES[7].key, condition: "" })
  const [tried, setTried] = useState(false)
  const free = t.kind === "Free RSVP"
  const err = !t.name.trim() ? "Name this ticket." : !free && t.price <= 0 ? "Paid tickets need a price. Choose Free RSVP for free entry." : t.qty < 1 ? "Set how many are available." : t.saleTo < t.saleFrom ? "Sales end before they start." : eventDate && t.saleTo > eventDate ? `Sales must close by the event date (${eventLabel(eventDate)}).` : eventDate && t.increase && t.increase.on > eventDate ? "The price increase is after the event." : t.increase && t.increase.price <= t.price ? "The new price should be higher than the current price." : null
  const dateSelect = (value: string, onChange: (v: string) => void, label: string) => (
    <select value={value} onChange={(e) => onChange(e.target.value)} aria-label={label}>
      {EVENT_DATES.map((d) => (
        <option key={d.key} value={d.key}>
          {d.label}
        </option>
      ))}
    </select>
  )
  return (
    <div className="form-stack ve-form">
      <div className="cp-chips">
        {(["Paid", "Free RSVP"] as const).map((k) => (
          <button key={k} aria-pressed={t.kind === k} className={t.kind === k ? "on" : ""} onClick={() => setT({ ...t, kind: k, price: k === "Free RSVP" ? 0 : t.price || 30, increase: k === "Free RSVP" ? undefined : t.increase })}>
            {k}
          </button>
        ))}
      </div>
      <label className="field">
        <span>Name</span>
        <input value={t.name} onChange={(e) => setT({ ...t, name: e.target.value })} placeholder={free ? "e.g. Free before 11" : "e.g. General Admission"} />
      </label>
      <div className="form-row">
        {!free && (
          <label className="field">
            <span>Price ($)</span>
            <input type="number" min={0} value={t.price || ""} onChange={(e) => setT({ ...t, price: Math.max(0, parseFloat(e.target.value) || 0) })} />
          </label>
        )}
        <label className="field">
          <span>Quantity</span>
          <input type="number" min={1} value={t.qty} onChange={(e) => setT({ ...t, qty: Math.max(0, parseInt(e.target.value) || 0) })} />
        </label>
      </div>
      <div className="form-row">
        <label className="field">
          <span>Sales open</span>
          {dateSelect(t.saleFrom, (saleFrom) => setT({ ...t, saleFrom }), "Sales open")}
        </label>
        <label className="field">
          <span>Sales close</span>
          {dateSelect(t.saleTo, (saleTo) => setT({ ...t, saleTo }), "Sales close")}
        </label>
      </div>
      <label className="field">
        <span>Entry condition</span>
        <input value={t.condition} onChange={(e) => setT({ ...t, condition: e.target.value })} placeholder="e.g. Entry before 11:30 PM" />
      </label>
      {!free && (
        <label className="srv-toggle">
          <span>
            <strong>Scheduled price increase</strong>
            <small>{t.increase ? `Goes to $${t.increase.price} on ${eventLabel(t.increase.on)}` : "Raise the price automatically on a date"}</small>
          </span>
          <input type="checkbox" checked={!!t.increase} onChange={(e) => setT({ ...t, increase: e.target.checked ? { on: EVENT_DATES[5].key, price: t.price + 5 } : undefined })} />
        </label>
      )}
      {t.increase && (
        <div className="form-row">
          <label className="field">
            <span>On</span>
            {dateSelect(t.increase.on, (on) => setT({ ...t, increase: { ...t.increase!, on } }), "Increase date")}
          </label>
          <label className="field">
            <span>New price ($)</span>
            <input type="number" min={0} value={t.increase.price} onChange={(e) => setT({ ...t, increase: { ...t.increase!, price: Math.max(0, parseFloat(e.target.value) || 0) } })} />
          </label>
        </div>
      )}
      {tried && err && <p className="srv-error">{err}</p>}
      <button className="primary-action full-action" onClick={() => (setTried(true), !err && (onSave({ ...t, name: t.name.trim() }), close()))}>
        {initial ? "Save ticket" : "Add ticket"}
      </button>
      {onDelete && (
        <button className="text-action danger" onClick={() => (onDelete(), close())}>
          Delete ticket
        </button>
      )}
    </div>
  )
}

export function TicketsEntry({ value, onChange, tablesAllowed, tablesNote, eventDate }: { value: Entry; onChange: (e: Entry) => void; tablesAllowed: boolean; tablesNote: string; eventDate?: string }) {
  const ui = useUI()
  const set = (p: Partial<Entry>) => onChange({ ...value, ...p })
  const edit = (t?: Tier) =>
    ui.sheet({
      eyebrow: "TICKETS & ENTRY",
      title: t ? t.name : "New ticket",
      body: (close) => <TierForm eventDate={eventDate} initial={t} close={close} onSave={(n) => set({ tiers: t ? value.tiers.map((x) => (x.id === t.id ? n : x)) : [...value.tiers, n] })} onDelete={t ? () => set({ tiers: value.tiers.filter((x) => x.id !== t.id) }) : undefined} />,
    })
  return (
    <div className="te">
      <section className="te-sec">
        <h3>Tickets</h3>
        <p className="srv-muted">Paid tickets and free RSVPs. Guests see the name, price and entry condition.</p>
        <div className="srv-list">
          {value.tiers.map((t) => (
            <button key={t.id} className="srv-req" onClick={() => edit(t)}>
              <span className="srv-main">
                <strong>{t.name}</strong>
                <small>
                  {t.kind === "Free RSVP" ? "Free RSVP" : `$${t.price}`} · {t.qty} available{t.condition ? ` · ${t.condition}` : ""}
                </small>
                <small>
                  On sale {eventLabel(t.saleFrom)} – {eventLabel(t.saleTo)}
                  {t.increase ? ` · $${t.increase.price} from ${eventLabel(t.increase.on)}` : ""}
                </small>
              </span>
              <Icon name="chevron" size={16} />
            </button>
          ))}
        </div>
        <button className="secondary-action full-action ve-add" onClick={() => edit()}>
          <Icon name="plus" size={16} /> Add a ticket or free RSVP
        </button>
      </section>
      <section className="te-sec">
        <h3>Guest list</h3>
        <label className="srv-toggle">
          <span>
            <strong>Offer guest list entry</strong>
            <small>Free names added by you, your team or ambassadors</small>
          </span>
          <input type="checkbox" checked={value.guestList.on} onChange={(e) => set({ guestList: { ...value.guestList, on: e.target.checked } })} />
        </label>
        {value.guestList.on && (
          <div className="form-row">
            <label className="field">
              <span>Spots</span>
              <input type="number" min={1} value={value.guestList.cap} onChange={(e) => set({ guestList: { ...value.guestList, cap: Math.max(1, parseInt(e.target.value) || 1) } })} />
            </label>
            <label className="field">
              <span>Valid until</span>
              <TimeSelect label="Guest list cut-off" value={value.guestList.cutoff} onChange={(cutoff) => set({ guestList: { ...value.guestList, cutoff } })} />
            </label>
          </div>
        )}
      </section>
      <section className="te-sec">
        <h3>Table reservations</h3>
        {tablesAllowed ? (
          <>
            <label className="srv-toggle">
              <span>
                <strong>Offer tables</strong>
                <small>A deposit holds the table and counts toward the minimum spend</small>
              </span>
              <input type="checkbox" checked={value.tables} onChange={(e) => set({ tables: e.target.checked })} />
            </label>
            {value.tables && (
              <div className="form-row">
                <label className="field">
                  <span>Deposit ($)</span>
                  <input type="number" min={0} value={value.deposit} onChange={(e) => set({ deposit: Math.max(0, parseInt(e.target.value) || 0) })} />
                </label>
                <label className="field">
                  <span>Minimum spend ($)</span>
                  <input type="number" min={0} value={value.minSpend} onChange={(e) => set({ minSpend: Math.max(0, parseInt(e.target.value) || 0) })} />
                </label>
              </div>
            )}
          </>
        ) : (
          <p className="srv-notice">
            <Icon name="lock" size={15} /> {tablesNote}
          </p>
        )}
      </section>
      <section className="te-sec">
        <h3>Bottle packages</h3>
        {tablesAllowed ? (
          <label className="srv-toggle">
            <span>
              <strong>Sell bottles with tables</strong>
              <small>Guests pre-order from the venue's bottle menu. Separate from tickets.</small>
            </span>
            <input type="checkbox" checked={value.bottles} onChange={(e) => set({ bottles: e.target.checked })} />
          </label>
        ) : (
          <p className="srv-notice">
            <Icon name="lock" size={15} /> Bottle packages come from the venue's menu, so they need a BottlesUp venue.
          </p>
        )}
      </section>
    </div>
  )
}

/* ---------------- Repeating events ---------------- */

export const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
export type Repeat = { mode: "once" | "weekly" | "custom"; days: string[]; every: number; until: string }

/** Dates the event happens on, from the start date. Capped at 12 for display. */
export function occurrences(startKey: string, r: Repeat, cap = 12) {
  const start = EVENT_DATES.find((d) => d.key === startKey) ?? EVENT_DATES[0]
  if (r.mode === "once") return [start]
  const days = r.mode === "weekly" ? [WEEKDAYS[(start.date.getDay() + 6) % 7]] : r.days
  const out = EVENT_DATES.filter((d) => d.key >= start.key && (!r.until || d.key <= r.until) && days.includes(WEEKDAYS[(d.date.getDay() + 6) % 7]))
  const weeks = r.every > 1 ? out.filter((d) => Math.floor((d.date.getTime() - start.date.getTime()) / (7 * 864e5)) % r.every === 0) : out
  return weeks.slice(0, cap)
}

export function RepeatEditor({ value, onChange, startKey }: { value: Repeat; onChange: (r: Repeat) => void; startKey: string }) {
  const list = occurrences(startKey, value)
  return (
    <div className="field">
      <span>Repeats</span>
      <div className="cp-chips">
        {(
          [
            ["once", "One time"],
            ["weekly", "Weekly"],
            ["custom", "Custom days"],
          ] as const
        ).map(([k, l]) => (
          <button key={k} aria-pressed={value.mode === k} className={value.mode === k ? "on" : ""} onClick={() => onChange({ ...value, mode: k, days: k === "custom" && !value.days.length ? ["Fri", "Sat"] : value.days })}>
            {l}
          </button>
        ))}
      </div>
      {value.mode === "custom" && (
        <div className="rp-days" role="group" aria-label="Days">
          {WEEKDAYS.map((d) => (
            <button key={d} aria-pressed={value.days.includes(d)} className={value.days.includes(d) ? "on" : ""} onClick={() => onChange({ ...value, days: value.days.includes(d) ? value.days.filter((x) => x !== d) : [...value.days, d] })}>
              {d.slice(0, 2)}
            </button>
          ))}
        </div>
      )}
      {value.mode !== "once" && (
        <div className="form-row">
          <label className="field">
            <span>Every</span>
            <select value={value.every} onChange={(e) => onChange({ ...value, every: Number(e.target.value) })}>
              <option value={1}>Week</option>
              <option value={2}>2 weeks</option>
            </select>
          </label>
          <label className="field">
            <span>Ends (optional)</span>
            <select value={value.until} onChange={(e) => onChange({ ...value, until: e.target.value })}>
              <option value="">No end date</option>
              {EVENT_DATES.filter((d) => d.key > startKey).map((d) => (
                <option key={d.key} value={d.key}>
                  {d.label}
                </option>
              ))}
            </select>
          </label>
        </div>
      )}
      {value.mode !== "once" && (
        <p className="pk-summary">
          <Icon name="calendar" size={14} /> {list.length ? `${list.length}${list.length === 12 ? "+" : ""} dates: ${list.slice(0, 4).map((d) => d.label).join(", ")}${list.length > 4 ? "…" : ""}` : "Pick at least one day"}
        </p>
      )}
    </div>
  )
}
