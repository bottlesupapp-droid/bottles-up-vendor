import { useState } from "react"
import { NIGHT } from "./data"
import { useGuests } from "./Guests"
import { Icon, clock, useUI } from "./kit"
import { useStore, type DoorParty } from "./store"

/* Door staff guest list: search, compact totals, filters, entry details, check-in,
   problem passes and Contact Assigned Staff (internal only). Payment details are hidden
   from door staff. Demo data. */

type Problem = "duplicate" | "cancelled" | "refunded" | "wrong-event"
type Meta = { kind: "Ticket" | "Table" | "Guest list"; ref: string; staff?: { name: string; role: string }; problem?: Problem; note?: string; window?: string }

const META: Record<string, Meta> = {
  p1: { kind: "Table", ref: "Table 4 · TB-4471", staff: { name: "Sam Patel", role: "Server" } },
  p2: { kind: "Table", ref: "VIP Booth · TB-4502", staff: { name: "Jordan Blake", role: "Host" } },
  p3: { kind: "Table", ref: "Table 7 · TB-4519" },
  p4: { kind: "Guest list", ref: "DJ guest list", window: "Before 11:30 PM" },
  p5: { kind: "Guest list", ref: "Promoter list", window: "Before 11:30 PM" },
  p6: { kind: "Table", ref: "Table 3 · TB-4488", staff: { name: "Riley Chen", role: "Server" } },
  p7: { kind: "Table", ref: "Halo Booth · NR-2841", staff: { name: "Sam Patel", role: "Server" }, note: "Birthday · sign at midnight" },
  p8: { kind: "Ticket", ref: "GA · TK-90812", window: "Before 11:30 PM" },
  p9: { kind: "Table", ref: "Halo Booth · NR-2841", problem: "cancelled", note: "Removed by the booking host at 9:12 PM" },
  p10: { kind: "Ticket", ref: "GA · TK-88310", problem: "refunded", note: "Refunded on Aug 20" },
  p11: { kind: "Ticket", ref: "GA · TK-90155", problem: "duplicate", note: "Already scanned at 9:58 PM, Main entrance" },
  p12: { kind: "Ticket", ref: "GA · TK-77102", problem: "wrong-event", note: "Ticket is for Neon Garden, Sat, Aug 31" },
}
export const EXTRA_PARTIES: DoorParty[] = [
  { id: "p7", name: "Jordan Ellis", type: "Halo Booth · 12:30 AM", size: 6, inside: 1 },
  { id: "p8", name: "Ava Thompson", type: "General admission", size: 2, inside: 0 },
  { id: "p9", name: "Chris Morgan", type: "Halo Booth guest", size: 1, inside: 0 },
  { id: "p10", name: "Lena Brooks", type: "General admission", size: 1, inside: 0 },
  { id: "p11", name: "Theo Grant", type: "General admission", size: 1, inside: 1 },
  { id: "p12", name: "Nadia Park", type: "General admission", size: 2, inside: 0 },
]

const PROBLEM: Record<Problem, { label: string; tone: string; action: string }> = {
  duplicate: { label: "Already scanned", tone: "amber", action: "Check ID before re-admitting" },
  cancelled: { label: "Cancelled", tone: "red", action: "Do not admit · the host removed this pass" },
  refunded: { label: "Refunded", tone: "red", action: "Do not admit · guest can buy a new ticket" },
  "wrong-event": { label: "Wrong event", tone: "red", action: "Do not admit · ticket is for another night" },
}
const meta = (p: DoorParty): Meta => META[p.id] ?? { kind: p.type.startsWith("Guest") ? "Guest list" : p.type.includes("admission") ? "Ticket" : "Table", ref: p.type }

export function DoorGuests({ entrance, admit }: { entrance: string; admit: (id: string, n: number) => void }) {
  const store = useStore()
  const g = useGuests()
  const ui = useUI()
  const [q, setQ] = useState("")
  const [status, setStatus] = useState<"All" | "Not arrived" | "Checked in">("All")
  const [kind, setKind] = useState<"All types" | "Ticket" | "Table" | "Guest list">("All types")
  const term = q.trim().toLowerCase()
  const shown = store.parties.filter((p) => {
    const m = meta(p)
    if (term && !`${p.name} ${m.ref}`.toLowerCase().includes(term)) return false
    if (status === "Not arrived" && p.inside > 0) return false
    if (status === "Checked in" && p.inside === 0) return false
    if (kind !== "All types" && m.kind !== kind) return false
    return true
  })

  const contactStaff = (p: DoorParty, close: () => void) => {
    const m = meta(p)
    const name = m.staff?.name ?? "Jordan Blake"
    const id = "t-staff-" + name.replace(/\s/g, "")
    g.setThreads((l) =>
      l.some((t) => t.id === id)
        ? l
        : [{ id, area: "Team", guest: name, context: m.staff ? `${m.staff.role} · ${m.ref}` : "Manager on shift", scope: "Nova Room", unread: 0, card: { kind: "Table", title: `${p.name} · ${m.ref}`, detail: `${p.inside} of ${p.size} in · ${entrance}` }, msgs: [] }, ...l],
    )
    close()
    g.openTo("Team", id)
  }

  const detail = (p: DoorParty) => {
    const m = meta(p)
    ui.sheet({
      eyebrow: `${m.kind.toUpperCase()} · ${entrance.toUpperCase()}`,
      title: p.name,
      body: (close) => {
        const cur = store.parties.find((x) => x.id === p.id) ?? p
        const left = cur.size - cur.inside
        const blocked = m.problem && m.problem !== "duplicate"
        return (
          <div className="srv-sheet dg-sheet">
            {m.problem && (
              <div className={`dg-alert tone-${PROBLEM[m.problem].tone}`} role="alert">
                <Icon name="warning" size={16} />
                <span>
                  <b>{PROBLEM[m.problem].label}</b>
                  <small>{m.note}</small>
                  <small>{PROBLEM[m.problem].action}</small>
                </span>
              </div>
            )}
            <div className="dg-facts">
              <div>
                <small>Reference</small>
                <b>{m.ref}</b>
              </div>
              <div>
                <small>Allowance</small>
                <b>
                  {cur.inside} of {cur.size} in
                </b>
              </div>
              <div>
                <small>Entry</small>
                <b>{m.window ?? "Any time tonight"}</b>
              </div>
              <div>
                <small>ID</small>
                <b>19+ · physical ID</b>
              </div>
            </div>
            {m.note && !m.problem && <p className="srv-notice">{m.note}</p>}
            <p className="srv-muted dg-private">
              <Icon name="lock" size={13} /> Payment details are only visible to managers.
            </p>
            {!blocked && left > 0 && (
              <div className="dual-actions">
                <button className="secondary-action" onClick={() => (admit(p.id, 1), ui.toast(`1 guest checked in for ${p.name}`), close())}>
                  Check in 1
                </button>
                <button className="primary-action" onClick={() => (admit(p.id, left), ui.toast(`${left} checked in for ${p.name}`), close())}>
                  Check in all {left}
                </button>
              </div>
            )}
            {!blocked && left === 0 && <p className="srv-notice">Everyone on this booking is already in.</p>}
            <div className="dg-staff">
              <small>Assigned staff</small>
              {m.staff ? (
                <button className="srv-req" onClick={() => contactStaff(p, close)}>
                  <span className="srv-avatar team">
                    {m.staff.name
                      .split(" ")
                      .map((x) => x[0])
                      .join("")}
                  </span>
                  <span className="srv-main">
                    <strong>{m.staff.name}</strong>
                    <small>{m.staff.role} · internal message</small>
                  </span>
                  <span className="dg-contact">Contact Assigned Staff</span>
                </button>
              ) : (
                <>
                  <p className="srv-muted">No one is assigned to this {m.kind === "Table" ? "table" : "guest"} yet.</p>
                  <div className="dual-actions">
                    <button className="secondary-action" onClick={() => (ui.toast("Assistance requested. A floor runner is on the way."), close())}>
                      Request Assistance
                    </button>
                    <button className="primary-action" onClick={() => contactStaff(p, close)}>
                      Contact Manager
                    </button>
                  </div>
                </>
              )}
            </div>
            <small className="srv-muted">Opened {clock()} · demo data</small>
          </div>
        )
      },
    })
  }

  return (
    <>
      <label className="search-field dg-search">
        <Icon name="search" size={16} />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, table or ticket" aria-label="Search guests" />
        {q && (
          <button aria-label="Clear search" onClick={() => setQ("")}>
            <Icon name="close" size={14} />
          </button>
        )}
      </label>
      <div className="dg-totals">
        <span>
          <b>{NIGHT.expected}</b> expected
        </span>
        <span>
          <b>{store.arrived}</b> checked in
        </span>
        <small>{entrance}</small>
      </div>
      <div className="srv-filters" role="tablist" aria-label="Arrival">
        {(["All", "Not arrived", "Checked in"] as const).map((s) => (
          <button key={s} role="tab" aria-selected={status === s} className={status === s ? "on" : ""} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <div className="msg-scopes" aria-label="Type">
        {(["All types", "Ticket", "Table", "Guest list"] as const).map((k) => (
          <button key={k} aria-pressed={kind === k} className={kind === k ? "on" : ""} onClick={() => setKind(k)}>
            {k}
          </button>
        ))}
      </div>
      {shown.length === 0 ? (
        <div className="state-block">
          <Icon name="search" size={26} />
          <h2>No guests found</h2>
          <p>{term ? "Check the spelling, or add them as a walk-in." : "No one matches these filters."}</p>
        </div>
      ) : (
        <div className="srv-list">
          {shown.map((p) => {
            const m = meta(p)
            return (
              <button key={p.id} className="srv-table dg-row" onClick={() => detail(p)}>
                <span className={`dg-kind k-${m.kind.replace(" ", "")}`}>{m.kind === "Guest list" ? "GL" : m.kind === "Ticket" ? "TK" : "TB"}</span>
                <span className="srv-main">
                  <strong>{p.name}</strong>
                  <small>{m.ref}</small>
                  {m.problem && <span className={`srv-chip tone-${PROBLEM[m.problem].tone}`}>{PROBLEM[m.problem].label}</span>}
                </span>
                <span className={`dg-count ${p.inside >= p.size ? "full" : p.inside ? "part" : ""}`}>
                  {p.inside}/{p.size}
                </span>
              </button>
            )
          })}
        </div>
      )}
      <p className="srv-muted os-note">Demo guest list for {entrance}.</p>
    </>
  )
}
