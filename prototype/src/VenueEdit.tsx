import { createContext, useContext, useRef, useState, type ReactNode } from "react"
import { usePersisted, Icon, useUI } from "./kit"
import { ACCESS, AGES, ChoiceChips, DEFAULT_HOURS, DRESS, ENTRY, GENRES, HoursEditor, MultiSelect, hoursSummary, type Hours } from "./Pickers"

/* What guests see on the Nova Room page and at checkout, edited by the owner:
   venue page (logo, hours, music, entry rules), tables (photos, walkthrough video,
   section, capacity, admissions, deposit, minimum, inclusions), bottles (photo, size,
   price, mixers, availability) and bottle-sign options. Demo data matches the user app. */

type Page = { logo?: string; about: string; hours: Hours; music: string[]; dress: string; age: string; entry: string[]; access: string[]; parking: string }
export type Media = { id: string; src: string; kind: "image" | "video" }
type VTable = { id: string; name: string; section: string; capacity: number; admissions: number; deposit: number; min: number; inclusions: string[]; photos: Media[]; video?: Media; live: boolean }
type Bottle = { id: string; name: string; size: string; price: number; available: boolean; mixers: string[]; photo?: string }
type SignOpt = { id: string; name: string; price: number; on: boolean }

type Api = {
  page: Page
  setPage: (p: Page) => void
  tables: VTable[]
  setTables: (fn: (t: VTable[]) => VTable[]) => void
  bottles: Bottle[]
  setBottles: (fn: (b: Bottle[]) => Bottle[]) => void
  signs: SignOpt[]
  setSigns: (fn: (s: SignOpt[]) => SignOpt[]) => void
  cutoff: string
  setCutoff: (c: string) => void
}
const Ctx = createContext<Api | null>(null)
const useVenue = () => {
  const c = useContext(Ctx)
  if (!c) throw new Error("useVenue outside VenueProvider")
  return c
}

// The venue's live bottle menu, for screens that price orders (null outside the provider).
export const useVenueBottles = () => useContext(Ctx)?.bottles ?? null

const img = (id: string, src: string): Media => ({ id, src, kind: "image" })

export function VenueProvider({ children }: { children: ReactNode }) {
  const [page, setPage] = usePersisted<Page>("bu-biz-venue-page", {
    logo: "/bottlesup-logo.png",
    about: "A two-level music room built for immersive sound, skyline views and intimate late-night sets.",
    hours: DEFAULT_HOURS,
    music: ["Afro house", "R&B", "Amapiano"],
    dress: "Smart evening wear",
    age: "19+",
    entry: ["Physical ID required", "No re-entry"],
    access: ["Step-free entry", "Accessible washroom"],
    parking: "Paid lot on Mercer · rideshare zone",
  })
  const [tables, setTables] = usePersisted<VTable[]>("bu-biz-venue-tables", [
    { id: "halo", name: "Halo Booth", section: "Upper level", capacity: 6, admissions: 6, deposit: 150, min: 1000, inclusions: ["Dedicated host", "Mixers and ice", "Priority entry"], photos: [img("h1", "/venue/booth.jpg"), img("h2", "/venue/main-room.jpg")], live: true },
    { id: "arc", name: "Arc Table", section: "Main floor", capacity: 8, admissions: 8, deposit: 200, min: 1500, inclusions: ["Mixers and ice", "Priority entry"], photos: [img("a1", "/venue/bar.jpg")], live: true },
    { id: "vip", name: "VIP Booth", section: "Upper level", capacity: 10, admissions: 10, deposit: 300, min: 2500, inclusions: ["Dedicated host", "Champagne toast", "Private entrance"], photos: [], live: false },
  ])
  const [bottles, setBottles] = usePersisted<Bottle[]>("bu-biz-venue-bottles", [
    { id: "donjulio", name: "Don Julio 1942", size: "750 ml", price: 1000, available: true, mixers: ["Soda", "Citrus", "Ice"], photo: "/venue/bar.jpg" },
    { id: "dom", name: "Dom Pérignon Brut", size: "750 ml", price: 850, available: false, mixers: ["Chilled flutes"] },
    { id: "greygoose", name: "Grey Goose", size: "1.75 L", price: 650, available: true, mixers: ["Soda", "Cranberry", "Ice"] },
  ])
  const [signs, setSigns] = usePersisted<SignOpt[]>("bu-biz-venue-signs", [
    { id: "led", name: "LED message board", price: 25, on: true },
    { id: "sparkler", name: "Sparkler sign", price: 40, on: true },
    { id: "neon", name: "Neon script", price: 60, on: true },
  ])
  const [cutoff, setCutoff] = usePersisted("bu-biz-venue-cutoff", "6 PM on the day")
  return <Ctx.Provider value={{ page, setPage, tables, setTables, bottles, setBottles, signs, setSigns, cutoff, setCutoff }}>{children}</Ctx.Provider>
}

function Switch({ on, label, onChange }: { on: boolean; label: string; onChange: () => void }) {
  return (
    <label className="dj-avail ve-switch">
      <input type="checkbox" role="switch" aria-label={label} checked={on} onChange={onChange} />
      <i />
    </label>
  )
}

/* ---------- media helpers ---------- */

function readFile(f: File): Promise<string> {
  return new Promise((res, rej) => {
    const r = new FileReader()
    r.onload = () => res(String(r.result))
    r.onerror = () => rej(new Error("read"))
    r.readAsDataURL(f)
  })
}

/** Photo grid with upload, preview, reorder, cover selection and removal. */
export function MediaPicker({ items, onChange, label, max = 8 }: { items: Media[]; onChange: (m: Media[]) => void; label: string; max?: number }) {
  const ui = useUI()
  const input = useRef<HTMLInputElement>(null)
  const [loading, setLoading] = useState(0)
  const [preview, setPreview] = useState<Media | null>(null)
  const add = async (files: FileList | null) => {
    if (!files) return
    const list = Array.from(files).filter((f) => f.type.startsWith("image/")).slice(0, max - items.length)
    if (!list.length) return ui.toast("Choose image files")
    setLoading(list.length)
    const out: Media[] = []
    for (const f of list) {
      if (f.size > 10 * 1024 * 1024) {
        ui.toast(`${f.name} is over 10 MB and was skipped`)
        continue
      }
      try {
        out.push(img("m" + Date.now() + Math.random(), await readFile(f)))
      } catch {
        ui.toast(`Couldn't read ${f.name}. Try again.`)
      }
    }
    setLoading(0)
    onChange([...items, ...out])
  }
  const move = (i: number, d: number) => {
    const j = i + d
    if (j < 0 || j >= items.length) return
    const next = [...items]
    ;[next[i], next[j]] = [next[j], next[i]]
    onChange(next)
  }
  return (
    <div className="mp">
      <div className="mp-grid">
        {items.map((m, i) => (
          <div key={m.id} className="mp-item">
            <button className="mp-thumb" onClick={() => setPreview(m)} aria-label={`Preview photo ${i + 1}`}>
              <img src={m.src} alt="" />
              {i === 0 && <span className="mp-cover">Cover</span>}
            </button>
            <div className="mp-tools">
              <button aria-label="Move earlier" disabled={i === 0} onClick={() => move(i, -1)}>
                <Icon name="back" size={13} />
              </button>
              {i !== 0 && (
                <button aria-label="Make cover" onClick={() => onChange([m, ...items.filter((x) => x.id !== m.id)])}>
                  <Icon name="star" size={13} />
                </button>
              )}
              <button aria-label="Move later" disabled={i === items.length - 1} onClick={() => move(i, 1)}>
                <Icon name="chevron" size={13} />
              </button>
              <button aria-label="Remove photo" onClick={() => onChange(items.filter((x) => x.id !== m.id))}>
                <Icon name="trash" size={13} />
              </button>
            </div>
          </div>
        ))}
        {Array.from({ length: loading }, (_, i) => (
          <div key={"l" + i} className="mp-item">
            <span className="mp-thumb mp-loading" aria-label="Uploading" />
          </div>
        ))}
        {items.length + loading < max && (
          <button className="mp-add" onClick={() => input.current?.click()}>
            <Icon name="plus" size={20} />
            <small>Add photos</small>
          </button>
        )}
      </div>
      <small className="srv-muted">
        {label} · first photo is the cover · {items.length}/{max}
      </small>
      <input ref={input} type="file" accept="image/*" multiple hidden onChange={(e) => (add(e.target.files), (e.target.value = ""))} />
      {preview && (
        <div className="mp-preview" role="dialog" aria-modal="true" aria-label="Photo preview" onClick={() => setPreview(null)}>
          <img src={preview.src} alt="" />
          <button className="secondary-action">Close</button>
        </div>
      )}
    </div>
  )
}

function VideoPicker({ value, onChange }: { value?: Media; onChange: (m?: Media) => void }) {
  const ui = useUI()
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  return (
    <div className="mp-video">
      {busy ? (
        <span className="mp-thumb mp-loading wide" aria-label="Uploading video" />
      ) : value ? (
        <>
          <video src={value.src} controls muted playsInline />
          <button className="text-action danger" onClick={() => onChange(undefined)}>
            Remove video
          </button>
        </>
      ) : (
        <button className="mp-add wide" onClick={() => input.current?.click()}>
          <Icon name="camera" size={20} />
          <small>Add a walkthrough video (optional)</small>
        </button>
      )}
      <input
        ref={input}
        type="file"
        accept="video/*"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0]
          e.target.value = ""
          if (!f) return
          if (f.size > 60 * 1024 * 1024) return ui.toast("Videos must be under 60 MB")
          setBusy(true)
          window.setTimeout(() => {
            onChange({ id: "v" + Date.now(), src: URL.createObjectURL(f), kind: "video" })
            setBusy(false)
          }, 600)
        }}
      />
    </div>
  )
}

/* ---------- Page ---------- */

export function PageEditor() {
  const v = useVenue()
  const ui = useUI()
  const [d, setD] = useState(v.page)
  const logo = useRef<HTMLInputElement>(null)
  const changed = JSON.stringify(d) !== JSON.stringify(v.page)
  return (
    <div className="form-stack ve">
      <p className="srv-muted">Guests see this on the Nova Room page. Changes go live when you publish.</p>
      <div className="ve-logo">
        <span>{d.logo ? <img src={d.logo} alt="Venue logo" /> : <Icon name="venue" size={24} />}</span>
        <div>
          <strong>Venue logo</strong>
          <small>Square image, shown on your profile and passes</small>
          <button className="text-action" onClick={() => logo.current?.click()}>
            {d.logo ? "Replace logo" : "Upload logo"}
          </button>
        </div>
        <input ref={logo} type="file" accept="image/*" hidden onChange={async (e) => { const f = e.target.files?.[0]; e.target.value = ""; if (f) setD({ ...d, logo: await readFile(f) }) }} />
      </div>
      <label className="field">
        <span>About</span>
        <textarea value={d.about} maxLength={400} onChange={(e) => setD({ ...d, about: e.target.value })} />
        <small className="srv-muted">Shown short with Read more · {d.about.length}/400</small>
      </label>
      <div className="field">
        <span>Opening hours</span>
        <HoursEditor value={d.hours} onChange={(hours) => setD({ ...d, hours })} />
      </div>
      <div className="field">
        <span>Music</span>
        <MultiSelect label="Genres" options={GENRES} value={d.music} onChange={(music) => setD({ ...d, music })} />
      </div>
      <div className="field">
        <span>Dress code</span>
        <ChoiceChips label="Dress code" options={DRESS} value={d.dress} onChange={(dress) => setD({ ...d, dress })} />
      </div>
      <div className="field">
        <span>Age</span>
        <ChoiceChips label="Age" options={AGES} value={d.age} onChange={(age) => setD({ ...d, age })} allowCustom={false} />
      </div>
      <div className="field">
        <span>Entry requirements</span>
        <MultiSelect label="Requirements" options={ENTRY} value={d.entry} onChange={(entry) => setD({ ...d, entry })} />
      </div>
      <div className="field">
        <span>Accessibility</span>
        <MultiSelect label="Features" options={ACCESS} value={d.access} onChange={(access) => setD({ ...d, access })} />
      </div>
      <label className="field">
        <span>Parking and getting there</span>
        <input value={d.parking} onChange={(e) => setD({ ...d, parking: e.target.value })} />
      </label>
      <GuestPreview title="How guests see it">
        <b>Nova Room</b>
        <small>{hoursSummary(d.hours)}</small>
        <small>
          {d.music.join(" · ")} · {d.dress} · {d.age}
        </small>
      </GuestPreview>
      <div className="srv-actions">
        <button className="secondary-action" disabled={!changed} onClick={() => (setD(v.page), ui.toast("Changes discarded"))}>
          Discard
        </button>
        <button className="primary-action" disabled={!changed} onClick={() => (v.setPage(d), ui.toast("Venue page updated for guests"))}>
          {changed ? "Publish changes" : "Up to date"}
        </button>
      </div>
    </div>
  )
}

function GuestPreview({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="ve-preview" aria-label={title}>
      <span className="ve-preview-label">
        <Icon name="eye" size={13} /> {title}
      </span>
      {children}
    </div>
  )
}

/* ---------- Tables ---------- */

const INCLUSIONS = ["Dedicated host", "Mixers and ice", "Priority entry", "Champagne toast", "Private entrance", "Sparkler delivery", "Coat check"]

function TableForm({ initial, onSave, onDelete, close }: { initial?: VTable; onSave: (t: VTable) => void; onDelete?: () => void; close: () => void }) {
  const [t, setT] = useState<VTable>(initial ?? { id: "t" + Date.now(), name: "", section: "Main floor", capacity: 6, admissions: 6, deposit: 150, min: 1000, inclusions: ["Mixers and ice"], photos: [], live: false })
  const [tried, setTried] = useState(false)
  const err = !t.name.trim() ? "Give the table a name guests will recognise." : t.admissions > t.capacity ? "Included admissions can't be more than the guest limit." : t.deposit > t.min ? "The deposit should be less than the minimum spend." : null
  const num = (k: "capacity" | "admissions" | "deposit" | "min", v: string) => setT({ ...t, [k]: Math.max(0, parseInt(v) || 0) })
  return (
    <div className="form-stack ve-form">
      <div className="field">
        <span>Table photos</span>
        <MediaPicker label="Real photos of this table" items={t.photos} onChange={(photos) => setT({ ...t, photos })} />
      </div>
      <div className="field">
        <span>Walkthrough video</span>
        <VideoPicker value={t.video} onChange={(video) => setT({ ...t, video })} />
      </div>
      <label className="field">
        <span>Table name</span>
        <input value={t.name} onChange={(e) => setT({ ...t, name: e.target.value })} placeholder="e.g. Skyline Booth" />
      </label>
      <div className="field">
        <span>Section</span>
        <ChoiceChips label="Section" options={["Main floor", "Upper level", "Terrace", "VIP room"]} value={t.section} onChange={(section) => setT({ ...t, section })} />
      </div>
      <div className="form-row">
        <label className="field">
          <span>Guest limit</span>
          <input type="number" min={1} value={t.capacity} onChange={(e) => num("capacity", e.target.value)} />
        </label>
        <label className="field">
          <span>Entry passes included</span>
          <input type="number" min={0} value={t.admissions} onChange={(e) => num("admissions", e.target.value)} />
        </label>
      </div>
      <div className="form-row">
        <label className="field">
          <span>Deposit ($)</span>
          <input type="number" min={0} value={t.deposit} onChange={(e) => num("deposit", e.target.value)} />
        </label>
        <label className="field">
          <span>Minimum spend ($)</span>
          <input type="number" min={0} value={t.min} onChange={(e) => num("min", e.target.value)} />
        </label>
      </div>
      <div className="field">
        <span>Package includes</span>
        <MultiSelect label="Inclusions" options={INCLUSIONS} value={t.inclusions} onChange={(inclusions) => setT({ ...t, inclusions })} />
      </div>
      <p className="srv-muted">The floor plan is managed separately in Setup → Rooms and floor plans.</p>
      <GuestPreview title="Guest view">
        <div className="ve-guest-table">
          {t.photos[0] ? <img src={t.photos[0].src} alt="" /> : <span className="ve-noimg">No photo yet</span>}
          <span>
            <b>{t.name || "Table name"}</b>
            <small>
              {t.section} · up to {t.capacity} · {t.admissions} entry passes
            </small>
            <small>
              ${t.min.toLocaleString()} minimum spend · ${t.deposit} deposit, counted toward your spend
            </small>
            <small>{t.inclusions.join(" · ")}</small>
          </span>
        </div>
      </GuestPreview>
      {tried && err && (
        <p className="srv-error" role="alert">
          <Icon name="warning" size={15} /> {err}
        </p>
      )}
      <button
        className="primary-action full-action"
        onClick={() => {
          setTried(true)
          if (err) return
          onSave({ ...t, name: t.name.trim() })
          close()
        }}
      >
        {initial ? "Save table" : "Add table"}
      </button>
      {onDelete && (
        <button className="text-action danger" onClick={() => (onDelete(), close())}>
          Delete table
        </button>
      )}
    </div>
  )
}

export function TablesEditor() {
  const v = useVenue()
  const ui = useUI()
  const edit = (t?: VTable) =>
    ui.sheet({
      eyebrow: t ? t.name.toUpperCase() : "NOVA ROOM",
      title: t ? "Edit table" : "Add a table",
      body: (close) => (
        <TableForm
          initial={t}
          close={close}
          onSave={(next) => {
            if (t) v.setTables((l) => l.map((x) => (x.id === t.id ? next : x)))
            else v.setTables((l) => [...l, next])
            ui.toast(t ? `${next.name} updated for guests` : `${next.name} added. It's hidden until you turn it on.`)
          }}
          onDelete={t ? () => (v.setTables((l) => l.filter((x) => x.id !== t.id)), ui.toast(`${t.name} deleted`)) : undefined}
        />
      ),
    })
  return (
    <div className="ve">
      <p className="srv-muted">Each table shows its photos, guest limit, deposit and minimum spend to guests. The deposit counts toward the minimum.</p>
      <div className="srv-list ve-gap">
        {v.tables.map((t) => (
          <div key={t.id} className="srv-req static ve-table">
            {t.photos[0] ? <img src={t.photos[0].src} alt="" /> : <span className="ve-noimg sm">No photo</span>}
            <button className="srv-main ve-open" onClick={() => edit(t)}>
              <strong>{t.name}</strong>
              <small>
                {t.section} · up to {t.capacity} · {t.photos.length} photo{t.photos.length === 1 ? "" : "s"}
                {t.video ? " · video" : ""}
              </small>
              <small>
                ${t.deposit} deposit · ${t.min.toLocaleString()} minimum
              </small>
            </button>
            <Switch on={t.live} label={`${t.name} bookable`} onChange={() => (v.setTables((l) => l.map((x) => (x.id === t.id ? { ...x, live: !x.live } : x))), ui.toast(t.live ? `${t.name} hidden from guests` : t.photos.length ? `${t.name} is bookable` : `${t.name} is bookable. Add a photo so guests know what they're booking.`))} />
          </div>
        ))}
      </div>
      <button className="secondary-action full-action ve-add" onClick={() => edit()}>
        <Icon name="plus" size={16} /> Add a table
      </button>
    </div>
  )
}

/* ---------- Bottles and signs ---------- */

const MIXERS = ["Soda", "Tonic", "Cola", "Cranberry", "Orange juice", "Citrus", "Ice", "Red Bull", "Chilled flutes"]

function BottleForm({ initial, onSave, onDelete, close }: { initial?: Bottle; onSave: (b: Bottle) => void; onDelete?: () => void; close: () => void }) {
  const [b, setB] = useState<Bottle>(initial ?? { id: "b" + Date.now(), name: "", size: "750 ml", price: 0, available: true, mixers: ["Ice"] })
  const [busy, setBusy] = useState(false)
  const [tried, setTried] = useState(false)
  const photo = useRef<HTMLInputElement>(null)
  const err = !b.name.trim() ? "Add the bottle's name." : b.price <= 0 ? "Set a price above $0." : null
  return (
    <div className="form-stack ve-form">
      <div className="ve-bottle-photo">
        {busy ? <span className="mp-thumb mp-loading" aria-label="Uploading" /> : b.photo ? <img src={b.photo} alt="" /> : <span className="ve-noimg">No photo</span>}
        <div>
          <button className="secondary-action" onClick={() => photo.current?.click()}>
            {b.photo ? "Replace photo" : "Add bottle photo"}
          </button>
          {b.photo && (
            <button className="text-action danger" onClick={() => setB({ ...b, photo: undefined })}>
              Remove
            </button>
          )}
        </div>
        <input
          ref={photo}
          type="file"
          accept="image/*"
          hidden
          onChange={async (e) => {
            const f = e.target.files?.[0]
            e.target.value = ""
            if (!f) return
            setBusy(true)
            const src = await readFile(f).catch(() => undefined)
            setBusy(false)
            setB((x) => ({ ...x, photo: src }))
          }}
        />
      </div>
      <label className="field">
        <span>Bottle name</span>
        <input value={b.name} onChange={(e) => setB({ ...b, name: e.target.value })} placeholder="e.g. Hennessy VS" />
      </label>
      <div className="field">
        <span>Size</span>
        <ChoiceChips label="Size" options={["375 ml", "750 ml", "1 L", "1.75 L", "3 L"]} value={b.size} onChange={(size) => setB({ ...b, size })} />
      </div>
      <label className="field">
        <span>Price ($)</span>
        <input type="number" min={0} value={b.price || ""} onChange={(e) => setB({ ...b, price: Math.max(0, parseInt(e.target.value) || 0) })} />
      </label>
      <div className="field">
        <span>Included mixers</span>
        <MultiSelect label="Mixers" options={MIXERS} value={b.mixers} onChange={(mixers) => setB({ ...b, mixers })} />
      </div>
      <div className="ve-row">
        <span>
          <strong>Available</strong>
          <small>Turning this off hides it at checkout and flags it for servers</small>
        </span>
        <Switch on={b.available} label="Available" onChange={() => setB({ ...b, available: !b.available })} />
      </div>
      {tried && err && (
        <p className="srv-error" role="alert">
          <Icon name="warning" size={15} /> {err}
        </p>
      )}
      <button
        className="primary-action full-action"
        disabled={busy}
        onClick={() => {
          setTried(true)
          if (err) return
          onSave({ ...b, name: b.name.trim() })
          close()
        }}
      >
        {initial ? "Save bottle" : "Add bottle"}
      </button>
      {onDelete && (
        <button className="text-action danger" onClick={() => (onDelete(), close())}>
          Remove from menu
        </button>
      )}
    </div>
  )
}

export function MenuEditor() {
  const v = useVenue()
  const ui = useUI()
  const edit = (b?: Bottle) =>
    ui.sheet({
      eyebrow: "BOTTLE MENU",
      title: b ? b.name : "Add a bottle",
      body: (close) => (
        <BottleForm
          initial={b}
          close={close}
          onSave={(next) => {
            if (b) v.setBottles((l) => l.map((x) => (x.id === b.id ? next : x)))
            else v.setBottles((l) => [...l, next])
            ui.toast(b ? `${next.name} updated. New bookings see the change.` : `${next.name} added to the menu`)
          }}
          onDelete={b ? () => (v.setBottles((l) => l.filter((x) => x.id !== b.id)), ui.toast(`${b.name} removed`)) : undefined}
        />
      ),
    })
  return (
    <div className="ve">
      <section className="srv-section">
        <h2>Bottle menu</h2>
        <p className="srv-muted">Guests pre-order these at checkout. Turning a bottle off also flags it for servers tonight.</p>
        <div className="srv-list ve-gap">
          {v.bottles.map((b) => (
            <div key={b.id} className="srv-req static ve-table">
              {b.photo ? <img src={b.photo} alt="" /> : <span className="ve-noimg sm">No photo</span>}
              <button className="srv-main ve-open" onClick={() => edit(b)}>
                <strong>{b.name}</strong>
                <small>
                  {b.size} · ${b.price.toLocaleString()} · {b.mixers.join(", ")}
                </small>
                {!b.available && <small className="ve-off">Unavailable tonight</small>}
              </button>
              <Switch on={b.available} label={`${b.name} available`} onChange={() => (v.setBottles((l) => l.map((x) => (x.id === b.id ? { ...x, available: !x.available } : x))), ui.toast(b.available ? `${b.name} marked unavailable` : `${b.name} back on the menu`))} />
            </div>
          ))}
        </div>
        <button className="secondary-action full-action ve-add" onClick={() => edit()}>
          <Icon name="plus" size={16} /> Add a bottle
        </button>
      </section>
      <section className="srv-section">
        <h2>Bottle signs</h2>
        <p className="srv-muted">Guests can add a message sign to a pre-ordered bottle. You approve each message in Messages → Requests.</p>
        <div className="srv-list ve-gap">
          {v.signs.map((s) => (
            <div key={s.id} className="srv-req static">
              <span className="srv-main">
                <strong>{s.name}</strong>
                <small>+${s.price} per sign</small>
              </span>
              <Switch on={s.on} label={`Offer ${s.name}`} onChange={() => (v.setSigns((l) => l.map((x) => (x.id === s.id ? { ...x, on: !x.on } : x))), ui.toast(s.on ? `${s.name} no longer offered` : `${s.name} offered to guests`))} />
            </div>
          ))}
        </div>
        <label className="field ve-cutoff">
          <span>Guests can change their message until</span>
          <select value={v.cutoff} onChange={(e) => (v.setCutoff(e.target.value), ui.toast(`Change cut-off: ${e.target.value}`))}>
            <option>6 PM on the day</option>
            <option>Noon on the day</option>
            <option>24 hours before</option>
          </select>
        </label>
      </section>
    </div>
  )
}
