import { createContext, useContext, useRef, useState, type PointerEvent as RPointerEvent, type ReactNode } from "react"
import { Icon, compressImage, usePersisted, useUI } from "./kit"
import { GENRES, MultiSelect, ChoiceChips, EVENT_DATES, TimeSelect, eventLabel } from "./Pickers"

/* DJ studio: the public profile, packages and add-ons, saved in this browser so edits
   survive reopening the app. Syncing them to the BottlesUp user app needs a backend. */

export type DjPkg = { id: string; name: string; desc: string; price: number; from: boolean; hours: number; includes: string[]; notice: string; setup: string; hidden: boolean }
export type DjAddon = { id: string; name: string; desc: string; price: number; unit: "flat" | "hour"; packages: string[]; hidden: boolean }
export type DjProfile = {
  photo?: string
  cover?: string
  coverY: number
  coverZoom: number
  stageName: string
  username: string
  bio: string
  location: string
  genres: string[]
  areas: string[]
  photos: string[]
  videos: { id: string; title: string; src?: string }[]
  links: { label: string; url: string }[]
  socials: { instagram: string; tiktok: string; soundcloud: string }
  notice: string
  eventTypes: string[]
  startingPrice: number
  visibility: "Public" | "Private"
}

export const DEFAULT_PACKAGES: DjPkg[] = [
  { id: "warmup", name: "Warm-up set", desc: "Set the room before the headliner.", price: 500, from: false, hours: 2, includes: ["Soundcheck", "Own USBs"], notice: "7 days", setup: "Venue decks and booth monitor", hidden: false },
  { id: "club", name: "Club set", desc: "Peak-time Afro house and amapiano.", price: 1200, from: false, hours: 4, includes: ["Soundcheck", "Custom intro edit", "Social post"], notice: "14 days", setup: "2 × CDJ-3000, DJM-A9, booth monitor", hidden: false },
  { id: "private", name: "Private event", desc: "Weddings, birthdays and brand nights.", price: 900, from: true, hours: 3, includes: ["Planning call", "Requests on the night"], notice: "21 days", setup: "Power and a 2 m table", hidden: false },
  { id: "festival", name: "Festival / headline", desc: "Headline slot with full production.", price: 2000, from: true, hours: 1.5, includes: ["Exclusive edits", "Rider-ready tech spec", "2 guest-list spots"], notice: "30 days", setup: "Full rider", hidden: false },
]
export const DEFAULT_ADDONS: DjAddon[] = [
  { id: "gear", name: "DJ equipment", desc: "I bring decks, mixer and monitors.", price: 300, unit: "flat", packages: ["private", "warmup"], hidden: false },
  { id: "lights", name: "Lighting package", desc: "Wash lights and haze for small rooms.", price: 350, unit: "flat", packages: ["private", "club"], hidden: false },
  { id: "mc", name: "MC / hype host", desc: "Mic work and announcements.", price: 200, unit: "flat", packages: ["private", "club", "festival"], hidden: false },
  { id: "extra", name: "Extra performance time", desc: "Keep the party going.", price: 250, unit: "hour", packages: ["warmup", "club", "private"], hidden: false },
  { id: "travel", name: "Travel outside Toronto", desc: "Up to 150 km.", price: 150, unit: "flat", packages: ["warmup", "club", "private", "festival"], hidden: false },
]
export const DEFAULT_PROFILE: DjProfile = {
  coverY: 50,
  coverZoom: 1,
  stageName: "Amara Vale",
  username: "amaravale",
  bio: "Resident at Nova Room. Clubs, private events and festivals across Ontario.",
  location: "Toronto",
  genres: ["Afro house", "Amapiano", "Deep house"],
  areas: ["Toronto", "GTA"],
  photos: [],
  videos: [{ id: "v1", title: "Live at Nova Room · Afterglow" }],
  links: [{ label: "SoundCloud mix", url: "soundcloud.com/amaravale/sunset-vol-3" }],
  socials: { instagram: "@amaravale", tiktok: "@amaravale", soundcloud: "amaravale" },
  notice: "14 days",
  eventTypes: ["Club night", "Private party", "Festival"],
  startingPrice: 500,
  visibility: "Public",
}

type Api = {
  profile: DjProfile
  setProfile: (p: DjProfile | ((x: DjProfile) => DjProfile)) => void
  pkgs: DjPkg[]
  setPkgs: (p: DjPkg[] | ((x: DjPkg[]) => DjPkg[])) => void
  addons: DjAddon[]
  setAddons: (a: DjAddon[] | ((x: DjAddon[]) => DjAddon[])) => void
  stored: boolean
}
const Ctx = createContext<Api | null>(null)
export const useDj = () => {
  const c = useContext(Ctx)
  if (!c) throw new Error("useDj outside DjProvider")
  return c
}
export function DjProvider({ children }: { children: ReactNode }) {
  const [profile, setProfile, s1] = usePersisted("bu-dj-profile", DEFAULT_PROFILE)
  const [pkgs, setPkgs, s2] = usePersisted("bu-dj-packages", DEFAULT_PACKAGES)
  const [addons, setAddons, s3] = usePersisted("bu-dj-addons", DEFAULT_ADDONS)
  return <Ctx.Provider value={{ profile, setProfile, pkgs, setPkgs, addons, setAddons, stored: s1 && s2 && s3 }}>{children}</Ctx.Provider>
}

const money0 = (n: number) => "$" + n.toLocaleString("en-US")
const priceLabel = (p: DjPkg) => `${p.from ? "From " : ""}${money0(p.price)}`

/* ---------------- shared bits ---------------- */

function ImageSlot({ src, label, onChange, round }: { src?: string; label: string; onChange: (v?: string) => void; round?: boolean }) {
  const ui = useUI()
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  return (
    <div className="ds-slot">
      <span className={`ds-slot-img ${round ? "round" : ""} ${busy ? "mp-loading" : ""}`}>{src ? <img src={src} alt="" /> : <Icon name="camera" size={20} />}</span>
      <div>
        <strong>{label}</strong>
        <span className="ds-slot-actions">
          <button className="text-action" onClick={() => input.current?.click()} disabled={busy}>
            {src ? "Replace" : "Upload"}
          </button>
          {src && (
            <button className="text-action danger" onClick={() => onChange(undefined)}>
              Remove
            </button>
          )}
        </span>
      </div>
      <input
        ref={input}
        type="file"
        accept="image/*"
        hidden
        onChange={async (e) => {
          const f = e.target.files?.[0]
          e.target.value = ""
          if (!f) return
          if (!f.type.startsWith("image/")) return ui.toast("Choose an image file")
          setBusy(true)
          try {
            onChange(await compressImage(f, round ? 400 : 1000))
          } catch {
            ui.toast("Couldn't read that image. Try another.")
          } finally {
            setBusy(false)
          }
        }}
      />
    </div>
  )
}

/** Cover image you can drag up and down and zoom, with a branded default. */
export function CoverFrame({ src, y, zoom, onMove, editable, children, fallback = "dj" }: { src?: string; y: number; zoom: number; onMove?: (y: number) => void; editable?: boolean; children?: ReactNode; fallback?: "dj" | "org" }) {
  const drag = useRef<{ y: number; start: number } | null>(null)
  const down = (e: RPointerEvent) => {
    if (!editable || !src) return
    drag.current = { y: e.clientY, start: y }
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
  }
  const move = (e: RPointerEvent) => {
    if (!drag.current || !onMove) return
    onMove(Math.max(0, Math.min(100, drag.current.start - (e.clientY - drag.current.y) / 2)))
  }
  return (
    <div className={`ds-cover ${editable && src ? "editable" : ""} fb-${fallback}`} onPointerDown={down} onPointerMove={move} onPointerUp={() => (drag.current = null)}>
      {src && <img src={src} alt="" style={{ objectPosition: `50% ${y}%`, transform: `scale(${zoom})` }} draggable={false} />}
      {editable && src && <span className="ds-drag-hint">Drag to reposition</span>}
      {children}
    </div>
  )
}

/* ---------------- Edit profile ---------------- */

const AREAS = ["Toronto", "GTA", "Hamilton", "Ottawa", "Montreal", "Anywhere in Ontario", "Will travel"]
const EVENT_TYPES = ["Club night", "Private party", "Wedding", "Corporate event", "Festival", "Brand event"]

export function DjProfileEditor({ onClose }: { onClose: () => void }) {
  const dj = useDj()
  const ui = useUI()
  const [d, setD] = useState<DjProfile>(dj.profile)
  const [tried, setTried] = useState(false)
  const set = (p: Partial<DjProfile>) => setD((x) => ({ ...x, ...p }))
  const photos = useRef<HTMLInputElement>(null)
  const video = useRef<HTMLInputElement>(null)
  const [link, setLink] = useState({ label: "", url: "" })
  const err = !d.stageName.trim() ? "Add your stage name." : !/^[a-z0-9._]{3,24}$/.test(d.username) ? "Usernames are 3–24 lowercase letters, numbers, dots or underscores." : d.bio.length > 220 ? "Keep your bio under 220 characters." : null
  const changed = JSON.stringify(d) !== JSON.stringify(dj.profile)
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Edit profile">
      <div className="gc-top">
        <button className="icon-button" aria-label="Close without saving" onClick={() => (changed ? ui.sheet({ eyebrow: "UNSAVED CHANGES", title: "Discard your changes?", body: (close) => <div className="srv-sheet"><button className="danger-action" onClick={() => (close(), onClose())}>Discard changes</button><button className="secondary-action full-action" onClick={close}>Keep editing</button></div> }) : onClose())}>
          <Icon name="close" size={18} />
        </button>
        <div>
          <span>DJ / ARTIST · PUBLIC PROFILE</span>
          <h1>Edit profile</h1>
        </div>
      </div>
      <div className="gc-body form-stack ds-edit">
        <CoverFrame src={d.cover} y={d.coverY} zoom={d.coverZoom} editable onMove={(coverY) => set({ coverY })}>
          <span className="ds-avatar">{d.photo ? <img src={d.photo} alt="" /> : d.stageName.slice(0, 2).toUpperCase()}</span>
        </CoverFrame>
        {d.cover && (
          <label className="cp-range">
            <span>Zoom</span>
            <input type="range" min={1} max={2} step={0.05} value={d.coverZoom} onChange={(e) => set({ coverZoom: Number(e.target.value) })} />
          </label>
        )}
        <div className="ds-slots">
          <ImageSlot label="Profile photo" round src={d.photo} onChange={(photo) => set({ photo })} />
          <ImageSlot label="Cover image" src={d.cover} onChange={(cover) => set({ cover, coverY: 50, coverZoom: 1 })} />
        </div>

        <label className="field">
          <span>Stage name</span>
          <input value={d.stageName} onChange={(e) => set({ stageName: e.target.value })} />
        </label>
        <label className="field">
          <span>Username</span>
          <input value={d.username} onChange={(e) => set({ username: e.target.value.toLowerCase().replace(/\s/g, "") })} />
        </label>
        <label className="field">
          <span>Bio</span>
          <textarea value={d.bio} maxLength={240} onChange={(e) => set({ bio: e.target.value })} />
          <small className="srv-muted">{d.bio.length}/220</small>
        </label>
        <div className="field">
          <span>Based in</span>
          <ChoiceChips label="Location" options={["Toronto", "Montreal", "Vancouver"]} value={d.location} onChange={(location) => set({ location })} />
        </div>
        <div className="field">
          <span>Genres</span>
          <MultiSelect label="Genres" options={GENRES} value={d.genres} onChange={(genres) => set({ genres })} />
        </div>
        <div className="field">
          <span>Service area</span>
          <MultiSelect label="Areas" options={AREAS} value={d.areas} onChange={(areas) => set({ areas })} />
        </div>

        <div className="field">
          <span>Photos</span>
          <div className="mp-grid">
            {d.photos.map((p, i) => (
              <div key={i} className="mp-item">
                <span className="mp-thumb">
                  <img src={p} alt="" />
                  {i === 0 && <span className="mp-cover">First</span>}
                </span>
                <div className="mp-tools">
                  <button aria-label="Move earlier" disabled={i === 0} onClick={() => set({ photos: d.photos.map((x, j) => (j === i - 1 ? p : j === i ? d.photos[i - 1] : x)) })}>
                    <Icon name="back" size={13} />
                  </button>
                  <button aria-label="Remove photo" onClick={() => set({ photos: d.photos.filter((_, j) => j !== i) })}>
                    <Icon name="trash" size={13} />
                  </button>
                </div>
              </div>
            ))}
            {d.photos.length < 6 && (
              <button className="mp-add" onClick={() => photos.current?.click()}>
                <Icon name="plus" size={20} />
                <small>Add photos</small>
              </button>
            )}
          </div>
          <input
            ref={photos}
            type="file"
            accept="image/*"
            multiple
            hidden
            onChange={async (e) => {
              const files = Array.from(e.target.files ?? []).slice(0, 6 - d.photos.length)
              e.target.value = ""
              const out: string[] = []
              for (const f of files) out.push(await compressImage(f, 700).catch(() => ""))
              set({ photos: [...d.photos, ...out.filter(Boolean)] })
            }}
          />
        </div>

        <div className="field">
          <span>Performance videos</span>
          <div className="srv-list">
            {d.videos.map((v) => (
              <div key={v.id} className="srv-req static">
                <span className="srv-avatar">▶</span>
                <span className="srv-main">
                  <strong>{v.title}</strong>
                  <small>{v.src ? "Uploaded video" : "Demo video"}</small>
                </span>
                <button className="text-action danger" onClick={() => set({ videos: d.videos.filter((x) => x.id !== v.id) })}>
                  Remove
                </button>
              </div>
            ))}
          </div>
          <button className="secondary-action full-action ve-add" onClick={() => video.current?.click()}>
            <Icon name="plus" size={16} /> Add a video
          </button>
          <small className="srv-muted">Videos stay on this device in the demo. Hosting them for visitors needs the BottlesUp backend.</small>
          <input
            ref={video}
            type="file"
            accept="video/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0]
              e.target.value = ""
              if (f) set({ videos: [...d.videos, { id: "v" + Date.now(), title: f.name.replace(/\.[^.]+$/, "") }] })
            }}
          />
        </div>

        <div className="field">
          <span>Music links</span>
          {d.links.map((l, i) => (
            <div key={i} className="ds-link">
              <span>
                <b>{l.label}</b>
                <small>{l.url}</small>
              </span>
              <button className="text-action danger" onClick={() => set({ links: d.links.filter((_, j) => j !== i) })}>
                Remove
              </button>
            </div>
          ))}
          <div className="form-row">
            <input className="pk-input" placeholder="Label (e.g. Mixcloud)" value={link.label} onChange={(e) => setLink({ ...link, label: e.target.value })} />
            <input className="pk-input" placeholder="Link" value={link.url} onChange={(e) => setLink({ ...link, url: e.target.value })} />
          </div>
          <button className="text-action" disabled={!link.label.trim() || !link.url.trim()} onClick={() => (set({ links: [...d.links, { label: link.label.trim(), url: link.url.trim() }] }), setLink({ label: "", url: "" }))}>
            + Add link
          </button>
        </div>

        <div className="field">
          <span>Social links</span>
          {(["instagram", "tiktok", "soundcloud"] as const).map((k) => (
            <label key={k} className="ds-social">
              <small>{k === "soundcloud" ? "SoundCloud" : k === "tiktok" ? "TikTok" : "Instagram"}</small>
              <input value={d.socials[k]} onChange={(e) => set({ socials: { ...d.socials, [k]: e.target.value } })} />
            </label>
          ))}
        </div>

        <div className="field">
          <span>Booking preferences</span>
          <ChoiceChips label="Minimum notice" options={["7 days", "14 days", "30 days"]} value={d.notice} onChange={(notice) => set({ notice })} />
          <MultiSelect label="Event types" options={EVENT_TYPES} value={d.eventTypes} onChange={(eventTypes) => set({ eventTypes })} />
        </div>
        <label className="field">
          <span>Starting price shown on your profile ($)</span>
          <input type="number" min={0} value={d.startingPrice} onChange={(e) => set({ startingPrice: Math.max(0, parseInt(e.target.value) || 0) })} />
        </label>
        {tried && err && (
          <p className="srv-error" role="alert">
            <Icon name="warning" size={15} /> {err}
          </p>
        )}
        <div className="srv-actions">
          <button className="secondary-action" onClick={onClose}>
            Cancel
          </button>
          <button
            className="primary-action"
            onClick={() => {
              setTried(true)
              if (err) return
              dj.setProfile({ ...d, stageName: d.stageName.trim() })
              ui.toast(dj.stored ? "Profile saved. It's live on your public profile." : "Saved for this session. Storage is full, so it won't survive a restart.")
              onClose()
            }}
          >
            Save profile
          </button>
        </div>
      </div>
    </div>
  )
}

/* ---------------- Public profile (as visitors see it) ---------------- */

export function DjPublicProfile({ onBack, onMessage, onRequest }: { onBack: () => void; onMessage: () => void; onRequest: () => void }) {
  const { profile: p, pkgs, addons } = useDj()
  const visible = pkgs.filter((x) => !x.hidden)
  return (
    <div className="gc ds-public" role="dialog" aria-modal="true" aria-label="Public profile">
      <div className="ds-public-bar">
        <button className="secondary-action" onClick={onBack}>
          <Icon name="back" size={15} /> Back to workspace
        </button>
        <span className={`srv-chip tone-${p.visibility === "Public" ? "green" : "gray"}`}>{p.visibility === "Public" ? "Visitors see this" : "Private · hidden from visitors"}</span>
      </div>
      <div className="gc-body ds-public-body">
        <CoverFrame src={p.cover} y={p.coverY} zoom={p.coverZoom}>
          <span className="ds-avatar">{p.photo ? <img src={p.photo} alt="" /> : p.stageName.slice(0, 2).toUpperCase()}</span>
        </CoverFrame>
        <div className="ds-identity">
          <h1>{p.stageName}</h1>
          <small>
            @{p.username} · DJ · {p.location}
          </small>
          <p>{p.bio}</p>
          <div className="cp-chips">
            {p.genres.map((g) => (
              <span key={g} className="ds-tag">
                {g}
              </span>
            ))}
          </div>
          <small className="srv-muted">
            From {money0(p.startingPrice)} · plays {p.areas.join(", ")} · {p.notice} notice
          </small>
        </div>
        <div className="ds-cta">
          <button className="secondary-action" onClick={onMessage}>
            <Icon name="chat" size={16} /> Message
          </button>
          <button className="primary-action" onClick={onRequest}>
            Request booking
          </button>
        </div>
        {p.photos.length > 0 && (
          <div className="ds-photos">
            {p.photos.map((src, i) => (
              <img key={i} src={src} alt="" />
            ))}
          </div>
        )}
        <section className="srv-section">
          <h2>Packages</h2>
          <div className="ds-cards">
            {visible.map((x) => (
              <article key={x.id} className="ds-card">
                <header>
                  <strong>{x.name}</strong>
                  <b>{priceLabel(x)}</b>
                </header>
                <small>
                  {x.hours} h · {x.desc}
                </small>
                <small className="srv-muted">{x.includes.join(" · ")}</small>
              </article>
            ))}
          </div>
        </section>
        <section className="srv-section">
          <h2>Add-ons</h2>
          <div className="srv-list">
            {addons
              .filter((a) => !a.hidden)
              .map((a) => (
                <div key={a.id} className="srv-req static">
                  <span className="srv-main">
                    <strong>{a.name}</strong>
                    <small>{a.desc}</small>
                  </span>
                  <b className="ds-price">
                    +{money0(a.price)}
                    {a.unit === "hour" ? "/h" : ""}
                  </b>
                </div>
              ))}
          </div>
        </section>
        {(p.videos.length > 0 || p.links.length > 0) && (
          <section className="srv-section">
            <h2>Listen and watch</h2>
            <div className="srv-list">
              {p.videos.map((v) => (
                <div key={v.id} className="srv-req static">
                  <span className="srv-avatar">▶</span>
                  <span className="srv-main">
                    <strong>{v.title}</strong>
                    <small>Video</small>
                  </span>
                </div>
              ))}
              {p.links.map((l, i) => (
                <div key={i} className="srv-req static">
                  <span className="srv-avatar">♪</span>
                  <span className="srv-main">
                    <strong>{l.label}</strong>
                    <small>{l.url}</small>
                  </span>
                </div>
              ))}
            </div>
          </section>
        )}
        <p className="srv-muted os-note">
          {p.socials.instagram} · {p.socials.tiktok} · soundcloud.com/{p.socials.soundcloud}
        </p>
      </div>
    </div>
  )
}

/* ---------------- Booking request form (visitor view) ---------------- */

export type NewRequest = { client: string; dateKey: string; start: string; end: string; venue: string; eventType: string; pkg: string; addons: string[]; message: string }

export function BookingRequestForm({ onBack, onSubmit }: { onBack: () => void; onSubmit: (r: NewRequest) => void }) {
  const dj = useDj()
  const ui = useUI()
  const pkgs = dj.pkgs.filter((p) => !p.hidden)
  const [r, setR] = useState<NewRequest>({ client: "Liam Carter", dateKey: EVENT_DATES[21].key, start: "10:00 PM", end: "2:00 AM", venue: "", eventType: "Club night", pkg: pkgs[0]?.id ?? "", addons: [], message: "" })
  const [tried, setTried] = useState(false)
  const addons = dj.addons.filter((a) => !a.hidden && a.packages.includes(r.pkg))
  const pkg = pkgs.find((p) => p.id === r.pkg)
  const total = (pkg?.price ?? 0) + addons.filter((a) => r.addons.includes(a.id)).reduce((s, a) => s + a.price * (a.unit === "hour" ? 1 : 1), 0)
  const err = !r.venue.trim() ? "Add where the event is." : !pkg ? "Choose a package." : null
  return (
    <div className="gc" role="dialog" aria-modal="true" aria-label="Request booking">
      <div className="gc-top">
        <button className="icon-button" aria-label="Back" onClick={onBack}>
          <Icon name="back" size={18} />
        </button>
        <div>
          <span>VISITOR VIEW · {dj.profile.stageName.toUpperCase()}</span>
          <h1>Request booking</h1>
        </div>
      </div>
      <div className="gc-body form-stack">
        <div className="field">
          <span>Date</span>
          <select value={r.dateKey} onChange={(e) => setR({ ...r, dateKey: e.target.value })}>
            {EVENT_DATES.map((d) => (
              <option key={d.key} value={d.key}>
                {d.label}
              </option>
            ))}
          </select>
        </div>
        <div className="form-row">
          <label className="field">
            <span>Start</span>
            <TimeSelect label="Start" value={r.start} onChange={(start) => setR({ ...r, start })} />
          </label>
          <label className="field">
            <span>End</span>
            <TimeSelect label="End" value={r.end} onChange={(end) => setR({ ...r, end })} />
          </label>
        </div>
        <label className="field">
          <span>Location</span>
          <input value={r.venue} onChange={(e) => setR({ ...r, venue: e.target.value })} placeholder="Venue or address" />
        </label>
        <div className="field">
          <span>Event type</span>
          <ChoiceChips label="Event type" options={dj.profile.eventTypes.length ? dj.profile.eventTypes : EVENT_TYPES} value={r.eventType} onChange={(eventType) => setR({ ...r, eventType })} />
        </div>
        <div className="field">
          <span>Package</span>
          <div className="srv-choices">
            {pkgs.map((p) => (
              <button key={p.id} role="radio" aria-checked={r.pkg === p.id} className={r.pkg === p.id ? "on" : ""} onClick={() => setR({ ...r, pkg: p.id, addons: [] })}>
                <span />
                {p.name} · {priceLabel(p)}
              </button>
            ))}
          </div>
        </div>
        {addons.length > 0 && (
          <div className="field">
            <span>Add-ons (optional)</span>
            <div className="cp-chips">
              {addons.map((a) => (
                <button key={a.id} aria-pressed={r.addons.includes(a.id)} className={r.addons.includes(a.id) ? "on" : ""} onClick={() => setR({ ...r, addons: r.addons.includes(a.id) ? r.addons.filter((x) => x !== a.id) : [...r.addons, a.id] })}>
                  {a.name} +{money0(a.price)}
                  {a.unit === "hour" ? "/h" : ""}
                </button>
              ))}
            </div>
          </div>
        )}
        <label className="field">
          <span>Message (optional)</span>
          <textarea value={r.message} onChange={(e) => setR({ ...r, message: e.target.value })} placeholder="Tell the DJ about the night" />
        </label>
        <p className="promo-preview">
          <span>Estimate</span>
          <b>
            {pkg?.from ? "From " : ""}
            {money0(total)} + HST
          </b>
          <small>No charge until the DJ accepts and you pay the deposit.</small>
        </p>
        {tried && err && <p className="srv-error">{err}</p>}
        <button
          className="primary-action full-action"
          onClick={() => {
            setTried(true)
            if (err) return
            onSubmit(r)
            ui.toast("Request sent. It's in Requests, with a linked conversation.")
          }}
        >
          Send request
        </button>
        <small className="srv-muted">Demo: this is what clients fill in. Submitting adds it to your Requests.</small>
      </div>
    </div>
  )
}

/* ---------------- Services: packages & add-ons ---------------- */

const INCLUDES = ["Soundcheck", "Own USBs", "Custom intro edit", "Social post", "Planning call", "Requests on the night", "Exclusive edits", "Rider-ready tech spec", "2 guest-list spots"]

function PkgForm({ initial, close, onSave, onDelete }: { initial?: DjPkg; close: () => void; onSave: (p: DjPkg) => void; onDelete?: () => void }) {
  const [p, setP] = useState<DjPkg>(initial ?? { id: "p" + Date.now(), name: "", desc: "", price: 0, from: false, hours: 2, includes: [], notice: "14 days", setup: "", hidden: false })
  const [tried, setTried] = useState(false)
  const err = !p.name.trim() ? "Give the package a name." : p.price <= 0 ? "Set a price above $0." : p.hours <= 0 ? "Set the set length." : null
  return (
    <div className="form-stack ve-form">
      <label className="field">
        <span>Name</span>
        <input value={p.name} onChange={(e) => setP({ ...p, name: e.target.value })} placeholder="e.g. Rooftop sunset set" />
      </label>
      <label className="field">
        <span>Description</span>
        <input value={p.desc} onChange={(e) => setP({ ...p, desc: e.target.value })} />
      </label>
      <div className="form-row">
        <label className="field">
          <span>Price ($)</span>
          <input type="number" min={0} value={p.price || ""} onChange={(e) => setP({ ...p, price: Math.max(0, parseInt(e.target.value) || 0) })} />
        </label>
        <label className="field">
          <span>Set length (hours)</span>
          <input type="number" min={0.5} step={0.5} value={p.hours} onChange={(e) => setP({ ...p, hours: Math.max(0, parseFloat(e.target.value) || 0) })} />
        </label>
      </div>
      <label className="srv-toggle">
        <span>
          <strong>Show as “From” price</strong>
          <small>For packages where the final price depends on the event</small>
        </span>
        <input type="checkbox" checked={p.from} onChange={(e) => setP({ ...p, from: e.target.checked })} />
      </label>
      <div className="field">
        <span>Included</span>
        <MultiSelect label="Inclusions" options={INCLUDES} value={p.includes} onChange={(includes) => setP({ ...p, includes })} />
      </div>
      <div className="field">
        <span>Booking notice</span>
        <ChoiceChips label="Notice" options={["7 days", "14 days", "21 days", "30 days"]} value={p.notice} onChange={(notice) => setP({ ...p, notice })} />
      </div>
      <label className="field">
        <span>Setup requirements</span>
        <input value={p.setup} onChange={(e) => setP({ ...p, setup: e.target.value })} placeholder="e.g. 2 × CDJ-3000, booth monitor" />
      </label>
      {tried && err && <p className="srv-error">{err}</p>}
      <button className="primary-action full-action" onClick={() => (setTried(true), !err && (onSave({ ...p, name: p.name.trim() }), close()))}>
        {initial ? "Save package" : "Add package"}
      </button>
      {onDelete && (
        <button className="text-action danger" onClick={() => (onDelete(), close())}>
          Delete package
        </button>
      )}
    </div>
  )
}

function AddonForm({ initial, pkgs, close, onSave, onDelete }: { initial?: DjAddon; pkgs: DjPkg[]; close: () => void; onSave: (a: DjAddon) => void; onDelete?: () => void }) {
  const [a, setA] = useState<DjAddon>(initial ?? { id: "a" + Date.now(), name: "", desc: "", price: 0, unit: "flat", packages: pkgs.map((p) => p.id), hidden: false })
  const [tried, setTried] = useState(false)
  const err = !a.name.trim() ? "Give the add-on a name." : a.price <= 0 ? "Set a price above $0." : !a.packages.length ? "Choose at least one package." : null
  return (
    <div className="form-stack ve-form">
      <label className="field">
        <span>Name</span>
        <input value={a.name} onChange={(e) => setA({ ...a, name: e.target.value })} placeholder="e.g. Smoke machine" />
      </label>
      <label className="field">
        <span>Description</span>
        <input value={a.desc} onChange={(e) => setA({ ...a, desc: e.target.value })} />
      </label>
      <div className="field">
        <span>Pricing</span>
        <div className="cp-chips">
          {(["flat", "hour"] as const).map((u) => (
            <button key={u} aria-pressed={a.unit === u} className={a.unit === u ? "on" : ""} onClick={() => setA({ ...a, unit: u })}>
              {u === "flat" ? "Flat fee" : "Per hour"}
            </button>
          ))}
        </div>
        <input type="number" min={0} value={a.price || ""} onChange={(e) => setA({ ...a, price: Math.max(0, parseInt(e.target.value) || 0) })} aria-label="Price" />
      </div>
      <div className="field">
        <span>Available with</span>
        <div className="cp-chips">
          {pkgs.map((p) => (
            <button key={p.id} aria-pressed={a.packages.includes(p.id)} className={a.packages.includes(p.id) ? "on" : ""} onClick={() => setA({ ...a, packages: a.packages.includes(p.id) ? a.packages.filter((x) => x !== p.id) : [...a.packages, p.id] })}>
              {p.name}
            </button>
          ))}
        </div>
      </div>
      {tried && err && <p className="srv-error">{err}</p>}
      <button className="primary-action full-action" onClick={() => (setTried(true), !err && (onSave({ ...a, name: a.name.trim() }), close()))}>
        {initial ? "Save add-on" : "Add add-on"}
      </button>
      {onDelete && (
        <button className="text-action danger" onClick={() => (onDelete(), close())}>
          Delete add-on
        </button>
      )}
    </div>
  )
}

function moveItem<T>(list: T[], i: number, d: number) {
  const j = i + d
  if (j < 0 || j >= list.length) return list
  const next = [...list]
  ;[next[i], next[j]] = [next[j], next[i]]
  return next
}

export function ServicesEditor() {
  const dj = useDj()
  const ui = useUI()
  const editPkg = (p?: DjPkg) =>
    ui.sheet({
      eyebrow: "PACKAGE",
      title: p ? p.name : "New package",
      body: (close) => <PkgForm initial={p} close={close} onSave={(n) => (dj.setPkgs((l) => (p ? l.map((x) => (x.id === p.id ? n : x)) : [...l, n])), ui.toast(p ? `${n.name} saved` : `${n.name} added`))} onDelete={p ? () => { const before = dj.pkgs; dj.setPkgs((l) => l.filter((x) => x.id !== p.id)); ui.toast(`${p.name} deleted`, () => dj.setPkgs(before)) } : undefined} />,
    })
  const editAddon = (a?: DjAddon) =>
    ui.sheet({
      eyebrow: "ADD-ON",
      title: a ? a.name : "New add-on",
      body: (close) => <AddonForm initial={a} pkgs={dj.pkgs} close={close} onSave={(n) => (dj.setAddons((l) => (a ? l.map((x) => (x.id === a.id ? n : x)) : [...l, n])), ui.toast(a ? `${n.name} saved` : `${n.name} added`))} onDelete={a ? () => { const before = dj.addons; dj.setAddons((l) => l.filter((x) => x.id !== a.id)); ui.toast(`${a.name} deleted`, () => dj.setAddons(before)) } : undefined} />,
    })
  const Tools = ({ i, n, hidden, onMove, onHide, onEdit }: { i: number; n: number; hidden: boolean; onMove: (d: number) => void; onHide: () => void; onEdit: () => void }) => (
    <div className="ds-tools">
      <button aria-label="Move up" disabled={i === 0} onClick={() => onMove(-1)}>
        ↑
      </button>
      <button aria-label="Move down" disabled={i === n - 1} onClick={() => onMove(1)}>
        ↓
      </button>
      <button onClick={onHide}>{hidden ? "Show" : "Hide"}</button>
      <button className="ds-edit-btn" onClick={onEdit}>
        <Icon name="pencil" size={13} /> Edit
      </button>
    </div>
  )
  return (
    <>
      <section className="srv-section">
        <div className="ds-sec-head">
          <h2>Packages</h2>
          <button className="text-action" onClick={() => editPkg()}>
            + New
          </button>
        </div>
        <div className="ds-cards">
          {dj.pkgs.map((p, i) => (
            <article key={p.id} className={`ds-card ${p.hidden ? "hidden" : ""}`}>
              <header>
                <strong>{p.name}</strong>
                <b>{priceLabel(p)}</b>
              </header>
              <small>
                {p.hours} h · {p.notice} notice{p.hidden ? " · Hidden from your profile" : ""}
              </small>
              {p.includes.length > 0 && <small className="srv-muted">{p.includes.join(" · ")}</small>}
              <Tools i={i} n={dj.pkgs.length} hidden={p.hidden} onMove={(d) => dj.setPkgs((l) => moveItem(l, i, d))} onHide={() => (dj.setPkgs((l) => l.map((x) => (x.id === p.id ? { ...x, hidden: !x.hidden } : x))), ui.toast(p.hidden ? `${p.name} shown on your profile` : `${p.name} hidden`))} onEdit={() => editPkg(p)} />
            </article>
          ))}
        </div>
      </section>
      <section className="srv-section">
        <div className="ds-sec-head">
          <h2>Add-ons</h2>
          <button className="text-action" onClick={() => editAddon()}>
            + New
          </button>
        </div>
        <div className="ds-cards">
          {dj.addons.map((a, i) => (
            <article key={a.id} className={`ds-card ${a.hidden ? "hidden" : ""}`}>
              <header>
                <strong>{a.name}</strong>
                <b>
                  +{money0(a.price)}
                  {a.unit === "hour" ? "/h" : ""}
                </b>
              </header>
              <small>
                {a.desc}
                {a.hidden ? " · Hidden" : ""}
              </small>
              <small className="srv-muted">With: {a.packages.map((id) => dj.pkgs.find((p) => p.id === id)?.name).filter(Boolean).join(", ") || "No packages"}</small>
              <Tools i={i} n={dj.addons.length} hidden={a.hidden} onMove={(d) => dj.setAddons((l) => moveItem(l, i, d))} onHide={() => (dj.setAddons((l) => l.map((x) => (x.id === a.id ? { ...x, hidden: !x.hidden } : x))), ui.toast(a.hidden ? `${a.name} shown` : `${a.name} hidden`))} onEdit={() => editAddon(a)} />
            </article>
          ))}
        </div>
      </section>
      <p className="status-explainer">Changes apply to new requests. Requests you've already received keep the price the client saw. Saved on this device; syncing to the BottlesUp app needs the backend.</p>
    </>
  )
}

export { eventLabel }
