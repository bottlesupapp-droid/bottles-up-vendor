import { ArrivedDetail, ExpectedDetail, SalesDetail } from "./OwnerStats"
import { MenuEditor, PageEditor, TablesEditor } from "./VenueEdit"
import { useGuestBadge, useGuests } from "./Guests"
import { MessagesFab } from "./Messages"
import { VenuePanels, useVenueOps } from "./VenueOps"
import { useState, type ReactNode } from "react"
import { FLOOR, NIGHT, NIGHTS, RANGES, avgSpend, bookingGuests, pct, tableState, toCsv, usd, type NightReport, type RangeKey } from "./data"
import { usePersisted, Icon, Lines, Options, QuickForm, ThemeToggle, Thread, useUI, type Appearance, type IconName, type Theme } from "./kit"
import {
  AssignServersBody,
  BookingList,
  Empty,
  InviteBody,
  MemberBody,
  PaymentReviewBody,
  Segmented,
  SettingsBody,
  SupportBody,
  TableWalkInBody,
  useBookingSheet,
  useFlagged,
  useUnassigned,
} from "./shared"
import { useStore } from "./store"
import { ACTIVE_LOUNGE_PHOTOS, PhotoManager, type Photo } from "./VenuePhotos"

type Screen = "overview" | "venues" | "tonight" | "reports" | "more"
type Detail =
  | { kind: "bookings" }
  | { kind: "expected" }
  | { kind: "arrived" }
  | { kind: "sales" }
  | { kind: "venue"; venue: VenueId }
  | { kind: "messages" }
  | { kind: "report"; night: string }
  | { kind: "payments" }
  | { kind: "team" }
  | { kind: "settings" }

type VenueId = "active" | "sky"
const SETUP_ITEMS = ["Venue profile", "Rooms and floor plans", "Tables and capacities", "Booking rules", "Payment settings", "Team invited"] as const
type SetupItem = (typeof SETUP_ITEMS)[number]
const SETUP_DESC: Record<SetupItem, string> = {
  "Venue profile": "Address, contact details, and venue description",
  "Rooms and floor plans": "Create areas where bookings can be placed",
  "Tables and capacities": "Set minimum spends and group sizes",
  "Booking rules": "Days, times, and how far ahead guests can book",
  "Payment settings": "Deposits, card holds, and cancellation policy",
  "Team invited": "Add managers, door staff, and servers",
}
const VENUES: Record<VenueId, { name: string; short: string; address: string; slug: string }> = {
  active: { name: "Nova Room", short: "NR", address: "19 Mercer Street", slug: "nova-room" },
  sky: { name: "Sky Room", short: "SK", address: "88 Harbour Avenue", slug: "sky-room" },
}

const navItems: { id: Screen; label: string; icon: IconName }[] = [
  { id: "overview", label: "Overview", icon: "overview" },
  { id: "venues", label: "Venues", icon: "venues" },
  { id: "tonight", label: "Tonight", icon: "tonight" },
  { id: "reports", label: "Reports", icon: "reports" },
  { id: "more", label: "More", icon: "more" },
]

function PageTitle({ eyebrow, title, action }: { eyebrow?: string; title: string; action?: ReactNode }) {
  return (
    <div className="page-title">
      <div>
        {eyebrow && <span>{eyebrow}</span>}
        <h1>{title}</h1>
      </div>
      {action}
    </div>
  )
}

function Metric({ label, value, note, trend, onOpen }: { label: string; value: string; note?: string; trend?: string; onOpen?: () => void }) {
  if (onOpen)
    return (
      <button className="metric card metric-btn" onClick={onOpen} aria-label={`${label}: ${value}. Open details`}>
        <div className="metric-top">
          <span>{label}</span>
          {trend ? <em>{trend}</em> : <Icon name="chevron" size={14} />}
        </div>
        <strong>{value}</strong>
        {note && <small>{note}</small>}
      </button>
    )
  return (
    <div className="metric card">
      <div className="metric-top">
        <span>{label}</span>
        {trend && <em>{trend}</em>}
      </div>
      <strong>{value}</strong>
      {note && <small>{note}</small>}
    </div>
  )
}

function DetailHeader({ eyebrow, title, onBack, action }: { eyebrow: string; title: string; onBack: () => void; action?: ReactNode }) {
  return (
    <div className="detail-heading">
      <button className="back-button" onClick={onBack} aria-label="Go back">
        <Icon name="back" />
      </button>
      <div>
        <span>{eyebrow}</span>
        <h1>{title}</h1>
      </div>
      {action || <span className="heading-spacer" />}
    </div>
  )
}

function AttentionRow({ icon, title, text, count, onClick, warning }: { icon: IconName; title: string; text: string; count: number; onClick: () => void; warning?: boolean }) {
  return (
    <button className="list-row" onClick={onClick}>
      <span className={`row-icon ${warning ? "warning" : ""}`}>
        <Icon name={icon} />
      </span>
      <span>
        <strong>{title}</strong>
        <small>{text}</small>
      </span>
      {count > 0 && <b>{count}</b>}
      <Icon name="chevron" size={17} />
    </button>
  )
}

function useAttention() {
  const ui = useUI()
  const flagged = useFlagged()
  const unassigned = useUnassigned()
  return {
    flagged,
    unassigned,
    reviewPayments: () => ui.sheet({ eyebrow: "PAYMENTS", title: "Review payments", body: (close) => <PaymentReviewBody close={close} /> }),
    assignTables: () => ui.sheet({ eyebrow: NIGHT.venue.toUpperCase(), title: "Assign servers", body: (close) => <AssignServersBody close={close} /> }),
  }
}

function Overview({ open, setScreen }: { open: (d: Detail) => void; setScreen: (s: Screen) => void }) {
  const ops = useVenueOps()
  const guests = useGuests()
  const guestCount = useGuestBadge()
  const { bookings, arrived } = useStore()
  const att = useAttention()
  return (
    <>
      <PageTitle
        eyebrow={NIGHT.eyebrow}
        title="Good evening, Alex"
        action={
          <button className="page-main-action" onClick={() => ops.openPanel({ kind: "events", create: true })}>
            Create event
          </button>
        }
      />
      <div className="hero-card">
        <div className="hero-copy">
          <span className="live-pill">
            <i /> LIVE · {NIGHT.now}
          </span>
          <h2>A strong night ahead</h2>
          <p>Bookings are up 12% from last Saturday.</p>
        </div>
      </div>
      <div className="metrics-grid">
        <Metric label="Bookings" value={String(bookings.length)} note={`${bookingGuests(bookings)} guests at tables`} trend="+12%" onOpen={() => open({ kind: "bookings" })} />
        <Metric label="Expected" value={String(NIGHT.expected)} note="Tickets, tables, guest list" onOpen={() => open({ kind: "expected" })} />
        <Metric label="Arrived" value={String(arrived)} note={`${pct(arrived, NIGHT.expected)}% checked in`} onOpen={() => open({ kind: "arrived" })} />
        <Metric label="Sales so far" value={usd(NIGHT.sales)} note="Gross · before fees" trend={NIGHT.salesChange} onOpen={() => open({ kind: "sales" })} />
      </div>
      <section>
        <div className="section-heading">
          <div>
            <span>NEEDS ATTENTION</span>
            <h2>Stay ahead</h2>
          </div>
        </div>
        <div className="attention-list card">
          {att.flagged === 0 && att.unassigned === 0 && <p className="all-clear">All clear. Nothing needs you right now.</p>}
          {att.flagged > 0 && <AttentionRow icon="card" warning title={`${att.flagged} payment${att.flagged === 1 ? " needs" : "s need"} review`} text="Flagged for an unusual amount" count={att.flagged} onClick={att.reviewPayments} />}
          {att.unassigned > 0 && <AttentionRow icon="team" title="Tables without a server" text={`${att.unassigned} seated table${att.unassigned === 1 ? "" : "s"} need a server`} count={att.unassigned} onClick={att.assignTables} />}
        </div>
      </section>
      <section>
        <div className="section-heading">
          <div>
            <span>YOUR VENUES</span>
            <h2>Tonight’s pulse</h2>
          </div>
          <button onClick={() => setScreen("venues")}>All venues</button>
        </div>
        <div className="venue-mini-grid">
          <button className="mini-venue card" onClick={() => setScreen("tonight")}>
            <span>NR</span>
            <div>
              <strong>Nova Room</strong>
              <small>
                {NIGHT.expected} expected · Open
              </small>
            </div>
            <i className="status-dot" />
          </button>
          <button className="mini-venue card" onClick={() => open({ kind: "venue", venue: "sky" })}>
            <span>SK</span>
            <div>
              <strong>Sky Room</strong>
              <small>Setup 3 of 6 · Not live yet</small>
            </div>
            <i className="status-dot amber" />
          </button>
        </div>
      </section>
    </>
  )
}

function Venues({ open, setup, addVenue, extra }: { open: (d: Detail) => void; setup: Record<VenueId, Record<SetupItem, boolean>>; addVenue: () => void; extra: string[] }) {
  const ui = useUI()
  const { bookings } = useStore()
  const done = (v: VenueId) => SETUP_ITEMS.filter((i) => setup[v][i]).length
  const total = SETUP_ITEMS.length * 2
  const venueMenu = (v: VenueId) =>
    ui.sheet({
      eyebrow: "VENUE",
      title: VENUES[v].name,
      body: (close) => (
        <Options
          close={close}
          items={[
            { label: "Manage venue", detail: "Setup checklist and booking link", icon: "settings", onSelect: () => open({ kind: "venue", venue: v }) },
            { label: "Copy booking link", detail: `bottlesup.com/book/${VENUES[v].slug}`, icon: "copy", onSelect: () => ui.copy(`https://bottlesup.com/book/${VENUES[v].slug}`, "Booking link copied") },
            { label: v === "active" ? "Pause new bookings" : "Delete draft venue", detail: v === "active" ? "Existing bookings stay confirmed" : "Removes this draft and its setup", icon: "warning", danger: true, onSelect: () => ui.toast(v === "active" ? "New bookings paused for tonight" : "Sky Room kept. Drafts can't be deleted in the demo.") },
          ]}
        />
      ),
    })
  return (
    <>
      <PageTitle
        eyebrow="YOUR BUSINESS"
        title="Venues"
        action={
          <button className="round-add" aria-label="Add venue" onClick={addVenue}>
            <Icon name="plus" />
          </button>
        }
      />
      <p className="page-intro">Manage spaces, teams, and tonight’s setup.</p>
      <div className="summary-strip card">
        <div>
          <span>{2 + extra.length}</span>
          <small>Venues</small>
        </div>
        <div>
          <span>1</span>
          <small>Live tonight</small>
        </div>
        <div>
          <span>{pct(done("active") + done("sky"), total)}%</span>
          <small>Setup complete</small>
        </div>
      </div>
      <section className="venue-stack">
        {(["active", "sky"] as VenueId[]).map((v) => {
          const d = done(v)
          return (
            <article className="venue-card card" key={v}>
              <div className={`venue-visual ${v === "active" ? "active-lounge" : "sky-room"}`}>
                <span>{VENUES[v].short}</span>
                {v === "active" ? (
                  <em>
                    <i /> OPEN
                  </em>
                ) : (
                  <em className="draft">DRAFT</em>
                )}
              </div>
              <div className="venue-body">
                <div className="venue-title">
                  <div>
                    <h2>{VENUES[v].name}</h2>
                    <p>{VENUES[v].address}</p>
                  </div>
                  <button aria-label={`${VENUES[v].name} options`} onClick={() => venueMenu(v)}>
                    <Icon name="more" />
                  </button>
                </div>
                <div className="progress-head">
                  <span>Venue setup</span>
                  <strong>
                    {d} of {SETUP_ITEMS.length}
                  </strong>
                </div>
                <div className="progress">
                  <i className={d === SETUP_ITEMS.length ? "complete" : ""} style={{ width: `${pct(d, SETUP_ITEMS.length)}%` }} />
                </div>
                {v === "active" ? (
                  <div className="venue-stats">
                    <span>
                      <strong>{NIGHT.expected}</strong> expected
                    </span>
                    <span>
                      <strong>{NIGHT.teamOnShift}</strong> staff
                    </span>
                    <span>
                      <strong>{bookings.length}</strong> bookings
                    </span>
                  </div>
                ) : (
                  <p className="setup-note">
                    <Icon name="clock" size={16} /> {SETUP_ITEMS.filter((i) => !setup.sky[i]).join(", ")} left to finish.
                  </p>
                )}
                <button className="secondary-action" onClick={() => open({ kind: "venue", venue: v })}>
                  {d === SETUP_ITEMS.length ? "Manage venue" : "Continue setup"} <Icon name="arrow" size={17} />
                </button>
              </div>
            </article>
          )
        })}
        {extra.map((name) => (
          <article className="venue-card card" key={name}>
            <div className="venue-body">
              <div className="venue-title">
                <div>
                  <h2>{name}</h2>
                  <p>New draft · 0 of 6 setup steps</p>
                </div>
              </div>
              <p className="setup-note">
                <Icon name="clock" size={16} /> Draft saved. Setup for new venues opens in the full app.
              </p>
            </div>
          </article>
        ))}
      </section>
    </>
  )
}

const DATES = [
  { label: "Friday, 23 August", note: "Closed · 248 guests", mode: "past" },
  { label: NIGHT.dayLabel, note: `Doors opened ${NIGHT.doorsOpened}`, mode: "live" },
  { label: "Friday, 30 August", note: "Doors open 7:00 PM · 21 bookings", mode: "future" },
] as const

function Tonight({ open }: { open: (d: Detail) => void }) {
  const ui = useUI()
  const store = useStore()
  const att = useAttention()
  const guests = useGuests()
  const guestCount = useGuestBadge()
  const openBooking = useBookingSheet()
  const [tab, setTab] = useState("Floor")
  const [day, setDay] = useState(1)
  const date = DATES[day]
  const seated = store.bookings.filter((b) => b.status === "Arrived").length
  const tableSheet = (table: string, name: string, seats: number) => {
    const b = store.bookings.find((x) => x.table === table)
    if (b) return openBooking(b.id)
    ui.sheet({
      eyebrow: "FLOOR",
      title: `${name} · Available`,
      body: (close) => (
        <>
          <p className="page-intro">{seats} seats · No booking tonight.</p>
          <button
            className="primary-action full-action"
            onClick={() => {
              close()
              ui.sheet({ eyebrow: "TONIGHT · NOVA ROOM", title: "Add walk-in", body: (c) => <TableWalkInBody close={c} /> })
            }}
          >
            Seat a walk-in here
          </button>
        </>
      ),
    })
  }
  return (
    <>
      <PageTitle
        eyebrow="NOVA ROOM"
        title={date.mode === "live" ? "Tonight" : date.mode === "past" ? "Past night" : "Upcoming"}
        action={
          date.mode === "live" ? (
            <span className="live-status">
              <i /> Live · {NIGHT.now}
            </span>
          ) : undefined
        }
      />
      <div className="date-switch">
        <button aria-label="Previous date" disabled={day === 0} onClick={() => setDay(day - 1)}>
          <Icon name="back" />
        </button>
        <div>
          <strong>{date.label}</strong>
          <small>{date.note}</small>
        </div>
        <button aria-label="Next date" disabled={day === DATES.length - 1} onClick={() => setDay(day + 1)}>
          <Icon name="chevron" />
        </button>
      </div>
      {date.mode !== "live" ? (
        <div className="day-summary card">
          <Icon name={date.mode === "past" ? "check" : "calendar"} size={26} />
          <h2>{date.mode === "past" ? "This night is closed" : "Bookings are open"}</h2>
          <p>{date.mode === "past" ? "Sales, payments and attendance are in Reports." : "21 tables booked so far. Live tools turn on when doors open."}</p>
          <button className="secondary-action" onClick={() => setDay(1)}>
            Back to tonight
          </button>
        </div>
      ) : (
        <>
          <Segmented items={["Floor", "Bookings", "Orders", "Team"]} active={tab} onChange={setTab} />
          <div className="tonight-actions">
            <button className="primary-action" onClick={() => ui.sheet({ eyebrow: "TONIGHT · NOVA ROOM", title: "Add walk-in", body: (c) => <TableWalkInBody close={c} /> })}>
              <Icon name="plus" size={18} /> Add walk-in
            </button>
            <button className="secondary-action" onClick={() => open({ kind: "messages" })}>
              <Icon name="team" size={18} /> Message team
            </button>
          </div>
          <button className="night-prep card" onClick={() => open({ kind: "report", night: "may24" })}>
            <span className="row-icon warning">
              <Icon name="tonight" />
            </span>
            <span>
              <strong>Prepare and close the night</strong>
              <small>Review sales, payments, and the final report.</small>
            </span>
            <Icon name="chevron" size={18} />
          </button>
          {tab === "Floor" && (
            <>
              <section>
                <div className="section-heading">
                  <div>
                    <span>AT A GLANCE</span>
                    <h2>The floor</h2>
                  </div>
                </div>
                <div className="night-grid">
                  <Metric label="Tables seated" value={`${seated} / ${NIGHT.tablesTotal}`} note={`${pct(seated, NIGHT.tablesTotal)}% occupancy`} />
                  <Metric label="Guests arrived" value={String(store.arrived)} note={`of ${NIGHT.expected} expected`} />
                  <Metric label="Open orders" value={String(NIGHT.openOrders)} note={`${usd(NIGHT.openOrdersValue)} value`} />
                  <Metric label="Team on shift" value={`${NIGHT.teamOnShift} / ${NIGHT.teamScheduled}`} note="2 arriving at 10 PM" />
                </div>
              </section>
              <section>
                <div className="section-heading">
                  <div>
                    <span>FLOOR PLAN · MAIN FLOOR</span>
                    <h2>Tables</h2>
                  </div>
                  <span className="tiny-legend">
                    <i /> Available <i /> Seated <i className="reserved" /> Reserved
                  </span>
                </div>
                <div className="floor card">
                  {FLOOR.map((t) => {
                    const state = tableState(t.table, store.bookings)
                    return (
                      <button className={`table ${state}`} key={t.name} onClick={() => tableSheet(t.table, t.name, t.seats)} aria-label={`${t.name}, ${t.seats} seats, ${state}`}>
                        <strong>{t.name}</strong>
                        <small>{t.seats} seats</small>
                      </button>
                    )
                  })}
                </div>
              </section>
            </>
          )}
          {tab === "Bookings" && (
            <section>
              <BookingList initialFilter="Confirmed" />
            </section>
          )}
          {tab === "Orders" && (
            <section>
              <div className="section-heading">
                <div>
                  <span>{NIGHT.openOrders} OPEN · {usd(NIGHT.openOrdersValue)}</span>
                  <h2>Orders</h2>
                </div>
              </div>
              <div className="summary-list card">
                {[
                  ["#1842 · Table 4", "Preparing · 8 min", "$420"],
                  ["#1840 · Table 10", "Ready to deliver", "$1,240"],
                  ["#1839 · Table 8", "Preparing · 5 min", "$310"],
                  ["#1836 · Table 12", "Delivered · Payment due", "$286"],
                ].map((r) => (
                  <div className="list-row static-row" key={r[0]}>
                    <span className="row-icon">
                      <Icon name="orders" />
                    </span>
                    <span>
                      <strong>{r[0]}</strong>
                      <small>{r[1]}</small>
                    </span>
                    <strong>{r[2]}</strong>
                  </div>
                ))}
              </div>
              <p className="list-count">Showing the 4 most recent of {NIGHT.openOrders} open orders.</p>
            </section>
          )}
          {tab === "Team" && (
            <section>
              <div className="section-heading">
                <div>
                  <span>
                    {NIGHT.teamOnShift} OF {NIGHT.teamScheduled} ON SHIFT
                  </span>
                  <h2>Team</h2>
                </div>
                <button onClick={() => open({ kind: "team" })}>Manage</button>
              </div>
              <div className="summary-list card">
                {["Sam Patel", "Riley Chen", "Dana Ortiz"].map((s) => {
                  const n = store.bookings.filter((b) => b.server === s && b.status === "Arrived").length
                  return (
                    <div className="list-row static-row" key={s}>
                      <span className="row-icon">
                        <Icon name="server" />
                      </span>
                      <span>
                        <strong>{s}</strong>
                        <small>Server · {n} seated table{n === 1 ? "" : "s"}</small>
                      </span>
                    </div>
                  )
                })}
              </div>
            </section>
          )}
          <section>
            <div className="section-heading">
              <div>
                <span>NEEDS ATTENTION</span>
                <h2>Before closing</h2>
              </div>
            </div>
            <div className="attention-list card">
              {att.flagged === 0 && att.unassigned === 0 && <p className="all-clear">All clear.</p>}
              {att.flagged > 0 && <AttentionRow icon="payments" warning title="Payments to check" text={`${att.flagged} flagged transaction`} count={att.flagged} onClick={att.reviewPayments} />}
              {guestCount > 0 && <AttentionRow icon="chat" title="Guests need you" text="Messages, help requests, bottle signs and refunds" count={guestCount} onClick={() => guests.setOpen(true)} />}
              {att.unassigned > 0 && <AttentionRow icon="server" title="Tables without a server" text="Assign a server now" count={att.unassigned} onClick={att.assignTables} />}
            </div>
          </section>
        </>
      )}
    </>
  )
}

const CHARTS: Record<RangeKey, { bars: number[]; labels: string[]; forecastFrom?: number; attendance: string; attendanceNote: string; spend: string; tables: string; orders: string }> = {
  Tonight: { bars: [18, 36, 54, 70, 88, 76, 58], labels: ["7", "8", "9", "10", "11", "12", "1"], forecastFrom: 3, attendance: String(NIGHT.arrived), attendanceNote: `${pct(NIGHT.arrived, NIGHT.expected)}% of expected so far`, spend: avgSpend(), tables: "$2.6k", orders: "154" },
  "7 days": { bars: [82, 44, 50, 62, 68, 78, 40], labels: ["S", "S", "M", "T", "W", "T", "F"], attendance: "1,482", attendanceNote: "82% of expected", spend: "$46.17", tables: "$41.2k", orders: "936" },
  "30 days": { bars: [61, 73, 79, 88, 52], labels: ["Apr 25", "May 2", "May 9", "May 16", "May 23"], attendance: "5,316", attendanceNote: "84% of expected", spend: "$46.43", tables: "$148k", orders: "3,482" },
}

function Reports({ open }: { open: (d: Detail) => void }) {
  const ui = useUI()
  const [range, setRange] = useState<RangeKey>("7 days")
  const r = RANGES[range]
  const c = CHARTS[range]
  const exportCsv = () =>
    ui.copy(
      toCsv([["Night", "Gross sales", "Guests"], ...NIGHTS.map((n) => [n.label, n.sales, n.arrived])]),
      "Recent nights copied as CSV. Paste into a spreadsheet.",
    )
  return (
    <>
      <PageTitle
        eyebrow="PERFORMANCE"
        title="Reports"
        action={
          <button className="icon-button" aria-label="Choose dates" onClick={() => ui.sheet({ eyebrow: "REPORTS", title: "Date range", body: (close) => <Options close={close} items={(Object.keys(RANGES) as RangeKey[]).map((k) => ({ label: k, detail: RANGES[k].period, icon: "calendar", onSelect: () => setRange(k) }))} /> })}>
            <Icon name="calendar" />
          </button>
        }
      />
      <Segmented items={Object.keys(RANGES)} active={range} onChange={(v) => setRange(v as RangeKey)} />
      <div className="report-total">
        <span>{range === "Tonight" ? "GROSS SALES SO FAR" : "GROSS SALES"}</span>
        <strong>{usd(r.sales)}</strong>
        <p>
          <em>{r.change}</em> {range === "Tonight" ? "vs last Saturday at this time" : "from previous period"}
        </p>
      </div>
      <div className="chart-card card">
        <div className="chart-head">
          <div>
            <strong>Sales trend</strong>
            <small>
              {r.period}
              {c.forecastFrom ? " · faded bars are forecast" : ""}
            </small>
          </div>
          <span>{usd(r.sales)}</span>
        </div>
        <div className="chart" style={{ gridTemplateColumns: `repeat(${c.bars.length}, 1fr)` }}>
          {c.bars.map((bar, i) => (
            <div key={i}>
              <i style={{ height: `${bar}%` }} className={c.forecastFrom !== undefined && i >= c.forecastFrom ? "forecast" : i === (c.forecastFrom ?? c.bars.length) - 1 ? "highlight" : ""} />
              <small>{c.labels[i]}</small>
            </div>
          ))}
        </div>
      </div>
      <div className="metrics-grid report-metrics">
        <Metric label="Attendance" value={c.attendance} note={c.attendanceNote} />
        <Metric label="Avg. spend" value={c.spend} note="Per guest" />
        <Metric label="Table sales" value={c.tables} note="60% of revenue" />
        <Metric label="Orders" value={c.orders} note="1.6 per guest" />
      </div>
      <section>
        <div className="section-heading">
          <div>
            <span>NIGHTLY SUMMARIES</span>
            <h2>Recent nights</h2>
          </div>
          <button onClick={exportCsv}>Export</button>
        </div>
        <div className="summary-list card">
          {NIGHTS.map((n) => (
            <button className="list-row" key={n.id} onClick={() => open({ kind: "report", night: n.id })}>
              <span className="report-date">
                <strong>{n.short.slice(0, 3)}</strong>
                <small>{n.short.slice(5)}</small>
              </span>
              <span>
                <strong>
                  {usd(n.sales)}
                  {n.live ? " so far" : ""}
                </strong>
                <small>
                  {n.arrived} guests{n.live ? " · Live" : ""}
                </small>
              </span>
              <Icon name="chevron" size={17} />
            </button>
          ))}
        </div>
      </section>
    </>
  )
}

function More({ open, agreementSheet, eventsSheet }: { open: (d: Detail) => void; agreementSheet: () => void; eventsSheet: () => void }) {
  const ui = useUI()
  const ops = useVenueOps()
  const { agreement } = useStore()
  const [profile, setProfile] = useState({ name: "Alex Morgan", title: "Owner · Northstar Hospitality" })
  const groups: { label: string; items: [IconName, string, string, string | undefined, () => void][] }[] = [
    {
      label: "OPERATIONS",
      items: [
        ["team", "Team", "Staff, roles, and invitations", String(NIGHT.teamScheduled), () => open({ kind: "team" })],
        ["inventory", "Inventory", "Stock, deliveries, and low-stock alerts", "3", () => ui.sheet({ eyebrow: "NOVA ROOM", title: "Low stock", body: (close) => <InventoryBody close={close} /> })],
        ["vip", "VIP clients", "Contacts, perks, hosts and private notes", "3", () => ops.openPanel({ kind: "vip" })],
      ],
    },
    {
      label: "BUSINESS",
      items: [
        ["payments", "Payments", "Payouts, balances, and transactions", undefined, () => open({ kind: "payments" })],
        ["events", "Events", "Create one-time or weekly events at Nova Room", "3", () => ops.openPanel({ kind: "events" })],
        ["ticket", "Agreements", "Organizer terms and approvals", agreement === "Pending approval" ? "1" : undefined, agreementSheet],
      ],
    },
    { label: "ACCOUNT", items: [["settings", "Settings", "Appearance, notifications, and account", undefined, () => open({ kind: "settings" })]] },
  ]
  return (
    <>
      <PageTitle eyebrow="NORTHSTAR HOSPITALITY" title="More" />
      <div className="profile-card card">
        <div className="profile-avatar">{profile.name.split(" ").map((x) => x[0]).join("").slice(0, 2)}</div>
        <div>
          <strong>{profile.name}</strong>
          <small>{profile.title}</small>
        </div>
        <button
          onClick={() =>
            ui.sheet({
              eyebrow: "PROFILE",
              title: "Edit profile",
              body: (close) => (
                <QuickForm
                  submit="Save"
                  fields={[
                    { id: "name", label: "Name", value: profile.name, required: true },
                    { id: "title", label: "Title", value: profile.title, required: true },
                  ]}
                  onSubmit={(v) => {
                    setProfile({ name: v.name.trim(), title: v.title.trim() })
                    ui.toast("Profile saved")
                    close()
                  }}
                />
              ),
            })
          }
        >
          Edit
        </button>
      </div>
      {groups.map((group) => (
        <section className="more-section" key={group.label}>
          <div className="section-heading">
            <div>
              <span>{group.label}</span>
            </div>
          </div>
          <div className="more-list card">
            {group.items.map(([icon, title, desc, count, onClick]) => (
              <button className="list-row" key={title} onClick={onClick}>
                <span className="row-icon">
                  <Icon name={icon} />
                </span>
                <span>
                  <strong>{title}</strong>
                  <small>{desc}</small>
                </span>
                {count && <b>{count}</b>}
                <Icon name="chevron" size={17} />
              </button>
            ))}
          </div>
        </section>
      ))}
      <p className="version">BottlesUp Business · Version 2.4.0</p>
    </>
  )
}

function InventoryBody({ close }: { close: () => void }) {
  const ui = useUI()
  const [ordered, setOrdered] = useState<string[]>([])
  const items = [
    ["Premium vodka", "4 bottles left · par 12"],
    ["Champagne", "6 bottles left · par 18"],
    ["Fresh limes", "1 case left · par 3"],
  ]
  return (
    <div className="form-stack">
      {items.map(([name, note]) => (
        <div className="list-row static-row card" key={name}>
          <span className="row-icon warning">
            <Icon name="inventory" />
          </span>
          <span>
            <strong>{name}</strong>
            <small>{ordered.includes(name) ? "Reorder sent · arrives tomorrow" : note}</small>
          </span>
          <button className="text-button" disabled={ordered.includes(name)} onClick={() => setOrdered([...ordered, name])}>
            {ordered.includes(name) ? "Ordered" : "Reorder"}
          </button>
        </div>
      ))}
      <button
        className="secondary-action full-action"
        onClick={() => {
          ui.toast("Inventory updated")
          close()
        }}
      >
        Done
      </button>
    </div>
  )
}

function Calendar({ selected, onSelect }: { selected: { m: number; d: number }; onSelect: (m: number, d: number) => void }) {
  const [month, setMonth] = useState(selected.m)
  const names = ["July", "August", "September"]
  const first = new Date(2024, 6 + month, 1)
  const offset = (first.getDay() + 6) % 7
  const days = new Date(2024, 4 + month, 0).getDate()
  return (
    <div className="calendar-card card">
      <div className="calendar-head">
        <button aria-label="Previous month" disabled={month === 0} onClick={() => setMonth(month - 1)}>
          <Icon name="back" />
        </button>
        <strong>{names[month]} 2024</strong>
        <button aria-label="Next month" disabled={month === 2} onClick={() => setMonth(month + 1)}>
          <Icon name="chevron" />
        </button>
      </div>
      <div className="calendar-grid">
        {["M", "T", "W", "T", "F", "S", "S"].map((d, i) => (
          <span className="weekday" key={"w" + i}>
            {d}
          </span>
        ))}
        {Array.from({ length: offset }, (_, i) => (
          <span key={"e" + i} />
        ))}
        {Array.from({ length: days }, (_, i) => i + 1).map((day) => (
          <button key={day} className={selected.m === month && selected.d === day ? "selected" : month === 1 && day === 24 ? "today" : ""} onClick={() => onSelect(month, day)}>
            {day}
          </button>
        ))}
      </div>
    </div>
  )
}

function BookingsDetail({ onBack }: { onBack: () => void }) {
  const [calendar, setCalendar] = useState(false)
  const [sel, setSel] = useState({ m: 1, d: 24 })
  const isTonight = sel.m === 1 && sel.d === 24
  const date = new Date(2024, 3 + sel.m, sel.d)
  const label = date.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })
  const past = date < new Date(2024, 4, 24)
  return (
    <>
      <DetailHeader eyebrow="NOVA ROOM" title="Bookings" onBack={onBack} />
      <button className="date-range card" onClick={() => setCalendar(!calendar)}>
        <Icon name="calendar" />
        <span>
          <small>DATE</small>
          <strong>{isTonight ? `Tonight · ${label}` : label}</strong>
        </span>
        <Icon name="chevron" />
      </button>
      {calendar && (
        <Calendar
          selected={sel}
          onSelect={(m, d) => {
            setSel({ m, d })
            setCalendar(false)
          }}
        />
      )}
      {isTonight ? (
        <BookingList initialFilter="All" />
      ) : (
        <Empty icon="calendar" title={past ? "This night is closed" : "No bookings to show yet"} text={past ? "See Reports for sales and attendance from past nights." : "Bookings for this date appear here as guests reserve."} />
      )}
    </>
  )
}

function SetupItemBody({ item, onSave, venue }: { item: SetupItem; onSave: () => void; venue: { name: string; address: string } }) {
  const [days, setDays] = useState([false, false, false, true, true, true, true])
  const [pay, setPay] = useState(0)
  if (item === "Payment settings")
    return (
      <>
        <p className="page-intro">Choose how reservations are secured and when guests are charged.</p>
        <div className="choice-list card">
          {["Pay ahead", "Card hold", "Customer chooses", "Pay at the venue"].map((label, i) => (
            <label className="choice" key={label}>
              <input type="radio" name="payment" checked={pay === i} onChange={() => setPay(i)} />
              <span>
                <strong>{label}</strong>
                <small>{["Guests pay in full when they reserve.", "Authorize a card and charge only for no-shows.", "Let guests choose between a full payment or hold.", "No payment is collected during booking."][i]}</small>
              </span>
            </label>
          ))}
        </div>
        <QuickForm submit="Save payment settings" fields={[{ id: "dep", label: "Deposit per guest", value: "$25", required: true }]} onSubmit={onSave} />
      </>
    )
  if (item === "Booking rules")
    return (
      <>
        <p className="page-intro">Set the days guests can reserve a table.</p>
        <div className="schedule card">
          {["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].map((day, i) => (
            <div key={day}>
              <span>{day}</span>
              <small>{days[i] ? "7:00 PM – 2:00 AM" : "No bookings accepted"}</small>
              <button className={days[i] ? "toggle on" : "toggle"} aria-pressed={days[i]} aria-label={`${day} bookings`} onClick={() => setDays(days.map((x, j) => (j === i ? !x : x)))}>
                <i />
              </button>
            </div>
          ))}
        </div>
        <button className="primary-action full-action" onClick={onSave}>
          Save booking rules
        </button>
      </>
    )
  const forms: Record<string, { id: string; label: string; value?: string; placeholder?: string; type?: string; required?: boolean; options?: string[] }[]> = {
    "Venue profile": [
      { id: "name", label: "Venue name", value: venue.name, required: true },
      { id: "addr", label: "Address", value: venue.address, required: true },
      { id: "phone", label: "Phone", placeholder: "(555) 010-2040", required: true },
    ],
    "Rooms and floor plans": [
      { id: "room", label: "Area name", value: "Rooftop terrace", required: true },
      { id: "cap", label: "Capacity", value: "120", type: "number", required: true },
    ],
    "Tables and capacities": [
      { id: "tables", label: "Number of tables", value: "14", type: "number", required: true },
      { id: "min", label: "Typical minimum spend", value: "$600", required: true },
    ],
    "Team invited": [
      { id: "email", label: "Manager email", placeholder: "name@example.com", type: "email", required: true },
      { id: "role", label: "Role", options: ["Manager", "Door staff", "Server"] },
    ],
  }
  return <QuickForm submit="Save" fields={forms[item]} onSubmit={onSave} />
}

function VenueDetail({ venue, onBack, setup, markDone, photos, setPhotos }: { venue: VenueId; onBack: () => void; setup: Record<SetupItem, boolean>; markDone: (i: SetupItem) => void; photos: Photo[]; setPhotos: (fn: (p: Photo[]) => Photo[]) => void }) {
  const ui = useUI()
  const [tab, setTab] = useState("Setup")
  const [item, setItem] = useState<SetupItem | null>(null)
  const v = VENUES[venue]
  const d = SETUP_ITEMS.filter((i) => setup[i]).length
  const link = `bottlesup.com/book/${v.slug}`
  return (
    <>
      <DetailHeader
        eyebrow={v.name.toUpperCase()}
        title="Manage venue"
        onBack={item ? () => setItem(null) : onBack}
        action={
          <span className="live-status">
            <i /> {venue === "active" ? "Open" : "Draft"}
          </span>
        }
      />
      {item ? (
        <div className="sub-detail">
          <div className="page-title">
            <div>
              <span>CONFIGURATION</span>
              <h1>{item}</h1>
            </div>
          </div>
          <SetupItemBody
            item={item}
            venue={v}
            onSave={() => {
              markDone(item)
              ui.toast(`${item} saved`)
              setItem(null)
            }}
          />
        </div>
      ) : (
        <>
          <div className="srv-filters" role="tablist" aria-label="Venue sections">
            {["Setup", "Page", "Tables", "Menu & signs", "Photos", "Booking link"].map((t) => (
              <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>
                {t}
              </button>
            ))}
          </div>
          {tab === "Page" ? (
            <PageEditor />
          ) : tab === "Tables" ? (
            <TablesEditor />
          ) : tab === "Menu & signs" ? (
            <MenuEditor />
          ) : tab === "Photos" ? (
            <PhotoManager name={v.name} photos={photos} setPhotos={setPhotos} />
          ) : tab === "Setup" ? (
            <section>
              <div className="setup-progress">
                <div>
                  <span>VENUE SETUP</span>
                  <strong>
                    {d} of {SETUP_ITEMS.length} complete
                  </strong>
                </div>
                <div className="progress">
                  <i className={d === SETUP_ITEMS.length ? "complete" : ""} style={{ width: `${pct(d, SETUP_ITEMS.length)}%` }} />
                </div>
              </div>
              <div className="checklist card">
                {SETUP_ITEMS.map((title) => (
                  <button key={title} onClick={() => setItem(title)}>
                    <span className={setup[title] ? "check done" : "check"}>{setup[title] ? <Icon name="check" size={15} /> : null}</span>
                    <span>
                      <strong>{title}</strong>
                      <small>{SETUP_DESC[title]}</small>
                    </span>
                    <em>{setup[title] ? "Done" : "Set up"}</em>
                    <Icon name="chevron" size={16} />
                  </button>
                ))}
              </div>
            </section>
          ) : d < SETUP_ITEMS.length ? (
            <Empty icon="ticket" title="Finish setup to get a booking link" text={`Complete ${SETUP_ITEMS.length - d} more step${SETUP_ITEMS.length - d === 1 ? "" : "s"} and ${v.name} can take bookings.`} />
          ) : (
            <div className="booking-link">
              <span className="link-icon">
                <Icon name="ticket" size={28} />
              </span>
              <h2>Accept bookings anywhere</h2>
              <p>Share this link on your website and social channels.</p>
              <div className="copy-link card">
                <span>{link}</span>
                <button onClick={() => ui.copy("https://" + link, "Booking link copied")}>Copy</button>
              </div>
              <div className="qr" aria-hidden="true">
                <span>BU</span>
                <i />
                <i />
                <i />
              </div>
              <p className="list-count">Guests can scan this code at your door or on printed menus.</p>
            </div>
          )}
        </>
      )}
    </>
  )
}

function MessagesDetail({ onBack }: { onBack: () => void }) {
  const ui = useUI()
  const [groups, setGroups] = useState([
    { name: "Floor team", members: "12 members", last: "Jordan: Table 4 is ready", time: "2m", unread: 3 },
    { name: "Door staff", members: "4 members", last: "Maya’s party just arrived", time: "8m", unread: 0 },
    { name: "Managers", members: "3 members", last: "Cash handover completed", time: "24m", unread: 0 },
    { name: "Bar team", members: "6 members", last: "Low stock: premium vodka", time: "31m", unread: 1 },
  ])
  const openGroup = (name: string, last: string) => {
    setGroups((g) => g.map((x) => (x.name === name ? { ...x, unread: 0 } : x)))
    ui.sheet({ eyebrow: "TEAM CHAT", title: name, body: () => <Thread initial={[{ mine: false, text: last.includes(":") ? last.split(": ")[1] : last, who: last.includes(":") ? last.split(":")[0] : name, time: "Earlier" }]} placeholder={`Message ${name}…`} reply="On it." replyFrom={name === "Floor team" ? "Jordan" : name} /> })
  }
  return (
    <>
      <DetailHeader
        eyebrow="NOVA ROOM"
        title="Team messages"
        onBack={onBack}
        action={
          <button
            className="round-add"
            aria-label="New group"
            onClick={() =>
              ui.sheet({
                eyebrow: "TEAM CHAT",
                title: "New group",
                body: (close) => (
                  <QuickForm
                    submit="Create group"
                    fields={[
                      { id: "name", label: "Group name", placeholder: "e.g. VIP hosts", required: true },
                      { id: "who", label: "Members", options: ["All staff on shift", "Managers", "Servers", "Door staff"] },
                    ]}
                    onSubmit={(v) => {
                      setGroups((g) => [{ name: v.name.trim(), members: v.who, last: "Group created", time: "Now", unread: 0 }, ...g])
                      ui.toast(`${v.name.trim()} created`)
                      close()
                    }}
                  />
                ),
              })
            }
          >
            <Icon name="plus" />
          </button>
        }
      />
      <div className="message-list">
        {groups.map((row) => (
          <button className="message-row card" key={row.name} onClick={() => openGroup(row.name, row.last)}>
            <span className="message-avatar">
              {row.name
                .split(" ")
                .map((x) => x[0])
                .join("")
                .slice(0, 2)}
            </span>
            <span>
              <strong>
                {row.name} <small>{row.members}</small>
              </strong>
              <em>{row.last}</em>
            </span>
            <span>
              <small>{row.time}</small>
              {row.unread > 0 && <b>{row.unread}</b>}
            </span>
          </button>
        ))}
      </div>
    </>
  )
}

function NightlyReportDetail({ night, onBack }: { night: NightReport; onBack: () => void }) {
  const ui = useUI()
  const { arrived } = useStore()
  const [closed, setClosed] = useState(!night.live)
  const [confirm, setConfirm] = useState(false)
  const guests = night.live ? arrived : night.arrived
  return (
    <>
      <DetailHeader
        eyebrow={night.label.toUpperCase()}
        title="Nightly report"
        onBack={onBack}
        action={
          <button
            className="text-button"
            onClick={() =>
              ui.copy(
                toCsv([
                  ["Line", "Value"],
                  ["Gross sales", night.sales],
                  ["Card", night.card],
                  ["Cash", night.cash],
                  ["Prepaid", night.prepaid],
                  ["Guests arrived", guests],
                ]),
                "Report copied as CSV",
              )
            }
          >
            Export
          </button>
        }
      />
      {closed && (
        <div className="complete-banner">
          <Icon name="check" size={17} /> {night.closedBy ? `Closed by ${night.closedBy}` : "Night closed successfully"}
        </div>
      )}
      <div className="report-hero card">
        <span>{night.live && !closed ? "GROSS SALES SO FAR" : "GROSS SALES"}</span>
        <strong>{usd(night.sales)}</strong>
        <small>
          {guests} guests · {usd(night.sales / guests, true)} average spend
        </small>
      </div>
      <section>
        <div className="section-heading">
          <div>
            <span>TABLES & GUESTS</span>
            <h2>Attendance</h2>
          </div>
        </div>
        <Lines
          rows={[
            ["Tables booked", String(night.tablesBooked)],
            ["Tables seated", String(night.tablesSeated)],
            ["Guests expected", String(night.expected)],
            ["Guests arrived", String(guests)],
            ["Walk-ins", String(night.walkIns)],
          ]}
        />
      </section>
      <section>
        <div className="section-heading">
          <div>
            <span>PAYMENTS</span>
            <h2>Money received</h2>
          </div>
        </div>
        <Lines
          rows={[
            ["Card payments", usd(night.card)],
            ["Cash collected", usd(night.cash)],
            ["Prepaid bookings", usd(night.prepaid)],
            ["Refunds", usd(night.refunds)],
            ["Total", usd(night.sales)],
          ]}
        />
      </section>
      {!closed &&
        (confirm ? (
          <div className="confirm-box card">
            <strong>Close the night now?</strong>
            <small>Open orders will be moved to tomorrow’s report. You can't undo this in the demo.</small>
            <div className="dual-actions">
              <button className="secondary-action" onClick={() => setConfirm(false)}>
                Cancel
              </button>
              <button
                className="primary-action"
                onClick={() => {
                  setClosed(true)
                  ui.toast("Night closed")
                }}
              >
                Close night
              </button>
            </div>
          </div>
        ) : (
          <button className="primary-action full-action" onClick={() => setConfirm(true)}>
            Review and close night
          </button>
        ))}
    </>
  )
}

/* A failed payout is the scariest moment for an owner, so it says exactly what
   happened, that the money is safe, and the one thing to do next. Demo data. */
function PayoutIssue() {
  const ui = useUI()
  const [state, setState] = useState<"failed" | "retrying" | "sent">(() => "failed")
  const [bank, setBank] = useState("4021")
  if (state === "sent")
    return (
      <div className="payout-issue ok card" role="status">
        <span className="row-icon">
          <Icon name="check" />
        </span>
        <span>
          <strong>{usd(9420)} sent to bank ending {bank}</strong>
          <small>Arrives by Thursday, 22 August. Nothing else to do.</small>
        </span>
      </div>
    )
  return (
    <div className="payout-issue card" role="alert">
      <div className="payout-issue-head">
        <span className="row-icon warning">
          <Icon name="warning" />
        </span>
        <span>
          <strong>Payout of {usd(9420)} didn't go through</strong>
          <small>Tue, Aug 20 · Your bank returned it because the account ending {bank} is closed.</small>
        </span>
      </div>
      <p className="payout-safe">
        <Icon name="lock" size={14} /> Your money is safe. It's held in your BottlesUp balance until you choose where it goes.
      </p>
      <div className="payout-actions">
        <button
          className="primary-action"
          disabled={state === "retrying"}
          onClick={() =>
            ui.sheet({
              eyebrow: "PAYOUT ACCOUNT",
              title: "Update bank account",
              body: (close) => <BankForm close={close} onSave={(last4) => (setBank(last4), setState("retrying"), window.setTimeout(() => setState("sent"), 1400))} />,
            })
          }
        >
          {state === "retrying" ? "Sending…" : "Fix bank details"}
        </button>
        <button className="secondary-action" onClick={() => ui.sheet({ eyebrow: "SUPPORT", title: "Payout help", body: (close) => <PayoutSupport close={close} /> })}>
          Contact support
        </button>
      </div>
      <small className="srv-muted">Demo data. Real payouts need the payments backend.</small>
    </div>
  )
}

function BankForm({ close, onSave }: { close: () => void; onSave: (last4: string) => void }) {
  const [acct, setAcct] = useState("")
  const [routing, setRouting] = useState("")
  const [tried, setTried] = useState(false)
  const err = !/^\d{9}$/.test(routing) ? "Routing numbers are 9 digits." : !/^\d{6,17}$/.test(acct) ? "Account numbers are 6 to 17 digits." : null
  return (
    <div className="srv-sheet">
      <label className="field">
        <span>Routing number</span>
        <input inputMode="numeric" aria-invalid={tried && !/^\d{9}$/.test(routing)} value={routing} onChange={(e) => setRouting(e.target.value.replace(/\D/g, ""))} placeholder="9 digits" />
      </label>
      <label className="field">
        <span>Account number</span>
        <input inputMode="numeric" aria-invalid={tried && !/^\d{6,17}$/.test(acct)} value={acct} onChange={(e) => setAcct(e.target.value.replace(/\D/g, ""))} placeholder="6 to 17 digits" />
      </label>
      {tried && err && <p className="srv-error">{err}</p>}
      <p className="srv-muted">We'll resend the {usd(9420)} payout to this account right away. Future payouts go here too.</p>
      <button
        className="primary-action full-action"
        onClick={() => {
          setTried(true)
          if (err) return
          onSave(acct.slice(-4))
          close()
        }}
      >
        Save and resend payout
      </button>
    </div>
  )
}

function PayoutSupport({ close }: { close: () => void }) {
  const ui = useUI()
  return (
    <div className="srv-sheet">
      <Lines rows={[["Payout", "PO-20824 · $9,420"], ["Reason", "Account closed (bank code R02)"], ["Typical reply", "Under 1 hour, 24/7"]]} />
      <p className="srv-muted">The payout details are attached for you, so you won't need to explain from scratch.</p>
      <button className="primary-action full-action" onClick={() => (ui.toast("Sent to support. We'll reply in Messages."), close())}>
        Message support
      </button>
      <button className="secondary-action full-action" onClick={() => ui.toast("Calling isn't available in the demo")}>
        Call (800) 555-0142
      </button>
    </div>
  )
}

function PaymentsDetail({ onBack }: { onBack: () => void }) {
  const ui = useUI()
  const { txns } = useStore()
  const flagged = useFlagged()
  const [range, setRange] = useState<RangeKey>("Tonight")
  const [all, setAll] = useState(false)
  const r = RANGES[range]
  return (
    <>
      <DetailHeader eyebrow="BUSINESS" title="Payments & earnings" onBack={onBack} />
      <Segmented items={Object.keys(RANGES)} active={range} onChange={(v) => setRange(v as RangeKey)} />
      <div className="report-total">
        <span>NET EARNINGS · {r.period.toUpperCase()}</span>
        <strong>{usd(r.sales)}</strong>
        <p>
          <em>Next payout</em> Tuesday, 27 August
        </p>
      </div>
      <PayoutIssue />
      <div className="payment-breakdown card">
        <div className="donut" style={{ ["--card" as string]: `${pct(r.card, r.sales)}%`, ["--cash" as string]: `${pct(r.card + r.cash, r.sales)}%` }}>
          <span>
            <strong>{pct(r.card, r.sales)}%</strong>
            <small>Card</small>
          </span>
        </div>
        <div>
          {[
            ["Card", r.card],
            ["Cash", r.cash],
            ["Prepaid", r.prepaid],
          ].map(([k, v], i) => (
            <p key={k}>
              <i className={`legend-${i}`} />
              <span>{k}</span>
              <strong>{usd(v as number)}</strong>
            </p>
          ))}
        </div>
      </div>
      {flagged > 0 && (
        <button className="night-prep card" onClick={() => ui.sheet({ eyebrow: "PAYMENTS", title: "Review payments", body: (close) => <PaymentReviewBody close={close} /> })}>
          <span className="row-icon warning">
            <Icon name="warning" />
          </span>
          <span>
            <strong>{flagged} payment needs review</strong>
            <small>Approve or refund before closing the night.</small>
          </span>
          <Icon name="chevron" size={18} />
        </button>
      )}
      <section>
        <div className="section-heading">
          <div>
            <span>TONIGHT</span>
            <h2>Transactions</h2>
          </div>
          <button onClick={() => setAll(!all)}>{all ? "Show less" : "View all"}</button>
        </div>
        <div className="summary-list card">
          {(all ? txns : txns.slice(0, 3)).map((t) => (
            <button
              className="list-row"
              key={t.id}
              onClick={() =>
                t.flagged
                  ? ui.sheet({ eyebrow: "PAYMENTS", title: "Review payments", body: (close) => <PaymentReviewBody close={close} /> })
                  : ui.sheet({ eyebrow: "TRANSACTION", title: t.label, body: () => <Lines rows={[["Amount", usd(t.amount)], ["Method", t.method], ["Time", t.time], ["Status", "Settled"]]} /> })
              }
            >
              <span className={`row-icon ${t.flagged ? "warning" : ""}`}>
                <Icon name={t.flagged ? "warning" : "payments"} />
              </span>
              <span>
                <strong>{t.label}</strong>
                <small>
                  {t.method} · {t.time}
                  {t.flagged ? " · Needs review" : ""}
                </small>
              </span>
              <strong>{usd(t.amount)}</strong>
              <Icon name="chevron" size={16} />
            </button>
          ))}
        </div>
      </section>
    </>
  )
}

function TeamDetail({ onBack }: { onBack: () => void }) {
  const ui = useUI()
  const [tab, setTab] = useState("Team")
  const [team, setTeam] = usePersisted("bu-biz-owner-team", [
    ["Alex Morgan", "Owner", "On shift"],
    ["Jordan Blake", "Manager", "On shift"],
    ["Sam Patel", "Server", "On break"],
    ["Riley Chen", "Server", "On shift"],
    ["Dana Ortiz", "Server", "On shift"],
    ["Chris Lee", "Door staff", "On shift"],
    ["Taylor Kim", "Security", "Starts 10 PM"],
  ])
  const [invites, setInvites] = usePersisted("bu-biz-owner-invites", [
    ["jamie@example.com", "Manager", "Sent today"],
    ["morgan@example.com", "Door staff", "Expires in 3 days"],
  ])
  const list = tab === "Team" ? team : invites
  return (
    <>
      <DetailHeader
        eyebrow="NOVA ROOM"
        title="Team"
        onBack={onBack}
        action={
          <button
            className="round-add"
            aria-label="Invite"
            onClick={() =>
              ui.sheet({
                eyebrow: "TEAM",
                title: "Invite to Nova Room",
                body: (close) => (
                  <InviteBody
                    close={close}
                    roles={["Manager", "Server", "Door staff", "Security"]}
                    onInvite={(email, role) => {
                      setInvites((i) => [[email, role, "Sent just now"], ...i])
                      setTab("Invitations")
                      ui.toast(`Invitation sent to ${email}`)
                    }}
                  />
                ),
              })
            }
          >
            <Icon name="plus" />
          </button>
        }
      />
      <Segmented items={["Team", "Invitations"]} active={tab} onChange={setTab} />
      <p className="list-count">
        {tab === "Team" ? `Showing ${team.length} of ${NIGHT.teamScheduled} scheduled tonight` : `${invites.length} pending invitation${invites.length === 1 ? "" : "s"}`}
      </p>
      <div className="team-list">
        {list.map((r) => (
          <button
            className="team-row card"
            key={r[0]}
            onClick={() =>
              tab === "Team"
                ? ui.sheet({ eyebrow: r[1].toUpperCase(), title: r[0], body: (close) => <MemberBody name={r[0]} role={r[1]} status={r[2]} close={close} onRemove={r[1] === "Owner" ? undefined : () => setTeam((t) => t.filter((x) => x[0] !== r[0]))} /> })
                : ui.sheet({
                    eyebrow: "INVITATION",
                    title: r[0],
                    body: (close) => (
                      <Options
                        close={close}
                        items={[
                          { label: "Resend invitation", icon: "send", onSelect: () => ui.toast(`Invitation resent to ${r[0]}`) },
                          { label: "Cancel invitation", icon: "close", danger: true, onSelect: () => setInvites((i) => i.filter((x) => x[0] !== r[0])) },
                        ]}
                      />
                    ),
                  })
            }
          >
            <span className="member-avatar">{r[0].slice(0, 2).toUpperCase()}</span>
            <span>
              <strong>{r[0]}</strong>
              <small>{r[1]}</small>
            </span>
            <em className={r[2] !== "On shift" && tab === "Team" ? "away" : ""}>{r[2]}</em>
            <Icon name="chevron" size={16} />
          </button>
        ))}
      </div>
    </>
  )
}

function SettingsDetail({ onBack, appearance, onAppearance, onSignOut }: { onBack: () => void; appearance: Appearance; onAppearance: (a: Appearance) => void; onSignOut: () => void }) {
  const ui = useUI()
  return (
    <>
      <DetailHeader eyebrow="ACCOUNT" title="Settings" onBack={onBack} />
      <SettingsBody appearance={appearance} onAppearance={onAppearance} onSignOut={onSignOut} />
      <div className="settings-group">
        <span>ACCOUNT</span>
        {[
          ["Business details", () => ui.sheet({ eyebrow: "ACCOUNT", title: "Business details", body: (close) => <QuickForm submit="Save" fields={[{ id: "n", label: "Business name", value: "Northstar Hospitality", required: true }, { id: "e", label: "Billing email", value: "alex@northstar.example", type: "email", required: true }]} onSubmit={() => { ui.toast("Business details saved"); close() }} /> })],
          ["Billing and payouts", () => ui.sheet({ eyebrow: "ACCOUNT", title: "Billing and payouts", body: () => <Lines rows={[["Payout account", "Bank account ending 4021"], ["Schedule", "Weekly, every Tuesday"], ["Next payout", "Tuesday, 27 August"], ["Plan", "BottlesUp Business Pro"]]} /> })],
          ["Privacy and security", () => ui.sheet({ eyebrow: "ACCOUNT", title: "Privacy and security", body: () => <Lines rows={[["Two-step sign-in", "On · Authenticator app"], ["Signed-in devices", "2 devices"], ["Last sign-in", "Today, 6:58 PM"]]} /> })],
          ["Help and support", () => ui.sheet({ eyebrow: "HELP", title: "Help and support", body: () => <SupportBody /> })],
        ].map(([x, fn]) => (
          <button className="list-row card" key={x as string} onClick={fn as () => void}>
            <span>
              <strong>{x as string}</strong>
            </span>
            <Icon name="chevron" size={17} />
          </button>
        ))}
      </div>
    </>
  )
}

function AgreementReviewBody({ close }: { close: () => void }) {
  const { agreement, setAgreement } = useStore()
  const ui = useUI()
  return (
    <>
      <p className="page-intro">Midnight Social wants to run Neon Garden at Nova Room on Saturday, 31 August.</p>
      <Lines
        rows={[
          ["Status", agreement],
          ["Table payments", "Organizer receives"],
          ["Bar-sales share", "15% above $8,000"],
          ["Minimum spend", "$5,000"],
          ["Security", "Venue supplies"],
          ["Settlement", "Within 5 business days"],
          ["Cancellation", "14 days’ notice"],
        ]}
      />
      {agreement === "Pending approval" && (
        <div className="dual-actions">
          <button
            className="secondary-action"
            onClick={() => {
              setAgreement("Changes requested")
              ui.toast("Change request sent to Midnight Social")
              close()
            }}
          >
            Request changes
          </button>
          <button
            className="primary-action"
            onClick={() => {
              setAgreement("Approved")
              ui.toast("Agreement approved. Neon Garden can go on sale.")
              close()
            }}
          >
            Approve terms
          </button>
        </div>
      )}
    </>
  )
}

export default function OwnerApp({ theme, onTheme, appearance, onAppearance, onSwitch }: { theme: Theme; onTheme: () => void; appearance: Appearance; onAppearance: (a: Appearance) => void; onSwitch: () => void }) {
  const ui = useUI()
  const { agreement } = useStore()
  const [screen, setScreen] = useState<Screen>("overview")
  const [detail, setDetail] = useState<Detail | null>(null)
  const [extraVenues, setExtraVenues] = useState<string[]>([])
  const [setup, setSetup] = useState<Record<VenueId, Record<SetupItem, boolean>>>({
    active: Object.fromEntries(SETUP_ITEMS.map((i) => [i, true])) as Record<SetupItem, boolean>,
    sky: Object.fromEntries(SETUP_ITEMS.map((i, n) => [i, n < 3])) as Record<SetupItem, boolean>,
  })
  const [photos, setPhotosAll] = useState<Record<VenueId, Photo[]>>({ active: ACTIVE_LOUNGE_PHOTOS, sky: [] })
  const go = (d: Detail | null) => {
    setDetail(d)
    window.scrollTo({ top: 0 })
  }
  const agreementSheet = () => ui.sheet({ eyebrow: "AGREEMENT · NEON GARDEN", title: "Midnight Social", body: (close) => <AgreementReviewBody close={close} /> })
  const eventsSheet = () =>
    ui.sheet({
      eyebrow: "NOVA ROOM",
      title: "Upcoming events",
      body: (close) => (
        <Options
          close={close}
          items={[
            { label: "Neon Garden · Sat, 31 Aug", detail: `Midnight Social · Agreement: ${agreement}`, icon: "events", onSelect: agreementSheet },
            { label: "Summer Signal · Fri, 11 Oct", detail: "Midnight Social · Approved", icon: "events", onSelect: () => ui.toast("Summer Signal is approved and ready for review by BottlesUp") },
          ]}
        />
      ),
    })
  const addVenue = () =>
    ui.sheet({
      eyebrow: "NEW VENUE",
      title: "Add a venue",
      body: (close) => (
        <QuickForm
          submit="Create draft"
          fields={[
            { id: "name", label: "Venue name", placeholder: "e.g. Harbour Club", required: true },
            { id: "addr", label: "Address", placeholder: "Street and number", required: true },
          ]}
          onSubmit={(v) => {
            setExtraVenues((x) => [...x, v.name.trim()])
            ui.toast(`${v.name.trim()} draft created`)
            close()
          }}
        />
      ),
    })
  const accountSheet = () =>
    ui.sheet({
      eyebrow: "SIGNED IN AS",
      title: "Alex Morgan",
      body: (close) => (
        <Options
          close={close}
          items={[
            { label: "Settings", detail: "Appearance, notifications, account", icon: "settings", onSelect: () => go({ kind: "settings" }) },
            { label: "Switch role", detail: "Choose another demo role", icon: "arrow", onSelect: onSwitch },
            { label: "Sign out", icon: "close", danger: true, onSelect: onSwitch },
          ]}
        />
      ),
    })
  const back = () => go(null)
  let body: ReactNode
  if (detail?.kind === "bookings") body = <BookingsDetail onBack={back} />
  else if (detail?.kind === "expected") body = <ExpectedDetail onBack={back} />
  else if (detail?.kind === "arrived") body = <ArrivedDetail onBack={back} />
  else if (detail?.kind === "sales") body = <SalesDetail onBack={back} openPayouts={() => go({ kind: "payments" })} />
  else if (detail?.kind === "venue")
    body = <VenueDetail venue={detail.venue} onBack={back} setup={setup[detail.venue]} markDone={(i) => setSetup((s) => ({ ...s, [detail.venue]: { ...s[detail.venue], [i]: true } }))} photos={photos[detail.venue]} setPhotos={(fn) => setPhotosAll((all) => ({ ...all, [detail.venue]: fn(all[detail.venue]) }))} />
  else if (detail?.kind === "messages") body = <MessagesDetail onBack={back} />
  else if (detail?.kind === "report") body = <NightlyReportDetail night={NIGHTS.find((n) => n.id === detail.night)!} onBack={back} />
  else if (detail?.kind === "payments") body = <PaymentsDetail onBack={back} />
  else if (detail?.kind === "team") body = <TeamDetail onBack={back} />
  else if (detail?.kind === "settings") body = <SettingsDetail onBack={back} appearance={appearance} onAppearance={onAppearance} onSignOut={onSwitch} />
  else if (screen === "overview") body = <Overview open={go} setScreen={setScreen} />
  else if (screen === "venues") body = <Venues open={go} setup={setup} addVenue={addVenue} extra={extraVenues} />
  else if (screen === "tonight") body = <Tonight open={go} />
  else if (screen === "reports") body = <Reports open={go} />
  else body = <More open={go} agreementSheet={agreementSheet} eventsSheet={eventsSheet} />
  return (
    <div className={`app-shell theme-${theme}`}>
      <div className="topbar">
        <button className="workspace-switch" onClick={onSwitch} aria-label="Switch role">
          <span className="brand-mark">
            <img src="/bottlesup-logo.png" alt="" />
          </span>
          <span>
            <strong>BottlesUp</strong>
            <small>Northstar Hospitality · Owner</small>
          </span>
          <Icon name="chevron" size={17} />
        </button>
        <div className="top-actions">
          <ThemeToggle theme={theme} onToggle={onTheme} />
          <button className="avatar" aria-label="Account" onClick={accountSheet}>
            <Icon name="person" size={19} />
          </button>
        </div>
      </div>
      <main className="page-content">{body}</main>
      <MessagesFab viewer="owner" hideButton={!!detail || (screen !== "overview" && screen !== "tonight")} />
      <VenuePanels who="owner" />
      <nav className="bottom-nav" aria-label="Primary navigation">
        {navItems.map((item) => (
          <button
            key={item.id}
            className={screen === item.id && !detail ? "active" : ""}
            aria-current={screen === item.id ? "page" : undefined}
            onClick={() => {
              setScreen(item.id)
              go(null)
            }}
          >
            <Icon name={item.icon} size={21} />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  )
}
