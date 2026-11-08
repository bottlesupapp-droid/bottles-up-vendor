import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react"
import { usePersisted, Icon, Lines, Options, Thread, clock, useUI, type Appearance, type IconName } from "./kit"
import { useGuests } from "./Guests"
import { useVenueBottles } from "./VenueEdit"
import { MemberBody, SettingsBody, ShiftBody, SupportBody } from "./shared"

/* =========================================================
   Server experience: state lives in a provider so tables,
   orders, drafts and requests survive tab changes.
   All data here is demo data.
   ========================================================= */

export type Arrival = "Seated" | "Arrived" | "Expected" | "Late"
export type Payment = "Deposit paid" | "Balance open" | "Paid in full" | "Pay at venue"
export type SrvTable = {
  id: string
  section: string
  guest: string
  party: number
  arrival: Arrival
  time: string
  mine: boolean
  pkg: string
  includes: string
  minSpend: number
  deposit: number
  payment: Payment
  handedTo?: string
}
export type OrderItem = { name: string; qty: number; mixers?: string; unavailable?: boolean; sub?: { name: string; status: "Waiting for manager" | "Approved" } }
export type OrderStatus = "Scheduled" | "Submitting" | "New" | "Preparing" | "Ready" | "Delivering" | "Delivered" | "Cancelled"
export type SignStatus = "Requested" | "Preparing" | "Delivered" | "Cancelled"
export type BottleSign = { style: string; text: string; timing: string; occasion?: string; status?: SignStatus }
export type Order = { id: string; table: string; items: OrderItem[]; note: string; time: string; status: OrderStatus; eta?: string; reason?: string; sign?: BottleSign }
export type ReqStatus = "Open" | "Acknowledged" | "Resolved"
export type GuestRequest = { id: string; table: string; kind: string; text: string; time: string; status: ReqStatus; escalated?: boolean }
export type Handover = { table: string; to: string; note: string; status: "Waiting" | "Accepted" }
export type Draft = { items: OrderItem[]; note: string; error?: string; retried?: boolean }
export type SrvView = { screen: "list" } | { screen: "table"; id: string } | { screen: "add"; id: string }

type Load = "loading" | "ready" | "error"

export const MENU: { name: string; kind: string; price: number; mixers?: string[]; unavailable?: boolean }[] = [
  { name: "Grey Goose", kind: "Bottle", price: 650, mixers: ["Soda", "Cranberry", "Orange juice", "Red Bull"] },
  { name: "Don Julio 1942", kind: "Bottle", price: 1000, mixers: ["Lime & soda", "Pineapple", "Grapefruit soda"] },
  { name: "Hennessy VS", kind: "Bottle", price: 380, mixers: ["Ginger ale", "Cola", "Neat"] },
  { name: "Moët Impérial", kind: "Champagne", price: 310 },
  { name: "Dom Pérignon Brut", kind: "Champagne", price: 850, unavailable: true },
  { name: "Cocktail round (4)", kind: "Cocktails", price: 86 },
  { name: "Sharing platter", kind: "Food", price: 64 },
  { name: "Still water (4)", kind: "Water", price: 24 },
]
/* Prices and availability come from the venue's menu (Venue page → Menu) when set there,
   so servers, the guest app and reports charge the same amount. */
function useMenu() {
  const bottles = useVenueBottles()
  if (!bottles) return MENU
  return MENU.map((m) => {
    const b = bottles.find((x) => x.name === m.name)
    return b ? { ...m, price: b.price, unavailable: !b.available } : m
  })
}
const SUBSTITUTES: Record<string, string[]> = { "Dom Pérignon Brut": ["Veuve Clicquot Rosé", "Moët Impérial × 2"] }
const TEAM = [
  { name: "Jordan Blake", role: "Manager", status: "On shift" },
  { name: "Riley Chen", role: "Server", status: "Section A" },
  { name: "Dana Ortiz", role: "Server", status: "Section C" },
]

const TABLES: SrvTable[] = [
  { id: "T4", section: "Section B", guest: "Maya Chen", party: 6, arrival: "Seated", time: "9:30 PM", mine: true, pkg: "Booth package", includes: "1 bottle, mixers, sparkler delivery", minSpend: 1200, deposit: 300, payment: "Deposit paid" },
  { id: "T12", section: "Section B", guest: "Chloe Hall", party: 6, arrival: "Seated", time: "9:00 PM", mine: true, pkg: "Main floor table", includes: "Mixers and water", minSpend: 800, deposit: 100, payment: "Balance open" },
  { id: "VIP", section: "Section B", guest: "Marcus Hill", party: 8, arrival: "Arrived", time: "10:00 PM", mine: true, pkg: "VIP Booth package", includes: "2 bottles, champagne toast, host", minSpend: 2500, deposit: 750, payment: "Deposit paid" },
  { id: "Halo", section: "Section B", guest: "Jordan Ellis", party: 6, arrival: "Expected", time: "12:30 AM", mine: true, pkg: "Halo Booth package", includes: "Bottle service, mixers, priority entry", minSpend: 1000, deposit: 150, payment: "Paid in full" },
  { id: "T7", section: "Section B", guest: "Sofia Reyes", party: 4, arrival: "Expected", time: "10:30 PM", mine: true, pkg: "Main floor table", includes: "Mixers and water", minSpend: 600, deposit: 100, payment: "Deposit paid" },
  { id: "T10", section: "Section B", guest: "Zoe Martin", party: 4, arrival: "Late", time: "9:15 PM", mine: true, pkg: "Main floor table", includes: "Mixers and water", minSpend: 600, deposit: 0, payment: "Pay at venue" },
  { id: "T9", section: "Section B", guest: "Noah Kim", party: 5, arrival: "Seated", time: "9:45 PM", mine: false, pkg: "Main floor table", includes: "Mixers and water", minSpend: 800, deposit: 100, payment: "Deposit paid", handedTo: "Riley Chen" },
]
const ORDERS: Order[] = [
  { id: "#1839", table: "Halo", items: [{ name: "Don Julio 1942", qty: 1, mixers: "Soda, citrus & ice" }], note: "Pre-ordered in the app. Birthday.", time: "Booked Aug 18", status: "Scheduled", sign: { style: "LED message board", text: "HAPPY 30TH JORDAN", timing: "At midnight", occasion: "Birthday", status: "Requested" } },
  { id: "#1846", table: "VIP", items: [{ name: "Dom Pérignon Brut", qty: 1, unavailable: true }, { name: "Grey Goose", qty: 1, mixers: "Soda, Cranberry" }], note: "Celebration table. Bring with sparklers.", time: "9:39 PM", status: "New", sign: { style: "Sparkler sign", text: "CONGRATS MARCUS", timing: "At midnight", occasion: "Celebration", status: "Preparing" } },
  { id: "#1845", table: "T4", items: [{ name: "Cocktail round (4)", qty: 1 }], note: "", time: "9:36 PM", status: "New" },
  { id: "#1842", table: "T4", items: [{ name: "Grey Goose", qty: 1, mixers: "Soda, Cranberry" }, { name: "Still water (4)", qty: 1 }], note: "Extra limes", time: "9:31 PM", status: "Preparing", eta: "About 6 min" },
  { id: "#1841", table: "T12", items: [{ name: "Sharing platter", qty: 1 }], note: "No nuts. Guest allergy.", time: "9:29 PM", status: "Preparing" },
  { id: "#1840", table: "T12", items: [{ name: "Moët Impérial", qty: 4 }], note: "", time: "9:22 PM", status: "Ready" },
  { id: "#1836", table: "T12", items: [{ name: "Cocktail round (4)", qty: 2 }], note: "", time: "9:05 PM", status: "Delivered" },
  { id: "#1833", table: "T10", items: [{ name: "Hennessy VS", qty: 1, mixers: "Ginger ale" }], note: "", time: "8:58 PM", status: "Cancelled", reason: "Guest changed their mind" },
]
const REQUESTS: GuestRequest[] = [
  { id: "r1", table: "T12", kind: "Bill", text: "Asked for the bill. Manager collects payment.", time: "9:40 PM", status: "Open" },
  { id: "r2", table: "T4", kind: "Ice & mixers", text: "More ice and two sodas.", time: "9:38 PM", status: "Open" },
  { id: "r3", table: "VIP", kind: "Celebration", text: "Birthday sparkler at midnight.", time: "9:20 PM", status: "Acknowledged" },
]

type SrvApi = {
  tables: SrvTable[]
  orders: Order[]
  requests: GuestRequest[]
  handovers: Handover[]
  drafts: Record<string, Draft>
  view: SrvView
  filter: string
  load: Load
  refreshing: boolean
  unstable: boolean
  assist: { reason: string; status: "Sending" | "On the way" } | null
  shiftRequest: boolean
  setView: (v: SrvView) => void
  setFilter: (f: string) => void
  setUnstable: (b: boolean) => void
  reload: () => void
  setDraft: (table: string, d: Draft) => void
  submit: (table: string) => Promise<boolean>
  advance: (id: string) => void
  cancel: (id: string, reason: string) => void
  setSign: (id: string, sign: BottleSign | undefined) => void
  requestSub: (id: string, item: string, sub: string) => void
  setReq: (id: string, patch: Partial<GuestRequest>) => void
  handover: (h: Omit<Handover, "status">) => void
  askManager: (reason: string) => void
  cancelAssist: () => void
  requestShiftChange: () => void
}

const SrvCtx = createContext<SrvApi | null>(null)
export const useServer = () => {
  const s = useContext(SrvCtx)
  if (!s) throw new Error("useServer outside ServerProvider")
  return s
}

const wait = (ms: number) => new Promise((r) => window.setTimeout(r, ms))

export function ServerProvider({ children }: { children: ReactNode }) {
  const [tables, setTables] = usePersisted("bu-biz-server-tables", TABLES)
  const [orders, setOrders] = usePersisted("bu-biz-server-orders", ORDERS)
  const [requests, setRequests] = usePersisted("bu-biz-server-requests", REQUESTS)
  const [handovers, setHandovers] = usePersisted<Handover[]>("bu-biz-server-handovers", [])
  const [drafts, setDrafts] = useState<Record<string, Draft>>({})
  const [view, setView] = useState<SrvView>({ screen: "list" })
  const [filter, setFilter] = useState("New")
  const [load, setLoad] = useState<Load>("loading")
  const [refreshing, setRefreshing] = useState(false)
  const [unstable, setUnstable] = useState(false)
  const [assist, setAssist] = useState<SrvApi["assist"]>(null)
  const [shiftRequest, setShiftRequest] = useState(false)
  const failedLoad = useRef(false)
  const seq = useRef(1847)
  const busy = useRef<Set<string>>(new Set())

  const fetchTables = (first: boolean) => {
    if (first) setLoad("loading")
    else setRefreshing(true)
    window.setTimeout(() => {
      setRefreshing(false)
      if (unstable && !failedLoad.current) {
        failedLoad.current = true
        setLoad("error")
        return
      }
      failedLoad.current = false
      setLoad("ready")
    }, 650)
  }

  const patchOrder = (id: string, patch: Partial<Order> | ((o: Order) => Partial<Order>)) =>
    setOrders((l) => l.map((o) => (o.id === id ? { ...o, ...(typeof patch === "function" ? patch(o) : patch) } : o)))

  const api: SrvApi = {
    tables,
    orders,
    requests,
    handovers,
    drafts,
    view,
    filter,
    load,
    refreshing,
    unstable,
    assist,
    shiftRequest,
    setView: (v) => {
      setView(v)
      window.scrollTo({ top: 0 })
    },
    setFilter,
    setUnstable: (b) => {
      setUnstable(b)
      failedLoad.current = false
    },
    reload: () => fetchTables(load !== "ready"),
    setDraft: (table, d) => setDrafts((all) => ({ ...all, [table]: d })),
    submit: async (table) => {
      // One submission per table at a time: blocks double taps.
      if (busy.current.has(table)) return false
      const draft = drafts[table]
      if (!draft || draft.items.length === 0) return false
      busy.current.add(table)
      const id = "#" + seq.current++
      const time = clock()
      setOrders((l) => [{ id, table, items: draft.items, note: draft.note.trim(), time, status: "Submitting" }, ...l])
      await wait(900)
      if (unstable && !draft.retried) {
        setOrders((l) => l.filter((o) => o.id !== id))
        seq.current--
        setDrafts((all) => ({ ...all, [table]: { ...draft, error: "We couldn't reach the bar. Your order is saved here.", retried: true } }))
        busy.current.delete(table)
        return false
      }
      // Sent, but not yet accepted by the bar.
      patchOrder(id, { status: "New" })
      setDrafts((all) => {
        const next = { ...all }
        delete next[table]
        return next
      })
      busy.current.delete(table)
      window.setTimeout(() => {
        setOrders((l) =>
          l.map((o) => {
            if (o.id !== id || o.status !== "New") return o
            const items = o.items.map((it) => (MENU.find((m) => m.name === it.name)?.unavailable ? { ...it, unavailable: true } : it))
            return items.some((it) => it.unavailable && !it.sub) ? { ...o, items } : { ...o, items, status: "Preparing", eta: "About 8 min" }
          }),
        )
      }, 2600)
      return true
    },
    advance: (id) => {
      const o = orders.find((x) => x.id === id)
      if (!o) return
      if (o.status === "Scheduled") {
        setTables((l) => l.map((t) => (t.id === o.table ? { ...t, arrival: "Seated" } : t)))
        patchOrder(id, { status: "Preparing", eta: "About 6 min" })
      } else if (o.status === "New") {
        patchOrder(id, { status: "Preparing", eta: undefined })
      } else if (o.status === "Preparing") {
        window.setTimeout(() => patchOrder(id, { status: "Ready", eta: undefined }), 900)
      } else if (o.status === "Ready") patchOrder(id, { status: "Delivering" })
      else if (o.status === "Delivering") patchOrder(id, { status: "Delivered" })
    },
    cancel: (id, reason) => patchOrder(id, { status: "Cancelled", reason, eta: undefined }),
    setSign: (id, sign) => patchOrder(id, { sign }),
    requestSub: (id, item, sub) => {
      patchOrder(id, (o) => ({ items: o.items.map((it) => (it.name === item ? { ...it, sub: { name: sub, status: "Waiting for manager" } } : it)) }))
      window.setTimeout(() => {
        patchOrder(id, (o) => {
          const items = o.items.map((it) => (it.name === item && it.sub ? { ...it, name: it.sub.name, unavailable: false, sub: { ...it.sub, status: "Approved" as const } } : it))
          return { items, status: items.some((it) => it.unavailable) ? o.status : "Preparing", eta: undefined }
        })
      }, 1800)
    },
    setReq: (id, patch) => setRequests((l) => l.map((r) => (r.id === id ? { ...r, ...patch } : r))),
    handover: (h) => {
      setHandovers((l) => [{ ...h, status: "Waiting" }, ...l.filter((x) => x.table !== h.table)])
      window.setTimeout(() => {
        setHandovers((l) => l.map((x) => (x.table === h.table ? { ...x, status: "Accepted" } : x)))
        setTables((l) => l.map((t) => (t.id === h.table ? { ...t, mine: false, handedTo: h.to } : t)))
      }, 1600)
    },
    askManager: (reason) => {
      setAssist({ reason, status: "Sending" })
      window.setTimeout(() => setAssist((a) => (a ? { ...a, status: "On the way" } : a)), 1200)
    },
    cancelAssist: () => setAssist(null),
    requestShiftChange: () => setShiftRequest(true),
  }
  return <SrvCtx.Provider value={api}>{children}</SrvCtx.Provider>
}

/* ---------------- helpers ---------------- */

type Tone = "green" | "blue" | "amber" | "red" | "gray" | "orange"
const ARRIVAL_TONE: Record<Arrival, Tone> = { Seated: "green", Arrived: "blue", Expected: "gray", Late: "amber" }
const ORDER_LABEL: Record<OrderStatus, [string, Tone]> = {
  Scheduled: ["Pre-order · waiting for arrival", "gray"],
  Submitting: ["Sending…", "gray"],
  New: ["Sent · waiting for bar", "gray"],
  Preparing: ["Preparing", "amber"],
  Ready: ["Ready for pickup", "blue"],
  Delivering: ["On the way", "blue"],
  Delivered: ["Delivered", "green"],
  Cancelled: ["Cancelled", "red"],
}
const needsSub = (o: Order) => o.items.some((it) => it.unavailable && !it.sub)
const subPending = (o: Order) => o.items.some((it) => it.sub?.status === "Waiting for manager")
const filterOf = (o: Order) => (o.status === "Submitting" || o.status === "Scheduled" ? "New" : o.status === "Delivering" ? "Ready" : o.status)
const openReqs = (reqs: GuestRequest[], table?: string) => reqs.filter((r) => r.status !== "Resolved" && (!table || r.table === table))
const itemLine = (it: OrderItem) => `${it.qty} × ${it.name}`

function Chip({ tone, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`srv-chip tone-${tone}`}>{children}</span>
}

function Title({ eyebrow, title, action }: { eyebrow?: string; title: string; action?: ReactNode }) {
  return (
    <div className="srv-title">
      <div>
        {eyebrow && <span>{eyebrow}</span>}
        <h1>{title}</h1>
      </div>
      {action}
    </div>
  )
}

function Skeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="srv-skeleton" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} />
      ))}
    </div>
  )
}

function StateBlock({ icon, title, text, action, onAction }: { icon: IconName; title: string; text: string; action?: string; onAction?: () => void }) {
  return (
    <div className="state-block">
      <Icon name={icon} size={26} />
      <h2>{title}</h2>
      <p>{text}</p>
      {action && (
        <button className="primary-action" onClick={onAction}>
          {action}
        </button>
      )}
    </div>
  )
}

/* ---------------- sheets ---------------- */

function ConfirmCancel({ order, close }: { order: Order; close: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const [reason, setReason] = useState("Guest changed their mind")
  return (
    <div className="srv-sheet">
      <p className="srv-muted">
        {order.items.map(itemLine).join(", ")} for {order.table}. {order.status === "Preparing" ? "The bar has started this order and may already have opened bottles." : "The bar hasn't accepted it yet."}
      </p>
      <label className="field">
        <span>Reason</span>
        <select value={reason} onChange={(e) => setReason(e.target.value)}>
          <option>Guest changed their mind</option>
          <option>Ordered by mistake</option>
          <option>Duplicate order</option>
          <option>Guest left</option>
        </select>
      </label>
      <div className="dual-actions">
        <button className="secondary-action" onClick={close}>
          Keep order
        </button>
        <button
          className="danger-action"
          onClick={() => {
            srv.cancel(order.id, reason)
            ui.toast(`Order ${order.id} cancelled`)
            close()
          }}
        >
          Cancel order
        </button>
      </div>
    </div>
  )
}

function SubstituteBody({ order, close }: { order: Order; close: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const item = order.items.find((it) => it.unavailable && !it.sub)
  const [choice, setChoice] = useState(item ? SUBSTITUTES[item.name]?.[0] ?? "" : "")
  if (!item) return <p className="srv-muted">Nothing to replace on this order.</p>
  const subs = SUBSTITUTES[item.name] ?? []
  return (
    <div className="srv-sheet">
      <p className="srv-muted">
        The bar marked <b>{item.name}</b> unavailable. Ask the guest which replacement they'd like. A manager approves substitutions because the price can change.
      </p>
      <div className="srv-choices" role="radiogroup" aria-label="Replacement">
        {subs.map((s) => (
          <button key={s} role="radio" aria-checked={choice === s} className={choice === s ? "on" : ""} onClick={() => setChoice(s)}>
            <span />
            {s}
          </button>
        ))}
      </div>
      <button
        className="primary-action full-action"
        disabled={!choice}
        onClick={() => {
          srv.requestSub(order.id, item.name, choice)
          ui.toast("Sent to the manager for approval")
          close()
        }}
      >
        Request approval
      </button>
    </div>
  )
}

function RequestBody({ id, close }: { id: string; close: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const r = srv.requests.find((x) => x.id === id)
  if (!r) return <p className="srv-muted">This request is no longer open.</p>
  const isBill = r.kind === "Bill"
  return (
    <div className="srv-sheet">
      <div className="srv-req-head">
        <Chip tone={r.status === "Open" ? "orange" : r.status === "Acknowledged" ? "blue" : "green"}>{r.status}</Chip>
        {r.escalated && <Chip tone="amber">Manager notified</Chip>}
        <small>{r.time}</small>
      </div>
      <p className="srv-req-text">{r.text}</p>
      {isBill && (
        <p className="srv-notice">
          <Icon name="lock" size={15} /> Servers can't take or mark payments. A manager collects the bill and records it.
        </p>
      )}
      {r.status === "Open" && (
        <button
          className="primary-action full-action"
          onClick={() => {
            srv.setReq(r.id, { status: "Acknowledged" })
            ui.toast(`${r.table}: guest told you're on it`)
          }}
        >
          Acknowledge
        </button>
      )}
      {r.status === "Acknowledged" && (
        <button
          className="primary-action full-action"
          onClick={() => {
            srv.setReq(r.id, { status: "Resolved" })
            ui.toast(`${r.table} request resolved`)
            close()
          }}
        >
          {isBill ? "Mark handed to manager" : "Mark resolved"}
        </button>
      )}
      {!r.escalated && r.status !== "Resolved" && (
        <button
          className="secondary-action full-action"
          onClick={() => {
            srv.setReq(r.id, { escalated: true })
            ui.toast("Jordan Blake (manager) notified")
          }}
        >
          {isBill ? "Ask manager to collect payment" : "Escalate to manager"}
        </button>
      )}
    </div>
  )
}

function HandoverBody({ table, close }: { table?: string; close: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const mine = srv.tables.filter((t) => t.mine)
  const [t, setT] = useState(table ?? mine[0]?.id ?? "")
  const [to, setTo] = useState(TEAM[1].name)
  const [note, setNote] = useState("")
  const pendingOrders = srv.orders.filter((o) => o.table === t && ["New", "Preparing", "Ready", "Delivering"].includes(o.status)).length
  if (!mine.length) return <p className="srv-muted">You don't have any tables to hand over.</p>
  return (
    <form
      noValidate
      className="form-stack srv-sheet"
      onSubmit={(e) => {
        e.preventDefault()
        srv.handover({ table: t, to, note })
        ui.toast(`Handover sent to ${to.split(" ")[0]}`)
        close()
      }}
    >
      <label className="field">
        <span>Table</span>
        <select value={t} onChange={(e) => setT(e.target.value)}>
          {mine.map((x) => (
            <option key={x.id} value={x.id}>
              {x.id} · {x.guest}
            </option>
          ))}
        </select>
      </label>
      <label className="field">
        <span>Hand over to</span>
        <select value={to} onChange={(e) => setTo(e.target.value)}>
          {TEAM.filter((m) => m.role === "Server").map((m) => (
            <option key={m.name}>{m.name}</option>
          ))}
        </select>
      </label>
      <label className="field">
        <span>Note for {to.split(" ")[0]} (optional)</span>
        <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Allergy, open requests, anything to know" />
      </label>
      {pendingOrders > 0 && (
        <p className="srv-notice">
          <Icon name="orders" size={15} /> {pendingOrders} open order{pendingOrders === 1 ? "" : "s"} move with the table.
        </p>
      )}
      <button className="primary-action full-action" type="submit">
        Send handover
      </button>
    </form>
  )
}

function useServerSheets() {
  const ui = useUI()
  const srv = useServer()
  const askManager = () =>
    ui.sheet({
      eyebrow: "MANAGER ASSIST",
      title: "What's going on?",
      body: (close) => (
        <Options
          close={close}
          items={[
            { label: "Payment or bill", detail: "Collect, split, or a card issue", icon: "card", onSelect: () => srv.askManager("Payment or bill") },
            { label: "Guest issue", detail: "Complaint or a difficult situation", icon: "guests", onSelect: () => srv.askManager("Guest issue") },
            { label: "Order problem", detail: "Wrong, missing or delayed order", icon: "orders", onSelect: () => srv.askManager("Order problem") },
            { label: "Safety concern", detail: "Security is alerted too", icon: "warning", danger: true, onSelect: () => srv.askManager("Safety concern") },
          ]}
        />
      ),
    })
  const handover = (table?: string) => ui.sheet({ eyebrow: "HANDOVER", title: "Hand over a table", body: (close) => <HandoverBody table={table} close={close} /> })
  const chat = () =>
    ui.sheet({
      eyebrow: "TEAM CHAT",
      title: "Floor team",
      body: () => <Thread initial={[{ mine: false, who: "Jordan", text: "T7 arrives at 10:30. Can you set it up?", time: "9:20 PM" }]} placeholder="Message the floor team…" reply="Got it, thanks!" replyFrom="Jordan" />,
    })
  const request = (id: string) => {
    const r = srv.requests.find((x) => x.id === id)
    ui.sheet({ eyebrow: `${r?.table ?? ""} · GUEST REQUEST`, title: r?.kind ?? "Request", body: (close) => <RequestBody id={id} close={close} /> })
  }
  const contact = (table?: string) =>
    ui.sheet({
      eyebrow: table ? `${table} · CONTACT TEAM` : "CONTACT TEAM",
      title: "Who do you need?",
      body: (close) => (
        <Options
          close={close}
          items={[
            { label: "Message floor team", detail: "Chat with servers and runners", icon: "chat", onSelect: chat },
            { label: "Ask a manager", detail: "Payments, issues, approvals", icon: "team", onSelect: askManager },
            { label: "Hand over this table", detail: "Pass it to another server", icon: "handover", onSelect: () => handover(table) },
          ]}
        />
      ),
    })
  return { askManager, handover, chat, request, contact }
}

/* ---------------- bottle signs ---------------- */

const SIGN_TONE: Record<SignStatus, Tone> = { Requested: "orange", Preparing: "amber", Delivered: "green", Cancelled: "gray" }
const OCCASIONS = ["Birthday", "Celebration", "Anniversary", "Engagement", "Bachelorette", "Other"]
const SIGN_STYLES = ["LED message board", "Sparkler sign", "Neon script"]

function SignForm({ order, close }: { order: Order; close: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const g = useGuests()
  const [d, setD] = useState<BottleSign>(order.sign ?? { style: SIGN_STYLES[0], text: "", timing: "On arrival", occasion: "Birthday", status: "Requested" })
  const [tried, setTried] = useState(false)
  const err = !d.text.trim() ? "Add the sign's message." : d.text.trim().length > 24 ? "Keep it to 24 characters." : null
  const post = (text: string) => g.setThreads((l) => l.map((t) => (t.id === "t-floor" ? { ...t, msgs: [...t.msgs, { id: "s" + Date.now(), mine: true, text, time: clock(), status: "sent" }] } : t)))
  const save = (next: BottleSign | undefined, note: string) => {
    const before = order.sign
    srv.setSign(order.id, next)
    post(note)
    if (next) ui.toast("Saved. Bar and floor team notified.")
    else
      ui.toast("Sign removed. Bar and floor team notified.", () => {
        srv.setSign(order.id, before)
        post(`Sign restored on ${order.table} (${order.id})`)
      })
    close()
  }
  return (
    <div className="srv-sheet">
      <div className={`gc-sign ${d.style.startsWith("Neon") ? "neon" : d.style.startsWith("Sparkler") ? "sparkler" : "led"}`}>{(d.style.startsWith("Neon") ? d.text : d.text.toUpperCase()) || "YOUR MESSAGE"}</div>
      <label className="field">
        <span>Sign text ({d.text.length}/24)</span>
        <input value={d.text} maxLength={24} onChange={(e) => setD({ ...d, text: e.target.value })} placeholder="e.g. HAPPY 30TH JORDAN" />
      </label>
      <div className="field">
        <span>Occasion</span>
        <div className="cp-chips">
          {OCCASIONS.map((o) => (
            <button key={o} aria-pressed={d.occasion === o} className={d.occasion === o ? "on" : ""} onClick={() => setD({ ...d, occasion: o })}>
              {o}
            </button>
          ))}
        </div>
      </div>
      <div className="field">
        <span>Style</span>
        <div className="cp-chips">
          {SIGN_STYLES.map((o) => (
            <button key={o} aria-pressed={d.style === o} className={d.style === o ? "on" : ""} onClick={() => setD({ ...d, style: o })}>
              {o}
            </button>
          ))}
        </div>
      </div>
      <div className="field">
        <span>Bring it out</span>
        <select value={d.timing} onChange={(e) => setD({ ...d, timing: e.target.value })}>
          {["On arrival", "At midnight", "11:00 PM", "11:30 PM", "12:30 AM", "1:00 AM", "When the guest asks"].map((t) => (
            <option key={t}>{t}</option>
          ))}
        </select>
      </div>
      <div className="field">
        <span>Status</span>
        <div className="cp-chips">
          {(["Requested", "Preparing", "Delivered", "Cancelled"] as const).map((st) => (
            <button key={st} aria-pressed={d.status === st} className={d.status === st ? "on" : ""} onClick={() => setD({ ...d, status: st })}>
              {st}
            </button>
          ))}
        </div>
      </div>
      {tried && err && <p className="srv-error">{err}</p>}
      <button
        className="primary-action full-action"
        onClick={() => {
          setTried(true)
          if (err) return
          save({ ...d, text: d.text.trim() }, `Sign for ${order.table} (${order.id}): “${d.text.trim().toUpperCase()}” · ${d.status} · ${d.timing.toLowerCase()}`)
        }}
      >
        {order.sign ? "Save sign" : "Add sign"}
      </button>
      {order.sign && (
        <button className="text-action danger" onClick={() => save(undefined, `Sign removed from ${order.table} (${order.id})`)}>
          Remove sign
        </button>
      )}
    </div>
  )
}

function useSignSheet() {
  const ui = useUI()
  return (order: Order) => ui.sheet({ eyebrow: `${order.table} · ORDER ${order.id}`, title: order.sign ? "Edit bottle sign" : "Add bottle sign", body: (close) => <SignForm order={order} close={close} /> })
}

/* ---------------- order card ---------------- */

const STEPS = ["Sent", "Accepted", "Ready", "Delivered"]
const stepOf = (s: OrderStatus) => ({ Scheduled: 0, Submitting: 0, New: 1, Preparing: 2, Ready: 3, Delivering: 3, Delivered: 4, Cancelled: 0 })[s]

function OrderCard({ order, showTable = true }: { order: Order; showTable?: boolean }) {
  const srv = useServer()
  const ui = useUI()
  const openSign = useSignSheet()
  const [label, tone] = ORDER_LABEL[order.status]
  const step = stepOf(order.status)
  const flagged = needsSub(order)
  const pendingSub = subPending(order)
  const canCancel = order.status === "New" || order.status === "Preparing"
  let action: { label: string; run: () => void } | null = null
  if (flagged) action = { label: "Request substitution", run: () => ui.sheet({ eyebrow: `ORDER ${order.id}`, title: "Item unavailable", body: (close) => <SubstituteBody order={order} close={close} /> }) }
  else if (pendingSub) action = null
  else if (order.status === "Scheduled") action = { label: "Party arrived · send to bar", run: () => (srv.advance(order.id), ui.toast(`${order.id} sent to the bar`)) }
  else if (order.status === "New") action = { label: "Remind bar", run: () => ui.toast("Bar reminded about " + order.id) }
  else if (order.status === "Preparing") action = { label: "Ask bar for update", run: () => (srv.advance(order.id), ui.toast("Asked the bar. They'll mark it ready.")) }
  else if (order.status === "Ready") action = { label: "Pick up & deliver", run: () => (srv.advance(order.id), ui.toast(`${order.id} picked up`)) }
  else if (order.status === "Delivering") action = { label: "Mark delivered", run: () => (srv.advance(order.id), ui.toast(`${order.id} delivered to ${order.table}`)) }
  const eta =
    order.status === "Preparing" ? (order.eta ? `${order.eta} · from bar` : "No estimate from the bar yet") : order.status === "New" && !flagged ? "Waiting for the bar to accept" : null
  return (
    <article className={`srv-order ${order.status === "Cancelled" ? "muted" : ""}`} aria-label={`Order ${order.id}`}>
      <header>
        <strong>
          {showTable && <span className="srv-order-table">{order.table}</span>}
          {order.id}
        </strong>
        <Chip tone={flagged ? "red" : tone}>{flagged ? "Item unavailable" : pendingSub ? "Substitution pending" : label}</Chip>
      </header>
      <ul>
        {order.items.map((it) => (
          <li key={it.name} className={it.unavailable && !it.sub ? "flag" : ""}>
            <span>
              <b>{it.qty} ×</b> {it.name}
              {it.unavailable && !it.sub && <em> · unavailable</em>}
              {it.sub?.status === "Waiting for manager" && <em> · swap for {it.sub.name} (manager approving)</em>}
              {it.sub?.status === "Approved" && <em> · approved substitution</em>}
            </span>
            {it.mixers && <small>Mixers: {it.mixers}</small>}
          </li>
        ))}
      </ul>
      {order.sign ? (
        <div className={`srv-sign ${order.sign.status === "Cancelled" ? "off" : ""}`}>
          <span>{order.sign.text}</span>
          <small>
            {order.sign.style} · {order.sign.occasion ? `${order.sign.occasion} · ` : ""}bring out {order.sign.timing.toLowerCase()}
          </small>
          <span className="srv-sign-foot">
            <Chip tone={SIGN_TONE[order.sign.status ?? "Requested"]}>{order.sign.status ?? "Requested"}</Chip>
            {order.status !== "Cancelled" && (
              <button className="text-action" onClick={() => openSign(order)}>
                <Icon name="pencil" size={13} /> Edit sign
              </button>
            )}
          </span>
        </div>
      ) : (
        order.status !== "Cancelled" &&
        order.status !== "Delivered" && (
          <button className="text-action srv-add-sign" onClick={() => openSign(order)}>
            + Add bottle sign
          </button>
        )
      )}
      {order.note && <p className="srv-order-note">“{order.note}”</p>}
      {order.status !== "Cancelled" && order.status !== "Submitting" && (
        <ol className="srv-steps" aria-label="Delivery progress">
          {STEPS.map((s, i) => (
            <li key={s} className={i < step ? "done" : ""}>
              {s}
            </li>
          ))}
        </ol>
      )}
      <footer>
        <small>
          {order.status === "Cancelled" ? `Cancelled · ${order.reason}` : order.status === "Scheduled" ? `${order.time} · sends when the party arrives` : `Sent ${order.time}`}
          {eta && ` · ${eta}`}
        </small>
        {order.status === "Submitting" && <span className="spinner small" aria-label="Sending" />}
      </footer>
      {(action || canCancel) && (
        <div className="srv-order-actions">
          {canCancel && (
            <button className="text-action danger" onClick={() => ui.sheet({ eyebrow: `ORDER ${order.id}`, title: "Cancel this order?", body: (close) => <ConfirmCancel order={order} close={close} /> })}>
              Cancel
            </button>
          )}
          {action && (
            <button className="primary-action" onClick={action.run}>
              {action.label}
            </button>
          )}
        </div>
      )}
    </article>
  )
}

/* ---------------- My Tables ---------------- */

function TableRow({ t }: { t: SrvTable }) {
  const srv = useServer()
  const reqs = openReqs(srv.requests, t.id).length
  const ready = srv.orders.some((o) => o.table === t.id && o.status === "Ready")
  const flagged = srv.orders.some((o) => o.table === t.id && needsSub(o))
  const handing = srv.handovers.find((h) => h.table === t.id && h.status === "Waiting")
  return (
    <button className="srv-table" onClick={() => srv.setView({ screen: "table", id: t.id })}>
      <span className="srv-num">{t.id}</span>
      <span className="srv-main">
        <strong>{t.guest}</strong>
        <small>
          {t.section} · {t.party} guests · {t.time}
        </small>
        <span className="srv-tags">
          <Chip tone={ARRIVAL_TONE[t.arrival]}>{t.arrival}</Chip>
          {reqs > 0 && <Chip tone="orange">{reqs} request{reqs === 1 ? "" : "s"}</Chip>}
          {ready && <Chip tone="blue">Order ready</Chip>}
          {flagged && <Chip tone="red">Item unavailable</Chip>}
          {handing && <Chip tone="gray">Handing to {handing.to.split(" ")[0]}</Chip>}
          {!t.mine && t.handedTo && <Chip tone="gray">{t.handedTo.split(" ")[0]}'s table</Chip>}
        </span>
      </span>
      <Icon name="chevron" size={16} />
    </button>
  )
}

function TablesList() {
  const srv = useServer()
  const sheets = useServerSheets()
  const mine = srv.tables.filter((t) => t.mine)
  const others = srv.tables.filter((t) => !t.mine)
  const reqs = openReqs(srv.requests)
  if (srv.load === "loading")
    return (
      <>
        <Title eyebrow="ON SHIFT · 7 PM – 2 AM" title="My Tables" />
        <Skeleton rows={5} />
      </>
    )
  if (srv.load === "error")
    return (
      <>
        <Title eyebrow="ON SHIFT · 7 PM – 2 AM" title="My Tables" />
        <StateBlock icon="wifi" title="Couldn't load your tables" text="Check your connection. Nothing you started has been lost." action="Retry" onAction={srv.reload} />
      </>
    )
  return (
    <>
      <Title
        eyebrow="ON SHIFT · 7 PM – 2 AM"
        title="My Tables"
        action={
          <button className="icon-button" aria-label="Refresh tables" onClick={srv.reload} disabled={srv.refreshing}>
            {srv.refreshing ? <span className="spinner small" /> : <Icon name="refresh" size={18} />}
          </button>
        }
      />
      {reqs.length > 0 && (
        <section className="srv-section">
          <h2>
            Guest requests <span>{reqs.length}</span>
          </h2>
          <div className="srv-list">
            {reqs.map((r) => (
              <button key={r.id} className="srv-req" onClick={() => sheets.request(r.id)}>
                <span className="srv-num small">{r.table}</span>
                <span className="srv-main">
                  <strong>{r.kind}</strong>
                  <small>{r.text}</small>
                </span>
                <Chip tone={r.status === "Open" ? "orange" : "blue"}>{r.status === "Open" ? "New" : "On it"}</Chip>
              </button>
            ))}
          </div>
        </section>
      )}
      <section className="srv-section">
        <h2>
          Assigned to you <span>{mine.length}</span>
        </h2>
        {mine.length ? (
          <div className="srv-list">
            {mine.map((t) => (
              <TableRow key={t.id} t={t} />
            ))}
          </div>
        ) : (
          <StateBlock icon="venue" title="No tables assigned" text="Your manager hasn't assigned tables yet. They'll appear here." />
        )}
      </section>
      {others.length > 0 && (
        <section className="srv-section">
          <h2>Elsewhere in your section</h2>
          <div className="srv-list">
            {others.map((t) => (
              <TableRow key={t.id} t={t} />
            ))}
          </div>
        </section>
      )}
    </>
  )
}

function TableDetail({ id }: { id: string }) {
  const srv = useServer()
  const openSign = useSignSheet()
  const sheets = useServerSheets()
  const t = srv.tables.find((x) => x.id === id)
  if (!t)
    return (
      <>
        <BackBar label="My Tables" onBack={() => srv.setView({ screen: "list" })} />
        <StateBlock icon="venue" title="Table not found" text="It may have been reassigned." action="Back to My Tables" onAction={() => srv.setView({ screen: "list" })} />
      </>
    )
  const orders = srv.orders.filter((o) => o.table === id)
  const reqs = openReqs(srv.requests, id)
  const draft = srv.drafts[id]
  const canOrder = t.mine && (t.arrival === "Seated" || t.arrival === "Arrived")
  const payNote: Record<Payment, string> = {
    "Deposit paid": `Deposit of $${t.deposit} recorded. A manager settles the balance.`,
    "Balance open": `Deposit of $${t.deposit} recorded. Balance to be collected by a manager.`,
    "Paid in full": "Paid in full. Nothing to collect.",
    "Pay at venue": "No deposit. A manager collects payment at the end.",
  }
  return (
    <>
      <BackBar label="My Tables" onBack={() => srv.setView({ screen: "list" })} />
      <div className="srv-detail-head">
        <span className="srv-num big">{t.id}</span>
        <div>
          <h1>{t.guest}</h1>
          <p>
            {t.section} · {t.party} guests · <Chip tone={ARRIVAL_TONE[t.arrival]}>{t.arrival}</Chip>
          </p>
        </div>
      </div>
      {!t.mine && <p className="srv-notice">{t.handedTo ? `Handed to ${t.handedTo}. You can view this table but not order for it.` : "Not assigned to you."}</p>}

      {reqs.length > 0 && (
        <section className="srv-section">
          <h2>Guest requests</h2>
          <div className="srv-list">
            {reqs.map((r) => (
              <button key={r.id} className="srv-req" onClick={() => sheets.request(r.id)}>
                <span className="srv-main">
                  <strong>{r.kind}</strong>
                  <small>
                    {r.text} · {r.time}
                  </small>
                </span>
                <Chip tone={r.status === "Open" ? "orange" : "blue"}>{r.status === "Open" ? "New" : "On it"}</Chip>
              </button>
            ))}
          </div>
        </section>
      )}

      <section className="srv-section">
        <div className="ds-sec-head">
          <h2>Orders</h2>
          {orders.some((o) => o.status !== "Cancelled" && o.status !== "Delivered") && (
            <button className="text-action" onClick={() => openSign(orders.find((o) => o.sign && o.status !== "Cancelled") ?? orders.find((o) => o.status !== "Cancelled" && o.status !== "Delivered")!)}>
              <Icon name="pencil" size={13} /> Bottle sign
            </button>
          )}
        </div>
        {draft && draft.items.length > 0 && (
          <button className="srv-draft" onClick={() => srv.setView({ screen: "add", id })}>
            <Icon name="orders" size={16} /> Unsent order · {draft.items.reduce((s, i) => s + i.qty, 0)} items <span>Continue</span>
          </button>
        )}
        {orders.length ? orders.map((o) => <OrderCard key={o.id} order={o} showTable={false} />) : <p className="srv-muted pad">No orders yet.</p>}
      </section>

      <section className="srv-section">
        <h2>Reservation</h2>
        <Lines
          rows={[
            ["Booked for", t.time],
            ["Party", `${t.party} guests`],
            ["Package", t.pkg],
            ["Includes", t.includes],
            ["Minimum spend", `$${t.minSpend.toLocaleString()}`],
          ]}
        />
      </section>

      <section className="srv-section">
        <h2>Payment</h2>
        <div className="srv-pay">
          <Chip tone={t.payment === "Paid in full" ? "green" : t.payment === "Balance open" ? "amber" : "gray"}>{t.payment}</Chip>
          <p>{payNote[t.payment]}</p>
          <small>
            <Icon name="lock" size={13} /> Only managers can take payments, discounts or refunds.
          </small>
        </div>
      </section>

      <div className="srv-actions">
        <button className="secondary-action" onClick={() => sheets.contact(id)}>
          Contact Team
        </button>
        {reqs.length > 0 && (
          <button className="secondary-action" onClick={() => sheets.request(reqs[0].id)}>
            Respond
          </button>
        )}
        <button className="primary-action" disabled={!canOrder} onClick={() => srv.setView({ screen: "add", id })}>
          {!canOrder ? "Add Order after arrival" : draft?.items.length ? "Continue order" : "Add Order"}
        </button>
      </div>
      {t.mine && !canOrder && <p className="srv-muted center">You can order once the party arrives.</p>}
    </>
  )
}

function BackBar({ label, onBack }: { label: string; onBack: () => void }) {
  return (
    <button className="srv-back" onClick={onBack}>
      <Icon name="back" size={18} /> {label}
    </button>
  )
}

/* ---------------- Add Order ---------------- */

function AddOrder({ id }: { id: string }) {
  const srv = useServer()
  const ui = useUI()
  const draft: Draft = srv.drafts[id] ?? { items: [], note: "" }
  const [sending, setSending] = useState(false)
  const MENU = useMenu()
  const set = (d: Partial<Draft>) => srv.setDraft(id, { ...draft, error: undefined, ...d })
  const qtyOf = (name: string) => draft.items.find((i) => i.name === name)?.qty ?? 0
  const change = (name: string, delta: number) => {
    const m = MENU.find((x) => x.name === name)!
    const cur = draft.items.find((i) => i.name === name)
    const qty = Math.max(0, (cur?.qty ?? 0) + delta)
    const items = cur ? draft.items.map((i) => (i.name === name ? { ...i, qty } : i)).filter((i) => i.qty > 0) : qty > 0 ? [...draft.items, { name, qty, mixers: m.mixers?.[0] }] : draft.items
    set({ items })
  }
  const count = draft.items.reduce((s, i) => s + i.qty, 0)
  const total = draft.items.reduce((s, i) => s + i.qty * (MENU.find((m) => m.name === i.name)?.price ?? 0), 0)
  const send = async () => {
    if (sending) return
    setSending(true)
    const ok = await srv.submit(id)
    setSending(false)
    if (ok) {
      ui.toast("Sent. Waiting for the bar to accept.")
      srv.setView({ screen: "table", id })
    }
  }
  const trySend = () => {
    const key = (items: OrderItem[]) => items.map((i) => `${i.qty}${i.name}${i.mixers ?? ""}`).sort().join("|")
    const dup = srv.orders.find((o) => o.table === id && ["New", "Preparing", "Submitting"].includes(o.status) && key(o.items) === key(draft.items))
    if (dup)
      return ui.sheet({
        eyebrow: "CHECK BEFORE SENDING",
        title: "Looks like a duplicate",
        body: (close) => (
          <div className="srv-sheet">
            <p className="srv-muted">
              Order {dup.id} for {id} has the same items and is {dup.status === "Preparing" ? "being prepared" : "already sent"}. Send another one?
            </p>
            <div className="dual-actions">
              <button className="secondary-action" onClick={close}>
                Don't send
              </button>
              <button
                className="primary-action"
                onClick={() => {
                  close()
                  void send()
                }}
              >
                Send anyway
              </button>
            </div>
          </div>
        ),
      })
    void send()
  }
  return (
    <>
      <BackBar label={id} onBack={() => srv.setView({ screen: "table", id })} />
      <Title eyebrow={`${id} · ADD ORDER`} title="Add Order" />
      <p className="srv-muted">Your selection is saved if you leave this screen.</p>
      <div className="srv-menu">
        {MENU.map((m) => {
          const q = qtyOf(m.name)
          const item = draft.items.find((i) => i.name === m.name)
          return (
            <div key={m.name} className={`srv-menu-item ${m.unavailable ? "off" : ""}`}>
              <div className="srv-menu-row">
                <span className="srv-main">
                  <strong>{m.name}</strong>
                  <small>
                    {m.kind} · ${m.price}
                    {m.unavailable && " · Unavailable tonight"}
                  </small>
                </span>
                {m.unavailable ? (
                  <Chip tone="red">Unavailable</Chip>
                ) : (
                  <span className="srv-stepper">
                    <button aria-label={`Remove ${m.name}`} disabled={q === 0 || sending} onClick={() => change(m.name, -1)}>
                      −
                    </button>
                    <b aria-live="polite">{q}</b>
                    <button aria-label={`Add ${m.name}`} disabled={sending} onClick={() => change(m.name, 1)}>
                      +
                    </button>
                  </span>
                )}
              </div>
              {q > 0 && m.mixers && (
                <label className="srv-mixers">
                  <span>Mixers</span>
                  <select value={item?.mixers} onChange={(e) => set({ items: draft.items.map((i) => (i.name === m.name ? { ...i, mixers: e.target.value } : i)) })}>
                    {m.mixers.map((x) => (
                      <option key={x}>{x}</option>
                    ))}
                    {m.mixers.length > 1 && <option>{`${m.mixers[0]}, ${m.mixers[1]}`}</option>}
                  </select>
                </label>
              )}
              {m.unavailable && <small className="srv-sub-hint">Ask a manager about a substitute: {SUBSTITUTES[m.name]?.join(" or ")}.</small>}
            </div>
          )
        })}
      </div>
      <label className="field srv-note-field">
        <span>Special instructions</span>
        <textarea rows={2} value={draft.note} maxLength={160} placeholder="Allergies, sparklers, timing…" onChange={(e) => set({ note: e.target.value })} />
      </label>
      {draft.error && (
        <div className="srv-error" role="alert">
          <Icon name="wifi" size={16} />
          <span>{draft.error}</span>
        </div>
      )}
      <div className="srv-actions">
        <button className="primary-action grow" disabled={count === 0 || sending} onClick={trySend}>
          {sending ? (
            <>
              <span className="spinner small" /> Sending…
            </>
          ) : draft.error ? (
            "Retry · send to bar"
          ) : count ? (
            `Send to bar · ${count} item${count === 1 ? "" : "s"} · $${total.toLocaleString()}`
          ) : (
            "Choose items"
          )}
        </button>
      </div>
    </>
  )
}

/* ---------------- Orders ---------------- */

function OrdersTab() {
  const srv = useServer()
  const filters = ["New", "Preparing", "Ready", "Delivered", "Cancelled"]
  const mineIds = new Set(srv.tables.filter((t) => t.mine).map((t) => t.id))
  const all = srv.orders.filter((o) => mineIds.has(o.table) || o.status === "Submitting")
  const shown = all.filter((o) => filterOf(o) === srv.filter)
  return (
    <>
      <Title eyebrow="YOUR TABLES" title="Orders" />
      <div className="srv-filters" role="tablist" aria-label="Order status">
        {filters.map((f) => {
          const n = all.filter((o) => filterOf(o) === f).length
          return (
            <button key={f} role="tab" aria-selected={srv.filter === f} className={srv.filter === f ? "on" : ""} onClick={() => srv.setFilter(f)}>
              {f}
              {n > 0 && f !== "Delivered" && f !== "Cancelled" && <span>{n}</span>}
            </button>
          )
        })}
      </div>
      {srv.load === "loading" ? (
        <Skeleton rows={3} />
      ) : srv.load === "error" ? (
        <StateBlock icon="wifi" title="Couldn't load orders" text="Check your connection and try again." action="Retry" onAction={srv.reload} />
      ) : shown.length === 0 ? (
        <StateBlock icon="orders" title={`No ${srv.filter.toLowerCase()} orders`} text={srv.filter === "New" ? "Add an order from a table to get started." : "Orders move here as the bar updates them."} />
      ) : (
        <div className="srv-orders">
          {shown.map((o) => (
            <OrderCard key={o.id} order={o} />
          ))}
        </div>
      )}
    </>
  )
}

/* ---------------- Team ---------------- */

function TeamTab() {
  const srv = useServer()
  const ui = useUI()
  const sheets = useServerSheets()
  return (
    <>
      <Title eyebrow="NOVA ROOM" title="Team" />
      <div className="srv-shift">
        <div>
          <span>Current shift</span>
          <strong>Main floor · Section B</strong>
          <small>Nova Room · 7:00 PM – 2:00 AM</small>
        </div>
        <Chip tone="green">On shift</Chip>
      </div>
      {srv.assist && (
        <div className="srv-assist" role="status">
          <Icon name="team" size={18} />
          <span>
            <strong>{srv.assist.status === "Sending" ? "Notifying manager…" : "Jordan is on the way"}</strong>
            <small>{srv.assist.reason}</small>
          </span>
          <button className="text-action" onClick={() => (srv.cancelAssist(), ui.toast("Request cancelled"))}>
            Cancel
          </button>
        </div>
      )}
      <div className="srv-list">
        <button className="srv-req" onClick={sheets.askManager}>
          <span className="row-icon">
            <Icon name="team" size={18} />
          </span>
          <span className="srv-main">
            <strong>Ask a manager</strong>
            <small>Payments, guest issues, approvals</small>
          </span>
          <Icon name="chevron" size={16} />
        </button>
        <button className="srv-req" onClick={() => sheets.handover()}>
          <span className="row-icon">
            <Icon name="handover" size={18} />
          </span>
          <span className="srv-main">
            <strong>Hand over a table</strong>
            <small>Pass a table and its orders to a teammate</small>
          </span>
          <Icon name="chevron" size={16} />
        </button>
        <button className="srv-req" onClick={sheets.chat}>
          <span className="row-icon">
            <Icon name="chat" size={18} />
          </span>
          <span className="srv-main">
            <strong>Floor team chat</strong>
            <small>Jordan: T7 arrives at 10:30</small>
          </span>
          <Icon name="chevron" size={16} />
        </button>
      </div>
      {srv.handovers.length > 0 && (
        <section className="srv-section">
          <h2>Handovers</h2>
          <div className="srv-list">
            {srv.handovers.map((h) => (
              <div key={h.table} className="srv-req static">
                <span className="srv-num small">{h.table}</span>
                <span className="srv-main">
                  <strong>To {h.to}</strong>
                  <small>{h.note || "No note"}</small>
                </span>
                <Chip tone={h.status === "Accepted" ? "green" : "gray"}>{h.status === "Accepted" ? "Accepted" : "Waiting"}</Chip>
              </div>
            ))}
          </div>
        </section>
      )}
      <section className="srv-section">
        <h2>On shift</h2>
        <div className="srv-list">
          {TEAM.map((m) => (
            <button key={m.name} className="srv-req" onClick={() => ui.sheet({ eyebrow: m.role.toUpperCase(), title: m.name, body: (close) => <MemberBody name={m.name} role={m.role} status={m.status} close={close} /> })}>
              <span className="srv-avatar">{m.name.split(" ").map((p) => p[0]).join("")}</span>
              <span className="srv-main">
                <strong>{m.name}</strong>
                <small>
                  {m.role} · {m.status}
                </small>
              </span>
              <Icon name="chevron" size={16} />
            </button>
          ))}
        </div>
      </section>
      <section className="srv-section">
        <h2>Shift changes</h2>
        <div className="srv-pay">
          <p>
            <Icon name="lock" size={14} /> Only managers can change shifts or reassign tables.
          </p>
          <button className="secondary-action" disabled={srv.shiftRequest} onClick={() => (srv.requestShiftChange(), ui.toast("Shift change request sent to Jordan"))}>
            {srv.shiftRequest ? "Request sent" : "Request a shift change"}
          </button>
        </div>
      </section>
    </>
  )
}

/* ---------------- More ---------------- */

function MoreTab({ appearance, onAppearance, onSignOut }: { appearance: Appearance; onAppearance: (a: Appearance) => void; onSignOut: () => void }) {
  const srv = useServer()
  const ui = useUI()
  const row = (icon: IconName, title: string, desc: string, run: () => void) => (
    <button className="srv-req" onClick={run}>
      <span className="row-icon">
        <Icon name={icon} size={18} />
      </span>
      <span className="srv-main">
        <strong>{title}</strong>
        <small>{desc}</small>
      </span>
      <Icon name="chevron" size={16} />
    </button>
  )
  return (
    <>
      <Title eyebrow="SERVER" title="More" />
      <div className="srv-list">
        {row("clock", "Shift details", "Schedule, breaks and location", () => ui.sheet({ eyebrow: "SERVER", title: "Shift details", body: () => <ShiftBody place="Nova Room · Main floor, section B" hours="7:00 PM – 2:00 AM" /> }))}
        {row("chat", "Support", "Help articles and chat", () => ui.sheet({ eyebrow: "HELP", title: "Support", body: () => <SupportBody /> }))}
        {row("settings", "Settings", "Follow system appearance, notifications", () => ui.sheet({ eyebrow: "ACCOUNT", title: "Settings", body: () => <SettingsBody appearance={appearance} onAppearance={onAppearance} onSignOut={onSignOut} /> }))}
      </div>
      <section className="srv-section">
        <h2>Demo controls</h2>
        <label className="srv-toggle">
          <span>
            <strong>Simulate connection problems</strong>
            <small>The next load or order fails once, so you can try Retry.</small>
          </span>
          <input type="checkbox" checked={srv.unstable} onChange={(e) => srv.setUnstable(e.target.checked)} />
        </label>
        {srv.unstable && (
          <button className="secondary-action full-action" onClick={() => (srv.setView({ screen: "list" }), srv.reload())}>
            Reload tables now
          </button>
        )}
      </section>
      <button className="signout-button" onClick={onSignOut}>
        Sign out of demo
      </button>
    </>
  )
}

/* ---------------- entry ---------------- */

export function ServerApp({ tab, appearance, onAppearance, onSignOut }: { tab: string; appearance: Appearance; onAppearance: (a: Appearance) => void; onSignOut: () => void }) {
  const srv = useServer()
  useEffect(() => {
    if (srv.load === "loading") srv.reload()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  if (tab === "orders") return <OrdersTab />
  if (tab === "team") return <TeamTab />
  if (tab === "more") return <MoreTab appearance={appearance} onAppearance={onAppearance} onSignOut={onSignOut} />
  if (srv.view.screen === "table") return <TableDetail id={srv.view.id} />
  if (srv.view.screen === "add") return <AddOrder id={srv.view.id} />
  return <TablesList />
}

export function useServerBadges() {
  const srv = useServer()
  const mine = new Set(srv.tables.filter((t) => t.mine).map((t) => t.id))
  return {
    tables: openReqs(srv.requests).filter((r) => mine.has(r.table)).length,
    orders: srv.orders.filter((o) => mine.has(o.table) && (o.status === "Ready" || needsSub(o))).length,
  }
}
