import { useEffect, useRef, useState } from "react"
import { ChangeSignBody, Tag, useGuestBadge, useGuests, type GuestThread, type Msg, type Viewer } from "./Guests"
import { Icon, clock, useUI } from "./kit"

/* Messages: Customers (guests, table enquiries, bookings), Team (staff, managers,
   organisers, handovers) and Requests (help, bottle signs, refunds). Opens over the
   current screen, so whatever you were doing is still there when you close it. */

const initials = (n: string) =>
  n
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)

/** Small round chat button with an unread badge, shown on operational screens. */
export function MessagesFab({ viewer, hideButton }: { viewer: Viewer; hideButton?: boolean }) {
  const g = useGuests()
  const n = useGuestBadge()
  useEffect(() => {
    if (g.viewer !== viewer) g.setViewer(viewer)
  }, [viewer, g])
  return (
    <>
      {!hideButton && <button className="msg-fab" aria-label={`Messages${n ? `, ${n} unread` : ""}`} onClick={() => g.openTo(viewer === "staff" ? "Team" : g.openArea)}>
        <Icon name="chat" size={22} />
        {n > 0 && <i className="nav-badge">{n > 99 ? "99+" : n}</i>}
      </button>}
      {g.open && <MessagesCenter onClose={() => g.setOpen(false)} />}
    </>
  )
}

export function MessagesCenter({ onClose }: { onClose: () => void }) {
  const g = useGuests()
  const staff = g.viewer === "staff"
  const [area, setArea] = useState<"Customers" | "Team" | "Requests">(staff ? "Team" : g.openArea)
  const [q, setQ] = useState("")
  const [scope, setScope] = useState("All")
  const [chat, setChat] = useState<string | null>(g.pendingThread)
  useEffect(() => {
    if (g.pendingThread) g.clearPending()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || document.querySelector(".sheet-wrap")) return
      if (chat) setChat(null)
      else onClose()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [chat, onClose])
  const unreadOf = (a: "Customers" | "Team") => g.threads.filter((t) => t.area === a).reduce((s, t) => s + t.unread, 0)
  const reqCount = g.help.filter((h) => h.status === "New").length + g.signs.filter((s) => s.status === "Waiting").length + (g.viewer === "owner" ? g.refunds.filter((r) => r.status === "Waiting for owner").length : 0)
  const areas: ["Customers" | "Team" | "Requests", number][] = staff ? [["Team", unreadOf("Team")]] : [["Customers", unreadOf("Customers") + g.requests.length], ["Team", unreadOf("Team")], ["Requests", reqCount]]
  const scopes = ["All", "Nova Room", "Neon Garden"]
  const term = q.trim().toLowerCase()
  const list = g.threads.filter((t) => t.area === area && (scope === "All" || t.scope === scope) && (!term || `${t.guest} ${t.context} ${t.msgs.map((m) => m.text).join(" ")}`.toLowerCase().includes(term)))
  const current = g.threads.find((t) => t.id === chat)
  if (current) return <ChatView t={current} update={g.setThreads} failNext={g.failNext} setFailNext={g.setFailNext} onBack={() => setChat(null)} onClose={onClose} />
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Messages">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close messages" onClick={onClose}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>NOVA ROOM · {g.viewer === "owner" ? "OWNER" : g.viewer === "manager" ? "MANAGER" : "STAFF"}</span>
          <h1>Messages</h1>
        </div>
      </div>
      {areas.length > 1 && (
        <div className="msg-areas" role="tablist" aria-label="Message areas">
          {areas.map(([a, n]) => (
            <button key={a} role="tab" aria-selected={area === a} className={area === a ? "on" : ""} onClick={() => setArea(a)}>
              {a}
              {n > 0 && <span>{n}</span>}
            </button>
          ))}
        </div>
      )}
      <div className="gc-body">
        {area !== "Requests" ? (
          <>
            <p className="msg-hint">{area === "Customers" ? "Guests, table enquiries and booking conversations. Guests never see team messages." : "Staff, managers, organisers and table handovers. Internal only."}</p>
            <label className="search-field msg-search">
              <Icon name="search" size={16} />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={`Search ${area.toLowerCase()}`} aria-label={`Search ${area.toLowerCase()}`} />
              {q && (
                <button aria-label="Clear search" onClick={() => setQ("")}>
                  <Icon name="close" size={14} />
                </button>
              )}
            </label>
            <div className="msg-scopes" aria-label="Filter by venue or event">
              {scopes.map((s) => (
                <button key={s} aria-pressed={scope === s} className={scope === s ? "on" : ""} onClick={() => setScope(s)}>
                  {s}
                </button>
              ))}
            </div>
            {area === "Customers" && g.requests.length > 0 && !term && <MessageRequests />}
            {list.length === 0 ? (
              <div className="state-block">
                <Icon name="chat" size={26} />
                <h2>{term ? "No matches" : "No conversations"}</h2>
                <p>{term ? `Nothing matches “${q.trim()}”.` : "New conversations appear here."}</p>
              </div>
            ) : (
              <div className="srv-list msg-list">
                {list.map((t) => {
                  const last = t.msgs[t.msgs.length - 1]
                  return (
                    <button
                      key={t.id}
                      className={`msg-row ${t.unread ? "unread" : ""}`}
                      onClick={() => {
                        g.setThreads((l) => l.map((x) => (x.id === t.id ? { ...x, unread: 0 } : x)))
                        setChat(t.id)
                      }}
                    >
                      <span className={`srv-avatar ${t.area === "Team" ? "team" : ""}`}>{initials(t.guest)}</span>
                      <span className="srv-main">
                        <span className="msg-row-top">
                          <strong>{t.guest}</strong>
                          <small>{last?.time}</small>
                        </span>
                        <small className="gc-ellipsis">
                          {last?.mine ? "You: " : ""}
                          {last?.image ? "Photo" : last?.text}
                        </small>
                        <small className="gc-ellipsis msg-ctx">{t.context}</small>
                      </span>
                      {t.unread > 0 && <i className="msg-count">{t.unread}</i>}
                    </button>
                  )
                })}
              </div>
            )}
            <p className="srv-muted os-note">Demo conversations.</p>
          </>
        ) : (
          <Requests openChat={(guest) => {
            const t = g.threads.find((x) => x.guest === guest)
            if (t) {
              setArea("Customers")
              setChat(t.id)
            }
          }} />
        )}
      </div>
    </div>
  )
}

function MessageRequests() {
  const g = useGuests()
  const ui = useUI()
  return (
    <section className="srv-section">
      <h2>
        Message requests <span>{g.requests.length}</span>
      </h2>
      <p className="srv-muted">From people who haven't booked or followed Nova Room. They can't see you've read it until you accept.</p>
      <div className="srv-list gc-gap">
        {g.requests.map((r) => (
          <div key={r.id} className="srv-req static gc-request">
            <span className="srv-avatar">{initials(r.guest)}</span>
            <span className="srv-main">
              <strong>{r.guest}</strong>
              <small>{r.text}</small>
              <span className="gc-actions">
                <button
                  className="primary-action"
                  onClick={() => {
                    g.setRequests((l) => l.filter((x) => x.id !== r.id))
                    g.setThreads((l) => [{ id: "t-" + r.id, area: "Customers", guest: r.guest, context: "New conversation", scope: "Nova Room", unread: 0, msgs: [{ id: r.id, mine: false, who: r.guest.split(" ")[0], text: r.text, time: r.time }] }, ...l])
                    ui.toast(`Accepted. ${r.guest} moved to conversations.`)
                  }}
                >
                  Accept
                </button>
                <button className="secondary-action" onClick={() => (g.setRequests((l) => l.filter((x) => x.id !== r.id)), ui.toast("Request declined"))}>
                  Decline
                </button>
                <button className="text-action danger" onClick={() => (g.setRequests((l) => l.filter((x) => x.id !== r.id)), ui.toast(`${r.guest} blocked`))}>
                  Block
                </button>
              </span>
            </span>
          </div>
        ))}
      </div>
    </section>
  )
}

/* ---------------- Chat ---------------- */

const REPLIES: Record<string, string> = { Customers: "Thank you!", Team: "On it." }

export function ChatView({ t, update, failNext, setFailNext, onBack, onClose }: { t: GuestThread; update: (fn: (l: GuestThread[]) => GuestThread[]) => void; failNext: boolean; setFailNext: (b: boolean) => void; onBack: () => void; onClose: () => void }) {
  const ui = useUI()
  const [text, setText] = useState("")
  const end = useRef<HTMLDivElement>(null)
  const file = useRef<HTMLInputElement>(null)
  useEffect(() => {
    end.current?.scrollIntoView({ block: "end" })
  }, [t.msgs.length])
  const patch = (id: string, p: Partial<Msg>) => update((l) => l.map((x) => (x.id === t.id ? { ...x, msgs: x.msgs.map((m) => (m.id === id ? { ...m, ...p } : m)) } : x)))
  const deliver = (id: string) => {
    patch(id, { status: "sending" })
    const fail = failNext || navigator.onLine === false
    window.setTimeout(() => {
      if (fail) {
        setFailNext(false)
        patch(id, { status: "failed" })
        return
      }
      patch(id, { status: "sent" })
      window.setTimeout(() => {
        update((l) => l.map((x) => (x.id === t.id ? { ...x, msgs: [...x.msgs, { id: "r" + Date.now(), mine: false, who: t.guest.split(" ")[0], text: REPLIES[t.area] ?? "Thanks!", time: clock() }] } : x)))
      }, 1400)
    }, 700)
  }
  const send = (msg: Partial<Msg>) => {
    const id = "m" + Date.now()
    update((l) => l.map((x) => (x.id === t.id ? { ...x, msgs: [...x.msgs, { id, mine: true, text: "", time: clock(), status: "sending", ...msg }] } : x)))
    deliver(id)
  }
  return (
    <div className="gc chat" role="dialog" aria-modal="true" aria-label={`Conversation with ${t.guest}`}>
      <div className="chat-head">
        <button className="icon-button" aria-label="Back to messages" onClick={onBack}>
          <Icon name="back" size={18} />
        </button>
        <span className={`srv-avatar ${t.area === "Team" ? "team" : ""}`}>{initials(t.guest)}</span>
        <span className="chat-title">
          <strong>{t.guest}</strong>
          <small>
            {t.area === "Team" ? (t.members ? "Team" : "Team · internal") : "External"} · {t.context}
          </small>
        </span>
        <button className="icon-button" aria-label="Close messages" onClick={onClose}>
          <Icon name="close" size={16} />
        </button>
      </div>
      {t.card && (
        <button className="chat-card" onClick={() => ui.toast(`${t.card!.kind}: ${t.card!.title}`)}>
          <span className="chat-card-kind">{t.card.kind}</span>
          <span className="srv-main">
            <strong>{t.card.title}</strong>
            <small>{t.card.detail}</small>
          </span>
          <Icon name="chevron" size={15} />
        </button>
      )}
      <div className="chat-body">
        {t.msgs.map((m) => (
          <div key={m.id} className={`chat-msg ${m.mine ? "mine" : "theirs"}`}>
            {!m.mine && m.who && <b className="chat-who">{m.who}</b>}
            <div className="chat-bubble">
              {m.image ? <img src={m.image} alt="Attachment" /> : m.text}
            </div>
            <small className="chat-meta">
              {m.time}
              {m.mine && m.status === "sending" && " · Sending…"}
              {m.mine && m.status === "sent" && " · Sent"}
              {m.mine && m.status === "failed" && (
                <>
                  <span className="chat-failed"> · Not sent</span>
                  <button className="text-action" onClick={() => deliver(m.id)}>
                    Retry
                  </button>
                </>
              )}
            </small>
          </div>
        ))}
        <div ref={end} />
      </div>
      <form
        noValidate
        className="chat-compose"
        onSubmit={(e) => {
          e.preventDefault()
          const v = text.trim()
          if (!v) return
          send({ text: v })
          setText("")
        }}
      >
        <button type="button" className="chat-attach" aria-label="Attach a photo" onClick={() => file.current?.click()}>
          <Icon name="paperclip" size={19} />
        </button>
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder={t.area === "Team" ? "Message the team…" : `Reply to ${t.guest.split(" ")[0]}…`} aria-label="Message" enterKeyHint="send" />
        <button type="submit" className="chat-send" aria-label="Send" disabled={!text.trim()}>
          <Icon name="send" size={17} />
        </button>
        <input
          ref={file}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0]
            e.target.value = ""
            if (!f) return
            const r = new FileReader()
            r.onload = () => send({ image: String(r.result), text: "Photo" })
            r.onerror = () => ui.toast("Couldn't attach that photo. Try another.")
            r.readAsDataURL(f)
          }}
        />
      </form>
      <label className="chat-demo">
        <input type="checkbox" checked={failNext} onChange={(e) => setFailNext(e.target.checked)} /> Demo: next message fails to send
      </label>
    </div>
  )
}

/* ---------------- Requests: help, signs, refunds ---------------- */

function Requests({ openChat }: { openChat: (guest: string) => void }) {
  const g = useGuests()
  const ui = useUI()
  const [kind, setKind] = useState<"Help" | "Signs" | "Refunds">("Help")
  const counts = { Help: g.help.filter((h) => h.status === "New").length, Signs: g.signs.filter((s) => s.status === "Waiting").length, Refunds: g.refunds.filter((r) => r.status === "Waiting for owner").length }
  return (
    <>
      <div className="msg-scopes">
        {(["Help", "Signs", "Refunds"] as const).map((k) => (
          <button key={k} aria-pressed={kind === k} className={kind === k ? "on" : ""} onClick={() => setKind(k)}>
            {k}
            {counts[k] > 0 && ` · ${counts[k]}`}
          </button>
        ))}
      </div>
      {kind === "Help" && (
        <section className="srv-section">
          <p className="srv-muted">Sent from guests' My Night → Help. Safety reports appear first.</p>
          <div className="gc-cards">
            {[...g.help]
              .sort((a, b) => Number(!!b.safety) - Number(!!a.safety))
              .map((h) => (
                <article key={h.id} className={`gc-card ${h.safety ? "safety" : ""}`}>
                  <header>
                    <strong>{h.kind}</strong>
                    <Tag tone={h.status === "New" ? (h.safety ? "red" : "orange") : h.status === "On it" ? "blue" : "green"}>{h.status}</Tag>
                  </header>
                  <p>“{h.text}”</p>
                  <small>
                    {h.guest} · {h.booking} · {h.time}
                  </small>
                  {h.status !== "Resolved" && (
                    <div className="gc-actions">
                      {h.status === "New" && (
                        <button className="primary-action" onClick={() => (g.setHelp((l) => l.map((x) => (x.id === h.id ? { ...x, status: "On it" } : x))), ui.toast(h.safety ? "Security alerted. Guest told help is coming." : `${h.guest.split(" ")[0]} told you're on it`))}>
                          {h.safety ? "Send security" : "On it"}
                        </button>
                      )}
                      {h.status === "On it" && (
                        <button className="primary-action" onClick={() => (g.setHelp((l) => l.map((x) => (x.id === h.id ? { ...x, status: "Resolved" } : x))), ui.toast("Marked resolved"))}>
                          Mark resolved
                        </button>
                      )}
                      <button className="secondary-action" onClick={() => (g.threads.some((x) => x.guest === h.guest) ? openChat(h.guest) : ui.toast(`Message sent to ${h.guest.split(" ")[0]}`))}>
                        Message guest
                      </button>
                      {h.kind.includes("pass") && (
                        <button className="text-action" onClick={() => (g.setHelp((l) => l.map((x) => (x.id === h.id ? { ...x, status: "Resolved" } : x))), ui.toast(`New pass sent to ${h.guest}`))}>
                          Reissue pass
                        </button>
                      )}
                    </div>
                  )}
                </article>
              ))}
          </div>
        </section>
      )}
      {kind === "Signs" && (
        <section className="srv-section">
          <p className="srv-muted">Approve each bottle-sign message before it's printed.</p>
          <div className="gc-cards">
            {g.signs.map((s) => (
              <article key={s.id} className="gc-card">
                <div className={`gc-sign ${s.style.startsWith("Neon") ? "neon" : s.style.startsWith("Sparkler") ? "sparkler" : "led"}`}>{s.style.startsWith("Neon") ? s.text : s.text.toUpperCase()}</div>
                <header>
                  <strong>{s.style}</strong>
                  <Tag tone={s.status === "Approved" ? "green" : s.status === "Waiting" ? "orange" : "amber"}>{s.status}</Tag>
                </header>
                <small>
                  {s.guest} · {s.booking} · with {s.bottle} · {s.timing.toLowerCase()}
                </small>
                {s.note && <small>Asked: “{s.note}”</small>}
                {s.status === "Waiting" && (
                  <div className="gc-actions">
                    <button className="primary-action" onClick={() => (g.setSigns((l) => l.map((x) => (x.id === s.id ? { ...x, status: "Approved" } : x))), ui.toast("Sign approved. It's on the server's order."))}>
                      Approve
                    </button>
                    <button className="secondary-action" onClick={() => ui.sheet({ eyebrow: s.guest.toUpperCase(), title: "Ask for a change", body: (close) => <ChangeSignBody close={close} onSend={(note) => (g.setSigns((l) => l.map((x) => (x.id === s.id ? { ...x, status: "Change requested", note } : x))), ui.toast(`${s.guest.split(" ")[0]} asked to update the sign`))} /> })}>
                      Ask for a change
                    </button>
                  </div>
                )}
              </article>
            ))}
          </div>
        </section>
      )}
      {kind === "Refunds" && (
        <section className="srv-section">
          <p className="srv-muted">Managers refund within the policy (full refund 48+ hours before). Anything outside it needs the owner's approval.</p>
          {g.refunds.length === 0 ? (
            <p className="srv-muted pad">No refund requests.</p>
          ) : (
            <div className="gc-cards">
              {g.refunds.map((r) => (
                <article key={r.id} className="gc-card">
                  <header>
                    <strong>
                      {"$" + r.amount.toLocaleString("en-CA", { minimumFractionDigits: 2 })} · {r.guest}
                    </strong>
                    <Tag tone={r.status === "Approved" ? "green" : r.status === "Declined" ? "red" : "amber"}>{r.status}</Tag>
                  </header>
                  <p>“{r.reason}”</p>
                  <small>Requested by {r.by} · outside the 48-hour policy</small>
                  {g.viewer === "owner" && r.status === "Waiting for owner" && (
                    <div className="gc-actions">
                      <button className="primary-action" onClick={() => (g.setRefunds((l) => l.map((x) => (x.id === r.id ? { ...x, status: "Approved" } : x))), ui.toast(`Refund sent to ${r.guest}`))}>
                        Approve refund
                      </button>
                      <button className="secondary-action" onClick={() => (g.setRefunds((l) => l.map((x) => (x.id === r.id ? { ...x, status: "Declined" } : x))), ui.toast("Refund declined. The manager has been told."))}>
                        Decline
                      </button>
                    </div>
                  )}
                </article>
              ))}
            </div>
          )}
        </section>
      )}
    </>
  )
}
