import { createContext, useContext, useEffect, useState, type ReactNode } from "react"
import { usePersisted, Icon, Thread, useUI } from "./kit"
import { useStore } from "./store"

/* Guest side of the venue, shared by Owner and Manager:
   guest messages, message requests, help & safety requests, bottle-sign approvals,
   and refund requests. Demo data matches the BottlesUp user app (Jordan Ellis,
   Halo Booth at Nova Room, Don Julio 1942 with a "HAPPY 30TH JORDAN" sign). */

export type Viewer = "owner" | "manager" | "staff"
export type Msg = { id: string; mine: boolean; text: string; time: string; who?: string; status?: "sending" | "sent" | "failed"; image?: string }
export type Card = { kind: "Booking" | "Table" | "Handover" | "Event"; title: string; detail: string }
export type GuestThread = { id: string; area: "Customers" | "Team"; guest: string; context: string; scope: string; unread: number; msgs: Msg[]; card?: Card; members?: string[] }
export type MsgRequest = { id: string; guest: string; text: string; time: string }
export type HelpReq = { id: string; guest: string; booking: string; kind: string; text: string; time: string; status: "New" | "On it" | "Resolved"; safety?: boolean }
export type SignReq = { id: string; guest: string; booking: string; style: string; text: string; bottle: string; timing: string; status: "Waiting" | "Approved" | "Change requested"; note?: string }
export type RefundReq = { id: string; bookingId: string; guest: string; amount: number; reason: string; by: string; status: "Waiting for owner" | "Approved" | "Declined" }

export type PassStatus = "Valid" | "Invited" | "Open" | "Used" | "Cancelled" | "Refunded"
export type BookingExtra = { ref: string; passes: { name: string; status: PassStatus }[]; preorder: string[]; sign?: string; paid: number; hoursToStart: number }

/** Extra details for bookings made in the user app. */
export const EXTRAS: Record<string, BookingExtra> = {
  "b-jordan": {
    ref: "NR-2841",
    passes: [
      { name: "Jordan Ellis (host)", status: "Valid" },
      { name: "Maya Chen", status: "Valid" },
      { name: "Noah Reid", status: "Used" },
      { name: "Sofia Bell", status: "Valid" },
      { name: "Open pass", status: "Open" },
      { name: "Open pass", status: "Open" },
      { name: "Chris Morgan", status: "Cancelled" },
    ],
    preorder: ["Don Julio 1942 × 1"],
    sign: "LED board · “HAPPY 30TH JORDAN” · at midnight",
    paid: 1193.0, // deposit $150 credited to Don Julio $1,000 + LED sign $25, + 3% fee + 13% HST
    hoursToStart: 3,
  },
  "b-future": {
    ref: "NR-3107",
    passes: [{ name: "Priya Shah (host)", status: "Valid" }, { name: "Open pass", status: "Open" }, { name: "Open pass", status: "Open" }, { name: "Open pass", status: "Open" }],
    preorder: [],
    paid: 232.78, // Arc Table deposit $200 + 3% fee + 13% HST
    hoursToStart: 170,
  },
}

type Api = {
  viewer: Viewer
  setViewer: (v: Viewer) => void
  threads: GuestThread[]
  setThreads: (fn: (t: GuestThread[]) => GuestThread[]) => void
  requests: MsgRequest[]
  setRequests: (fn: (r: MsgRequest[]) => MsgRequest[]) => void
  help: HelpReq[]
  setHelp: (fn: (h: HelpReq[]) => HelpReq[]) => void
  signs: SignReq[]
  setSigns: (fn: (s: SignReq[]) => SignReq[]) => void
  refunds: RefundReq[]
  setRefunds: (fn: (r: RefundReq[]) => RefundReq[]) => void
  cancelled: Record<string, string>
  cancelBooking: (id: string, note: string) => void
  open: boolean
  setOpen: (o: boolean) => void
  openArea: "Customers" | "Team" | "Requests"
  openTo: (area: "Customers" | "Team" | "Requests", threadId?: string) => void
  pendingThread: string | null
  clearPending: () => void
  failNext: boolean
  setFailNext: (b: boolean) => void
}

const Ctx = createContext<Api | null>(null)
export const useGuests = () => {
  const c = useContext(Ctx)
  if (!c) throw new Error("useGuests outside GuestProvider")
  return c
}

export function GuestProvider({ children }: { children: ReactNode }) {
  const [viewer, setViewer] = useState<Viewer>("owner")
  const m = (id: string, mine: boolean, text: string, time: string, who?: string): Msg => ({ id, mine, text, time, who, status: mine ? "sent" : undefined })
  const [threads, setThreads] = usePersisted<GuestThread[]>("bu-biz-guests-threads", [
    { id: "t-jordan", area: "Customers", guest: "Jordan Ellis", context: "Halo Booth · arriving 12:30 AM", scope: "Nova Room", unread: 1, card: { kind: "Booking", title: "Halo Booth · NR-2841", detail: "6 guests · Don Julio 1942 · LED sign at midnight" }, msgs: [m("j1", false, "Hi! Can the sign come out right at midnight? It's my 30th.", "9:31 PM", "Jordan")] },
    { id: "t-maya", area: "Customers", guest: "Maya Chen", context: "Guest on Jordan's booking", scope: "Nova Room", unread: 0, msgs: [m("m1", false, "Is there coat check tonight?", "8:50 PM", "Maya"), m("m2", true, "Yes, by the main entrance. $4 per item.", "8:52 PM")] },
    { id: "t-priya", area: "Customers", guest: "Priya Shah", context: "Table enquiry · next Saturday", scope: "Nova Room", unread: 1, card: { kind: "Table", title: "Arc Table · Sat, Aug 31", detail: "Asking about a cake for 8 guests" }, msgs: [m("p1", false, "Can I bring my own birthday cake?", "7:12 PM", "Priya")] },
    { id: "t-neon", area: "Customers", guest: "Liam Carter", context: "Ticket question · Neon Garden", scope: "Neon Garden", unread: 0, msgs: [m("l1", false, "Do GA tickets include coat check?", "Yesterday", "Liam")] },
    { id: "t-floor", area: "Team", guest: "Floor team", context: "Servers, runners and managers on shift", scope: "Nova Room", unread: 2, msgs: [m("f1", false, "Halo Booth arrives 12:30. Sign goes out at midnight.", "9:20 PM", "Jordan B."), m("f2", false, "Runner needed at VIP in 5.", "9:39 PM", "Sam")] },
    { id: "t-door", area: "Team", guest: "Door team", context: "Main and VIP entrances", scope: "Nova Room", unread: 0, msgs: [m("d1", false, "Guest list printed. Line is moving.", "9:05 PM", "Jamie")] },
    { id: "t-handover", area: "Team", guest: "Riley Chen", context: "Table handover", scope: "Nova Room", unread: 1, card: { kind: "Handover", title: "T9 handed to Riley", detail: "Noah Kim · 5 guests · 1 open request" }, msgs: [m("r1", false, "Got T9. Anything I should know?", "9:36 PM", "Riley")] },
    { id: "t-org", area: "Team", guest: "Midnight Social", context: "Organiser · Neon Garden", scope: "Neon Garden", unread: 0, card: { kind: "Event", title: "Neon Garden · Sat, 31 Aug", detail: "Agreement: changes requested" }, msgs: [m("o1", false, "We've updated the bar-sales terms.", "8:58 PM", "Midnight Social")] },
  ])
  const [requests, setRequests] = usePersisted<MsgRequest[]>("bu-biz-guests-requests", [
    { id: "r1", guest: "Afterdark Events", text: "We'd love to host a takeover at Nova Room. Who handles bookings?", time: "1h" },
    { id: "r2", guest: "Marcus Lee", text: "Do you still have tables for tonight?", time: "22m" },
  ])
  const [help, setHelp] = usePersisted<HelpReq[]>("bu-biz-guests-help", [
    { id: "h1", guest: "Sofia Bell", booking: "Halo Booth · NR-2841", kind: "A guest can't access their pass", text: "My pass says Invited, but I accepted it.", time: "9:38 PM", status: "New" },
    { id: "h2", guest: "Zoe Martin", booking: "Table 10", kind: "Safety concern", text: "Someone near the bar is making our group uncomfortable.", time: "9:40 PM", status: "New", safety: true },
    { id: "h3", guest: "Grace King", booking: "Table 3", kind: "Question about my payment", text: "Was the deposit taken twice?", time: "8:15 PM", status: "On it" },
  ])
  const [signs, setSigns] = usePersisted<SignReq[]>("bu-biz-guests-signs", [
    { id: "s1", guest: "Jordan Ellis", booking: "Halo Booth · NR-2841", style: "LED message board", text: "HAPPY 30TH JORDAN", bottle: "Don Julio 1942", timing: "At midnight", status: "Waiting" },
    { id: "s2", guest: "Marcus Hill", booking: "VIP Booth", style: "Sparkler sign", text: "CONGRATS MARCUS", bottle: "Dom Pérignon Brut", timing: "At midnight", status: "Approved" },
    { id: "s3", guest: "Leo Scott", booking: "Table 16", style: "Neon script", text: "Leo's last night single", bottle: "Grey Goose", timing: "On arrival", status: "Waiting" },
  ])
  const [refunds, setRefunds] = usePersisted<RefundReq[]>("bu-biz-guests-refunds", [{ id: "rf1", bookingId: "b14", guest: "Grace King", amount: 150, reason: "Deposit charged twice", by: "Jordan Blake (manager)", status: "Waiting for owner" }])
  const [cancelled, setCancelled] = usePersisted<Record<string, string>>("bu-biz-guests-cancelled", {})
  const [open, setOpen] = useState(false)
  const [openArea, setOpenArea] = useState<"Customers" | "Team" | "Requests">("Customers")
  const [pendingThread, setPendingThread] = useState<string | null>(null)
  const [failNext, setFailNext] = useState(false)
  return (
    <Ctx.Provider
      value={{
        viewer,
        setViewer,
        threads,
        setThreads,
        requests,
        setRequests,
        help,
        setHelp,
        signs,
        setSigns,
        refunds,
        setRefunds,
        cancelled,
        cancelBooking: (id, note) => setCancelled((c) => ({ ...c, [id]: note })),
        open,
        setOpen,
        openArea,
        openTo: (area, threadId) => {
          setOpenArea(area)
          setPendingThread(threadId ?? null)
          setOpen(true)
        },
        pendingThread,
        clearPending: () => setPendingThread(null),
        failNext,
        setFailNext,
      }}
    >
      {children}
    </Ctx.Provider>
  )
}

/* ---------------- Badges ---------------- */

export function useGuestBadge() {
  const g = useGuests()
  const customers = g.viewer === "staff" ? 0 : g.threads.filter((t) => t.area === "Customers").reduce((s, t) => s + t.unread, 0) + g.requests.length
  const team = g.threads.filter((t) => t.area === "Team").reduce((s, t) => s + t.unread, 0)
  const reqs = g.viewer === "staff" ? 0 : g.help.filter((h) => h.status === "New").length + g.signs.filter((x) => x.status === "Waiting").length + (g.viewer === "owner" ? g.refunds.filter((r) => r.status === "Waiting for owner").length : 0)
  return customers + team + reqs
}

export function Tag({ tone, children }: { tone: string; children: ReactNode }) {
  return <span className={`srv-chip tone-${tone}`}>{children}</span>
}

export function ChangeSignBody({ onSend, close }: { onSend: (note: string) => void; close: () => void }) {
  const [note, setNote] = useState("Please shorten it to 20 characters for the LED board.")
  return (
    <div className="srv-sheet">
      <label className="field">
        <span>Message to the guest</span>
        <input value={note} onChange={(e) => setNote(e.target.value)} />
      </label>
      <button className="primary-action full-action" disabled={!note.trim()} onClick={() => (onSend(note.trim()), close())}>
        Send request
      </button>
    </div>
  )
}

/* ---------------- Booking details with passes, pre-orders and refunds ---------------- */

export function BookingExtras({ id, close }: { id: string; close: () => void }) {
  const g = useGuests()
  const ui = useUI()
  const { bookings } = useStore()
  const b = bookings.find((x) => x.id === id)
  const x = EXTRAS[id]
  const signReq = g.signs.find((s) => s.booking.includes(x?.ref ?? "#none"))
  const cancelledNote = g.cancelled[id]
  if (!b) return null
  const cancel = () =>
    ui.sheet({
      eyebrow: `${b.name.toUpperCase()} · ${b.table.toUpperCase()}`,
      title: "Cancel booking",
      body: (c) => <CancelBody bookingId={id} close={() => (c(), close())} />,
    })
  return (
    <>
      {x && (
        <>
          <div className="srv-section">
            <h2>
              Passes <span>{x.passes.length}</span>
            </h2>
            <div className="srv-list">
              {x.passes.map((p, i) => (
                <div key={i} className="srv-req static gc-pass">
                  <span className="srv-main">
                    <strong>{p.name}</strong>
                  </span>
                  <Tag tone={p.status === "Valid" ? "green" : p.status === "Used" ? "gray" : p.status === "Cancelled" ? "red" : p.status === "Refunded" ? "amber" : "blue"}>{p.status}</Tag>
                </div>
              ))}
            </div>
          </div>
          {(x.preorder.length > 0 || x.sign) && (
            <div className="srv-section">
              <h2>Pre-order</h2>
              <div className="srv-list">
                {x.preorder.map((o) => (
                  <div key={o} className="srv-req static">
                    <span className="srv-main">
                      <strong>{o}</strong>
                      <small>Sent to the bar when the party checks in</small>
                    </span>
                  </div>
                ))}
                {x.sign && (
                  <div className="srv-req static">
                    <span className="srv-main">
                      <strong>Bottle sign</strong>
                      <small>{x.sign}</small>
                    </span>
                    {signReq && <Tag tone={signReq.status === "Approved" ? "green" : "orange"}>{signReq.status}</Tag>}
                  </div>
                )}
              </div>
            </div>
          )}
          <p className="srv-muted gc-paid">
            Ref {x.ref} · paid {"$" + x.paid.toLocaleString("en-CA", { minimumFractionDigits: 2 })} · {x.hoursToStart >= 48 ? "inside the free-cancellation window" : "less than 48 hours to go"}
          </p>
        </>
      )}
      {cancelledNote ? (
        <p className="srv-notice">
          <Icon name="close" size={15} /> {cancelledNote}
        </p>
      ) : (
        <button className="text-action danger gc-cancel" onClick={cancel}>
          Cancel booking
        </button>
      )}
    </>
  )
}

function CancelBody({ bookingId, close }: { bookingId: string; close: () => void }) {
  const g = useGuests()
  const ui = useUI()
  const { bookings } = useStore()
  const b = bookings.find((x) => x.id === bookingId)!
  const x = EXTRAS[bookingId]
  const fmt = (n: number) => "$" + n.toLocaleString("en-CA", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  const amount = x?.paid ?? (b.payment.match(/\$(\d+)/) ? Number(b.payment.match(/\$(\d+)/)![1]) : 150)
  const inPolicy = (x?.hoursToStart ?? 0) >= 48
  const [reason, setReason] = useState("Guest asked to cancel")
  const owner = g.viewer === "owner"
  const done = (msg: string, note: string) => {
    g.cancelBooking(bookingId, note)
    ui.toast(msg)
    close()
  }
  return (
    <div className="srv-sheet">
      <p className="srv-muted">
        {inPolicy
          ? `More than 48 hours before the booking: the guest gets a full refund of ${fmt(amount)}.`
          : `Less than 48 hours before the booking: outside the free-cancellation policy.${owner ? " As the owner you can still refund." : " A refund needs the owner's approval."}`}
      </p>
      <label className="field">
        <span>Reason</span>
        <select value={reason} onChange={(e) => setReason(e.target.value)}>
          <option>Guest asked to cancel</option>
          <option>Charged twice</option>
          <option>Venue closed or event changed</option>
          <option>No-show</option>
        </select>
      </label>
      {inPolicy || owner ? (
        <>
          <button className="danger-action" onClick={() => done(`Cancelled. ${fmt(amount)} refunded to ${b.name}.`, `Cancelled · ${fmt(amount)} refunded · ${reason}`)}>
            Cancel and refund {fmt(amount)}
          </button>
          {!inPolicy && (
            <button className="secondary-action full-action" onClick={() => done(`Cancelled with no refund, per policy.`, `Cancelled · no refund (policy) · ${reason}`)}>
              Cancel without refund
            </button>
          )}
        </>
      ) : (
        <>
          <button
            className="primary-action full-action"
            onClick={() => {
              g.setRefunds((l) => [{ id: "rf" + Date.now(), bookingId, guest: b.name, amount, reason, by: "You (manager)", status: "Waiting for owner" }, ...l])
              done("Cancelled. Refund sent to the owner for approval.", `Cancelled · refund waiting for owner · ${reason}`)
            }}
          >
            Cancel and ask owner to refund
          </button>
          <button className="secondary-action full-action" onClick={() => done("Cancelled with no refund, per policy.", `Cancelled · no refund (policy) · ${reason}`)}>
            Cancel without refund
          </button>
        </>
      )}
      <p className="srv-muted">Every pass on this booking stops working at the door. The guest and their invitees are notified.</p>
    </div>
  )
}
