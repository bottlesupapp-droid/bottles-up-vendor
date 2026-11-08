import { Inbox, inboxUnread, useInbox, useStartThread } from "./Inbox"
import { useState, type ReactNode } from "react"
import { pct } from "./data"
import { usePersisted, Icon, Lines, Options, ThemeToggle, Thread, useUI, type Appearance, type IconName, type Theme } from "./kit"
import { Empty, InviteBody, MemberBody, SearchBox, Segmented, SettingsBody, SupportBody } from "./shared"
import { useStore } from "./store"
import { ContentManager, MessageOrganizerButton, ProfileEditor } from "./OrgProfile"
import { Analytics, Dashboard, EventBuilder, Opportunities, PromoList, SAMPLE_PROMOS, statusLabel, type Ev, type Promo } from "./OrgTools"

type Screen = "home" | "events" | "analytics" | "chat" | "more"
type Detail = { kind: "event"; id: string } | { kind: "edit"; id: string | null } | { kind: "agreement" } | { kind: "terms" } | { kind: "team" } | { kind: "chat"; id: string } | { kind: "settings" } | { kind: "profile" } | { kind: "content" } | { kind: "opps" } | { kind: "guests" }

const INITIAL_EVENTS: Ev[] = [
  { id: "ng", name: "Neon Garden", date: "Sat, 31 Aug", long: "Saturday, 31 August · 9:00 PM–2:00 AM", venue: "Nova Room", status: "Published", sold: 184, capacity: 300, gross: "$6.8k", art: 0, venueStatus: "Confirmed" },
  { id: "rf", name: "Rooftop Frequencies", date: "Fri, 6 Sep", long: "Friday, 6 September · 8:00 PM–1:00 AM", venue: "Sky Room", status: "Draft", sold: 0, capacity: 220, gross: "$0", art: 1, venueStatus: "Partnership requested" },
  { id: "as", name: "Afterdark Sessions", date: "Sat, 21 Sep", long: "Saturday, 21 September · 10:00 PM–3:00 AM", venue: "Venue needed", status: "Draft", sold: 0, capacity: 250, gross: "$0", art: 2 },
  { id: "wh", name: "Warehouse Sessions", date: "Sat, 28 Sep", long: "Sat, 28 Sep · 10:00 PM – Sun, 29 Sep · 4:00 AM", venue: "The Warehouse", status: "Published", sold: 46, capacity: 400, gross: "$0", art: 1, ticketOnly: true, venueStatus: "Not on BottlesUp" },
  { id: "ss", name: "Summer Signal", date: "Fri, 11 Oct", long: "Friday, 11 October · 9:00 PM–2:00 AM", venue: "Nova Room", status: "Published", sold: 12, capacity: 300, gross: "$420", art: 3, venueStatus: "Confirmed" },
  { id: "sp", name: "Spring Social", date: "Sat, 20 Jul", long: "Sat, 20 Jul · 9:00 PM – Sun, 21 Jul · 2:00 AM", venue: "Nova Room", status: "Completed", sold: 210, capacity: 220, gross: "$7.4k", art: 3, venueStatus: "Confirmed" },
]

const GUESTS: Record<string, { name: string; ticket: string; status: string }[]> = {
  ng: [
    { name: "Maya Chen", ticket: "VIP · 2 tickets", status: "Not arrived" },
    { name: "Jordan Blake", ticket: "General admission", status: "Not arrived" },
    { name: "Sofia Reyes", ticket: "VIP · 4 tickets", status: "Not arrived" },
    { name: "Sam Patel", ticket: "General admission", status: "Not arrived" },
  ],
  spring: [
    { name: "Maya Chen", ticket: "VIP · 2 tickets", status: "Checked in" },
    { name: "Jordan Blake", ticket: "General admission", status: "Checked in" },
    { name: "Sofia Reyes", ticket: "VIP · 4 tickets", status: "Checked in" },
    { name: "Sam Patel", ticket: "General admission", status: "No-show" },
  ],
  as: [],
}
const GUEST_EVENTS = [
  { id: "ng", label: "Neon Garden · 31 August", sold: 184, checked: 0, note: "Check-in opens on event night" },
  { id: "spring", label: "Spring Social · 20 Jul (past)", sold: 210, checked: 188, note: "Event finished" },
  { id: "as", label: "Afterdark Sessions · 21 September", sold: 0, checked: 0, note: "Not on sale yet" },
]

const CHATS = [
  { id: "al", name: "Nova Room", role: "Venue · Neon Garden", last: "We’ve reviewed the bar-sales terms.", time: "4m", unread: 2, initial: [{ mine: false, text: "We’ve reviewed the proposal. Could settlement move to five business days?", time: "8:39 PM", who: "Nova Room" }, { mine: true, text: "That works for us. I’ll update the terms now.", time: "8:41 PM" }, { mine: false, text: "We’ve reviewed the bar-sales terms.", time: "8:58 PM", who: "Nova Room" }] },
  { id: "team", name: "Neon Garden team", role: "Event team", last: "Jamie: I can cover the early shift.", time: "18m", unread: 0, initial: [{ mine: false, text: "I can cover the early shift.", time: "8:44 PM", who: "Jamie" }] },
  { id: "sky", name: "Sky Room", role: "Venue · Rooftop Frequencies", last: "Your venue request is being reviewed.", time: "1h", unread: 0, initial: [{ mine: false, text: "Your venue request is being reviewed.", time: "7:50 PM", who: "Sky Room" }] },
]

function Status({ children }: { children: string }) {
  return <em className={`status-badge ${children.toLowerCase().replaceAll(" ", "-")}`}>{statusLabel(children)}</em>
}

function Title({ eyebrow, children, action }: { eyebrow: string; children: ReactNode; action?: ReactNode }) {
  return (
    <div className="page-title">
      <div>
        <span>{eyebrow}</span>
        <h1>{children}</h1>
      </div>
      {action}
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

export default function OrganizerApp({ theme, onTheme, appearance, onAppearance, onSwitch }: { theme: Theme; onTheme: () => void; appearance: Appearance; onAppearance: (a: Appearance) => void; onSwitch: () => void }) {
  const ui = useUI()
  const store = useStore()
  const [screen, setScreen] = useState<Screen>("home")
  const [detail, setDetail] = useState<Detail | null>(null)
  const [stack, setStack] = useState<Detail[]>([])
  const [events, setEvents] = usePersisted<Ev[]>("bu-biz-org-events", INITIAL_EVENTS)
  const ib = useInbox()
  const orgUnread = inboxUnread(ib.threads.org)
  const [promos, setPromos] = useState<Record<string, Promo[]>>({ ng: SAMPLE_PROMOS })
  const profile = store.org
  const [unread, setUnread] = useState<Record<string, number>>({ al: 2 })
  const evs = events
  const published = evs.filter((e) => e.status === "Published")
  const drafts = evs.filter((e) => e.status === "Draft" || e.status === "Pending approval")
  const accepted = store.doorTeam.filter((m) => m.status === "Accepted").length

  const open = (d: Detail) => {
    if (detail) setStack((s) => [...s, detail])
    if (d.kind === "chat") setUnread((u) => ({ ...u, [d.id]: 0 }))
    setDetail(d)
    window.scrollTo({ top: 0 })
  }
  const back = () => {
    const prev = stack[stack.length - 1] ?? null
    setStack((s) => s.slice(0, -1))
    setDetail(prev)
  }
  const nav = (s: Screen) => {
    setStack([])
    setDetail(null)
    setScreen(s)
    window.scrollTo({ top: 0 })
  }

  const header = (
    <div className="topbar">
      <button className="workspace-switch" onClick={onSwitch} aria-label="Switch role">
        <span className="brand-mark">
          <img src="/bottlesup-logo.png" alt="" />
        </span>
        <span>
          <strong>BottlesUp</strong>
          <small>{profile.name} · Organizer</small>
        </span>
        <Icon name="arrow" size={15} />
      </button>
      <div className="top-actions">
        <ThemeToggle theme={theme} onToggle={onTheme} />
        <button
          className="avatar"
          aria-label="Account"
          onClick={() =>
            ui.sheet({
              eyebrow: "SIGNED IN AS",
              title: profile.name,
              body: (close) => (
                <Options
                  close={close}
                  items={[
                    { label: "Settings", detail: "Appearance, notifications, account", icon: "settings", onSelect: () => open({ kind: "settings" }) },
                    { label: "Switch role", detail: "Choose another demo role", icon: "arrow", onSelect: onSwitch },
                    { label: "Sign out", icon: "close", danger: true, onSelect: onSwitch },
                  ]}
                />
              ),
            })
          }
        >
          <Icon name="person" size={19} />
        </button>
      </div>
    </div>
  )

  const addButton = (
    <button className="round-add" aria-label="New event" onClick={() => open({ kind: "edit", id: null })}>
      <Icon name="plus" />
    </button>
  )

  let body: ReactNode = null

  if (detail?.kind === "event") {
    const e = evs.find((x) => x.id === detail.id)!
    const isNg = e.id === "ng"
    const agreementStatus = isNg ? store.agreement : e.status === "Approved" ? "Approved" : e.venue === "Venue needed" ? "No venue yet" : "Pending approval"
    body = (
      <>
        <DetailHeader
          eyebrow={statusLabel(e.status).toUpperCase()}
          title={e.name}
          onBack={back}
        />
        {e.status !== "Cancelled" && e.status !== "Completed" && (
          <button className="edit-event-btn wide" onClick={() => open({ kind: "edit", id: e.id })}>
            <Icon name="pencil" size={16} /> Edit Event
            <small>Details, media, tickets, promo codes, lineup</small>
          </button>
        )}
        <button
          className="text-action guest-preview-link"
          onClick={() =>
            ui.sheet({
              eyebrow: "GUEST VIEW · BOTTLESUP APP",
              title: e.name,
              body: () => (
                <div className="srv-sheet">
                  <div className={`event-detail-hero art-${e.art}`}>
                    <h2>{e.name}</h2>
                    <p>{e.long}</p>
                    <small>{e.venue}</small>
                  </div>
                  <p className="srv-muted">Tickets from $35{e.ticketOnly ? " · ticket-only" : " · tables available"}</p>
                  {e.ticketOnly && <p className="srv-notice">For table or bottle enquiries, contact the event organiser.</p>}
                  <div className="dual-actions">
                    <MessageOrganizerButton name={store.org.name} event={{ name: e.name, date: e.date, venue: e.venue }} />
                    <button className="primary-action" onClick={() => ui.toast("Guests buy tickets here in the BottlesUp app")}>
                      Book tickets
                    </button>
                  </div>
                </div>
              ),
            })
          }
        >
          <Icon name="eye" size={14} /> Preview guest page
        </button>
        <div className="pub-status">
          <div>
            <small>Event</small>
            <Status>{e.status}</Status>
          </div>
          {(e.venueStatus === "Confirmed" || e.venueStatus === "Partnership requested") && (
            <div>
              <small>Venue partnership</small>
              <span className={`srv-chip tone-${e.venueStatus === "Confirmed" ? "green" : "amber"}`}>{e.venueStatus}</span>
            </div>
          )}
        </div>
        <p className="srv-muted pub-explain">
          {e.status === "Published"
            ? "Live: guests can buy tickets now."
            : e.status === "Completed"
              ? "Completed: the event has happened. Payouts and recap are below."
              : e.status === "Cancelled"
                ? "Cancelled: ticket holders were refunded and notified."
                : "Draft: only your team can see it. Publish it when it's ready."}
          {e.venueStatus === "Partnership requested" ? ` ${e.venue} hasn't answered your partnership request yet. That only affects tables and bottles, not publishing.` : ""}
        </p>
        <div className={`event-detail-hero art-${e.art}`}>
          <Status>{e.status}</Status>
          <span>
            {e.name
              .split(" ")
              .map((x) => x[0])
              .join("")}
          </span>
          <h2>{e.name}</h2>
          <p>{e.long}</p>
          <small>{e.venue === "Venue needed" ? "Venue needed" : `${e.venue}${e.venue === "Nova Room" ? " · 1234 Main Street" : " · 88 Harbour Avenue"}`}</small>
        </div>
        <div className="summary-strip card">
          <div>
            <span>{e.sold}</span>
            <small>Tickets sold</small>
          </div>
          <div>
            <span>{e.capacity}</span>
            <small>Capacity</small>
          </div>
          <div>
            <span>{e.gross}</span>
            <small>Gross sales*</small>
          </div>
        </div>
        <p className="data-note">*Sample figures for concept purposes.</p>
        {e.ticketOnly ? (
          <section>
            <div className="section-heading">
              <div>
                <span>VENUE</span>
                <h2>{e.venue}</h2>
              </div>
            </div>
            <div className="srv-notice vm-warn">
              <Icon name="warning" size={15} />
              <span>
                <b>Ticket-only.</b> {e.venue} isn't a BottlesUp partner, so there are no tables, bottles or venue agreement here. Guests see:
                <em className="vm-quote">“For table or bottle enquiries, contact the event organiser.” → Message Midnight Social</em>
              </span>
            </div>
          </section>
        ) : (
        <section>
          <div className="section-heading">
            <div>
              <span>VENUE</span>
              <h2>Agreement</h2>
            </div>
          </div>
          <button className="agreement-card card" onClick={() => (isNg ? open({ kind: "agreement" }) : ui.toast(e.venue === "Venue needed" ? "Choose a venue in Edit event first" : `${e.venue}: ${agreementStatus}`))}>
            <span className={`row-icon ${agreementStatus === "Approved" ? "" : "warning"}`}>
              <Icon name="ticket" />
            </span>
            <span>
              <Status>{agreementStatus}</Status>
              <strong>{e.venue}</strong>
              <small>{isNg ? "Venue confirmed · bar-sales terms update in review" : agreementStatus}</small>
            </span>
            <Icon name="arrow" />
          </button>
        </section>
        )}
        <section>
          <div className="section-heading">
            <div>
              <span>DISCOUNTS</span>
              <h2>Promo codes</h2>
            </div>
          </div>
          <PromoList promos={promos[e.id] ?? []} setPromos={(p) => setPromos((all) => ({ ...all, [e.id]: p }))} tablesAllowed={!e.ticketOnly} />
        </section>
        <section>
          <div className="section-heading">
            <div>
              <span>EVENT TOOLS</span>
              <h2>Manage</h2>
            </div>
          </div>
          <div className="quick-grid">
            <button className="card" onClick={() => open({ kind: "team" })}>
              <Icon name="door" />
              <strong>Door staff</strong>
              <small>
                {store.doorTeam.length} invited · {accepted} confirmed
              </small>
            </button>
            <button className="card" onClick={() => open({ kind: "guests" })}>
              <Icon name="guests" />
              <strong>Guest list</strong>
              <small>{e.sold} guests</small>
            </button>
            <button className="card concept" onClick={() => ui.toast("Ticket tiers are a proposed feature and aren't available yet")}>
              <Icon name="ticket" />
              <strong>Ticket tiers</strong>
              <small>Concept feature</small>
            </button>
            <button
              className="card"
              onClick={() =>
                ui.sheet({
                  eyebrow: `${e.name.toUpperCase()} · SAMPLE DATA`,
                  title: "Analytics",
                  body: () => (
                    <Lines
                      rows={[
                        ["Tickets sold", `${e.sold} of ${e.capacity} (${pct(e.sold, e.capacity)}%)`],
                        ["Sold this week", e.sold ? "46" : "0"],
                        ["Top channel", e.sold ? "Ambassador links · 32%" : "—"],
                        ["Page views", e.sold ? "4,812" : "0"],
                      ]}
                    />
                  ),
                })
              }
            >
              <Icon name="chart" />
              <strong>Analytics</strong>
              <small>Sample data</small>
            </button>
          </div>
        </section>
        {(e.status === "Published" || e.status === "Approved" || e.status === "Pending approval") && (
          <button
            className="text-action danger cancel-event"
            onClick={() =>
              ui.sheet({
                eyebrow: e.name.toUpperCase(),
                title: "Cancel this event?",
                body: (close) => (
                  <div className="srv-sheet">
                    <p className="srv-muted">
                      {e.sold > 0 ? `${e.sold} ticket holders will be refunded in full and notified by email and in the app. ` : "No tickets have been sold. "}
                      {e.ticketOnly ? "" : `${e.venue} will be told the event is cancelled. `}This can't be undone.
                    </p>
                    <button
                      className="danger-action"
                      onClick={() => {
                        setEvents((l) => l.map((x) => (x.id === e.id ? { ...x, status: "Cancelled" } : x)))
                        ui.toast(e.sold ? `${e.name} cancelled. ${e.sold} refunds started.` : `${e.name} cancelled`)
                        close()
                      }}
                    >
                      Cancel event{e.sold > 0 ? ` and refund ${e.sold} guests` : ""}
                    </button>
                    <button className="secondary-action full-action" onClick={close}>
                      Keep event
                    </button>
                  </div>
                ),
              })
            }
          >
            Cancel event
          </button>
        )}
      </>
    )
  } else if (detail?.kind === "edit") {
    body = (
      <EventBuilder
        key={detail.id ?? "new"}
        event={detail.id ? evs.find((x) => x.id === detail.id)! : null}
        onBack={back}
        onSave={(ev) => setEvents((list) => (list.some((x) => x.id === ev.id) ? list.map((x) => (x.id === ev.id ? ev : x)) : [...list, ev]))}
        orgLogo={store.org.logoImg}
        orgName={store.org.name}
      />
    )
  } else if (detail?.kind === "opps") {
    body = <Opportunities onBack={back} />
  } else if (detail?.kind === "guests") {
    body = <GuestsScreen open={open} />
  } else if (detail?.kind === "agreement") {
    const withdrawn = store.agreement === "Withdrawn"
    const steps: [string, string, string][] = [
      ["Request sent", "20 Aug · 10:24 AM", "done"],
      ["Terms proposed", "21 Aug · 3:18 PM", "done"],
      ["Venue replied", "Today · 8:42 PM", store.agreement === "Pending approval" ? "current" : "done"],
      [store.agreement === "Changes requested" ? "Changes requested" : withdrawn ? "Request withdrawn" : "Agreement approved", store.agreement === "Approved" ? "Today" : store.agreement === "Pending approval" ? "Waiting for venue" : "Today", store.agreement === "Pending approval" ? "" : "done"],
    ]
    body = (
      <>
        <DetailHeader eyebrow="NEON GARDEN" title="Venue agreement" onBack={back} />
        <div className="agreement-status card">
          <span>
            <Status>{store.agreement}</Status>
            <h2>Nova Room</h2>
            <p>
              {store.agreement === "Approved"
                ? "The venue approved your terms. Neon Garden is on sale."
                : store.agreement === "Changes requested"
                  ? "The venue asked for changes. Propose updated terms."
                  : withdrawn
                    ? "You withdrew this request."
                    : "Your request is being discussed with the venue."}
            </p>
          </span>
          <Icon name="venue" size={32} />
        </div>
        <div className="timeline">
          {steps.map((r) => (
            <div className={r[2]} key={r[0]}>
              <i />
              <span>
                <strong>{r[0]}</strong>
                <small>{r[1]}</small>
              </span>
            </div>
          ))}
        </div>
        <section>
          <div className="section-heading">
            <div>
              <span>CURRENT TERMS</span>
              <h2>Proposal summary</h2>
            </div>
          </div>
          <Lines
            rows={[
              ["Tables", "Organizer receives payments"],
              ["Bar sales", "15% above $8,000"],
              ["Minimum spend", "$5,000"],
              ["Settlement", "Within 5 business days"],
              ["Cancellation", "14 days’ notice"],
            ]}
          />
        </section>
        {!withdrawn && store.agreement !== "Approved" && (
          <>
            <div className="dual-actions">
              <button className="secondary-action" onClick={() => open({ kind: "chat", id: "al" })}>
                Discuss terms
              </button>
              <button className="primary-action" onClick={() => open({ kind: "terms" })}>
                Propose changes
              </button>
            </div>
            <WithdrawButton
              onConfirm={() => {
                store.setAgreement("Withdrawn")
                ui.toast("Venue request withdrawn")
              }}
            />
          </>
        )}
      </>
    )
  } else if (detail?.kind === "terms") {
    body = (
      <Terms
        onBack={back}
        onSubmit={() => {
          store.setAgreement("Pending approval")
        }}
      />
    )
  } else if (detail?.kind === "team") {
    body = (
      <>
        <DetailHeader
          eyebrow="NEON GARDEN"
          title="Door staff"
          onBack={back}
          action={
            <button
              className="round-add"
              aria-label="Invite door staff"
              onClick={() =>
                ui.sheet({
                  eyebrow: "NEON GARDEN",
                  title: "Invite door staff",
                  body: (close) => (
                    <InviteBody
                      close={close}
                      roles={["Door staff", "Door lead"]}
                      onInvite={(email, role) => {
                        store.setDoorTeam((t) => [...t, { name: email, role, status: "Pending" }])
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
        <div className="permission-note card">
          <Icon name="door" />
          <span>
            <strong>Event access only</strong>
            <small>Door staff can scan tickets and admit guests. They cannot change prices, issue refunds, or access banking.</small>
          </span>
        </div>
        <section>
          <div className="section-heading">
            <div>
              <span>EVENT TEAM</span>
              <h2>
                {store.doorTeam.length} invited · {accepted} confirmed
              </h2>
            </div>
          </div>
          <div className="team-list">
            {store.doorTeam.map((m) => (
              <button
                className="team-row card"
                key={m.name}
                onClick={() =>
                  ui.sheet({
                    eyebrow: m.role.toUpperCase(),
                    title: m.name,
                    body: (close) => <MemberBody name={m.name} role={m.role} status={m.status} close={close} onRemove={() => store.setDoorTeam((t) => t.filter((x) => x.name !== m.name))} />,
                  })
                }
              >
                <span className="member-avatar">{m.name.slice(0, 2).toUpperCase()}</span>
                <span>
                  <strong>{m.name}</strong>
                  <small>{m.role}</small>
                </span>
                <Status>{m.status}</Status>
                <Icon name="arrow" size={15} />
              </button>
            ))}
          </div>
        </section>
      </>
    )
  } else if (detail?.kind === "chat") {
    const c = CHATS.find((x) => x.id === detail.id)!
    body = (
      <>
        <DetailHeader eyebrow={c.role.toUpperCase()} title={c.name} onBack={back} />
        <Thread initial={c.initial} placeholder={`Message ${c.name}…`} reply={c.id === "team" ? "Sounds good." : "Thanks, we'll review and reply shortly."} replyFrom={c.id === "team" ? "Jamie" : c.name} />
      </>
    )
  } else if (detail?.kind === "content") {
    body = <ContentManager onBack={back} published={published.length} />
  } else if (detail?.kind === "profile") {
    body = <ProfileEditor onBack={back} published={published.length} />
  } else if (detail?.kind === "settings") {
    body = (
      <>
        <DetailHeader eyebrow="ACCOUNT" title="Settings" onBack={back} />
        <SettingsBody appearance={appearance} onAppearance={onAppearance} onSignOut={onSwitch} />
      </>
    )
  } else if (screen === "home") {
    const attention: { icon: IconName; title: string; desc: string; run: () => void }[] = []
    if (store.agreement === "Pending approval" || store.agreement === "Changes requested")
      attention.push({ icon: "ticket", title: store.agreement === "Changes requested" ? "Nova Room asked for changes" : "Partnership terms update", desc: "Neon Garden · Nova Room replied", run: () => open({ kind: "agreement" }) })
    if (accepted < store.doorTeam.length) attention.push({ icon: "door", title: "Door team not confirmed", desc: `${accepted} of ${store.doorTeam.length} door staff accepted`, run: () => open({ kind: "team" }) })
    const noVenue = evs.filter((e) => e.venue === "Venue needed")
    if (noVenue.length) attention.push({ icon: "venue", title: `${noVenue[0].name} needs a venue`, desc: "Draft · can't be submitted yet", run: () => open({ kind: "edit", id: noVenue[0].id }) })
    attention.push({ icon: "sparkle", title: "2 new applications", desc: "Photographer · Neon Garden", run: () => open({ kind: "opps" }) })
    body = (
      <Dashboard
        brand={profile.name}
        evs={evs}
        attention={attention}
        onEvent={(id) => open({ kind: "event", id })}
        onNew={() => open({ kind: "edit", id: null })}
        go={(w) => (w === "events" ? nav("events") : w === "analytics" ? nav("analytics") : w === "opps" ? open({ kind: "opps" }) : open({ kind: "team" }))}
      />
    )
  } else if (screen === "events") {
    body = <EventsList evs={evs} open={open} addButton={addButton} brand={profile.name} />
  } else if (screen === "analytics") {
    body = <Analytics evs={evs} />
  } else if (screen === "chat") {
    body = (
      <>
        <Title eyebrow="VENUES AND TEAM">Messages</Title>
        <div className="message-list">
          {CHATS.map((r) => (
            <button className="message-row card" key={r.id} onClick={() => open({ kind: "chat", id: r.id })}>
              <span className="message-avatar">{r.name.slice(0, 2).toUpperCase()}</span>
              <span>
                <strong>
                  {r.name} <small>{r.role}</small>
                </strong>
                <em>{r.last}</em>
              </span>
              <span>
                <small>{r.time}</small>
                {(unread[r.id] ?? 0) > 0 && <b>{unread[r.id]}</b>}
              </span>
            </button>
          ))}
        </div>
      </>
    )
  } else {
    const items: [IconName, string, string, (() => void) | null, string?][] = [
      ["ticket", "Venue agreements", "Requests, terms, approvals, and history", () => open({ kind: "agreement" }), store.agreement === "Pending approval" ? "1" : undefined],
      ["guests", "Team and door staff", "Event-specific invitations and access", () => open({ kind: "team" })],
      ["scan", "Guests and check-in", "Guest lists and arrivals", () => open({ kind: "guests" })],
      ["sparkle", "Opportunities", "Open roles and private applications", () => open({ kind: "opps" })],
      ["settings", "Settings", "Appearance, notifications, and account", () => open({ kind: "settings" })],
      ["chat", "Help and support", "Articles, chat, and request a call", () => ui.sheet({ eyebrow: "HELP", title: "Help and support", body: () => <SupportBody /> })],
      ["person", "Organizer profile", "What guests see: bio, links, past events", () => open({ kind: "profile" })],
      ["share", "Posts & highlights", `${store.posts.length} posts · ${store.highlights.length} highlights`, () => open({ kind: "content" })],
      ["chart", "Settlement", "Payouts and post-event statements", null, "Soon"],
    ]
    body = (
      <>
        <Title eyebrow={profile.name.toUpperCase()}>More</Title>
        <div className="profile-card card">
          <div className="profile-avatar">{profile.name.split(" ").map((x) => x[0]).join("").slice(0, 2)}</div>
          <div>
            <strong>{profile.name}</strong>
            <small>
              Organizer · {published.length} published event{published.length === 1 ? "" : "s"}
            </small>
          </div>
          <button onClick={() => open({ kind: "profile" })}>Edit</button>
        </div>
        <section>
          <div className="section-heading">
            <div>
              <span>ORGANIZER TOOLS</span>
            </div>
          </div>
          <div className="more-list card">
            {items.map(([icon, title, desc, fn, badge]) => (
              <button className="list-row" key={title} onClick={fn ?? (() => ui.toast(`${title} isn't available yet`))}>
                <span className="row-icon">
                  <Icon name={icon} />
                </span>
                <span>
                  <strong>{title}</strong>
                  <small>{desc}</small>
                </span>
                {badge && <b>{badge}</b>}
                <Icon name="arrow" size={16} />
              </button>
            ))}
          </div>
        </section>
        <p className="concept-note">Features marked “Soon” are proposed additions and are not yet available.</p>
      </>
    )
  }

  const navItems: { id: Screen; label: string; icon: IconName }[] = [
    { id: "home", label: "Home", icon: "home" },
    { id: "events", label: "Events", icon: "events" },
    { id: "analytics", label: "Analytics", icon: "chart" },
    { id: "chat", label: "Messages", icon: "chat" },
    { id: "more", label: "More", icon: "more" },
  ]
  return (
    <div className={`app-shell theme-${theme}`}>
      {header}
      <main className="page-content">{body}</main>
      {ib.pending?.acc === "org" && <Inbox acc="org" start={ib.pending.start} openId={ib.pending.id} onClose={() => ib.openFor(null)} contacts={["Amara Vale", "Nova Room", "Sky Room", "Jamie Fox", "Morgan Lee"]} events={evs.filter((e) => e.status !== "Completed" && e.status !== "Cancelled").map((e) => e.name)} />}
      <nav className="bottom-nav">
        {navItems.map((item) => (
          <button key={item.id} className={screen === item.id && !detail ? "active" : ""} aria-current={screen === item.id ? "page" : undefined} onClick={() => (item.id === "chat" ? ib.openFor({ acc: "org", start: "Inquiries", id: null }) : nav(item.id))}>
            <span className="nav-icon">
              <Icon name={item.icon} size={21} />
              {item.id === "chat" && orgUnread > 0 && <i className="nav-badge">{orgUnread}</i>}
            </span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  )
}

function WithdrawButton({ onConfirm }: { onConfirm: () => void }) {
  const [confirm, setConfirm] = useState(false)
  return confirm ? (
    <div className="confirm-box card">
      <strong>Withdraw your request to Nova Room?</strong>
      <small>Neon Garden will need a new venue before it can stay on sale.</small>
      <div className="dual-actions">
        <button className="secondary-action" onClick={() => setConfirm(false)}>
          Keep request
        </button>
        <button className="danger-button" onClick={onConfirm}>
          Withdraw
        </button>
      </div>
    </div>
  ) : (
    <button className="danger-button" onClick={() => setConfirm(true)}>
      Withdraw venue request
    </button>
  )
}

function EventsList({ evs, open, addButton, brand }: { evs: Ev[]; open: (d: Detail) => void; addButton: ReactNode; brand: string }) {
  const [filter, setFilter] = useState("All")
  const rows = evs.filter((r) => filter === "All" || (filter === "Drafts" ? r.status === "Draft" || r.status === "Pending approval" : r.status === "Published" || r.status === "Approved"))
  return (
    <>
      <Title eyebrow={brand.toUpperCase()} action={addButton}>
        Events
      </Title>
      <Segmented items={["All", "Drafts", "Live"]} active={filter} onChange={setFilter} />
      <div className="event-list">
        {rows.map((r) => (
          <button className="event-card card" key={r.id} onClick={() => open({ kind: "event", id: r.id })}>
            <span className={`event-art art-${r.art}`}>
              {r.name
                .split(" ")
                .map((x) => x[0])
                .join("")
                .slice(0, 2)}
            </span>
            <span>
              <Status>{r.status}</Status>
              <strong>{r.name}</strong>
              <small>
                {r.date} · {r.venue}
              </small>
              <em>{r.status === "Published" ? `Live · ${r.sold} sold` : r.status === "Completed" ? `${r.sold} attended` : r.status === "Cancelled" ? "Ticket holders refunded" : r.venueStatus === "Partnership requested" ? "Draft · partnership requested" : "Draft · not visible to guests"}</em>
            </span>
            <Icon name="arrow" size={16} />
          </button>
        ))}
      </div>
    </>
  )
}

function GuestsScreen({ open }: { open: (d: Detail) => void }) {
  const ui = useUI()
  const [eventId, setEventId] = useState("ng")
  const [search, setSearch] = useState("")
  const ev = GUEST_EVENTS.find((e) => e.id === eventId)!
  const guests = (GUESTS[eventId] ?? []).filter((g) => g.name.toLowerCase().includes(search.trim().toLowerCase()))
  return (
    <>
      <Title
        eyebrow="GUEST LIST"
        action={
          <button className="date-button" onClick={() => open({ kind: "team" })}>
            <Icon name="door" size={16} /> Door team
          </button>
        }
      >
        Guests
      </Title>
      <label className="field event-selector">
        <span>EVENT</span>
        <select value={eventId} onChange={(e) => setEventId(e.target.value)}>
          {GUEST_EVENTS.map((e) => (
            <option key={e.id} value={e.id}>
              {e.label}
            </option>
          ))}
        </select>
      </label>
      <div className="guest-totals card">
        <div>
          <strong>{ev.sold}</strong>
          <small>Tickets sold</small>
        </div>
        <div>
          <strong>{ev.checked}</strong>
          <small>Checked in</small>
        </div>
        <div>
          <strong>{ev.sold ? `${pct(ev.checked, ev.sold)}%` : "—"}</strong>
          <small>Arrival rate</small>
        </div>
      </div>
      <p className="list-count">{ev.note}</p>
      {(GUESTS[eventId] ?? []).length === 0 ? (
        <Empty icon="guests" title="No guests yet" text="Guest details appear once tickets are sold." />
      ) : (
        <>
          <SearchBox value={search} onChange={setSearch} placeholder="Search name or ticket code" />
          {guests.length === 0 ? (
            <Empty icon="search" title="No matching guests" text="Check the spelling or try a ticket code." />
          ) : (
            <div className="guest-list card">
              {guests.map((g) => (
                <button
                  className="list-row"
                  key={g.name}
                  onClick={() =>
                    ui.sheet({
                      eyebrow: ev.label.toUpperCase(),
                      title: g.name,
                      body: (close) => (
                        <>
                          <Lines
                            rows={[
                              ["Tickets", g.ticket],
                              ["Status", g.status],
                              ["Ticket code", `NG-${g.name.slice(0, 2).toUpperCase()}${g.name.length * 37}`],
                            ]}
                          />
                          <button
                            className="secondary-action full-action"
                            onClick={() => {
                              ui.toast(`Tickets resent to ${g.name}`)
                              close()
                            }}
                          >
                            Resend tickets
                          </button>
                        </>
                      ),
                    })
                  }
                >
                  <span className="member-avatar">{g.name.slice(0, 2).toUpperCase()}</span>
                  <span>
                    <strong>{g.name}</strong>
                    <small>{g.ticket}</small>
                  </span>
                  <Status>{g.status}</Status>
                  <Icon name="arrow" size={15} />
                </button>
              ))}
            </div>
          )}
        </>
      )}
    </>
  )
}

function Terms({ onBack, onSubmit }: { onBack: () => void; onSubmit: () => void }) {
  const [step, setStep] = useState(1)
  const [sent, setSent] = useState(false)
  const [share, setShare] = useState("15%")
  const [threshold, setThreshold] = useState("$8,000")
  const [mode, setMode] = useState(0)
  if (sent)
    return (
      <>
        <DetailHeader eyebrow="NEON GARDEN" title="Terms submitted" onBack={onBack} />
        <div className="success-state">
          <span>
            <Icon name="check" size={32} />
          </span>
          <h2>Proposal sent</h2>
          <p>Nova Room can now review your updated terms.</p>
          <button className="primary-action" onClick={onBack}>
            Back to agreement
          </button>
        </div>
      </>
    )
  return (
    <>
      <DetailHeader eyebrow={`STEP ${step} OF 3`} title="Propose terms" onBack={step > 1 ? () => setStep(step - 1) : onBack} />
      <div className="step-progress">
        <i className="active" />
        <i className={step > 1 ? "active" : ""} />
        <i className={step > 2 ? "active" : ""} />
      </div>
      {step === 1 && (
        <div className="form-stack">
          <Title eyebrow="REVENUE">Payment allocation</Title>
          <label className="field">
            <span>Table booking payments</span>
            <select>
              <option>Organizer receives payments</option>
              <option>Venue receives payments</option>
            </select>
          </label>
          <label className="field">
            <span>Organizer share of bar sales</span>
            <input value={share} onChange={(e) => setShare(e.target.value)} />
          </label>
          <label className="field">
            <span>Sales threshold</span>
            <input value={threshold} onChange={(e) => setThreshold(e.target.value)} />
          </label>
          <div className="choice-list card">
            {["Only sales above the threshold", "All sales once threshold is met"].map((x, i) => (
              <label className="choice" key={x}>
                <input type="radio" name="threshold" checked={mode === i} onChange={() => setMode(i)} />
                <span>
                  <strong>{x}</strong>
                  <small>{i === 0 ? `${share} applies only after the first ${threshold}.` : `${share} applies to all eligible bar sales.`}</small>
                </span>
              </label>
            ))}
          </div>
        </div>
      )}
      {step === 2 && (
        <div className="form-stack">
          <Title eyebrow="RESPONSIBILITIES">Running the event</Title>
          {[
            ["Admissions", "Organizer manages tickets and guest list"],
            ["Door staff", "Organizer supplies 2 door staff"],
            ["Security", "Venue supplies licensed security"],
            ["Refunds", "Organizer-approved before settlement"],
            ["Discounts & comps", "Excluded from revenue share"],
            ["Taxes, tips & fees", "Excluded from eligible sales"],
          ].map((r) => (
            <label className="field" key={r[0]}>
              <span>{r[0]}</span>
              <select>
                <option>{r[1]}</option>
                <option>Shared responsibility</option>
              </select>
            </label>
          ))}
        </div>
      )}
      {step === 3 && (
        <div>
          <Title eyebrow="REVIEW">Proposal summary</Title>
          <Lines
            rows={[
              ["Table payments", "Organizer"],
              ["Bar-sales share", `${share} ${mode === 0 ? "above" : "once over"} ${threshold}`],
              ["Minimum spend", "$5,000"],
              ["Admissions", "Organizer"],
              ["Security", "Venue"],
              ["Cancellation", "14 days"],
              ["Settlement", "5 business days"],
            ]}
          />
          <p className="approval-note">
            <Icon name="ticket" size={15} /> The venue must approve these terms before publication.
          </p>
        </div>
      )}
      <div className="dual-actions">
        {step > 1 && (
          <button className="secondary-action" onClick={() => setStep(step - 1)}>
            Back
          </button>
        )}
        <button
          className="primary-action"
          onClick={() => {
            if (step < 3) setStep(step + 1)
            else {
              onSubmit()
              setSent(true)
            }
          }}
        >
          {step < 3 ? "Continue" : "Submit proposal"}
        </button>
      </div>
    </>
  )
}
