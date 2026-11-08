import { useState } from "react"
import { NIGHT, bookingGuests, pct, usd } from "./data"
import { Icon, Lines } from "./kit"
import { useStore } from "./store"

/* Detail pages behind the owner's dashboard numbers. Each keeps the venue and date
   visible so it's clear what the number covers. All figures are demo data. */

function Head({ title, onBack, note, backLabel = "Overview" }: { title: string; onBack: () => void; note: string; backLabel?: string }) {
  return (
    <>
      <button className="srv-back" onClick={onBack}>
        <Icon name="back" size={18} /> {backLabel}
      </button>
      <div className="srv-title">
        <div>
          <span>
            {NIGHT.venue.toUpperCase()} · {NIGHT.dayLabel.toUpperCase()}
          </span>
          <h1>{title}</h1>
        </div>
      </div>
      <p className="srv-muted os-note">{note}</p>
    </>
  )
}

function Bar({ label, value, total, tone = "orange" }: { label: string; value: number; total: number; tone?: string }) {
  return (
    <div className="os-bar">
      <span>
        {label}
        <b>{value}</b>
      </span>
      <i className={`tone-bg-${tone}`} style={{ width: `${Math.max(2, (value / total) * 100)}%` }} />
    </div>
  )
}

export function ExpectedDetail({ onBack, backLabel }: { onBack: () => void; backLabel?: string }) {
  const { bookings } = useStore()
  const tables = bookingGuests(bookings)
  const guestList = 38
  const overlap = 6 // people with a ticket who also joined a table: counted once
  const tickets = NIGHT.expected - tables - guestList + overlap
  return (
    <>
      <Head backLabel={backLabel} title={`${NIGHT.expected} expected`} onBack={onBack} note="Everyone with a confirmed way in tonight. Each person is counted once, even if they hold a ticket and a table pass." />
      <div className="ot-card os-gap">
        <Bar label="Table reservations" value={tables} total={NIGHT.expected} />
        <Bar label="Tickets" value={tickets} total={NIGHT.expected} tone="blue" />
        <Bar label="Guest list" value={guestList} total={NIGHT.expected} tone="green" />
        <Bar label="Counted in two places" value={-overlap} total={NIGHT.expected} tone="gray" />
      </div>
      <Lines
        rows={[
          ["Table reservations", `${tables} guests · ${bookings.length} bookings`],
          ["Tickets sold", `${tickets + overlap} · ${overlap} also on a table`],
          ["Guest list", `${guestList} names`],
          ["Not included", "Cancelled and refunded passes, walk-ins"],
          ["Total", `${NIGHT.expected} people`],
        ]}
      />
      <p className="srv-muted os-note">Demo data.</p>
    </>
  )
}

const ARRIVALS = [
  ["7–8 PM", 14],
  ["8–9 PM", 31],
  ["9–10 PM", 51],
] as const

export function ArrivedDetail({ onBack, backLabel }: { onBack: () => void; backLabel?: string }) {
  const { arrived } = useStore()
  const max = Math.max(...ARRIVALS.map(([, n]) => n))
  const extra = arrived - ARRIVALS.reduce((s, [, n]) => s + n, 0)
  const rows: [string, number][] = ARRIVALS.map(([k, n], i) => [k, i === ARRIVALS.length - 1 ? n + extra : n])
  return (
    <>
      <Head backLabel={backLabel} title={`${arrived} checked in`} onBack={onBack} note="Check-ins recorded at the door since 7 PM. Departures aren't tracked, so this is not how many people are inside right now." />
      <div className="ot-card os-gap">
        <div className="ot-bars" role="img" aria-label={rows.map(([k, n]) => `${k}: ${n}`).join(", ")}>
          {rows.map(([k, n]) => (
            <span key={k}>
              <em>{n}</em>
              <i style={{ height: Math.max(4, Math.round((n / max) * 104)) }} />
              <small>{k}</small>
            </span>
          ))}
        </div>
      </div>
      <Lines
        rows={[
          ["Checked in", `${arrived} of ${NIGHT.expected} expected (${pct(arrived, NIGHT.expected)}%)`],
          ["Main entrance", `${Math.round(arrived * 0.82)}`],
          ["VIP entrance", `${arrived - Math.round(arrived * 0.82)}`],
          ["Walk-ins", "9 · included above"],
          ["Last check-in", NIGHT.now],
        ]}
      />
      <p className="srv-muted os-note">Demo data.</p>
    </>
  )
}

export function SalesDetail({ onBack, openPayouts, backLabel }: { onBack: () => void; openPayouts: () => void; backLabel?: string }) {
  const [view, setView] = useState<"Breakdown" | "Payouts">("Breakdown")
  const refunds = 150
  const cardFees = Math.round(NIGHT.card * 0.029 * 100) / 100
  const platform = Math.round(NIGHT.prepaid * 0.03 * 100) / 100
  const net = NIGHT.sales - refunds - cardFees - platform
  return (
    <>
      <Head backLabel={backLabel} title={`${usd(NIGHT.sales)} gross`} onBack={onBack} note="Gross sales are everything charged tonight before refunds and fees. Earnings are what's left. Payouts are when that money reaches your bank." />
      <div className="srv-filters" role="tablist">
        {(["Breakdown", "Payouts"] as const).map((v) => (
          <button key={v} role="tab" aria-selected={view === v} className={view === v ? "on" : ""} onClick={() => setView(v)}>
            {v}
          </button>
        ))}
      </div>
      {view === "Breakdown" ? (
        <>
          <section className="srv-section">
            <h2>Where it came from</h2>
            <div className="ot-card">
              <Bar label="Card at the venue" value={NIGHT.card} total={NIGHT.sales} />
              <Bar label="Cash" value={NIGHT.cash} total={NIGHT.sales} tone="green" />
              <Bar label="Prepaid in the app" value={NIGHT.prepaid} total={NIGHT.sales} tone="blue" />
            </div>
          </section>
          <section className="srv-section">
            <h2>From gross to earnings</h2>
            <Lines
              rows={[
                ["Gross sales", usd(NIGHT.sales, true)],
                ["Refunds", "− " + usd(refunds, true)],
                ["Card processing (2.9%)", "− " + usd(cardFees, true)],
                ["BottlesUp fee (3% of app sales)", "− " + usd(platform, true)],
                ["Earnings", usd(net, true)],
              ]}
            />
          </section>
        </>
      ) : (
        <section className="srv-section">
          <div className="ot-payouts">
            <div>
              <span className="srv-chip tone-amber">Pending</span>
              <b>{usd(net, true)}</b>
              <small>Tonight's earnings · paid Tue, Aug 27</small>
            </div>
            <div>
              <span className="srv-chip tone-green">Available</span>
              <b>{usd(12840)}</b>
              <small>From Aug 16–17 · ready to pay out</small>
            </div>
          </div>
          <button className="secondary-action full-action os-gap" onClick={openPayouts}>
            Open payments and payouts
          </button>
        </section>
      )}
      <p className="srv-muted os-note">Demo data.</p>
    </>
  )
}
