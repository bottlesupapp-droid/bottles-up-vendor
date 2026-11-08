import { useRef, useState, type ReactNode } from "react"
import { Icon, Lines, QuickForm, compressImage, useUI, type IconName } from "./kit"
import { useStore } from "./store"
import { CoverFrame } from "./DjStudio"
import { AGES, ChoiceChips, DRESS, EVENT_DATES, EventTimes, GENRES, MultiSelect, TimeSelect, eventLabel } from "./Pickers"
import { DEFAULT_TIERS, RepeatEditor, TicketsEntry, occurrences, type Entry, type Repeat } from "./EventParts"

/* Organizer tools: dashboard, event builder, flyer tool, analytics, opportunities.
   Everything here is private to the organizer and their team. All numbers are demo data. */

export type Ev = { id: string; name: string; date: string; long: string; venue: string; status: string; sold: number; capacity: number; gross: string; art: number; flyer?: string; ticketOnly?: boolean; venueStatus?: string; repeat?: Repeat; series?: string; logo?: string; dateKey?: string; start?: string; end?: string; entry?: Entry; lineup?: string[]; promos?: Promo[] }

/** Honest labels: nothing reads as published or confirmed until it is. */
export const statusLabel = (s: string) => ({ "Pending approval": "Draft", Approved: "Draft", Published: "Live", Draft: "Draft", Cancelled: "Cancelled", Completed: "Completed" })[s] ?? s
const statusTone = (s: string) => ({ Published: "green", Approved: "gray", "Pending approval": "gray", Draft: "gray", Cancelled: "red", Completed: "gray" })[s] ?? "gray"

export function StatusChip({ s }: { s: string }) {
  return <span className={`srv-chip tone-${statusTone(s)}`}>{statusLabel(s)}</span>
}

function Head({ eyebrow, title, action }: { eyebrow: string; title: string; action?: ReactNode }) {
  return (
    <div className="srv-title">
      <div>
        <span>{eyebrow}</span>
        <h1>{title}</h1>
      </div>
      {action}
    </div>
  )
}

/* ---------------- Branded banner ---------------- */

function BannerEditor({ evs, close }: { evs: Ev[]; close: () => void }) {
  const { org, setOrg } = useStore()
  const ui = useUI()
  const [d, setD] = useState({ name: org.name, tagline: org.tagline, coverImg: org.coverImg, coverY: org.coverY ?? 50, coverZoom: org.coverZoom ?? 1, logoImg: org.logoImg, featuredId: org.featuredId ?? evs.find((e) => e.status === "Published")?.id ?? "" })
  const [busy, setBusy] = useState<"" | "cover" | "logo">("")
  const up = async (f: File | undefined, k: "cover" | "logo") => {
    if (!f) return
    setBusy(k)
    try {
      const src = await compressImage(f, k === "logo" ? 400 : 1200)
      setD((x) => (k === "logo" ? { ...x, logoImg: src } : { ...x, coverImg: src, coverY: 50, coverZoom: 1 }))
    } catch {
      ui.toast("Couldn't read that image. Try another.")
    } finally {
      setBusy("")
    }
  }
  const err = !d.name.trim() ? "Add your organization name." : d.tagline.length > 90 ? "Keep the description under 90 characters." : null
  return (
    <div className="form-stack ve-form">
      <CoverFrame src={d.coverImg} y={d.coverY} zoom={d.coverZoom} editable onMove={(coverY) => setD({ ...d, coverY })} fallback="org">
        <span className="bn-logo">{d.logoImg ? <img src={d.logoImg} alt="" /> : <b>{d.name.split(" ").map((x) => x[0]).join("").slice(0, 2)}</b>}</span>
      </CoverFrame>
      {busy && <p className="srv-muted">Uploading…</p>}
      {d.coverImg && (
        <label className="cp-range">
          <span>Zoom</span>
          <input type="range" min={1} max={2} step={0.05} value={d.coverZoom} onChange={(e) => setD({ ...d, coverZoom: Number(e.target.value) })} />
        </label>
      )}
      <div className="bn-uploads">
        <label className="secondary-action">
          {d.coverImg ? "Replace cover" : "Upload cover"}
          <input type="file" accept="image/*" hidden onChange={(e) => (up(e.target.files?.[0], "cover"), (e.target.value = ""))} />
        </label>
        <label className="secondary-action">
          {d.logoImg ? "Replace logo" : "Upload logo"}
          <input type="file" accept="image/*" hidden onChange={(e) => (up(e.target.files?.[0], "logo"), (e.target.value = ""))} />
        </label>
      </div>
      <div className="bn-uploads">
        {d.coverImg && (
          <button className="text-action danger" onClick={() => setD({ ...d, coverImg: undefined })}>
            Remove cover
          </button>
        )}
        {d.logoImg && (
          <button className="text-action danger" onClick={() => setD({ ...d, logoImg: undefined })}>
            Remove logo
          </button>
        )}
      </div>
      <small className="srv-muted bn-help">Cover, logo and event flyers are separate images. Events can use this logo or their own artwork.</small>
      <label className="field">
        <span>Organization name</span>
        <input value={d.name} onChange={(e) => setD({ ...d, name: e.target.value })} />
      </label>
      <label className="field">
        <span>Short description</span>
        <input value={d.tagline} maxLength={100} onChange={(e) => setD({ ...d, tagline: e.target.value })} />
      </label>
      <label className="field">
        <span>Featured event</span>
        <select value={d.featuredId} onChange={(e) => setD({ ...d, featuredId: e.target.value })}>
          <option value="">None</option>
          {evs
            .filter((e) => e.status === "Published")
            .map((e) => (
              <option key={e.id} value={e.id}>
                {e.name} · {e.date}
              </option>
            ))}
        </select>
      </label>
      {err && <p className="srv-error">{err}</p>}
      <button
        className="primary-action full-action"
        disabled={!!err || !!busy}
        onClick={() => {
          setOrg({ ...org, ...d, name: d.name.trim(), tagline: d.tagline.trim() })
          ui.toast("Banner updated")
          close()
        }}
      >
        Save banner
      </button>
    </div>
  )
}

export function Banner({ evs, onEvent }: { evs: Ev[]; onEvent: (id: string) => void }) {
  const { org } = useStore()
  const ui = useUI()
  const featured = evs.find((e) => e.id === (org.featuredId ?? "")) ?? evs.find((e) => e.status === "Published")
  return (
    <section className="bn" aria-label="Organization banner">
      <CoverFrame src={org.coverImg} y={org.coverY ?? 50} zoom={org.coverZoom ?? 1} fallback="org">
        <button className="bn-edit" onClick={() => ui.sheet({ eyebrow: "BRANDING", title: "Edit banner", body: (close) => <BannerEditor evs={evs} close={close} /> })}>
          <Icon name="pencil" size={14} /> Edit banner
        </button>
      </CoverFrame>
      <div className="bn-body">
        <span className="bn-logo">{org.logoImg ? <img src={org.logoImg} alt="" /> : <b>{org.name.split(" ").map((x) => x[0]).join("").slice(0, 2)}</b>}</span>
        <div>
          <h2>{org.name}</h2>
          <p>{org.tagline}</p>
        </div>
      </div>
      {featured && (
        <button className="bn-featured" onClick={() => onEvent(featured.id)}>
          <span className={`ot-thumb art-${featured.art}`} style={featured.flyer ? { backgroundImage: `url(${featured.flyer})` } : undefined} />
          <span className="srv-main">
            <small>FEATURED</small>
            <strong>{featured.name}</strong>
            <small>
              {featured.date} · {featured.venue}
            </small>
          </span>
          <Icon name="chevron" size={16} />
        </button>
      )}
    </section>
  )
}

/* ---------------- Dashboard ---------------- */

export function Dashboard({
  brand,
  evs,
  attention,
  onEvent,
  onNew,
  go,
}: {
  brand: string
  evs: Ev[]
  attention: { icon: IconName; title: string; desc: string; run: () => void }[]
  onEvent: (id: string) => void
  onNew: () => void
  go: (where: "events" | "analytics" | "opps" | "team") => void
}) {
  const live = evs.filter((e) => e.status === "Published")
  const sold = live.reduce((s, e) => s + e.sold, 0)
  return (
    <>
      <Head
        eyebrow={`${brand.toUpperCase()} · PRIVATE`}
        title="Overview"
        action={
          <button className="page-main-action" onClick={onNew}>
            New event
          </button>
        }
      />
      <nav className="ot-access" aria-label="Organizer tools">
        {(
          [
            ["events", "event", "Events"],
            ["analytics", "chart", "Analytics"],
            ["opps", "sparkle", "Opportunities"],
            ["team", "team", "Team"],
          ] as const
        ).map(([id, icon, label]) => (
          <button key={id} onClick={() => go(id)}>
            <Icon name={icon} size={20} />
            {label}
          </button>
        ))}
      </nav>

      <Banner evs={evs} onEvent={onEvent} />

      <section className="srv-section">
        <h2>Upcoming events</h2>
        <div className="srv-list">
          {evs.slice(0, 4).map((e) => (
            <button key={e.id} className="srv-table" onClick={() => onEvent(e.id)}>
              <span className={`ot-thumb art-${e.art}`} style={e.flyer ? { backgroundImage: `url(${e.flyer})` } : undefined} />
              <span className="srv-main">
                <strong>{e.name}</strong>
                <small>
                  {e.date} · {e.venue}
                </small>
                <span className="srv-tags">
                  <StatusChip s={e.status} />
                </span>
              </span>
              <Icon name="chevron" size={16} />
            </button>
          ))}
        </div>
      </section>

      <section className="srv-section">
        <h2>
          Needs attention {attention.length > 0 && <span>{attention.length}</span>}
        </h2>
        {attention.length ? (
          <div className="srv-list">
            {attention.map((a) => (
              <button key={a.title} className="srv-req" onClick={a.run}>
                <span className="row-icon">
                  <Icon name={a.icon} size={18} />
                </span>
                <span className="srv-main">
                  <strong>{a.title}</strong>
                  <small>{a.desc}</small>
                </span>
                <Icon name="chevron" size={16} />
              </button>
            ))}
          </div>
        ) : (
          <p className="srv-muted pad">All clear. Nothing needs you right now.</p>
        )}
      </section>

      <section className="srv-section">
        <h2>Bookings and sales</h2>
        <Lines
          rows={[
            ["Tickets sold", `${sold} across ${live.length} event${live.length === 1 ? "" : "s"} on sale`],
            ["Tables booked", "6 of 10 · Neon Garden"],
            ["Gross sales", "$6,840"],
          ]}
        />
        <button className="text-action ot-more" onClick={() => go("analytics")}>
          See analytics
        </button>
        <p className="srv-muted ot-note">Demo data. Drafts and events awaiting approval don't sell tickets.</p>
      </section>
    </>
  )
}

/* ---------------- Flyer tool ---------------- */

const TEMPLATES = [
  { id: "bold", label: "Bold" },
  { id: "minimal", label: "Minimal" },
  { id: "neon", label: "Neon" },
] as const
type Tpl = (typeof TEMPLATES)[number]["id"]
const TPL_BG: Record<Tpl, [string, string]> = { bold: ["#ff5a2f", "#2a0f0a"], minimal: ["#f2efe9", "#d9d3c7"], neon: ["#14002b", "#ff2d95"] }
const TPL_INK: Record<Tpl, string> = { bold: "#ffffff", minimal: "#141414", neon: "#ffffff" }

export type FlyerState = { tpl: Tpl; image?: string; title: string; line: string; venue: string }

export function FlyerTool({ flyer, setFlyer, onExport }: { flyer: FlyerState; setFlyer: (f: FlyerState) => void; onExport: (dataUrl: string) => void }) {
  const ui = useUI()
  const [advanced, setAdvanced] = useState(false)
  const [align, setAlign] = useState<"left" | "center">("left")
  const [busy, setBusy] = useState(false)
  const file = useRef<HTMLInputElement>(null)
  const upload = (f?: File) => {
    if (!f) return
    if (!f.type.startsWith("image/")) return ui.toast("Choose an image file")
    if (f.size > 8 * 1024 * 1024) return ui.toast("That image is over 8 MB. Try a smaller one.")
    const r = new FileReader()
    r.onload = () => setFlyer({ ...flyer, image: String(r.result) })
    r.onerror = () => ui.toast("We couldn't read that image. Try another.")
    r.readAsDataURL(f)
  }
  const exportPng = async () => {
    setBusy(true)
    try {
      const c = document.createElement("canvas")
      c.width = 1080
      c.height = 1350
      const g = c.getContext("2d")!
      const [a, b] = TPL_BG[flyer.tpl]
      const grad = g.createLinearGradient(0, 0, 1080, 1350)
      grad.addColorStop(0, a)
      grad.addColorStop(1, b)
      g.fillStyle = grad
      g.fillRect(0, 0, 1080, 1350)
      if (flyer.image) {
        const img = new Image()
        await new Promise<void>((res, rej) => {
          img.onload = () => res()
          img.onerror = () => rej(new Error("image"))
          img.src = flyer.image!
        })
        const s = Math.max(1080 / img.width, 1350 / img.height)
        g.drawImage(img, (1080 - img.width * s) / 2, (1350 - img.height * s) / 2, img.width * s, img.height * s)
        g.fillStyle = "rgba(0,0,0,.35)"
        g.fillRect(0, 0, 1080, 1350)
      }
      g.fillStyle = flyer.image ? "#fff" : TPL_INK[flyer.tpl]
      g.textAlign = align
      const x = align === "center" ? 540 : 90
      g.font = "800 112px -apple-system, Inter, sans-serif"
      g.fillText(flyer.title || "Event name", x, flyer.tpl === "neon" ? 260 : 1060)
      g.font = "600 48px -apple-system, Inter, sans-serif"
      g.fillText(flyer.line, x, flyer.tpl === "neon" ? 340 : 1150)
      g.fillText(flyer.venue, x, flyer.tpl === "neon" ? 400 : 1215)
      const url = c.toDataURL("image/png")
      onExport(url)
      try {
        const a = document.createElement("a")
        a.href = url
        a.download = `${(flyer.title || "flyer").replace(/\s+/g, "-").toLowerCase()}.png`
        a.click()
      } catch {
        /* downloads can be blocked in previews; the flyer is still saved to the event */
      }
      ui.toast("Flyer exported and added to the event")
    } catch {
      ui.toast("Export failed. Try a different image.")
    } finally {
      setBusy(false)
    }
  }
  const bg = flyer.image ? { backgroundImage: `linear-gradient(rgba(0,0,0,.35),rgba(0,0,0,.35)), url(${flyer.image})` } : { background: `linear-gradient(160deg, ${TPL_BG[flyer.tpl][0]}, ${TPL_BG[flyer.tpl][1]})` }
  return (
    <div className="ot-flyer">
      <div className={`ot-preview tpl-${flyer.tpl} ${flyer.image ? "has-img" : ""} align-${align}`} style={bg} aria-label="Flyer preview">
        <b>{flyer.title || "Event name"}</b>
        <small>{flyer.line}</small>
        <small>{flyer.venue}</small>
      </div>
      <div className="ot-templates" role="radiogroup" aria-label="Template">
        {TEMPLATES.map((t) => (
          <button key={t.id} role="radio" aria-checked={flyer.tpl === t.id} className={flyer.tpl === t.id ? "on" : ""} onClick={() => setFlyer({ ...flyer, tpl: t.id })}>
            <i style={{ background: `linear-gradient(160deg, ${TPL_BG[t.id][0]}, ${TPL_BG[t.id][1]})` }} />
            {t.label}
          </button>
        ))}
      </div>
      <div className="ot-row">
        <button className="secondary-action" onClick={() => file.current?.click()}>
          <Icon name="plus" size={16} /> {flyer.image ? "Replace artwork" : "Upload artwork"}
        </button>
        {flyer.image && (
          <button className="secondary-action" onClick={() => setFlyer({ ...flyer, image: undefined })}>
            Remove
          </button>
        )}
        <input ref={file} type="file" accept="image/*" hidden onChange={(e) => upload(e.target.files?.[0])} />
      </div>
      <label className="field">
        <span>Flyer title</span>
        <input value={flyer.title} maxLength={28} onChange={(e) => setFlyer({ ...flyer, title: e.target.value })} />
      </label>
      <label className="field">
        <span>Date and time line</span>
        <input value={flyer.line} maxLength={40} onChange={(e) => setFlyer({ ...flyer, line: e.target.value })} />
      </label>
      <label className="field">
        <span>Venue line</span>
        <input value={flyer.venue} maxLength={40} onChange={(e) => setFlyer({ ...flyer, venue: e.target.value })} />
      </label>
      <button className="text-action" onClick={() => setAdvanced(!advanced)} aria-expanded={advanced}>
        {advanced ? "Hide advanced options" : "Advanced options"}
      </button>
      {advanced && (
        <div className="ot-row">
          {(["left", "center"] as const).map((a) => (
            <button key={a} className={`secondary-action ${align === a ? "ot-on" : ""}`} aria-pressed={align === a} onClick={() => setAlign(a)}>
              Align {a}
            </button>
          ))}
        </div>
      )}
      <button className="primary-action full-action" disabled={busy} onClick={exportPng}>
        {busy ? "Exporting…" : "Export flyer"}
      </button>
    </div>
  )
}

/* ---------------- Event builder ---------------- */

const STEPS = ["Details", "Venue", "Media", "Tickets & entry", "Promo codes", "Lineup", "Publish"] as const

export type Promo = { id: string; code: string; type: "percent" | "amount"; value: number; tiers: string[]; from: string; to: string; limit: number; used: number; on: boolean }
const TIERS = ["General admission", "Early bird", "VIP ticket", "Table deposit"]
const TIER_PRICE: Record<string, number> = { "General admission": 35, "Early bird": 25, "VIP ticket": 80, "Table deposit": 150 }
export const SAMPLE_PROMOS: Promo[] = [{ id: "p1", code: "GARDEN10", type: "percent", value: 10, tiers: ["General admission", "Early bird"], from: "2024-08-24", to: "2024-09-14", limit: 100, used: 37, on: true }]

const LISTED = [
  { name: "Nova Room", note: "Agreement needed for each event" },
  { name: "Sky Room", note: "Agreement needed for each event" },
]

type Draft = {
  name: string
  desc: string
  dateKey: string
  start: string
  end: string
  age: string
  music: string[]
  lastEntry: string
  dress: string
  refunds: string
  venueMode: "listed" | "unlisted" | null
  venue: string
  ext: { name: string; address: string; city: string; notes: string }
  entry: Entry
  partner: boolean
  repeat: Repeat
  logoMode: "org" | "custom"
  logoImg?: string
  lineup: string[]
  promos: Promo[]
}

export function promoCheck(p: Promo, all: Promo[]) {
  if (!/^[A-Z0-9]{4,16}$/.test(p.code)) return "Codes are 4–16 letters or numbers, no spaces."
  if (all.some((x) => x.id !== p.id && x.code === p.code)) return "That code already exists for this event."
  if (p.value <= 0) return "Enter a discount above zero."
  if (p.type === "percent" && p.value > 90) return "Percentage discounts can be up to 90%."
  if (!p.tiers.length) return "Choose at least one ticket type."
  if (p.to < p.from) return "The end date is before the start date."
  if (p.limit < 1) return "Set a usage limit of at least 1."
  return null
}

export function PromoForm({ initial, all, onSave, close, tablesAllowed }: { initial?: Promo; all: Promo[]; onSave: (p: Promo) => void; close: () => void; tablesAllowed: boolean }) {
  const [p, setP] = useState<Promo>(initial ?? { id: "p" + Date.now(), code: "", type: "percent", value: 10, tiers: ["General admission"], from: EVENT_DATES[0].key, to: EVENT_DATES[20].key, limit: 50, used: 0, on: true })
  const [tried, setTried] = useState(false)
  const err = promoCheck(p, all)
  const tiers = TIERS.filter((t) => tablesAllowed || t !== "Table deposit")
  const example = p.tiers[0] ?? "General admission"
  const base = TIER_PRICE[example]
  const after = Math.max(0, p.type === "percent" ? base * (1 - p.value / 100) : base - p.value)
  return (
    <div className="form-stack ve-form">
      <label className="field">
        <span>Code</span>
        <input value={p.code} maxLength={16} onChange={(e) => setP({ ...p, code: e.target.value.toUpperCase().replace(/\s/g, "") })} placeholder="e.g. GARDEN10" aria-invalid={!!(tried && err)} />
      </label>
      <div className="field">
        <span>Discount</span>
        <div className="cp-chips">
          {(["percent", "amount"] as const).map((t) => (
            <button key={t} type="button" aria-pressed={p.type === t} className={p.type === t ? "on" : ""} onClick={() => setP({ ...p, type: t })}>
              {t === "percent" ? "Percentage" : "Fixed amount"}
            </button>
          ))}
        </div>
        <input type="number" min={1} value={p.value || ""} onChange={(e) => setP({ ...p, value: Math.max(0, parseFloat(e.target.value) || 0) })} aria-label={p.type === "percent" ? "Percent off" : "Dollars off"} />
      </div>
      <div className="field">
        <span>Works on</span>
        <div className="cp-chips">
          {tiers.map((t) => (
            <button key={t} type="button" aria-pressed={p.tiers.includes(t)} className={p.tiers.includes(t) ? "on" : ""} onClick={() => setP({ ...p, tiers: p.tiers.includes(t) ? p.tiers.filter((x) => x !== t) : [...p.tiers, t] })}>
              {t}
            </button>
          ))}
        </div>
      </div>
      <div className="form-row">
        <label className="field">
          <span>Valid from</span>
          <select value={p.from} onChange={(e) => setP({ ...p, from: e.target.value })}>
            {EVENT_DATES.map((d) => (
              <option key={d.key} value={d.key}>
                {d.label}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Until</span>
          <select value={p.to} onChange={(e) => setP({ ...p, to: e.target.value })}>
            {EVENT_DATES.map((d) => (
              <option key={d.key} value={d.key}>
                {d.label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="field">
        <span>Total uses allowed</span>
        <input type="number" min={1} value={p.limit || ""} onChange={(e) => setP({ ...p, limit: Math.max(0, parseInt(e.target.value) || 0) })} />
      </label>
      <div className="promo-preview" aria-live="polite">
        <span>Preview</span>
        <b>
          {example}: <s>${base.toFixed(2)}</s> → ${after.toFixed(2)}
        </b>
        <small>One code per order. Codes can't be combined with each other. Ambassador commission is paid separately and isn't affected.</small>
      </div>
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
          onSave(p)
          close()
        }}
      >
        {initial ? "Save code" : "Create code"}
      </button>
    </div>
  )
}

export function PromoList({ promos, setPromos, tablesAllowed }: { promos: Promo[]; setPromos: (p: Promo[]) => void; tablesAllowed: boolean }) {
  const ui = useUI()
  const edit = (p?: Promo) =>
    ui.sheet({
      eyebrow: "PROMO CODE",
      title: p ? p.code : "New promo code",
      body: (close) => <PromoForm initial={p} all={promos} tablesAllowed={tablesAllowed} close={close} onSave={(n) => (setPromos(p ? promos.map((x) => (x.id === p.id ? n : x)) : [...promos, n]), ui.toast(p ? `${n.code} updated` : `${n.code} created`))} />,
    })
  return (
    <div className="promo-list">
      {promos.length === 0 ? (
        <p className="srv-muted pad">No promo codes yet.</p>
      ) : (
        <div className="srv-list">
          {promos.map((p) => (
            <div key={p.id} className="srv-req static">
              <button className="srv-main ve-open" onClick={() => edit(p)}>
                <strong className="promo-code">{p.code}</strong>
                <small>
                  {p.type === "percent" ? `${p.value}% off` : `$${p.value} off`} · {p.tiers.join(", ")}
                </small>
                <small>
                  {eventLabel(p.from)} – {eventLabel(p.to)} · {p.used}/{p.limit} used
                </small>
              </button>
              <label className="dj-avail ve-switch">
                <input type="checkbox" role="switch" aria-label={`${p.code} enabled`} checked={p.on} onChange={() => (setPromos(promos.map((x) => (x.id === p.id ? { ...x, on: !x.on } : x))), ui.toast(p.on ? `${p.code} turned off` : `${p.code} turned on`))} />
                <i />
              </label>
            </div>
          ))}
        </div>
      )}
      <button className="secondary-action full-action ve-add" onClick={() => edit()}>
        <Icon name="plus" size={16} /> Create a promo code
      </button>
      <p className="srv-muted">Promo codes lower what guests pay. They're separate from ambassador commissions and referral rewards.</p>
    </div>
  )
}

export function EventBuilder({ event, onBack, onSave, venueLocked, orgLogo, orgName = "Midnight Social" }: { event: Ev | null; onBack: () => void; onSave: (e: Ev, submit: boolean) => void; venueLocked?: string; orgLogo?: string; orgName?: string }) {
  const ui = useUI()
  const [step, setStep] = useState(0)
  const published = event?.status === "Published"
  const [d, setD] = useState<Draft>({
    name: event?.name ?? "",
    desc: event ? "An immersive late-night garden of house, disco and live visuals." : "",
    dateKey: event?.dateKey ?? EVENT_DATES[7].key,
    start: event?.start ?? "10:00 PM",
    end: event?.end ?? "3:00 AM",
    age: "19+",
    music: ["House", "Disco"],
    lastEntry: "1:30 AM",
    dress: "Smart evening wear",
    refunds: "Up to 48 hours before doors",
    venueMode: venueLocked ? "listed" : event ? (event.ticketOnly ? "unlisted" : "listed") : null,
    venue: venueLocked ?? (event && !event.ticketOnly && event.venue !== "Venue needed" ? event.venue : "Nova Room"),
    ext: { name: event?.ticketOnly ? event.venue : "", address: "", city: "Toronto", notes: "" },
    entry: event?.entry ?? { tiers: DEFAULT_TIERS, guestList: { on: true, cap: 60, cutoff: "11:30 PM" }, tables: !event?.ticketOnly, deposit: 150, minSpend: 1000, bottles: !event?.ticketOnly },
    partner: !!venueLocked || event?.venueStatus === "Confirmed" || event?.venueStatus === "Partnership requested",
    repeat: event?.repeat ?? { mode: "once", days: [], every: 1, until: "" },
    logoMode: event?.logo && event.logo !== "org" ? "custom" : "org",
    logoImg: event?.logo && event.logo !== "org" ? event.logo : undefined,
    lineup: event?.lineup ?? (event?.id === "ng" ? ["Amara Vale"] : ["EONICS"]),
    promos: event?.promos ?? (event?.id === "ng" ? SAMPLE_PROMOS : []),
  })
  const [artist, setArtist] = useState("")
  const [flyer, setFlyer] = useState<FlyerState>({ tpl: "bold", title: event?.name ?? "", line: event?.date ? `${event.date} · 10 PM` : "", venue: event?.venue && event.venue !== "Venue needed" ? event.venue : "" })
  const [flyerUrl, setFlyerUrl] = useState(event?.flyer)
  const [tried, setTried] = useState(false)
  const set = (p: Partial<Draft>) => setD((x) => ({ ...x, ...p }))
  const status = event?.status ?? "Draft"
  const unlisted = d.venueMode === "unlisted"
  // Until a venue option is picked, show it as missing rather than the default.
  const venueName = !d.venueMode ? "" : unlisted ? d.ext.name.trim() : d.venue
  // Ticket sales must close by the event (the last date, for a series).
  const lastDate = occurrences(d.dateKey, d.repeat).slice(-1)[0]?.key ?? d.dateKey
  const missing = [!d.name.trim() && "Event name", !d.venueMode && "Venue", unlisted && !d.ext.name.trim() && "Venue name", unlisted && !d.ext.address.trim() && "Venue address", !d.entry.tiers.length && !d.entry.guestList.on && "Tickets, RSVP or a guest list", d.repeat.mode === "custom" && !d.repeat.days.length && "Repeat days", d.entry.tiers.some((t) => t.saleTo > lastDate || (t.increase && t.increase.on > lastDate)) && "ticket sales that close by the event date (Tickets & entry)"].filter(Boolean) as string[]
  const tablesAllowed = !unlisted && (d.partner || !!venueLocked)
  const venueStatus = unlisted ? "Not on BottlesUp" : venueLocked ? "Your venue" : d.partner ? (event?.venueStatus === "Confirmed" ? "Confirmed" : "Partnership requested") : "Tickets only"
  const build = (s: string): Ev => ({
    id: event?.id ?? "e" + Date.now(),
    name: d.name.trim() || "Untitled event",
    date: eventLabel(d.dateKey),
    long: `${eventLabel(d.dateKey)} · ${d.start} – ${d.end}`,
    venue: venueName || "Venue needed",
    status: s,
    sold: event?.sold ?? 0,
    capacity: Math.max(1, d.entry.tiers.reduce((n, t) => n + t.qty, 0) + (d.entry.guestList.on ? d.entry.guestList.cap : 0)),
    gross: event?.gross ?? "$0",
    art: event?.art ?? 2,
    flyer: flyerUrl,
    ticketOnly: unlisted || !tablesAllowed,
    venueStatus,
    repeat: d.repeat,
    dateKey: d.dateKey,
    start: d.start,
    end: d.end,
    series: d.repeat.mode !== "once" ? event?.series ?? "s" + Date.now() : undefined,
    logo: d.logoMode === "org" ? "org" : d.logoImg,
    entry: d.entry,
    lineup: d.lineup,
    promos: d.promos,
  })
  const saveDraft = () => {
    if (published) return confirmPublishedChange()
    onSave(build("Draft"), false)
    ui.toast("Saved as draft. Guests can't see it yet.")
  }
  const confirmPublishedChange = () =>
    ui.sheet({
      eyebrow: "EVENT IS ON SALE",
      title: "Update for ticket holders?",
      body: (close) => (
        <div className="srv-sheet">
          <p className="srv-muted">
            {event?.sold ?? 0} people already have tickets. Changes to the date, time, venue or lineup are sent to them by notification and email. If the date, time or venue changes, they can ask for a full refund within 7 days.
          </p>
          <Lines
            rows={[
              ["When", `${eventLabel(d.dateKey)} · ${d.start} – ${d.end}`],
              ["Venue", venueName],
              ["Lineup", d.lineup.join(", ")],
            ]}
          />
          <button
            className="primary-action full-action"
            onClick={() => {
              onSave(build("Published"), false)
              ui.toast(`Saved. ${event?.sold ?? 0} ticket holders notified.`)
              close()
            }}
          >
            Save and notify ticket holders
          </button>
          <button className="secondary-action full-action" onClick={close}>
            Keep editing
          </button>
        </div>
      ),
    })
  const submit = () => {
    setTried(true)
    if (missing.length) return
    onSave(build("Published"), true)
    ui.toast(d.repeat.mode !== "once" ? `Published. ${occurrences(d.dateKey, d.repeat).length} dates are live.` : "Published. Your event is live.")
    onBack()
  }
  return (
    <>
      <button className="srv-back" onClick={onBack}>
        <Icon name="back" size={18} /> Events
      </button>
      <Head eyebrow={`${event ? "EDIT EVENT" : "NEW EVENT"} · ${statusLabel(status).toUpperCase()}`} title={d.name || "New event"} />
      <div className="ot-steps" role="tablist" aria-label="Steps">
        {STEPS.map((s, i) => (
          <button key={s} role="tab" aria-selected={step === i} className={step === i ? "on" : ""} onClick={() => setStep(i)}>
            <i>{i + 1}</i>
            {s}
          </button>
        ))}
      </div>

      <div className="form-stack ot-step">
        {step === 0 && (
          <>
            <label className="field">
              <span>Event name</span>
              <input value={d.name} onChange={(e) => (set({ name: e.target.value }), setFlyer({ ...flyer, title: e.target.value }))} placeholder="e.g. Neon Garden" />
            </label>
            <label className="field">
              <span>Short description</span>
              <textarea value={d.desc} maxLength={280} onChange={(e) => set({ desc: e.target.value })} placeholder="What makes this night special?" />
            </label>
            <EventTimes date={d.dateKey} start={d.start} end={d.end} onChange={(p) => set({ ...(p.date ? { dateKey: p.date } : {}), ...(p.start ? { start: p.start } : {}), ...(p.end ? { end: p.end } : {}) })} />
            <RepeatEditor value={d.repeat} startKey={d.dateKey} onChange={(repeat) => set({ repeat })} />
            <div className="field">
              <span>Music</span>
              <MultiSelect label="Genres" options={GENRES} value={d.music} onChange={(music) => set({ music })} />
            </div>
            <div className="field">
              <span>Age</span>
              <ChoiceChips label="Age" options={AGES} value={d.age} onChange={(age) => set({ age })} allowCustom={false} />
            </div>
            <div className="field">
              <span>Dress code</span>
              <ChoiceChips label="Dress code" options={DRESS} value={d.dress} onChange={(dress) => set({ dress })} />
            </div>
            <div className="form-row">
              <label className="field">
                <span>Last entry</span>
                <TimeSelect label="Last entry" value={d.lastEntry} onChange={(lastEntry) => set({ lastEntry })} />
              </label>
              <label className="field">
                <span>Refunds</span>
                <select value={d.refunds} onChange={(e) => set({ refunds: e.target.value })}>
                  <option>Up to 48 hours before doors</option>
                  <option>Up to 7 days before</option>
                  <option>No refunds</option>
                </select>
              </label>
            </div>
          </>
        )}
        {step === 1 && venueLocked && (
          <div className="vm-locked">
            <Icon name="venue" size={20} />
            <span>
              <b>{venueLocked}</b>
              <small>Your venue. Tables, bottle menu, staff and guest lists come from your venue setup. No approval needed.</small>
            </span>
          </div>
        )}
        {step === 1 && !venueLocked && (
          <>
            <div className="vm-choices" role="radiogroup" aria-label="Venue type">
              <button role="radio" aria-checked={d.venueMode === "listed"} className={d.venueMode === "listed" ? "on" : ""} onClick={() => set({ venueMode: "listed" })}>
                <Icon name="venue" size={20} />
                <span>
                  <b>Choose a BottlesUp venue</b>
                  <small>Tickets, tables and bottles. The venue must approve your event.</small>
                </span>
              </button>
              <button role="radio" aria-checked={d.venueMode === "unlisted"} className={d.venueMode === "unlisted" ? "on" : ""} onClick={() => set({ venueMode: "unlisted", partner: false })}>
                <Icon name="map" size={20} />
                <span>
                  <b>Venue not listed</b>
                  <small>Ticket-only event at a venue that isn't on BottlesUp.</small>
                </span>
              </button>
            </div>
            {d.venueMode === "listed" && (
              <>
                <label className="field">
                  <span>Venue</span>
                  <select value={d.venue} onChange={(e) => set({ venue: e.target.value })}>
                    {LISTED.map((v) => (
                      <option key={v.name}>{v.name}</option>
                    ))}
                  </select>
                </label>
                <label className="srv-toggle">
                  <span>
                    <strong>Request a partnership with {d.venue}</strong>
                    <small>Needed for tables and bottles through BottlesUp. Your event can be published before the venue replies.</small>
                  </span>
                  <input type="checkbox" checked={d.partner} onChange={(e) => set({ partner: e.target.checked })} />
                </label>
                <p className="srv-muted">{d.partner ? `${d.venue} will see your request. Partnership status is shown separately from your event's status.` : "Without a partnership, the event is tickets-only."}</p>
              </>
            )}
            {unlisted && (
              <>
                <label className="field">
                  <span>Venue name</span>
                  <input value={d.ext.name} onChange={(e) => set({ ext: { ...d.ext, name: e.target.value } })} placeholder="e.g. The Warehouse" />
                </label>
                <label className="field">
                  <span>Address</span>
                  <input value={d.ext.address} onChange={(e) => set({ ext: { ...d.ext, address: e.target.value } })} placeholder="Street and number" />
                </label>
                <div className="field">
                  <span>City</span>
                  <ChoiceChips label="City" options={["Toronto", "Montreal", "Vancouver"]} value={d.ext.city} onChange={(city) => set({ ext: { ...d.ext, city } })} />
                </div>
                <label className="field">
                  <span>Entry notes (optional)</span>
                  <input value={d.ext.notes} onChange={(e) => set({ ext: { ...d.ext, notes: e.target.value } })} placeholder="e.g. Side door on Queen St" />
                </label>
                <div className="srv-notice vm-warn">
                  <Icon name="warning" size={15} />
                  <span>
                    <b>Ticket-only event.</b> {d.ext.name || "This venue"} isn't a BottlesUp partner, so guests can't book tables or buy bottles through BottlesUp. You can publish right away. Guests will see:
                    <em className="vm-quote">“For table or bottle enquiries, contact the event organiser.” → Message {orgName}</em>
                    {/nova room|sky room/i.test(d.ext.name) && <small>This is a manual location. It won't link to or claim the {d.ext.name} venue on BottlesUp.</small>}
                  </span>
                </div>
              </>
            )}
            {tried && !d.venueMode && <p className="srv-error">Choose where the event is happening.</p>}
          </>
        )}
        {step === 2 && (
          <>
            <div className="field">
              <span>Event logo</span>
              <div className="cp-chips">
                <button aria-pressed={d.logoMode === "org"} className={d.logoMode === "org" ? "on" : ""} onClick={() => set({ logoMode: "org" })}>
                  Use organization logo
                </button>
                <button aria-pressed={d.logoMode === "custom"} className={d.logoMode === "custom" ? "on" : ""} onClick={() => set({ logoMode: "custom" })}>
                  Different artwork
                </button>
              </div>
              <div className="ev-logo-row">
                <span className="ev-logo">{d.logoMode === "org" ? orgLogo ? <img src={orgLogo} alt="" /> : <b>{orgName.split(" ").map((x) => x[0]).join("").slice(0, 2)}</b> : d.logoImg ? <img src={d.logoImg} alt="" /> : <Icon name="camera" size={18} />}</span>
                {d.logoMode === "custom" && (
                  <label className="secondary-action ev-logo-up">
                    {d.logoImg ? "Replace artwork" : "Upload artwork"}
                    <input type="file" accept="image/*" hidden onChange={async (e) => { const f = e.target.files?.[0]; e.target.value = ""; if (f) set({ logoImg: await compressImage(f, 400) }) }} />
                  </label>
                )}
                <small className="srv-muted">{d.logoMode === "org" ? "Changes to your organization logo update here too." : "Only this event uses it."}</small>
              </div>
            </div>
            <div className="field">
              <span>Flyer</span>
              <FlyerTool flyer={flyer} setFlyer={setFlyer} onExport={setFlyerUrl} />
            </div>
          </>
        )}
        {step === 3 && <TicketsEntry eventDate={lastDate} value={d.entry} onChange={(entry) => set({ entry })} tablesAllowed={tablesAllowed} tablesNote={unlisted ? "Tables aren't available at venues outside BottlesUp." : "Request a partnership with the venue (Venue step) to offer tables."} />}
        {step === 4 && <PromoList promos={d.promos} setPromos={(promos) => set({ promos })} tablesAllowed={tablesAllowed && d.entry.tables} />}
        {step === 5 && (
          <>
            <div className="srv-list">
              {d.lineup.map((a) => (
                <div key={a} className="srv-req static">
                  <span className="srv-avatar">{a.slice(0, 2).toUpperCase()}</span>
                  <span className="srv-main">
                    <strong>{a}</strong>
                    <small>Shown as “Invited” until the artist confirms</small>
                  </span>
                  <button className="text-action danger" onClick={() => set({ lineup: d.lineup.filter((x) => x !== a) })}>
                    Remove
                  </button>
                </div>
              ))}
            </div>
            <form
              noValidate
              className="ot-row"
              onSubmit={(e) => {
                e.preventDefault()
                if (!artist.trim() || d.lineup.includes(artist.trim())) return
                set({ lineup: [...d.lineup, artist.trim()] })
                setArtist("")
              }}
            >
              <input className="ot-input" value={artist} onChange={(e) => setArtist(e.target.value)} placeholder="Add an artist" aria-label="Artist name" />
              <button className="secondary-action" type="submit">
                Add
              </button>
            </form>
          </>
        )}
        {step === 6 && (
          <>
            <div className="pub-status">
              <div>
                <small>Event</small>
                <StatusChip s={status} />
              </div>
              {!unlisted && d.partner && !venueLocked && (
                <div>
                  <small>Venue partnership</small>
                  <span className={`srv-chip tone-${venueStatus === "Confirmed" ? "green" : "amber"}`}>{venueStatus}</span>
                </div>
              )}
            </div>
            <Lines
              rows={[
                ["Name", d.name || "Missing"],
                ["When", `${eventLabel(d.dateKey)} · ${d.start} – ${d.end}`],
                ["Repeats", d.repeat.mode === "once" ? "One time" : `${d.repeat.mode === "weekly" ? "Weekly" : d.repeat.days.join(", ")}${d.repeat.every > 1 ? ", every 2 weeks" : ""}${d.repeat.until ? ` until ${eventLabel(d.repeat.until)}` : ""}`],
                ["Venue", venueName || "Missing"],
                ["Tickets", d.entry.tiers.length ? d.entry.tiers.map((t) => `${t.name} ${t.kind === "Free RSVP" ? "(free)" : `$${t.price}`}`).join(", ") : "None"],
                ["Guest list", d.entry.guestList.on ? `${d.entry.guestList.cap} spots until ${d.entry.guestList.cutoff}` : "Off"],
                ["Tables", tablesAllowed && d.entry.tables ? `$${d.entry.deposit} deposit · $${d.entry.minSpend} minimum` : "Not offered"],
                ["Promo codes", d.promos.length ? d.promos.map((p) => p.code).join(", ") : "None"],
                ["Lineup", d.lineup.join(", ") || "None"],
              ]}
            />
            {tried && missing.length > 0 && (
              <p className="srv-error" role="alert">
                Add {missing.join(", ").toLowerCase()} before publishing.
              </p>
            )}
            <p className="srv-muted">Publishing makes the event live straight away.{!unlisted && d.partner && !venueLocked ? " Tables and bottles switch on when the venue accepts your partnership." : ""}</p>
            {!published && (
              <button className="primary-action full-action" onClick={submit}>
                Publish event
              </button>
            )}
          </>
        )}
      </div>

      <div className="srv-actions">
        <button className="secondary-action" onClick={saveDraft}>
          {published ? "Save changes" : "Save draft"}
        </button>
        {step < STEPS.length - 1 && (
          <button className="primary-action" onClick={() => setStep(step + 1)}>
            Next: {STEPS[step + 1]}
          </button>
        )}
      </div>
    </>
  )
}

/* ---------------- Analytics ---------------- */

type Series = { views: number[]; sales: number[] }
const DATA: Record<string, { series: Record<string, Series>; tickets: number; tables: number; checkout: number; views: number; referral: number; engagement: number; gross: number; refunds: number; fees: number; paidOut: number }> = {
  ng: {
    series: {
      "7 days": { views: [420, 380, 510, 620, 700, 940, 1120], sales: [8, 6, 11, 14, 17, 22, 31] },
      "30 days": { views: [1800, 2300, 2900, 4690], sales: [22, 31, 44, 87] },
    },
    tickets: 184,
    tables: 6,
    checkout: 412,
    views: 9800,
    referral: 1420,
    engagement: 7.4,
    gross: 6840,
    refunds: 210,
    fees: 547,
    paidOut: 0,
  },
}

function Bars({ values, labels, unit }: { values: number[]; labels: string[]; unit: string }) {
  const max = Math.max(...values, 1)
  return (
    <div className="ot-bars" role="img" aria-label={labels.map((l, i) => `${l}: ${values[i]} ${unit}`).join(", ")}>
      {values.map((v, i) => (
        <span key={i}>
          <em>{v}</em>
          <i style={{ height: Math.max(4, Math.round((v / max) * 104)) }} />
          <small>{labels[i]}</small>
        </span>
      ))}
    </div>
  )
}

export function Analytics({ evs }: { evs: Ev[] }) {
  const [id, setId] = useState(evs[0]?.id ?? "")
  const [range, setRange] = useState<"7 days" | "30 days">("7 days")
  const ev = evs.find((e) => e.id === id)
  const data = DATA[id]
  const s = data?.series[range]
  const labels = range === "7 days" ? ["M", "T", "W", "T", "F", "S", "S"] : ["Wk 1", "Wk 2", "Wk 3", "Wk 4"]
  const money = (n: number) => "$" + n.toLocaleString("en-CA")
  return (
    <>
      <Head eyebrow="PRIVATE · OWNER AND TEAM ONLY" title="Analytics" />
      <div className="ot-filters">
        <label className="field">
          <span>Event</span>
          <select value={id} onChange={(e) => setId(e.target.value)}>
            {evs.map((e) => (
              <option key={e.id} value={e.id}>
                {e.name} · {statusLabel(e.status)}
              </option>
            ))}
          </select>
        </label>
        <div className="srv-filters" role="tablist" aria-label="Date range">
          {(["7 days", "30 days"] as const).map((r) => (
            <button key={r} role="tab" aria-selected={range === r} className={range === r ? "on" : ""} onClick={() => setRange(r)}>
              {r}
            </button>
          ))}
        </div>
      </div>
      {!data || !s ? (
        <div className="state-block">
          <Icon name="chart" size={26} />
          <h2>No data yet</h2>
          <p>{ev && ev.status !== "Published" ? `${ev.name} is ${statusLabel(ev.status).toLowerCase()}, so it has no views or sales yet.` : "Data appears once the event is on sale."}</p>
        </div>
      ) : (
        <>
          <section className="srv-section">
            <h2>Ticket sales</h2>
            <div className="ot-card">
              <Bars values={s.sales} labels={labels} unit="tickets" />
              <p className="srv-muted">Sales picked up after the lineup post. Saturdays sell best.</p>
            </div>
          </section>
          <section className="srv-section">
            <h2>From views to bookings</h2>
            <div className="ot-card ot-funnel">
              {[
                ["Event views", data.views],
                ["Started checkout", data.checkout],
                ["Booked", data.tickets + data.tables],
              ].map(([k, v]) => (
                <div key={k as string}>
                  <span>
                    {k}
                    <b>{(v as number).toLocaleString("en-CA")}</b>
                  </span>
                  <i style={{ width: `${Math.max(3, ((v as number) / data.views) * 100)}%` }} />
                </div>
              ))}
              <p className="srv-muted">
                {(((data.tickets + data.tables) / data.views) * 100).toFixed(1)}% of viewers booked. {data.tickets} tickets and {data.tables} tables. Referral links brought {money(data.referral)} in sales. Engagement rate {data.engagement}%.
              </p>
            </div>
          </section>
          <section className="srv-section">
            <h2>Money</h2>
            <Lines
              rows={[
                ["Gross sales", money(data.gross)],
                ["Refunds", "− " + money(data.refunds)],
                ["Platform fees", "− " + money(data.fees)],
                ["Net earnings", money(data.gross - data.refunds - data.fees)],
              ]}
            />
            <div className="ot-payouts">
              <div>
                <span className="srv-chip tone-amber">Pending</span>
                <b>{money(data.gross - data.refunds - data.fees - data.paidOut)}</b>
                <small>Released 5 business days after the event</small>
              </div>
              <div>
                <span className="srv-chip tone-green">Available</span>
                <b>{money(data.paidOut)}</b>
                <small>Nothing to withdraw yet</small>
              </div>
            </div>
            <p className="srv-muted ot-note">Demo data. Financial analytics are never shown on your public profile.</p>
          </section>
        </>
      )}
    </>
  )
}

/* ---------------- Opportunities ---------------- */

type Opp = { id: string; role: string; event: string; date: string; pay: string; open: boolean; applicants: { name: string; note: string; status: "New" | "Shortlisted" | "Declined" }[] }

export function Opportunities({ onBack }: { onBack: () => void }) {
  const ui = useUI()
  const [opps, setOpps] = useState<Opp[]>([
    { id: "o1", role: "Photographer", event: "Neon Garden", date: "Sat, 31 Aug", pay: "$250 flat", open: true, applicants: [{ name: "Priya Shah", note: "Shot 30+ club nights. Portfolio on Instagram.", status: "New" }, { name: "Leo Park", note: "Film and digital. Fast turnaround.", status: "New" }] },
    { id: "o2", role: "Warm-up DJ", event: "Rooftop Frequencies", date: "Fri, 6 Sep", pay: "$400", open: true, applicants: [{ name: "KAIRO", note: "Afro house, 2 h warm-up sets.", status: "Shortlisted" }] },
    { id: "o3", role: "Ambassador", event: "Neon Garden", date: "Aug 20 – Aug 31", pay: "10% of referred sales", open: false, applicants: [] },
  ])
  const setApplicant = (oid: string, name: string, status: Opp["applicants"][number]["status"]) =>
    setOpps((l) => l.map((o) => (o.id === oid ? { ...o, applicants: o.applicants.map((a) => (a.name === name ? { ...a, status } : a)) } : o)))
  const view = (o: Opp) =>
    ui.sheet({
      eyebrow: `PRIVATE · ${o.event.toUpperCase()}`,
      title: `${o.role} applicants`,
      body: () => <Applicants id={o.id} />,
    })
  function Applicants({ id }: { id: string }) {
    const o = opps.find((x) => x.id === id)!
    if (!o.applicants.length) return <p className="srv-muted">No applications yet.</p>
    return (
      <div className="srv-list">
        {o.applicants.map((a) => (
          <div key={a.name} className="srv-req static ot-app">
            <span className="srv-main">
              <strong>{a.name}</strong>
              <small>{a.note}</small>
              <span className={`srv-chip tone-${a.status === "Shortlisted" ? "green" : a.status === "Declined" ? "red" : "gray"}`}>{a.status}</span>
            </span>
            {a.status === "New" && (
              <span className="ot-app-actions">
                <button className="text-action" onClick={() => (setApplicant(o.id, a.name, "Shortlisted"), ui.toast(`${a.name} shortlisted`), ui.close())}>
                  Shortlist
                </button>
                <button className="text-action danger" onClick={() => (setApplicant(o.id, a.name, "Declined"), ui.toast(`${a.name} declined`), ui.close())}>
                  Decline
                </button>
              </span>
            )}
          </div>
        ))}
      </div>
    )
  }
  return (
    <>
      <button className="srv-back" onClick={onBack}>
        <Icon name="back" size={18} /> Back
      </button>
      <Head
        eyebrow="SHOWN ON YOUR PUBLIC PROFILE"
        title="Opportunities"
        action={
          <button
            className="page-main-action"
            onClick={() =>
              ui.sheet({
                eyebrow: "NEW OPPORTUNITY",
                title: "Post a role",
                body: (close) => (
                  <QuickForm
                    submit="Post role"
                    fields={[
                      { id: "role", label: "Role", options: ["DJ", "Photographer", "Videographer", "Host", "Ambassador", "Other"] },
                      { id: "event", label: "Event", options: ["Neon Garden", "Rooftop Frequencies", "Summer Signal"] },
                      { id: "date", label: "Date", placeholder: "e.g. Sat, 31 Aug", required: true },
                      { id: "pay", label: "Compensation (optional)", placeholder: "e.g. $300 flat" },
                    ]}
                    onSubmit={(v) => {
                      setOpps((l) => [{ id: "o" + Date.now(), role: v.role, event: v.event, date: v.date, pay: v.pay || "Not listed", open: true, applicants: [] }, ...l])
                      ui.toast(`${v.role} role posted to your profile`)
                      close()
                    }}
                  />
                ),
              })
            }
          >
            Post a role
          </button>
        }
      />
      <p className="srv-muted">Roles appear on your public profile. Applications are private to you and your team.</p>
      <div className="srv-list ot-gap">
        {opps.map((o) => {
          const fresh = o.applicants.filter((a) => a.status === "New").length
          return (
            <button key={o.id} className="srv-table" onClick={() => view(o)}>
              <span className="srv-main">
                <strong>
                  {o.role} · {o.event}
                </strong>
                <small>
                  {o.date} · {o.pay}
                </small>
                <span className="srv-tags">
                  <span className={`srv-chip tone-${o.open ? "green" : "gray"}`}>{o.open ? "Open" : "Closed"}</span>
                  <span className="srv-chip tone-gray">
                    {o.applicants.length} applicant{o.applicants.length === 1 ? "" : "s"}
                  </span>
                  {fresh > 0 && <span className="srv-chip tone-orange">{fresh} new</span>}
                </span>
              </span>
              <Icon name="chevron" size={16} />
            </button>
          )
        })}
      </div>
    </>
  )
}
