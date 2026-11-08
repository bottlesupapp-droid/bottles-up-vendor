import { useInbox, useStartThread } from "./Inbox"
import { useState } from "react"
import { Icon, Lines, Options, QuickForm, useUI } from "./kit"
import { Segmented } from "./shared"
import { useStore, type OrgPost, type OrgProfile } from "./store"

const COVERS = 4
const initials = (name: string) =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .map((x) => x[0])
    .join("")
    .slice(0, 2)
    .toUpperCase() || "?"

const OPTIONAL: { key: keyof OrgProfile; label: string }[] = [
  { key: "tagline", label: "a tagline" },
  { key: "bio", label: "a bio" },
  { key: "genres", label: "your music" },
  { key: "instagram", label: "Instagram" },
  { key: "tiktok", label: "TikTok" },
  { key: "website", label: "a website" },
  { key: "email", label: "a contact email" },
]

function cleanHandle(v: string) {
  const t = v.trim().replace(/^https?:\/\/(www\.)?(instagram|tiktok)\.com\//i, "")
  return t && !t.startsWith("@") ? "@" + t : t
}

function errorsFor(p: OrgProfile) {
  const e: Partial<Record<keyof OrgProfile, string>> = {}
  if (!p.name.trim()) e.name = "Your organizer name is required."
  if (p.bio.length > 240) e.bio = `Keep it under 240 characters (${p.bio.length} now).`
  if (p.email && !/^\S+@\S+\.\S+$/.test(p.email)) e.email = "Enter a valid email address."
  if (p.website && !/^[\w.-]+\.[a-z]{2,}(\/\S*)?$/i.test(p.website.replace(/^https?:\/\//, ""))) e.website = "Enter a web address like yoursite.com."
  return e
}

/** How a guest sees the organizer in the BottlesUp app: a social-style profile. */
export function PublicProfile({ p, published }: { p: OrgProfile; published: number }) {
  const { posts, highlights } = useStore()
  const [tab, setTab] = useState<"grid" | "reels" | "events">("grid")
  const sorted = [...posts].sort((a, b) => Number(b.pinned) - Number(a.pinned))
  const grid = tab === "reels" ? sorted.filter((x) => x.kind === "Reel") : sorted
  return (
    <div className="org-public">
      <div className="ig-head">
        <span className={`ig-avatar cover-${p.cover}`}>{initials(p.name)}</span>
        <div className="ig-counts">
          <span>
            <b>{posts.length}</b>
            <small>Posts</small>
          </span>
          <span>
            <b>3.4K</b>
            <small>Followers</small>
          </span>
          <span>
            <b>182</b>
            <small>Following</small>
          </span>
        </div>
      </div>
      <div className="org-public-body">
        <strong className="org-name">
          {p.name || "Your organizer name"} <Icon name="check" size={14} />
        </strong>
        <small className="org-meta">
          Event organizer · {p.city || "City"}
          {p.genres ? ` · ${p.genres}` : ""}
        </small>
        {p.tagline && <em className="org-tagline">{p.tagline}</em>}
        {p.bio && <p className="org-bio">{p.bio}</p>}
        {p.website && <span className="org-site">{p.website}</span>}
        <div className="org-buttons">
          <span className="primary-action">Follow</span>
          {p.allowMessages && <MessageOrganizerButton name={p.name} />}
          <span className="secondary-action">Events</span>
        </div>
      </div>
      {highlights.length > 0 && (
        <div className="ig-highlights">
          {highlights.map((h) => (
            <span key={h.id}>
              <i className={`cover-${h.cover}`} />
              {h.name}
            </span>
          ))}
        </div>
      )}
      <div className="ig-tabs">
        {(
          [
            ["grid", "Posts"],
            ["reels", "Reels"],
            ["events", "Events"],
          ] as const
        ).map(([id, label]) => (
          <button key={id} className={tab === id ? "active" : ""} onClick={() => setTab(id)}>
            {label}
          </button>
        ))}
      </div>
      {tab !== "events" ? (
        grid.length === 0 ? (
          <p className="list-count">No {tab === "reels" ? "reels" : "posts"} yet.</p>
        ) : (
          <div className="ig-grid">
            {grid.map((x) => (
              <span key={x.id} className={`cover-${x.cover}`}>
                <em>{x.caption}</em>
                {x.pinned && tab === "grid" && <b className="ig-pin">Pinned</b>}
                {x.kind === "Reel" && <b className="ig-reel">▶</b>}
              </span>
            ))}
          </div>
        )
      ) : (
        <div className="org-public-body">
          <div className="org-section">
            <span>UPCOMING · {published}</span>
            <div className="org-event">
              <i className="event-art art-0">NG</i>
              <span>
                <b>Neon Garden</b>
                <small>Sat, 31 Aug · Nova Room</small>
              </span>
            </div>
          </div>
          {p.showPast && (
            <div className="org-section">
              <span>PAST EVENTS</span>
              <div className="org-event">
                <i className="event-art art-3">SS</i>
                <span>
                  <b>Spring Social</b>
                  <small>Sat, 20 Jul · 188 guests</small>
                </span>
              </div>
            </div>
          )}
          {p.showReviews && (
            <div className="org-section">
              <span>REVIEWS · 4.7 FROM 96</span>
              <p className="org-quote">“Great sound, quick door, and the visuals were unreal.” · Maya C.</p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

function Toggle({ label, detail, on, set }: { label: string; detail: string; on: boolean; set: (v: boolean) => void }) {
  return (
    <label className="setting-row card">
      <span>
        <strong>{label}</strong>
        <small>{detail}</small>
      </span>
      <input type="checkbox" checked={on} onChange={() => set(!on)} />
      <i />
    </label>
  )
}

export function ProfileEditor({ onBack, published }: { onBack: () => void; published: number }) {
  const ui = useUI()
  const store = useStore()
  const [draft, setDraft] = useState<OrgProfile>(store.org)
  const [tried, setTried] = useState(false)
  const [leaving, setLeaving] = useState(false)
  const errors = errorsFor(draft)
  const dirty = JSON.stringify(draft) !== JSON.stringify(store.org)
  const filled = OPTIONAL.filter((o) => String(draft[o.key]).trim()).length
  const missing = OPTIONAL.filter((o) => !String(draft[o.key]).trim())
  const set = <K extends keyof OrgProfile>(k: K, v: OrgProfile[K]) => setDraft((d) => ({ ...d, [k]: v }))
  const save = () => {
    setTried(true)
    if (Object.keys(errors).length) {
      ui.toast("Fix the highlighted fields to save")
      return
    }
    const clean = { ...draft, name: draft.name.trim(), instagram: cleanHandle(draft.instagram), tiktok: cleanHandle(draft.tiktok), website: draft.website.trim().replace(/^https?:\/\//, "") }
    store.setOrg(clean)
    setDraft(clean)
    ui.toast("Profile saved. Guests see the update now.")
  }
  const err = (k: keyof OrgProfile) => (tried || draft[k] !== store.org[k]) && errors[k] ? <em className="field-error">{errors[k]}</em> : null
  const field = (k: keyof OrgProfile, label: string, placeholder = "", type = "text") => (
    <label className="field">
      <span>{label}</span>
      <input type={type} value={String(draft[k])} placeholder={placeholder} onChange={(e) => set(k, e.target.value as never)} />
      {err(k)}
    </label>
  )
  return (
    <>
      <div className="detail-heading">
        <button className="back-button" aria-label="Go back" onClick={() => (dirty ? setLeaving(true) : onBack())}>
          <Icon name="back" />
        </button>
        <div>
          <span>{dirty ? "UNSAVED CHANGES" : "PUBLIC PAGE"}</span>
          <h1>Organizer profile</h1>
        </div>
        <button className="text-button" onClick={save} disabled={!dirty}>
          Save
        </button>
      </div>

      {leaving && (
        <div className="confirm-box card">
          <strong>Leave without saving?</strong>
          <small>Your changes to the profile will be lost.</small>
          <div className="dual-actions">
            <button className="secondary-action" onClick={() => setLeaving(false)}>
              Keep editing
            </button>
            <button className="danger-button" onClick={onBack}>
              Discard changes
            </button>
          </div>
        </div>
      )}

      <div className="profile-strength card">
        <div>
          <strong>Profile {Math.round((filled / OPTIONAL.length) * 100)}% complete</strong>
          <small>{missing.length ? `Add ${missing.slice(0, 2).map((m) => m.label).join(" and ")} so guests know what to expect.` : "Looking great. Guests have everything they need."}</small>
        </div>
        <div className="progress">
          <i className={missing.length ? "" : "complete"} style={{ width: `${(filled / OPTIONAL.length) * 100}%` }} />
        </div>
      </div>

      <section>
        <div className="section-heading">
          <div>
            <span>LIVE PREVIEW</span>
            <h2>What guests see</h2>
          </div>
          <button onClick={() => ui.sheet({ eyebrow: "GUEST VIEW · BOTTLESUP APP", title: draft.name || "Organizer", body: () => <PublicProfile p={draft} published={published} /> })}>Full preview</button>
        </div>
        <div className="org-mini card">
          <div className={`org-cover small cover-${draft.cover}`}>
            <span className="org-avatar">{initials(draft.name)}</span>
          </div>
          <div>
            <strong>{draft.name || "Your organizer name"}</strong>
            <small>{draft.tagline || "Add a tagline"}</small>
            <small>
              {draft.city || "City"}
              {draft.genres ? ` · ${draft.genres}` : ""}
            </small>
          </div>
        </div>
        <button className="secondary-action full-action" onClick={() => set("cover", (draft.cover + 1) % COVERS)}>
          Change cover colour
        </button>
      </section>

      <section className="form-stack">
        <div className="section-heading">
          <div>
            <span>PUBLIC DETAILS</span>
            <h2>About you</h2>
          </div>
        </div>
        {field("name", "Organizer name", "e.g. Midnight Social")}
        {field("tagline", "Tagline", "A short line under your name")}
        <label className="field">
          <span>Bio · {draft.bio.length}/240</span>
          <textarea value={draft.bio} onChange={(e) => set("bio", e.target.value)} placeholder="What kind of nights do you throw?" />
          {err("bio")}
        </label>
        <div className="form-row">
          {field("city", "City", "Toronto")}
          {field("genres", "Music", "House, Disco")}
        </div>
      </section>

      <section className="form-stack">
        <div className="section-heading">
          <div>
            <span>LINKS</span>
            <h2>Where guests can find you</h2>
          </div>
        </div>
        {field("instagram", "Instagram", "@yourhandle")}
        {field("tiktok", "TikTok", "@yourhandle")}
        {field("website", "Website", "yoursite.com")}
        {field("email", "Contact email (shown to venues only)", "you@example.com", "email")}
      </section>

      <section>
        <div className="section-heading">
          <div>
            <span>VISIBILITY</span>
            <h2>What to show</h2>
          </div>
        </div>
        <div className="settings-group">
          <Toggle label="Past events" detail="Show recaps and attendance from past nights" on={draft.showPast} set={(v) => set("showPast", v)} />
          <Toggle label="Reviews" detail="Show your rating and guest reviews" on={draft.showReviews} set={(v) => set("showReviews", v)} />
          <Toggle label="Messages from guests" detail="Let guests message you from your profile" on={draft.allowMessages} set={(v) => set("allowMessages", v)} />
        </div>
      </section>

      <div className="dual-actions">
        <button className="secondary-action" disabled={!dirty} onClick={() => setDraft(store.org)}>
          Discard
        </button>
        <button className="primary-action" disabled={!dirty} onClick={save}>
          Save profile
        </button>
      </div>
      <p className="approval-note">
        <Icon name="check" size={15} /> Verified organizers show a check next to their name. Changes appear to guests right away.
      </p>
    </>
  )
}

const fmt = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}K` : String(n))
const MAX_PINS = 3

function PostSheet({ id, close }: { id: string; close: () => void }) {
  const ui = useUI()
  const { posts, setPosts } = useStore()
  const [confirm, setConfirm] = useState(false)
  const [editing, setEditing] = useState(false)
  const post = posts.find((x) => x.id === id)
  if (!post) return null
  const pins = posts.filter((x) => x.pinned).length
  if (editing)
    return (
      <QuickForm
        submit="Save caption"
        fields={[{ id: "caption", label: "Caption", value: post.caption, required: true }]}
        onSubmit={(v) => {
          setPosts((list) => list.map((x) => (x.id === id ? { ...x, caption: v.caption.trim() } : x)))
          ui.toast("Caption updated")
          close()
        }}
      />
    )
  return (
    <>
      <div className={`post-preview cover-${post.cover}`}>
        <em>{post.caption}</em>
        {post.kind === "Reel" && <b className="ig-reel">▶</b>}
      </div>
      <Lines
        rows={[
          ["Likes", post.likes.toLocaleString("en-US")],
          ["Comments", String(post.comments)],
          ["Accounts reached", post.reach.toLocaleString("en-US")],
          ["Tagged event", post.event || "None"],
          ["Type", post.kind],
        ]}
      />
      <div className="ve-post-settings">
        <label className="field">
          <span>Who can see this</span>
          <select
            value={post.audience ?? "Public"}
            onChange={(e) => {
              const audience = e.target.value as "Public" | "Followers" | "Members Only"
              setPosts((list) => list.map((x) => (x.id === id ? { ...x, audience, allowRepost: audience === "Public" ? x.allowRepost : false } : x)))
              ui.toast(audience === "Public" ? "Anyone can see this post" : `Only ${audience.toLowerCase()} can see this post`)
            }}
          >
            <option>Public</option>
            <option>Followers</option>
            <option>Members Only</option>
          </select>
        </label>
        <div className="ve-row">
          <span>
            <strong>Allow reposts</strong>
            <small>{(post.audience ?? "Public") !== "Public" ? "Only public posts can be reposted" : "Guests can share it to their profile, credited to you"}</small>
          </span>
          <label className="dj-avail">
            <input
              type="checkbox"
              role="switch"
              aria-label="Allow reposts"
              disabled={(post.audience ?? "Public") !== "Public"}
              checked={(post.audience ?? "Public") === "Public" && post.allowRepost !== false}
              onChange={(e) => (setPosts((list) => list.map((x) => (x.id === id ? { ...x, allowRepost: e.target.checked } : x))), ui.toast(e.target.checked ? "Reposts on" : "Reposts off"))}
            />
            <i />
          </label>
        </div>
        <button className="secondary-action full-action" onClick={() => ui.sheet({ eyebrow: "COMMENTS", title: `${post.comments} comments`, body: () => <CommentsMod caption={post.caption} /> })}>
          Read and reply to comments
        </button>
      </div>
      <div className="dual-actions">
        <button
          className="secondary-action"
          disabled={!post.pinned && pins >= MAX_PINS}
          onClick={() => {
            setPosts((list) => list.map((x) => (x.id === id ? { ...x, pinned: !x.pinned } : x)))
            ui.toast(post.pinned ? "Unpinned" : "Pinned to the top of your profile")
            close()
          }}
        >
          {post.pinned ? "Unpin" : pins >= MAX_PINS ? "3 pins max" : "Pin to top"}
        </button>
        <button className="secondary-action" onClick={() => setEditing(true)}>
          Edit caption
        </button>
      </div>
      {confirm ? (
        <div className="confirm-box card">
          <strong>Delete this post?</strong>
          <small>It disappears from your profile and guests' feeds. You can't undo this.</small>
          <div className="dual-actions">
            <button className="secondary-action" onClick={() => setConfirm(false)}>
              Keep post
            </button>
            <button
              className="danger-button"
              onClick={() => {
                setPosts((list) => list.filter((x) => x.id !== id))
                ui.toast("Post deleted")
                close()
              }}
            >
              Delete
            </button>
          </div>
        </div>
      ) : (
        <button className="danger-button" onClick={() => setConfirm(true)}>
          Delete post
        </button>
      )}
    </>
  )
}

function NewPostForm({ close }: { close: () => void }) {
  const ui = useUI()
  const { setPosts, posts } = useStore()
  const [cover, setCover] = useState(0)
  return (
    <>
      <div className={`post-preview cover-${cover}`}>
        <em>Your cover</em>
      </div>
      <button className="secondary-action full-action" type="button" onClick={() => setCover((cover + 1) % COVERS)}>
        Change cover
      </button>
      <QuickForm
        submit="Publish post"
        fields={[
          { id: "caption", label: "Caption", placeholder: "What's happening?", required: true },
          { id: "kind", label: "Type", options: ["Photo", "Reel"] },
          { id: "event", label: "Tag an event", options: ["None", "Neon Garden", "Summer Signal"] },
          { id: "pin", label: "Pin to top of profile", options: posts.filter((x) => x.pinned).length >= MAX_PINS ? ["No (3 pins already)"] : ["No", "Yes"] },
        ]}
        onSubmit={(v) => {
          const post: OrgPost = { id: "p" + Date.now(), caption: v.caption.trim(), cover, kind: v.kind as OrgPost["kind"], likes: 0, comments: 0, reach: 0, pinned: v.pin === "Yes", event: v.event === "None" ? "" : v.event }
          setPosts((list) => [post, ...list])
          ui.toast("Posted. Your followers can see it now.")
          close()
        }}
      />
    </>
  )
}

function HighlightSheet({ id, close }: { id: string | null; close: () => void }) {
  const ui = useUI()
  const { highlights, setHighlights } = useStore()
  const h = id ? highlights.find((x) => x.id === id) : null
  const [cover, setCover] = useState(h?.cover ?? 1)
  return (
    <>
      <div className="hl-preview">
        <i className={`cover-${cover}`} />
        <button className="text-button" type="button" onClick={() => setCover((cover + 1) % COVERS)}>
          Change cover
        </button>
      </div>
      <QuickForm
        submit={h ? "Save highlight" : "Create highlight"}
        fields={[{ id: "name", label: "Name", value: h?.name ?? "", placeholder: "e.g. Afterparties", required: true }]}
        onSubmit={(v) => {
          const name = v.name.trim().slice(0, 18)
          if (h) setHighlights((list) => list.map((x) => (x.id === h.id ? { ...x, name, cover } : x)))
          else setHighlights((list) => [...list, { id: "h" + Date.now(), name, cover, items: 0 }])
          ui.toast(h ? "Highlight updated" : `${name} added to your highlights`)
          close()
        }}
      />
      {h && (
        <button
          className="danger-button"
          onClick={() => {
            setHighlights((list) => list.filter((x) => x.id !== h.id))
            ui.toast(`${h.name} removed`)
            close()
          }}
        >
          Remove highlight
        </button>
      )}
    </>
  )
}

export function ContentManager({ onBack, published }: { onBack: () => void; published: number }) {
  const ui = useUI()
  const store = useStore()
  const [filter, setFilter] = useState("All")
  const sorted = [...store.posts].sort((a, b) => Number(b.pinned) - Number(a.pinned))
  const shown = filter === "All" ? sorted : sorted.filter((x) => (filter === "Reels" ? x.kind === "Reel" : x.pinned))
  const likes = store.posts.reduce((s, x) => s + x.likes, 0)
  const reach = store.posts.reduce((s, x) => s + x.reach, 0)
  return (
    <>
      <div className="detail-heading">
        <button className="back-button" aria-label="Go back" onClick={onBack}>
          <Icon name="back" />
        </button>
        <div>
          <span>{store.org.name.toUpperCase()}</span>
          <h1>Posts & highlights</h1>
        </div>
        <button className="round-add" aria-label="New post" onClick={() => ui.sheet({ eyebrow: "NEW POST", title: "Share with your followers", body: (close) => <NewPostForm close={close} /> })}>
          <Icon name="plus" />
        </button>
      </div>
      <div className="summary-strip card">
        <div>
          <span>{store.posts.length}</span>
          <small>Posts</small>
        </div>
        <div>
          <span>{fmt(likes)}</span>
          <small>Total likes</small>
        </div>
        <div>
          <span>{fmt(reach)}</span>
          <small>Accounts reached</small>
        </div>
      </div>

      <section>
        <div className="section-heading">
          <div>
            <span>STORY HIGHLIGHTS</span>
            <h2>Highlights</h2>
          </div>
        </div>
        <div className="ig-highlights manage">
          {store.highlights.map((h) => (
            <button key={h.id} onClick={() => ui.sheet({ eyebrow: `${h.items} STORIES`, title: h.name, body: (close) => <HighlightSheet id={h.id} close={close} /> })}>
              <i className={`cover-${h.cover}`} />
              {h.name}
            </button>
          ))}
          <button className="hl-new" onClick={() => ui.sheet({ eyebrow: "HIGHLIGHT", title: "New highlight", body: (close) => <HighlightSheet id={null} close={close} /> })}>
            <i>
              <Icon name="plus" size={22} />
            </i>
            New
          </button>
        </div>
      </section>

      <section>
        <div className="section-heading">
          <div>
            <span>FEED</span>
            <h2>Your posts</h2>
          </div>
          <button onClick={() => ui.sheet({ eyebrow: "GUEST VIEW · BOTTLESUP APP", title: store.org.name, body: () => <PublicProfile p={store.org} published={published} /> })}>Preview profile</button>
        </div>
        <Segmented items={["All", "Reels", "Pinned"]} active={filter} onChange={setFilter} />
        {shown.length === 0 ? (
          <p className="list-count">Nothing here yet. Tap + to create a post.</p>
        ) : (
          <div className="ig-grid manage">
            {shown.map((x) => (
              <button key={x.id} className={`cover-${x.cover}`} onClick={() => ui.sheet({ eyebrow: x.pinned ? "PINNED POST" : "POST", title: "Post insights", body: (close) => <PostSheet id={x.id} close={close} /> })}>
                <em>{x.caption}</em>
                {x.pinned && <b className="ig-pin">Pinned</b>}
                {x.kind === "Reel" && <b className="ig-reel">▶</b>}
                <small className="ig-stat">♥ {fmt(x.likes)}</small>
              </button>
            ))}
          </div>
        )}
        <p className="list-count">Pin up to {MAX_PINS} posts to keep them at the top of your profile.</p>
      </section>
      <button
        className="secondary-action full-action"
        onClick={() =>
          ui.sheet({
            eyebrow: "TIPS",
            title: "Grow your following",
            body: (close) => (
              <Options
                close={close}
                items={[
                  { label: "Post a lineup reveal", detail: "Lineup posts get 2× more saves", icon: "events", onSelect: () => ui.sheet({ eyebrow: "NEW POST", title: "Share with your followers", body: (c) => <NewPostForm close={c} /> }) },
                  { label: "Add a Recaps highlight", detail: "Guests check recaps before buying", icon: "star", onSelect: () => ui.sheet({ eyebrow: "HIGHLIGHT", title: "New highlight", body: (c) => <HighlightSheet id={null} close={c} /> }) },
                  { label: "Finish your profile", detail: "Complete profiles get more follows", icon: "person", onSelect: () => ui.toast("Open More, then Organizer profile") },
                ]}
              />
            ),
          })
        }
      >
        Tips to grow your following
      </button>
    </>
  )
}

const DEMO_COMMENTS = [
  { who: "maya.chen", text: "Saturday can't come soon enough" },
  { who: "jordanafterdark", text: "Booked the Halo Booth for my 30th 🎉" },
  { who: "noahreid", text: "Is there a dress code?" },
  { who: "spam_deals99", text: "Cheap followers, DM me" },
]

function CommentsMod({ caption }: { caption: string }) {
  const ui = useUI()
  const [list, setList] = useState(DEMO_COMMENTS.map((c, i) => ({ ...c, id: i, state: "shown" as "shown" | "hidden", reply: "" })))
  const [draft, setDraft] = useState<Record<number, string>>({})
  return (
    <div className="cm">
      <p className="srv-muted">On “{caption.slice(0, 60)}{caption.length > 60 ? "…" : ""}”. Hidden comments are only visible to the person who wrote them.</p>
      {list.map((c) => (
        <div key={c.id} className={`cm-row ${c.state}`}>
          <p>
            <b>{c.who}</b> {c.text}
          </p>
          {c.reply && <p className="cm-reply">↳ You: {c.reply}</p>}
          {c.state === "hidden" ? (
            <div className="cm-actions">
              <small>Hidden</small>
              <button className="text-action" onClick={() => setList((l) => l.map((x) => (x.id === c.id ? { ...x, state: "shown" } : x)))}>
                Show again
              </button>
            </div>
          ) : (
            <>
              {!c.reply && (
                <form
                  noValidate
                  className="cm-form"
                  onSubmit={(e) => {
                    e.preventDefault()
                    const t = (draft[c.id] ?? "").trim()
                    if (!t) return
                    setList((l) => l.map((x) => (x.id === c.id ? { ...x, reply: t } : x)))
                    ui.toast("Reply posted")
                  }}
                >
                  <input value={draft[c.id] ?? ""} onChange={(e) => setDraft({ ...draft, [c.id]: e.target.value })} placeholder={`Reply to ${c.who}…`} aria-label={`Reply to ${c.who}`} />
                  <button type="submit" className="text-action">
                    Reply
                  </button>
                </form>
              )}
              <div className="cm-actions">
                <button className="text-action" onClick={() => (setList((l) => l.map((x) => (x.id === c.id ? { ...x, state: "hidden" } : x))), ui.toast("Comment hidden"))}>
                  Hide
                </button>
                <button className="text-action danger" onClick={() => (setList((l) => l.filter((x) => x.id !== c.id)), ui.toast(`Reported and removed. ${c.who} can't comment again.`))}>
                  Report
                </button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  )
}

/** Visitors message the organizer; the conversation lands in Messages → Inquiries. */
export function MessageOrganizerButton({ name, event }: { name: string; event?: { name: string; date: string; venue: string } }) {
  const ui = useUI()
  const ib = useInbox()
  const start = useStartThread("org")
  return (
    <button
      className="secondary-action"
      onClick={() => {
        const id = start({
          id: "visit-" + (event?.name ?? "profile") + "-" + Date.now(),
          area: "Customers",
          guest: "Visitor (preview)",
          context: event ? `About ${event.name}` : `From your public profile`,
          scope: event?.name ?? name,
          card: event ? { kind: "Event", title: `${event.name} · ${event.date}`, detail: event.venue } : undefined,
          first: event ? `Hi! Question about ${event.name}.` : `Hi ${name}! I'd love to work with you.`,
        })
        ui.close()
        ib.openFor({ acc: "org", start: "Inquiries", id })
      }}
    >
      Message organizer
    </button>
  )
}
