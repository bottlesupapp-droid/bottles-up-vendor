import { useState } from "react"
import { Icon } from "./kit"

/* Reusable pickers that replace free typing in setup screens. */

export const TIMES = Array.from({ length: 48 }, (_, i) => {
  const h = Math.floor(i / 2)
  const m = i % 2 ? "30" : "00"
  const h12 = h % 12 === 0 ? 12 : h % 12
  return `${h12}:${m} ${h < 12 ? "AM" : "PM"}`
})
const toMin = (t: string) => {
  const [hm, ap] = t.split(" ")
  const [h, m] = hm.split(":").map(Number)
  return ((h % 12) + (ap === "PM" ? 12 : 0)) * 60 + m
}
/** True when the end time is on the following day. */
export const pastMidnight = (start: string, end: string) => toMin(end) <= toMin(start)

export function TimeSelect({ value, onChange, label }: { value: string; onChange: (v: string) => void; label: string }) {
  return (
    <select className="pk-time" value={value} onChange={(e) => onChange(e.target.value)} aria-label={label}>
      {TIMES.map((t) => (
        <option key={t}>{t}</option>
      ))}
    </select>
  )
}

/* ---------- Opening hours ---------- */

export const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] as const
export type Hours = Record<(typeof DAYS)[number], { start: string; end: string }[]>

export const DEFAULT_HOURS: Hours = {
  Monday: [],
  Tuesday: [],
  Wednesday: [],
  Thursday: [{ start: "9:00 PM", end: "2:00 AM" }],
  Friday: [{ start: "10:00 PM", end: "3:00 AM" }],
  Saturday: [
    { start: "6:00 PM", end: "9:00 PM" },
    { start: "10:00 PM", end: "3:00 AM" },
  ],
  Sunday: [],
}

export function hoursSummary(h: Hours) {
  const open = DAYS.filter((d) => h[d].length)
  if (!open.length) return "Closed all week"
  return open.map((d) => `${d.slice(0, 3)} ${h[d].map((p) => `${p.start}–${p.end}`).join(", ")}`).join(" · ")
}

export function HoursEditor({ value, onChange }: { value: Hours; onChange: (h: Hours) => void }) {
  const set = (d: (typeof DAYS)[number], periods: { start: string; end: string }[]) => onChange({ ...value, [d]: periods })
  return (
    <div className="pk-hours">
      {DAYS.map((d) => {
        const periods = value[d]
        const open = periods.length > 0
        return (
          <div key={d} className="pk-day">
            <div className="pk-day-head">
              <b>{d}</b>
              <label className="dj-avail">
                <span>{open ? "Open" : "Closed"}</span>
                <input type="checkbox" role="switch" aria-label={`${d} open`} checked={open} onChange={() => set(d, open ? [] : [{ start: "10:00 PM", end: "3:00 AM" }])} />
                <i />
              </label>
            </div>
            {periods.map((p, i) => (
              <div key={i} className="pk-period">
                <TimeSelect label={`${d} opens`} value={p.start} onChange={(v) => set(d, periods.map((x, j) => (j === i ? { ...x, start: v } : x)))} />
                <span>to</span>
                <TimeSelect label={`${d} closes`} value={p.end} onChange={(v) => set(d, periods.map((x, j) => (j === i ? { ...x, end: v } : x)))} />
                {pastMidnight(p.start, p.end) && <em className="pk-next">next day</em>}
                {periods.length > 1 && (
                  <button className="pk-x" aria-label="Remove period" onClick={() => set(d, periods.filter((_, j) => j !== i))}>
                    <Icon name="close" size={14} />
                  </button>
                )}
              </div>
            ))}
            {open && periods.length < 3 && (
              <button className="text-action pk-add" onClick={() => set(d, [...periods, { start: "6:00 PM", end: "9:00 PM" }])}>
                + Add another period
              </button>
            )}
          </div>
        )
      })}
    </div>
  )
}

/* ---------- Choices ---------- */

/** Single choice with an optional custom value. */
export function ChoiceChips({ options, value, onChange, label, allowCustom = true }: { options: string[]; value: string; onChange: (v: string) => void; label: string; allowCustom?: boolean }) {
  const custom = !options.includes(value)
  const [editing, setEditing] = useState(custom)
  return (
    <div className="pk-choice" role="radiogroup" aria-label={label}>
      <div className="cp-chips">
        {options.map((o) => (
          <button key={o} type="button" role="radio" aria-checked={value === o} className={value === o ? "on" : ""} onClick={() => (setEditing(false), onChange(o))}>
            {o}
          </button>
        ))}
        {allowCustom && (
          <button type="button" role="radio" aria-checked={editing} className={editing ? "on" : ""} onClick={() => (setEditing(true), onChange(custom ? value : ""))}>
            Custom…
          </button>
        )}
      </div>
      {editing && <input className="pk-input" value={value} onChange={(e) => onChange(e.target.value)} placeholder={`Your ${label.toLowerCase()}`} aria-label={`Custom ${label.toLowerCase()}`} />}
    </div>
  )
}

/** Searchable multi-select with an optional custom value. */
export function MultiSelect({ options, value, onChange, label, max = 6 }: { options: string[]; value: string[]; onChange: (v: string[]) => void; label: string; max?: number }) {
  const [q, setQ] = useState("")
  const pool = Array.from(new Set([...options, ...value]))
  const shown = pool.filter((o) => o.toLowerCase().includes(q.trim().toLowerCase()))
  const toggle = (o: string) => onChange(value.includes(o) ? value.filter((x) => x !== o) : value.length >= max ? value : [...value, o])
  const canAdd = q.trim() && !pool.some((o) => o.toLowerCase() === q.trim().toLowerCase())
  return (
    <div className="pk-multi">
      {value.length > 0 && (
        <div className="pk-selected" aria-label={`Selected ${label.toLowerCase()}`}>
          {value.map((v) => (
            <button key={v} type="button" className="pk-tag" onClick={() => toggle(v)} aria-label={`Remove ${v}`}>
              {v} <Icon name="close" size={12} />
            </button>
          ))}
        </div>
      )}
      <label className="search-field pk-search">
        <Icon name="search" size={16} />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={`Search ${label.toLowerCase()}`} aria-label={`Search ${label.toLowerCase()}`} />
      </label>
      <div className="cp-chips">
        {shown.slice(0, 14).map((o) => (
          <button key={o} type="button" aria-pressed={value.includes(o)} className={value.includes(o) ? "on" : ""} onClick={() => toggle(o)}>
            {o}
          </button>
        ))}
        {canAdd && (
          <button
            type="button"
            onClick={() => {
              toggle(q.trim())
              setQ("")
            }}
          >
            + Add “{q.trim()}”
          </button>
        )}
      </div>
      <small className="srv-muted">
        {value.length}/{max} selected{value.length >= max ? " · remove one to add another" : ""}
      </small>
    </div>
  )
}

export const GENRES = ["Afro house", "Amapiano", "House", "Deep house", "Techno", "Disco", "R&B", "Hip hop", "Dancehall", "Reggaeton", "Latin", "Pop", "Open format", "Drum & bass", "Garage", "Soca", "Jazz", "Live band"]
export const DRESS = ["Smart evening wear", "Smart casual", "Casual", "All black", "Themed"]
export const AGES = ["19+", "21+", "All ages"]
export const ENTRY = ["Physical ID required", "Digital ID accepted", "No re-entry", "Bag check", "Coat check available"]
export const ACCESS = ["Step-free entry", "Accessible washroom", "Elevator", "Quiet area", "Service animals welcome"]

/* ---------- Event date and time ---------- */

const fmtDay = (d: Date) => d.toLocaleDateString("en-CA", { weekday: "short", month: "short", day: "numeric" })
export const EVENT_DATES = Array.from({ length: 60 }, (_, i) => {
  const d = new Date(2024, 7, 24 + i)
  return { key: d.toISOString().slice(0, 10), label: fmtDay(d), date: d }
})

export function EventTimes({ date, start, end, onChange }: { date: string; start: string; end: string; onChange: (p: { date?: string; start?: string; end?: string }) => void }) {
  const d = EVENT_DATES.find((x) => x.key === date) ?? EVENT_DATES[0]
  const next = new Date(d.date)
  next.setDate(next.getDate() + 1)
  const overnight = pastMidnight(start, end)
  return (
    <div className="pk-event">
      <label className="field">
        <span>Date</span>
        <select value={d.key} onChange={(e) => onChange({ date: e.target.value })}>
          {EVENT_DATES.map((x) => (
            <option key={x.key} value={x.key}>
              {x.label}
            </option>
          ))}
        </select>
      </label>
      <div className="form-row">
        <label className="field">
          <span>Starts</span>
          <TimeSelect label="Start time" value={start} onChange={(v) => onChange({ start: v })} />
        </label>
        <label className="field">
          <span>Ends</span>
          <TimeSelect label="End time" value={end} onChange={(v) => onChange({ end: v })} />
        </label>
      </div>
      <p className="pk-summary">
        <Icon name="clock" size={14} /> {d.label}, {start} → {overnight ? fmtDay(next) + ", " : ""}
        {end}
        {overnight && <em> · ends the next day</em>}
      </p>
    </div>
  )
}

export const eventLabel = (date: string) => (EVENT_DATES.find((x) => x.key === date) ?? EVENT_DATES[0]).label
