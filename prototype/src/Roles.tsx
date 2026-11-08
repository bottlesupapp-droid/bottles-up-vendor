import { useState, type ReactNode } from "react"
import { NIGHT, bookingGuests, pct, usd } from "./data"
import { ErrorBoundary, Icon, Lines, Options, QuickForm, ThemeToggle, Thread, clock, useUI, type Appearance, type IconName, type Theme } from "./kit"
import {
  AssignServersBody,
  BookingList,
  Empty,
  InviteBody,
  MemberBody,
  OfflineBody,
  PaymentReviewBody,
  RowList,
  SearchBox,
  Segmented,
  SettingsBody,
  ShiftBody,
  SupportBody,
  TableWalkInBody,
  useFlagged,
  useUnassigned,
  type Row,
} from "./shared"
import { useStore } from "./store"
import { ServerApp, useServer, useServerBadges } from "./Server"
import { useGuests, useGuestBadge } from "./Guests"
import { MessagesFab } from "./Messages"
import { VenuePanels, useVenueOps } from "./VenueOps"
import { DoorGuests } from "./DoorGuests"

export type StaffRole = "venue-manager" | "door-staff" | "server" | "ambassador" | "event-lead"

type Ctx = { appearance: Appearance; onAppearance: (a: Appearance) => void; onSwitch: () => void; setTab: (t: string) => void }

const CONFIGS: Record<StaffRole, { label: string; context: string; place: string; hours: string; tabs: { id: string; label: string; icon: IconName }[] }> = {
  "venue-manager": {
    label: "Venue Manager",
    context: "Nova Room · Tonight",
    place: "Nova Room · Manager",
    hours: "6:00 PM – 3:00 AM",
    tabs: [
      { id: "today", label: "Today", icon: "home" },
      { id: "bookings", label: "Bookings", icon: "event" },
      { id: "tonight", label: "Tonight", icon: "clock" },
      { id: "team", label: "Team", icon: "team" },
      { id: "more", label: "More", icon: "more" },
    ],
  },
  "door-staff": {
    label: "Door Staff",
    context: "Nova Room · Main entrance",
    place: "Nova Room · Main entrance",
    hours: "8:30 PM – 2:30 AM",
    tabs: [
      { id: "scan", label: "Scan", icon: "scan" },
      { id: "guests", label: "Guests", icon: "guests" },
      { id: "walkins", label: "Walk-ins", icon: "plus" },
      { id: "more", label: "More", icon: "more" },
    ],
  },
  server: {
    label: "Server",
    context: "Nova Room · Section B",
    place: "Nova Room · Main floor, section B",
    hours: "7:00 PM – 2:00 AM",
    tabs: [
      { id: "tables", label: "My Tables", icon: "venue" },
      { id: "orders", label: "Orders", icon: "orders" },
      { id: "team", label: "Team", icon: "team" },
      { id: "more", label: "More", icon: "more" },
    ],
  },
  ambassador: {
    label: "Ambassador",
    context: "Alex Morgan · Midnight Social",
    place: "Midnight Social · Ambassador",
    hours: "Flexible · events you're assigned to",
    tabs: [
      { id: "home", label: "Home", icon: "home" },
      { id: "events", label: "Events", icon: "event" },
      { id: "share", label: "Share", icon: "share" },
      { id: "earnings", label: "Earnings", icon: "earnings" },
      { id: "more", label: "More", icon: "more" },
    ],
  },
  "event-lead": {
    label: "Event Lead",
    context: "Neon Garden · Event team",
    place: "Neon Garden · Event Lead",
    hours: "Event night: Sat, 31 August · 8:00 PM – 2:30 AM",
    tabs: [
      { id: "overview", label: "Overview", icon: "home" },
      { id: "events", label: "Events", icon: "event" },
      { id: "team", label: "Team", icon: "team" },
      { id: "earnings", label: "Earnings", icon: "earnings" },
      { id: "more", label: "More", icon: "more" },
    ],
  },
}

function Page({ heading, eyebrow, action, onAction }: { heading: string; eyebrow: string; action?: string; onAction?: () => void }) {
  return (
    <div className="page-title">
      <div>
        <span>{eyebrow}</span>
        <h1>{heading}</h1>
      </div>
      {action && (
        <button className="page-main-action" onClick={onAction}>
          {action}
        </button>
      )}
    </div>
  )
}

function Stat({ label, value, note }: { label: string; value: string; note: string }) {
  return (
    <div className="metric card">
      <div className="metric-top">
        <span>{label}</span>
      </div>
      <strong>{value}</strong>
      <small>{note}</small>
    </div>
  )
}

function Section({ eyebrow, title, children, action }: { eyebrow: string; title: string; children: ReactNode; action?: ReactNode }) {
  return (
    <section>
      <div className="section-heading">
        <div>
          <span>{eyebrow}</span>
          <h2>{title}</h2>
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}

function MoreScreen({ role, ctx }: { role: StaffRole; ctx: Ctx }) {
  const ui = useUI()
  const ops = useVenueOps()
  const c = CONFIGS[role]
  return (
    <>
      <Page heading="More" eyebrow={c.label.toUpperCase()} />
      {role === "venue-manager" && (
        <>
          <p className="srv-muted os-note">Assigned venue: Nova Room. You have the same venue tools as the owner here.</p>
          <RowList
            rows={[
              { icon: "plus", title: "Create event", desc: "One-time or weekly events at Nova Room", onOpen: () => ops.openPanel({ kind: "events", create: true }) },
              { icon: "event", title: "Events", desc: "Series, dates, tickets and guest lists", onOpen: () => ops.openPanel({ kind: "events" }) },
              { icon: "star", title: "VIP clients", desc: "Contacts, perks, hosts and private notes", onOpen: () => ops.openPanel({ kind: "vip" }) },
              { icon: "venue", title: "Venue page, tables and menu", desc: "Hours, photos, tables, bottles and signs", onOpen: () => ops.openPanel({ kind: "tools" }) },
              { icon: "chart", title: "Venue reports", desc: "Sales, expected guests and check-ins", onOpen: () => ops.openPanel({ kind: "reports" }) },
            ]}
          />
        </>
      )}
      <RowList
        rows={[
          { icon: "clock", title: "Shift details", desc: "Schedule, breaks, and assigned location", onOpen: () => ui.sheet({ eyebrow: c.label.toUpperCase(), title: "Shift details", body: () => <ShiftBody place={c.place} hours={c.hours} /> }) },
          { icon: "chat", title: "Support", desc: "Help articles, chat, and request a call", onOpen: () => ui.sheet({ eyebrow: "HELP", title: "Support", body: () => <SupportBody /> }) },
          { icon: "settings", title: "Settings", desc: "Appearance, notifications, and account", onOpen: () => ui.sheet({ eyebrow: "ACCOUNT", title: "Settings", body: () => <SettingsBody appearance={ctx.appearance} onAppearance={ctx.onAppearance} onSignOut={ctx.onSwitch} /> }) },
          { icon: "warning", title: "Offline demo", desc: "Preview what happens without a connection", onOpen: () => ui.sheet({ eyebrow: "DEMO", title: "Offline mode", body: () => <OfflineBody /> }) },
        ]}
      />
      <button className="signout-button" onClick={ctx.onSwitch}>
        Sign out of demo
      </button>
    </>
  )
}

/* ---------------- Venue Manager ---------------- */

const OPENING_TASKS = ["Bar stocked and counted", "Floor plan and tables reset", "Card readers charged", "Security briefed", "Music and lighting checked", "Guest list printed for the door"]

function ChecklistBody({ done, setDone }: { done: boolean[]; setDone: (d: boolean[]) => void }) {
  const [local, setLocal] = useState(done)
  return (
    <div className="checklist card">
      {OPENING_TASKS.map((t, i) => (
        <button
          key={t}
          aria-pressed={local[i]}
          onClick={() => {
            const next = local.map((x, j) => (j === i ? !x : x))
            setLocal(next)
            setDone(next)
          }}
        >
          <span className={local[i] ? "check done" : "check"}>{local[i] ? <Icon name="check" size={15} /> : null}</span>
          <span>
            <strong>{t}</strong>
          </span>
          <em>{local[i] ? "Done" : "To do"}</em>
        </button>
      ))}
    </div>
  )
}

function Manager({ tab, ctx }: { tab: string; ctx: Ctx }) {
  const ui = useUI()
  const store = useStore()
  const unassigned = useUnassigned()
  const flagged = useFlagged()
  const guests = useGuests()
  const guestCount = useGuestBadge()
  const [tasks, setTasks] = useState([true, true, true, false, true, true])
  const [team, setTeam] = useState([
    ["Jordan Blake", "Floor manager", "On shift"],
    ["Sam Patel", "Server", "On break"],
    ["Riley Chen", "Server", "On shift"],
    ["Dana Ortiz", "Server", "On shift"],
    ["Chris Lee", "Door staff", "On shift"],
  ])
  const [shiftOffered, setShiftOffered] = useState(false)
  const done = tasks.filter(Boolean).length
  const seated = store.bookings.filter((b) => b.status === "Arrived").length
  const checklist = () => ui.sheet({ eyebrow: "NOVA ROOM", title: "Opening checklist", body: () => <ChecklistBody done={tasks} setDone={setTasks} /> })
  const assign = () => ui.sheet({ eyebrow: "NOVA ROOM", title: "Assign servers", body: (close) => <AssignServersBody close={close} /> })
  const review = () => ui.sheet({ eyebrow: "PAYMENTS", title: "Review payments", body: (close) => <PaymentReviewBody close={close} /> })
  const walkIn = () => ui.sheet({ eyebrow: "TONIGHT · NOVA ROOM", title: "Add walk-in", body: (close) => <TableWalkInBody close={close} /> })
  const orders = () =>
    ui.sheet({
      eyebrow: "BAR",
      title: "Orders preparing",
      body: () => (
        <Lines
          rows={[
            ["#1842 · Table 4", "8 min · $420"],
            ["#1839 · Table 8", "5 min · $310"],
            ["#1838 · Table 15", "12 min · $640"],
            ["#1837 · Table 1", "3 min · $96"],
          ]}
        />
      ),
    })

  if (tab === "bookings")
    return (
      <>
        <Page
          heading="Bookings"
          eyebrow="NOVA ROOM · TONIGHT"
          action="Add booking"
          onAction={() =>
            ui.sheet({
              eyebrow: "TONIGHT",
              title: "Add booking",
              body: (close) => (
                <QuickForm
                  submit="Add booking"
                  fields={[
                    { id: "name", label: "Guest name", required: true, placeholder: "Enter a name" },
                    { id: "time", label: "Arrival time", options: ["11:45 PM", "12:00 AM", "12:30 AM"] },
                    { id: "size", label: "Guests", value: "4", type: "number", required: true },
                  ]}
                  onSubmit={(v) => {
                    store.setBookings((l) => [...l, { id: "m" + Date.now(), name: v.name.trim(), time: v.time, table: "Table 6", guests: Math.max(1, parseInt(v.size) || 1), payment: "Pay at venue", status: "Confirmed", server: null }])
                    ui.toast(`Booking added for ${v.name.trim()} at ${v.time}`)
                    close()
                  }}
                />
              ),
            })
          }
        />
        <BookingList initialFilter="Confirmed" />
      </>
    )
  if (tab === "tonight")
    return (
      <>
        <Page heading="Tonight" eyebrow="NOVA ROOM" action="Add walk-in" onAction={walkIn} />
        <div className="role-metrics">
          <Stat label="Tables seated" value={`${seated} / ${NIGHT.tablesTotal}`} note={`${pct(seated, NIGHT.tablesTotal)}% occupied`} />
          <Stat label="Open orders" value={String(NIGHT.openOrders)} note={`${usd(NIGHT.openOrdersValue)} value`} />
        </div>
        <Section eyebrow="FLOOR OPERATIONS" title="Needs attention">
          {unassigned + flagged + guestCount === 0 ? (
            <p className="all-clear card">All clear. Orders are moving.</p>
          ) : null}
          <RowList
            rows={[
              ...(guestCount ? [{ icon: "chat", tone: "warning", title: "Guests need you", desc: "Messages, help requests, bottle signs", badge: String(guestCount), onOpen: () => guests.setOpen(true) } as Row] : []),
              ...(unassigned ? [{ icon: "warning", tone: "warning", title: `${unassigned} table${unassigned === 1 ? "" : "s"} need a server`, desc: "Assign from the team", onOpen: assign } as Row] : []),
              { icon: "orders", title: "4 orders preparing", desc: "Longest wait is 12 minutes", onOpen: orders },
              ...(flagged ? [{ icon: "earnings", tone: "warning", title: `${flagged} payment flagged`, desc: "Manager review permitted", onOpen: review } as Row] : []),
            ]}
          />
        </Section>
      </>
    )
  if (tab === "team")
    return (
      <>
        <Page
          heading="Team"
          eyebrow="TONIGHT’S SHIFT"
          action="Invite"
          onAction={() =>
            ui.sheet({
              eyebrow: "NOVA ROOM",
              title: "Invite to the team",
              body: (close) => (
                <InviteBody
                  close={close}
                  roles={["Server", "Door staff", "Security", "Bartender"]}
                  onInvite={(email, role) => {
                    setTeam((t) => [...t, [email, role, "Invited"]])
                    ui.toast(`Invitation sent to ${email}`)
                  }}
                />
              ),
            })
          }
        />
        <div className="role-metrics">
          <Stat label="On shift" value={String(NIGHT.teamOnShift)} note={`of ${NIGHT.teamScheduled} scheduled`} />
          <Stat label="Coverage" value={`${pct(NIGHT.teamOnShift, NIGHT.teamScheduled)}%`} note="2 arrive at 10 PM" />
        </div>
        <RowList
          rows={[
            ...team.map(
              (m) =>
                ({
                  icon: m[1].includes("Server") ? "server" : m[1].includes("Door") ? "door" : "team",
                  title: m[0],
                  desc: `${m[1]} · ${m[2]}`,
                  onOpen: () => ui.sheet({ eyebrow: m[1].toUpperCase(), title: m[0], body: (close) => <MemberBody name={m[0]} role={m[1]} status={m[2]} close={close} onRemove={() => setTeam((t) => t.filter((x) => x[0] !== m[0]))} /> }),
                }) as Row,
            ),
            {
              icon: "warning",
              tone: shiftOffered ? undefined : "warning",
              title: "Open server shift",
              desc: shiftOffered ? "Offered to 3 servers · waiting for a reply" : "10 PM–2 AM · Needs cover",
              onOpen: shiftOffered
                ? undefined
                : () => {
                    setShiftOffered(true)
                    ui.toast("Shift offered to 3 available servers")
                  },
            },
          ]}
        />
        <p className="list-count">
          Showing {team.length} of {NIGHT.teamOnShift} on shift. See the owner's Team page for everyone.
        </p>
      </>
    )
  if (tab === "more") return <MoreScreen role="venue-manager" ctx={ctx} />
  return (
    <>
      <Page heading="Today" eyebrow={NIGHT.eyebrow} action="Opening checklist" onAction={checklist} />
      <div className="role-hero card">
        <span>SHIFT STATUS · LIVE {NIGHT.now}</span>
        <h2>Service is running</h2>
        <p>
          Nova Room · Doors opened {NIGHT.doorsOpened}
        </p>
        <button onClick={checklist}>
          Opening checklist · {done} of {OPENING_TASKS.length} done <Icon name="arrow" />
        </button>
      </div>
      <div className="role-metrics">
        <Stat label="Reservations" value={String(store.bookings.length)} note={`${bookingGuests(store.bookings)} guests at tables`} />
        <Stat label="Arrived" value={String(store.arrived)} note={`${pct(store.arrived, NIGHT.expected)}% of ${NIGHT.expected} checked in`} />
        <Stat label="Staffing" value={`${NIGHT.teamOnShift} / ${NIGHT.teamScheduled}`} note="2 starting later" />
        <Stat label="Sales so far" value={usd(NIGHT.sales)} note="Demo activity" />
      </div>
      <Section eyebrow="URGENT" title="Needs you now">
        {unassigned === 0 && tasks[3] ? (
          <p className="all-clear card">All clear.</p>
        ) : (
          <RowList
            rows={[
              ...(guestCount ? [{ icon: "chat", tone: "warning", title: "Guests need you", desc: "Messages, help requests, bottle signs", badge: String(guestCount), onOpen: () => guests.setOpen(true) } as Row] : []),
              ...(unassigned ? [{ icon: "warning", tone: "warning", title: "Assign tables", desc: `${unassigned} seated table${unassigned === 1 ? "" : "s"} without a server`, badge: String(unassigned), onOpen: assign } as Row] : []),
              ...(!tasks[3]
                ? [
                    {
                      icon: "team",
                      title: "Confirm security brief",
                      desc: "4 team members",
                      badge: "1",
                      onOpen: () => {
                        setTasks((t) => t.map((x, i) => (i === 3 ? true : x)))
                        ui.toast("Security brief confirmed")
                      },
                    } as Row,
                  ]
                : []),
            ]}
          />
        )}
      </Section>
    </>
  )
}

/* ---------------- Door Staff ---------------- */

function Door({ tab, ctx }: { tab: string; ctx: Ctx }) {
  const ui = useUI()
  const store = useStore()
  const [entrance, setEntrance] = useState("Main entrance")
  const [scan, setScan] = useState<{ state: "ready" | "valid" | "invalid" | "done"; name?: string; detail?: string; time?: string; title?: string; action?: string }>({ state: "ready" })
  const [recent, setRecent] = useState<[string, string][]>([
    ["Alex Turner", "Guest list · 9:36 PM"],
    ["Maya Chen", "Table 4 · 9:31 PM"],
  ])
  const [q, setQ] = useState("")
  const admit = (id: string, count: number) => {
    const p = store.parties.find((x) => x.id === id)!
    const n = Math.min(count, p.size - p.inside)
    if (n <= 0) return
    store.setParties((list) => list.map((x) => (x.id === id ? { ...x, inside: x.inside + n } : x)))
    store.setArrived((a) => a + n)
    setRecent((r) => [[p.name, `${p.type.split(" · ")[0]} · ${clock()}`] as [string, string], ...r].slice(0, 5))
    return { p, n }
  }
  const partySheet = (id: string) => {
    const p = store.parties.find((x) => x.id === id)!
    ui.sheet({
      eyebrow: entrance.toUpperCase(),
      title: p.name,
      body: (close) => (
        <>
          <Lines
            rows={[
              ["Booking", p.type],
              ["Party size", String(p.size)],
              ["Inside", `${p.inside} of ${p.size}`],
            ]}
          />
          <div className="dual-actions">
            <button
              className="secondary-action"
              disabled={p.inside >= p.size}
              onClick={() => {
                admit(id, 1)
                ui.toast(`1 guest admitted for ${p.name}`)
                close()
              }}
            >
              Admit 1
            </button>
            <button
              className="primary-action"
              disabled={p.inside >= p.size}
              onClick={() => {
                const r = admit(id, p.size)
                ui.toast(`${r?.n ?? 0} admitted for ${p.name}`)
                close()
              }}
            >
              {p.inside >= p.size ? "Everyone is in" : `Admit all ${p.size - p.inside}`}
            </button>
          </div>
        </>
      ),
    })
  }
  if (tab === "guests")
    return (
      <>
        <Page heading="Guests" eyebrow={`NOVA ROOM · ${entrance.toUpperCase()}`} />
        <DoorGuests entrance={entrance} admit={(id, n) => void admit(id, n)} />
      </>
    )
  if (tab === "walkins")
    return (
      <>
        <Page
          heading="Walk-ins"
          eyebrow={entrance.toUpperCase()}
          action="Add walk-in"
          onAction={() =>
            ui.sheet({
              eyebrow: "DOOR · $20 COVER PER GUEST",
              title: "Add walk-in",
              body: (close) => (
                <QuickForm
                  submit="Charge and admit"
                  fields={[
                    { id: "name", label: "Name", placeholder: "Guest name", required: true },
                    { id: "guests", label: "Guests", value: "2", type: "number", required: true },
                    { id: "method", label: "Payment", options: ["Card", "Cash"] },
                  ]}
                  onSubmit={(v) => {
                    const g = Math.max(1, parseInt(v.guests) || 1)
                    store.setWalkIns((w) => [{ name: v.name.trim(), guests: g, method: v.method, amount: g * 20, time: clock() }, ...w])
                    store.setArrived((a) => a + g)
                    ui.toast(`${v.name.trim()} · ${g} admitted · ${usd(g * 20)} ${v.method.toLowerCase()}`)
                    close()
                  }}
                />
              ),
            })
          }
        />
        <Section eyebrow="TONIGHT" title={`Door entries · ${store.walkIns.reduce((s, w) => s + w.guests, 0)} guests`}>
          <RowList
            rows={store.walkIns.map(
              (w) =>
                ({
                  icon: "check",
                  title: `${w.name} · ${w.guests} guest${w.guests === 1 ? "" : "s"}`,
                  desc: `${w.method} · ${usd(w.amount)} · ${w.time}`,
                  onOpen: () => ui.sheet({ eyebrow: "DOOR ENTRY", title: w.name, body: () => <Lines rows={[["Guests", String(w.guests)], ["Cover", `${usd(w.amount)} (${usd(20)} each)`], ["Payment", w.method], ["Time", w.time], ["Entrance", entrance]]} /> }),
                }) as Row,
            )}
          />
        </Section>
      </>
    )
  if (tab === "more") return <MoreScreen role="door-staff" ctx={ctx} />
  const next = store.parties.find((p) => p.inside < p.size)
  return (
    <>
      <Page heading="Scan tickets" eyebrow={`NOVA ROOM · ${store.arrived} IN`} />
      <label className="field">
        <span>ENTRANCE</span>
        <select value={entrance} onChange={(e) => setEntrance(e.target.value)}>
          <option>Main entrance</option>
          <option>VIP entrance</option>
        </select>
      </label>
      <div className={`scanner card state-${scan.state === "done" ? "valid" : scan.state}`}>
        <span className="scan-frame">
          <i />
          <i />
          <i />
          <i />
          <Icon name={scan.state === "valid" || scan.state === "done" ? "check" : scan.state === "invalid" ? "warning" : "scan"} size={42} />
        </span>
        {scan.state === "ready" && (
          <>
            <h2>Ready to scan</h2>
            <p>Position the guest’s QR code inside the frame.</p>
          </>
        )}
        {scan.state === "valid" && (
          <>
            <h2>Valid ticket</h2>
            <p>
              {scan.name} · {scan.detail}
            </p>
            <strong>Checked in at {scan.time}</strong>
          </>
        )}
        {scan.state === "done" && (
          <>
            <h2>Everyone on the list is in</h2>
            <p>New arrivals can be added as walk-ins.</p>
          </>
        )}
        {scan.state === "invalid" && (
          <>
            <h2>{scan.title ?? "Unable to verify"}</h2>
            <p>{scan.detail ?? "This ticket is for another event. It remains unverified."}</p>
            <strong>{scan.action ?? "Do not admit"}</strong>
          </>
        )}
      </div>
      <div className="scan-actions">
        <button
          className="secondary-action"
          onClick={() =>
            ui.sheet({
              eyebrow: "DEMO",
              title: "Test a problem pass",
              body: (close) => (
                <Options
                  close={close}
                  items={[
                    { label: "Cancelled pass", detail: "Removed by the booking host", icon: "close", onSelect: () => setScan({ state: "invalid", title: "Pass cancelled", detail: "Chris Morgan · Halo Booth (NR-2841). The host removed this guest at 9:12 PM.", action: "Do not admit · offer to contact the host" }) },
                    { label: "Refunded ticket", detail: "Money returned to the guest", icon: "earnings", onSelect: () => setScan({ state: "invalid", title: "Ticket refunded", detail: "Jordan Ellis · General admission. Refunded on Aug 20.", action: "Do not admit · guest can buy a new ticket" }) },
                    { label: "Already used", detail: "Scanned earlier tonight", icon: "check", onSelect: () => setScan({ state: "invalid", title: "Already checked in", detail: "Noah Reid · Halo Booth. Scanned at 11:52 PM at Main entrance.", action: "Check the guest's ID before re-admitting" }) },
                    { label: "General admission after cut-off", detail: "Entry before 11:30 PM only", icon: "clock", onSelect: () => setScan({ state: "invalid", title: "Entry window closed", detail: "General admission is valid until 11:30 PM. Table guests are not affected.", action: "Ask a manager to override" }) },
                    { label: "Transferred pass", detail: "Sent to someone else", icon: "share", onSelect: () => setScan({ state: "invalid", title: "Pass was transferred", detail: "Maya Chen · Halo Booth (NR-2841). Maya sent this pass to Sofia Bell at 8:40 PM, so this copy no longer works.", action: "Ask for the pass in Sofia Bell’s app, or check the guest list" }) },
                    { label: "Wrong event", detail: "Ticket for another night", icon: "warning", onSelect: () => setScan({ state: "invalid", title: "Different event", detail: "This ticket is for Neon Garden, Sat, Aug 31.", action: "Do not admit" }) },
                  ]}
                />
              ),
            })
          }
        >
          Test a problem pass
        </button>
        <button
          className="primary-action"
          onClick={() => {
            if (!next) return setScan({ state: "done" })
            const r = admit(next.id, 1)!
            setScan({ state: "valid", name: r.p.name, detail: `${r.p.type.split(" · ")[0]} · guest ${r.p.inside + 1} of ${r.p.size}`, time: clock() })
          }}
        >
          Scan demo ticket
        </button>
      </div>
      <Section eyebrow="RECENT ACTIVITY" title="Last check-ins">
        <RowList rows={recent.map(([n, d], i) => ({ icon: "check", title: n, desc: d, onOpen: undefined, badge: i === 0 && scan.state === "valid" ? "New" : undefined }) as Row)} />
      </Section>
    </>
  )
}

/* ---------------- Ambassador & Event Lead ---------------- */

const LINK = "https://bottlesup.com/e/neon-garden?ref=ALEX20"

function EarningsBody({ status }: { status: string }) {
  const rows: Record<string, [string, string][]> = {
    Pending: [["Neon Garden · 12 tickets", "$96.00"], ["Expected", "After Sat, 31 August"]],
    Confirmed: [["Spring Social · 30 tickets", "$240.00"], ["Warehouse Sessions · 20 tickets", "$160.00"], ["3 table bookings", "$28.00"]],
    Reversed: [["Spring Social · 3 refunds", "−$24.00"]],
    Paid: [["Payout 17 Aug", "$1,240.00"], ["Sent to", "Bank account ending 8812"]],
  }
  return <Lines rows={rows[status]} />
}

function Earnings({ team }: { team: boolean }) {
  const ui = useUI()
  return (
    <>
      <Page heading="Earnings" eyebrow={team ? "EVENT LEAD · SAMPLE" : "AMBASSADOR · SAMPLE"} />
      <div className="earnings-total">
        <span>{team ? "PERSONAL EARNINGS" : "AVAILABLE EARNINGS"}</span>
        <strong>{team ? "$304.00" : "$428.00"}</strong>
        <small>Demo financial activity · CAD</small>
      </div>
      {team && (
        <div className="team-total card">
          <span>Permitted team total</span>
          <strong>$2,416.00</strong>
          <small>Not your personal payout</small>
        </div>
      )}
      <RowList
        rows={(
          [
            ["clock", "Pending", "$96.00 · Awaiting event completion"],
            ["check", "Confirmed", team ? "$304.00 · Approved commission" : "$428.00 · Approved commission"],
            ["warning", "Reversed", "$24.00 · Refunded tickets"],
            ["earnings", "Paid", "$1,240.00 · Last payout 17 Aug"],
          ] as [IconName, string, string][]
        ).map(([icon, title, desc]) => ({ icon, title, desc, onOpen: () => ui.sheet({ eyebrow: "EARNINGS · SAMPLE", title, body: () => <EarningsBody status={title} /> }) }))}
      />
      <p className="status-explainer">Pending is estimated. Confirmed is approved. Reversed was removed after a refund. Paid has been sent.</p>
    </>
  )
}

function ShareBody() {
  const ui = useUI()
  return (
    <Options
      close={() => {}}
      items={[
        { label: "Copy link", detail: LINK.replace("https://", ""), icon: "copy", onSelect: () => ui.copy(LINK, "Referral link copied") },
        { label: "Copy message", detail: "Ready to paste into a post or chat", icon: "chat", onSelect: () => ui.copy(`Neon Garden is on Sat, 31 August at Nova Room. Get tickets with my code ALEX20: ${LINK}`, "Message copied") },
        { label: "Copy code", detail: "ALEX20", icon: "ticket", onSelect: () => ui.copy("ALEX20", "Code copied") },
      ]}
    />
  )
}

const EVENT_SUMMARY: Record<string, [string, string][]> = {
  "Neon Garden": [["Date", "Sat, 31 August"], ["Venue", "Nova Room"], ["Tickets sold", "184 of 300"], ["Your referral sales", "32"]],
  "Rooftop Frequencies": [["Date", "Fri, 6 September"], ["Venue", "Sky Room · partnership requested"], ["Status", "Draft · sharing opens when it goes live"]],
  "Afterdark Sessions": [["Date", "Sat, 21 September"], ["Venue", "Not chosen yet"], ["Status", "Draft · sharing opens when tickets go on sale"]],
}

function Ambassador({ tab, ctx }: { tab: string; ctx: Ctx }) {
  const ui = useUI()
  const share = () => ui.sheet({ eyebrow: "NEON GARDEN", title: "Share event", body: () => <ShareBody /> })
  const eventSheet = (name: string) =>
    ui.sheet({
      eyebrow: "ASSIGNED EVENT",
      title: name,
      body: () => (
        <>
          <Lines rows={EVENT_SUMMARY[name]} />
          {name === "Neon Garden" && <ShareBody />}
        </>
      ),
    })
  if (tab === "events")
    return (
      <>
        <Page heading="Assigned events" eyebrow="MIDNIGHT SOCIAL" />
        <RowList
          rows={[
            { icon: "event", title: "Neon Garden", desc: "31 Aug · 32 referral sales", onOpen: () => eventSheet("Neon Garden") },
            { icon: "clock", title: "Rooftop Frequencies", desc: "6 Sep · Sharing opens when it goes live", onOpen: () => eventSheet("Rooftop Frequencies") },
            { icon: "clock", title: "Afterdark Sessions", desc: "21 Sep · Sharing opens soon", onOpen: () => eventSheet("Afterdark Sessions") },
          ]}
        />
      </>
    )
  if (tab === "share")
    return (
      <>
        <Page heading="Share" eyebrow="NEON GARDEN" />
        <div className="referral-card card">
          <span>YOUR REFERRAL CODE</span>
          <strong>ALEX20</strong>
          <p>{LINK.replace("https://", "")}</p>
          <div className="mini-qr" aria-label="QR code for your referral link">
            BU
          </div>
          <div className="dual-actions">
            <button className="secondary-action" onClick={() => ui.copy(LINK, "Referral link copied")}>
              <Icon name="copy" /> Copy link
            </button>
            <button className="primary-action" onClick={share}>
              <Icon name="share" /> Share event
            </button>
          </div>
        </div>
      </>
    )
  if (tab === "earnings") return <Earnings team={false} />
  if (tab === "more") return <MoreScreen role="ambassador" ctx={ctx} />
  return (
    <>
      <Page heading="Performance" eyebrow="AMBASSADOR" action="Share event" onAction={share} />
      <div className="role-hero card">
        <span>THIS MONTH · SAMPLE</span>
        <h2>$428.00 confirmed</h2>
        <p>From 50 referred ticket sales and 3 bookings.</p>
        <button onClick={() => ctx.setTab("earnings")}>
          View earnings <Icon name="arrow" />
        </button>
      </div>
      <div className="role-metrics">
        <Stat label="Link visits" value="1,284" note="+18% this week" />
        <Stat label="Ticket sales" value="50" note="3.9% conversion" />
        <Stat label="Target" value={`${pct(50, 70)}%`} note="50 of 70 sales" />
        <Stat label="Rank" value="#3" note="of 18 ambassadors" />
      </div>
      <Section eyebrow="NEXT EVENT" title="Neon Garden">
        <RowList
          rows={[
            { icon: "event", title: "Saturday, 31 August", desc: "184 sold · 7 days away", onOpen: () => eventSheet("Neon Garden") },
            { icon: "share", title: "Your referral link", desc: "32 sales · $256 confirmed", onOpen: () => ctx.setTab("share") },
          ]}
        />
      </Section>
    </>
  )
}

function EventLead({ tab, ctx }: { tab: string; ctx: Ctx }) {
  const ui = useUI()
  const [team, setTeam] = useState<[string, string][]>([
    ["Maya Chen", "72 sales · $576 confirmed"],
    ["Alex Morgan", "50 sales · $428 confirmed"],
    ["Jordan Blake", "42 sales · $336 confirmed"],
  ])
  const [nudged, setNudged] = useState<string[]>([])
  const [resent, setResent] = useState(false)
  const teamChat = () =>
    ui.sheet({
      eyebrow: "NEON GARDEN",
      title: "Team chat",
      body: () => <Thread initial={[{ mine: false, who: "Maya", text: "Posted the lineup reel. Link clicks are up!", time: "8:10 PM" }]} placeholder="Message 18 ambassadors…" reply="On it!" replyFrom="Maya" />,
    })
  const invite = () =>
    ui.sheet({
      eyebrow: "NEON GARDEN",
      title: "Invite ambassador",
      body: (close) => (
        <QuickForm
          submit="Send invitation"
          fields={[
            { id: "email", label: "Email address", type: "email", placeholder: "name@example.com", required: true },
            { id: "target", label: "Ticket target", value: "20", type: "number", required: true },
          ]}
          onSubmit={(v) => {
            setTeam((t) => [...t, [v.email.trim(), `Invited · target ${v.target} sales`]])
            ui.toast(`Invitation sent to ${v.email.trim()}`)
            close()
          }}
        />
      ),
    })
  const leaderboard = () =>
    ui.sheet({
      eyebrow: "NEON GARDEN · SAMPLE",
      title: "Leaderboard",
      body: () => (
        <Lines
          rows={[
            ["1. Maya Chen", "72 sales"],
            ["2. Priya Shah", "54 sales"],
            ["3. Alex Morgan", "50 sales"],
            ["4. Jordan Blake", "42 sales"],
            ["5. You", "38 sales"],
          ]}
        />
      ),
    })
  const inactive = () =>
    ui.sheet({
      eyebrow: "NO ACTIVITY IN 7 DAYS",
      title: "Inactive ambassadors",
      body: () => <NudgeList nudged={nudged} setNudged={setNudged} />,
    })
  if (tab === "events")
    return (
      <>
        <Page heading="Events" eyebrow="ASSIGNED" />
        <RowList
          rows={[
            { icon: "event", title: "Neon Garden", desc: "31 Aug · Published · 184 sold", onOpen: () => ui.sheet({ eyebrow: "EVENT", title: "Neon Garden", body: () => <Lines rows={[...EVENT_SUMMARY["Neon Garden"].slice(0, 3), ["Team referral sales", "286"]]} /> }) },
            { icon: "event", title: "Rooftop Frequencies", desc: "6 Sep · Draft · partnership requested", onOpen: () => ui.sheet({ eyebrow: "EVENT", title: "Rooftop Frequencies", body: () => <Lines rows={EVENT_SUMMARY["Rooftop Frequencies"].slice(0, 3)} /> }) },
            { icon: "clock", title: "Afterdark Sessions", desc: "21 Sep · Draft", onOpen: () => ui.sheet({ eyebrow: "EVENT", title: "Afterdark Sessions", body: () => <Lines rows={EVENT_SUMMARY["Afterdark Sessions"]} /> }) },
          ]}
        />
      </>
    )
  if (tab === "team")
    return (
      <>
        <Page heading="Team" eyebrow="NEON GARDEN" action="Invite" onAction={invite} />
        <div className="role-metrics">
          <Stat label="Ambassadors" value="18" note="14 active" />
          <Stat label="Team sales" value="286" note="tickets referred" />
        </div>
        <RowList
          rows={[
            ...team.map(([n, d]) => ({ icon: "team", title: n, desc: d, onOpen: () => ui.sheet({ eyebrow: "AMBASSADOR", title: n, body: (close) => <MemberBody name={n} role="Ambassador" status={d} close={close} /> }) }) as Row),
            { icon: "plus", title: "Invite ambassador", desc: "Assign event and target", onOpen: invite },
          ]}
        />
        <p className="list-count">Showing your top ambassadors and new invitations.</p>
      </>
    )
  if (tab === "earnings") return <Earnings team />
  if (tab === "more") return <MoreScreen role="event-lead" ctx={ctx} />
  const inactiveLeft = 4 - nudged.length
  return (
    <>
      <Page heading="Team overview" eyebrow="NEON GARDEN" action="Message team" onAction={teamChat} />
      <div className="role-hero card">
        <span>TEAM PERFORMANCE · SAMPLE</span>
        <h2>286 referral sales</h2>
        <p>$2,416 confirmed team commission.</p>
        <button onClick={leaderboard}>
          Open leaderboard <Icon name="arrow" />
        </button>
      </div>
      <div className="role-metrics">
        <Stat label="Your sales" value="38" note="$304 personal" />
        <Stat label="Team sales" value="286" note="$2,416 team total" />
        <Stat label="Active" value="14 / 18" note="ambassadors" />
        <Stat label="Target" value={`${pct(286, 350)}%`} note="286 of 350" />
      </div>
      <Section eyebrow="NEEDS ATTENTION" title="Team actions">
        <RowList
          rows={[
            { icon: "warning", tone: inactiveLeft ? "warning" : undefined, title: inactiveLeft ? `${inactiveLeft} inactive ambassadors` : "Everyone nudged", desc: inactiveLeft ? "No link activity in 7 days" : "Reminders sent today", onOpen: inactive },
            {
              icon: "clock",
              title: resent ? "Invitations resent" : "3 invitations pending",
              desc: resent ? "New links expire in 7 days" : "Expire in 2 days",
              onOpen: resent
                ? undefined
                : () => {
                    setResent(true)
                    ui.toast("3 invitations resent")
                  },
            },
          ]}
        />
      </Section>
    </>
  )
}

function NudgeList({ nudged, setNudged }: { nudged: string[]; setNudged: (n: string[]) => void }) {
  const ui = useUI()
  const [local, setLocal] = useState(nudged)
  return (
    <div className="form-stack">
      {["Sam Rivera", "Kai Johnson", "Lena Park", "Omar Haddad"].map((n) => (
        <div className="list-row static-row card" key={n}>
          <span className="member-avatar">{n.slice(0, 2).toUpperCase()}</span>
          <span>
            <strong>{n}</strong>
            <small>{local.includes(n) ? "Reminder sent" : "Last share 9 days ago"}</small>
          </span>
          <button
            className="text-button"
            disabled={local.includes(n)}
            onClick={() => {
              const next = [...local, n]
              setLocal(next)
              setNudged(next)
              ui.toast(`Reminder sent to ${n}`)
            }}
          >
            {local.includes(n) ? "Sent" : "Nudge"}
          </button>
        </div>
      ))}
    </div>
  )
}

export function RoleExperience({ role, theme, onTheme, appearance, onAppearance, onSwitch }: { role: StaffRole; theme: Theme; onTheme: () => void; appearance: Appearance; onAppearance: (a: Appearance) => void; onSwitch: () => void }) {
  const config = CONFIGS[role]
  const [active, setActive] = useState(config.tabs[0].id)
  const srv = useServer()
  const badges = useServerBadges()
  const setTab = (t: string) => {
    // Tapping the current tab again returns to its first screen.
    if (role === "server" && t === "tables" && active === "tables") srv.setView({ screen: "list" })
    setActive(t)
    window.scrollTo({ top: 0 })
  }
  const ctx: Ctx = { appearance, onAppearance, onSwitch, setTab }
  return (
    <div className={`app-shell theme-${theme}`}>
      <div className="topbar">
        <button className="workspace-switch" onClick={onSwitch} aria-label="Switch role">
          <span className="brand-mark">
            <img src="/bottlesup-logo.png" alt="" />
          </span>
          <span>
            <strong>BottlesUp</strong>
            <small>{config.context}</small>
          </span>
          <Icon name="arrow" size={15} />
        </button>
        <div className="top-actions">
          <span className="demo-label">DEMO</span>
          <ThemeToggle theme={theme} onToggle={onTheme} />
        </div>
      </div>
      <main className={`page-content ${role === "server" ? "srv-page" : ""}`}>
        <ErrorBoundary resetKey={active}>
        {role === "venue-manager" && <Manager tab={active} ctx={ctx} />}
        {role === "door-staff" && <Door tab={active} ctx={ctx} />}
        {role === "server" && <ServerApp tab={active} appearance={appearance} onAppearance={onAppearance} onSignOut={onSwitch} />}
        {role === "ambassador" && <Ambassador tab={active} ctx={ctx} />}
        {role === "event-lead" && <EventLead tab={active} ctx={ctx} />}
        </ErrorBoundary>
      </main>
      {role === "venue-manager" && <MessagesFab viewer="manager" />}
      {role === "venue-manager" && <VenuePanels who="manager" />}
      {(role === "server" || role === "door-staff") && <MessagesFab viewer="staff" />}
      <nav className={`bottom-nav role-nav tabs-${config.tabs.length}`}>
        {config.tabs.map((tab) => (
          <button key={tab.id} className={active === tab.id ? "active" : ""} aria-current={active === tab.id ? "page" : undefined} onClick={() => setTab(tab.id)}>
            <span className="nav-icon">
              <Icon name={tab.icon} />
              {role === "server" && (tab.id === "tables" || tab.id === "orders") && badges[tab.id] > 0 && <i className="nav-badge">{badges[tab.id]}</i>}
            </span>
            <span>{tab.label}</span>
          </button>
        ))}
      </nav>
    </div>
  )
}
