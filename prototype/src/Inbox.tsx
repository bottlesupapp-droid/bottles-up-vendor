import { createContext, useContext, useState, type ReactNode } from "react"
import type { Card, GuestThread, Msg } from "./Guests"
import { usePersisted, Icon, useUI } from "./kit"
import { ChatView } from "./Messages"

/* Inquiries (external) and Team (internal, invited members only) for organizers and DJs.
   Event conversations show the event at the top. Demo data; delivery needs the backend. */

export type Account = "org" | "dj"
type Store = Record<Account, GuestThread[]>
const m = (id: string, mine: boolean, text: string, time: string, who?: string): Msg => ({ id, mine, text, time, who, status: mine ? "sent" : undefined })

const SEED: Store = {
  org: [
    { id: "o-liam", area: "Customers", guest: "Liam Carter", context: "About Neon Garden", scope: "Neon Garden", unread: 1, card: { kind: "Event", title: "Neon Garden · Sat, 31 Aug", detail: "Nova Room · tickets from $35" }, msgs: [m("1", false, "Do GA tickets include coat check?", "9:12 PM", "Liam")] },
    { id: "o-brand", area: "Customers", guest: "Northwind Agency", context: "Private event enquiry", scope: "Midnight Social", unread: 1, msgs: [m("2", false, "Could you produce a staff party for 300 in November?", "Yesterday", "Northwind")] },
    { id: "o-maya", area: "Customers", guest: "Maya Chen", context: "About Warehouse Sessions", scope: "Warehouse Sessions", unread: 0, card: { kind: "Event", title: "Warehouse Sessions · Sat, 28 Sep", detail: "The Warehouse · ticket-only" }, msgs: [m("3", false, "Can I book a table for this one?", "Mon", "Maya"), m("4", true, "It's ticket-only, but I can reserve a standing area near the booth for your group.", "Mon")] },
    { id: "o-ng-team", area: "Team", guest: "Neon Garden crew", context: "Event group · 5 members", scope: "Neon Garden", unread: 2, members: ["Jamie Fox", "Morgan Lee", "Amara Vale", "Nova Room (venue)", "You"], card: { kind: "Event", title: "Neon Garden · Sat, 31 Aug", detail: "Doors 9 PM · 184 tickets sold" }, msgs: [m("5", false, "I can cover the early door shift.", "8:44 PM", "Jamie"), m("6", false, "Set times locked: 11 PM – 1 AM.", "8:51 PM", "Amara")] },
    { id: "o-nova", area: "Team", guest: "Nova Room", context: "Venue contact", scope: "Neon Garden", unread: 0, msgs: [m("7", false, "We've reviewed the bar-sales terms.", "8:58 PM", "Nova Room")] },
    { id: "o-amara", area: "Team", guest: "Amara Vale", context: "DJ · direct message", scope: "Midnight Social", unread: 0, msgs: [m("8", true, "Can you send your rider for Sep 14?", "Sun"), m("9", false, "Sent! Two CDJ-3000s and a DJM-A9.", "Sun", "Amara")] },
  ],
  dj: [
    { id: "d-ellis", area: "Customers", guest: "Jordan Ellis", context: "Booking BK-7559 · Sat, Sep 7", scope: "Bookings", unread: 1, card: { kind: "Booking", title: "BK-7559 · Club set", detail: "Nova Room · 11 PM – 4 AM · New request" }, msgs: [m("1", false, "Big birthday at Nova Room. Afro house all night, please!", "12 min ago", "Jordan")] },
    { id: "d-priya", area: "Customers", guest: "Priya Shah", context: "Booking BK-7490 · Fri, Aug 30", scope: "Bookings", unread: 0, card: { kind: "Booking", title: "BK-7490 · Private event", detail: "42 Queen St W · 8 – 11 PM" }, msgs: [m("2", false, "Some Bollywood mixed in would be amazing.", "Yesterday", "Priya")] },
    { id: "d-ask", area: "Customers", guest: "Sofia Bell", context: "Question before booking", scope: "Inquiries", unread: 1, msgs: [m("3", false, "Do you play weddings outside Toronto?", "2h", "Sofia")] },
    { id: "d-ng", area: "Team", guest: "Neon Garden crew", context: "Event group · invited by Midnight Social", scope: "Events", unread: 1, members: ["Midnight Social", "Jamie Fox", "Nova Room (venue)", "You"], card: { kind: "Event", title: "Neon Garden · Sat, 31 Aug", detail: "Your set: 11 PM – 1 AM" }, msgs: [m("4", false, "Set times locked: 11 PM – 1 AM.", "8:51 PM", "Midnight Social")] },
    { id: "d-sky", area: "Team", guest: "Sky Room", context: "Venue contact", scope: "Events", unread: 0, msgs: [m("5", false, "Load-in is through the back lane on Sep 20.", "Fri", "Sky Room")] },
  ],
}

type Pending = { acc: Account; start: "Inquiries" | "Team"; id: string | null } | null
type Api = { threads: Store; update: (acc: Account, fn: (l: GuestThread[]) => GuestThread[]) => void; failNext: boolean; setFailNext: (b: boolean) => void; pending: Pending; openFor: (p: Pending) => void }
const Ctx = createContext<Api | null>(null)
export const useInbox = () => {
  const c = useContext(Ctx)
  if (!c) throw new Error("useInbox outside InboxProvider")
  return c
}
export function InboxProvider({ children }: { children: ReactNode }) {
  const [threads, setThreads] = usePersisted<Store>("bu-biz-inbox-threads", SEED)
  const [failNext, setFailNext] = useState(false)
  const [pending, openFor] = useState<Pending>(null)
  return <Ctx.Provider value={{ threads, update: (acc, fn) => setThreads((s) => ({ ...s, [acc]: fn(s[acc]) })), failNext, setFailNext, pending, openFor }}>{children}</Ctx.Provider>
}

export const inboxUnread = (l: GuestThread[]) => l.reduce((s, t) => s + t.unread, 0)

/** Start (or reopen) a conversation and return its id. */
export function useStartThread(acc: Account) {
  const ib = useInbox()
  return (t: { id: string; area: "Customers" | "Team"; guest: string; context: string; scope: string; card?: Card; members?: string[]; first?: string }) => {
    ib.update(acc, (l) => (l.some((x) => x.id === t.id) ? l : [{ id: t.id, area: t.area, guest: t.guest, context: t.context, scope: t.scope, unread: 0, card: t.card, members: t.members, msgs: t.first ? [m("f" + Date.now(), false, t.first, "Now", t.guest.split(" ")[0])] : [] }, ...l]))
    return t.id
  }
}

const initials = (n: string) =>
  n
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)

export function Inbox({ acc, onClose, start, openId, contacts, events }: { acc: Account; onClose: () => void; start?: "Inquiries" | "Team"; openId?: string | null; contacts: string[]; events: string[] }) {
  const ib = useInbox()
  const ui = useUI()
  const startThread = useStartThread(acc)
  const [tab, setTab] = useState<"Inquiries" | "Team">(start ?? "Inquiries")
  const [q, setQ] = useState("")
  const [chat, setChat] = useState<string | null>(openId ?? null)
  const list = ib.threads[acc]
  const area = tab === "Inquiries" ? "Customers" : "Team"
  const term = q.trim().toLowerCase()
  const shown = list.filter((t) => t.area === area && (!term || `${t.guest} ${t.context} ${t.msgs.map((x) => x.text).join(" ")}`.toLowerCase().includes(term)))
  const current = list.find((t) => t.id === chat)
  if (current) return <ChatView t={current} update={(fn) => ib.update(acc, fn)} failNext={ib.failNext} setFailNext={ib.setFailNext} onBack={() => setChat(null)} onClose={onClose} />
  const newDm = () =>
    ui.sheet({
      eyebrow: "NEW MESSAGE",
      title: "Message someone",
      body: (close) => (
        <div className="sheet-options">
          {contacts.map((c) => (
            <button
              key={c}
              onClick={() => {
                close()
                setTab("Team")
                setChat(startThread({ id: `dm-${c}`, area: "Team", guest: c, context: "Direct message", scope: "Direct" }))
              }}
            >
              <span className="row-icon">
                <Icon name="chat" size={18} />
              </span>
              <span>
                <strong>{c}</strong>
                <small>Direct message · internal</small>
              </span>
              <Icon name="chevron" size={16} />
            </button>
          ))}
        </div>
      ),
    })
  const newGroup = () => ui.sheet({ eyebrow: "EVENT GROUP CHAT", title: "Create a group", body: (close) => <GroupForm events={events} contacts={contacts} close={close} onCreate={(ev, members) => { setTab("Team"); setChat(startThread({ id: `g-${ev}-${Date.now()}`, area: "Team", guest: `${ev} crew`, context: `Event group · ${members.length + 1} members`, scope: ev, members: [...members, "You"], card: { kind: "Event", title: ev, detail: `Group with ${members.join(", ")}` } })); ui.toast(`Group created. Only invited members can see it.`) }} /> })
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Messages">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close messages" onClick={onClose}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>{acc === "org" ? "MIDNIGHT SOCIAL" : "AMARA VALE · DJ"}</span>
          <h1>Messages</h1>
        </div>
        <button className="icon-button ib-new" aria-label="New message" onClick={newDm}>
          <Icon name="pencil" size={17} />
        </button>
      </div>
      <div className="msg-areas" role="tablist">
        {(["Inquiries", "Team"] as const).map((t) => {
          const n = inboxUnread(list.filter((x) => x.area === (t === "Inquiries" ? "Customers" : "Team")))
          return (
            <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>
              {t}
              {n > 0 && <span>{n}</span>}
            </button>
          )
        })}
      </div>
      <div className="gc-body">
        <p className="msg-hint">{tab === "Inquiries" ? "Guests, clients and anyone contacting you or one of your events." : "Staff, venues, DJs and collaborators. Only invited members can read these."}</p>
        <label className="search-field msg-search">
          <Icon name="search" size={16} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={`Search ${tab.toLowerCase()}`} aria-label={`Search ${tab.toLowerCase()}`} />
        </label>
        {tab === "Team" && (
          <div className="ib-actions">
            <button className="secondary-action" onClick={newDm}>
              <Icon name="chat" size={15} /> Direct message
            </button>
            <button className="secondary-action" onClick={newGroup}>
              <Icon name="team" size={15} /> Event group
            </button>
          </div>
        )}
        {shown.length === 0 ? (
          <div className="state-block">
            <Icon name="chat" size={26} />
            <h2>{term ? "No matches" : "No conversations yet"}</h2>
            <p>{term ? `Nothing matches “${q.trim()}”.` : tab === "Inquiries" ? "When someone messages you or one of your events, it appears here." : "Start a direct message or an event group."}</p>
          </div>
        ) : (
          <div className="srv-list msg-list">
            {shown.map((t) => {
              const last = t.msgs[t.msgs.length - 1]
              return (
                <button
                  key={t.id}
                  className={`msg-row ${t.unread ? "unread" : ""}`}
                  onClick={() => {
                    ib.update(acc, (l) => l.map((x) => (x.id === t.id ? { ...x, unread: 0 } : x)))
                    setChat(t.id)
                  }}
                >
                  <span className={`srv-avatar ${t.area === "Team" ? "team" : ""}`}>{t.members ? <Icon name="team" size={16} /> : initials(t.guest)}</span>
                  <span className="srv-main">
                    <span className="msg-row-top">
                      <strong>{t.guest}</strong>
                      <small>{last?.time ?? ""}</small>
                    </span>
                    <small className="gc-ellipsis">{last ? `${last.mine ? "You: " : ""}${last.image ? "Photo" : last.text}` : "No messages yet"}</small>
                    <small className="gc-ellipsis msg-ctx">{t.card ? `${t.card.kind}: ${t.card.title}` : t.context}</small>
                  </span>
                  {t.unread > 0 && <i className="msg-count">{t.unread}</i>}
                </button>
              )
            })}
          </div>
        )}
        <p className="srv-muted os-note">Demo conversations. Real delivery and notifications need the BottlesUp backend.</p>
      </div>
    </div>
  )
}

function GroupForm({ events, contacts, close, onCreate }: { events: string[]; contacts: string[]; close: () => void; onCreate: (event: string, members: string[]) => void }) {
  const [ev, setEv] = useState(events[0])
  const [members, setMembers] = useState<string[]>([])
  return (
    <div className="form-stack ve-form">
      <label className="field">
        <span>Event</span>
        <select value={ev} onChange={(e) => setEv(e.target.value)}>
          {events.map((x) => (
            <option key={x}>{x}</option>
          ))}
        </select>
      </label>
      <div className="field">
        <span>Invite</span>
        <div className="cp-chips">
          {contacts.map((c) => (
            <button key={c} aria-pressed={members.includes(c)} className={members.includes(c) ? "on" : ""} onClick={() => setMembers(members.includes(c) ? members.filter((x) => x !== c) : [...members, c])}>
              {c}
            </button>
          ))}
        </div>
      </div>
      <button className="primary-action full-action" disabled={!members.length} onClick={() => (onCreate(ev, members), close())}>
        Create group{members.length ? ` with ${members.length}` : ""}
      </button>
    </div>
  )
}
