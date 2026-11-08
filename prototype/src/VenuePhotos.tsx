import { useRef, useState } from "react"
import { Icon, QuickForm, useUI } from "./kit"

export type Photo = { id: string; src: string; caption: string; area: string }

export const AREAS = ["Space", "Tables", "Bar", "Nights", "Outdoor"]

export const ACTIVE_LOUNGE_PHOTOS: Photo[] = [
  { id: "a1", src: "/venue/main-room.jpg", caption: "Main room", area: "Space" },
  { id: "a2", src: "/venue/stage.jpg", caption: "Stage and lights", area: "Space" },
  { id: "a3", src: "/venue/booth.jpg", caption: "VIP Booth", area: "Tables" },
  { id: "a4", src: "/venue/dance-floor.jpg", caption: "Dance floor on a Friday", area: "Nights" },
  { id: "a5", src: "/venue/bar.jpg", caption: "Bar and bottle service", area: "Bar" },
  { id: "a6", src: "/venue/event-night.jpg", caption: "Neon Garden preview", area: "Nights" },
  { id: "a7", src: "/venue/dj-booth.jpg", caption: "DJ booth", area: "Space" },
]

const GOAL = 8

/** Swipeable preview of what guests see on the venue page. */
function GuestPreview({ photos, name }: { photos: Photo[]; name: string }) {
  const [i, setI] = useState(0)
  return (
    <div className="pv-wrap">
      <div
        className="pv-track"
        onScroll={(e) => {
          const el = e.currentTarget
          setI(Math.round(el.scrollLeft / el.clientWidth))
        }}
      >
        {photos.map((p) => (
          <figure key={p.id}>
            <img src={p.src} alt={p.caption} draggable={false} />
          </figure>
        ))}
      </div>
      <span className="pv-count">
        {i + 1} / {photos.length} · {photos[i]?.caption}
      </span>
      <div className="pv-dots">
        {photos.map((p, k) => (
          <i key={p.id} className={k === i ? "on" : ""} />
        ))}
      </div>
      <p className="list-count">Swipe to browse. This is the top of {name}'s page in the BottlesUp app. The first photo is the cover.</p>
    </div>
  )
}

function PhotoSheet({ photo, index, count, onSave, onMove, onCover, onDelete, close }: { photo: Photo; index: number; count: number; onSave: (p: Photo) => void; onMove: (dir: -1 | 1) => void; onCover: () => void; onDelete: () => void; close: () => void }) {
  const [confirm, setConfirm] = useState(false)
  return (
    <>
      <img className="ps-image" src={photo.src} alt={photo.caption} />
      <div className="ps-tools">
        <button className="secondary-action" disabled={index === 0} onClick={() => { onCover(); close() }}>
          {index === 0 ? "Cover photo" : "Make cover"}
        </button>
        <button className="secondary-action" aria-label="Move earlier" disabled={index === 0} onClick={() => { onMove(-1); close() }}>
          <Icon name="back" size={16} />
        </button>
        <button className="secondary-action" aria-label="Move later" disabled={index === count - 1} onClick={() => { onMove(1); close() }}>
          <Icon name="chevron" size={16} />
        </button>
      </div>
      <QuickForm
        submit="Save details"
        fields={[
          { id: "caption", label: "Caption", value: photo.caption, required: true },
          { id: "area", label: "Area", options: [photo.area, ...AREAS.filter((a) => a !== photo.area)] },
        ]}
        onSubmit={(v) => {
          onSave({ ...photo, caption: v.caption.trim().slice(0, 40), area: v.area })
          close()
        }}
      />
      {confirm ? (
        <div className="confirm-box card">
          <strong>Delete this photo?</strong>
          <small>Guests won't see it on your venue page anymore.</small>
          <div className="dual-actions">
            <button className="secondary-action" onClick={() => setConfirm(false)}>
              Keep
            </button>
            <button className="danger-button solid" onClick={() => { onDelete(); close() }}>
              Delete
            </button>
          </div>
        </div>
      ) : (
        <button className="danger-button" onClick={() => setConfirm(true)}>
          Delete photo
        </button>
      )}
    </>
  )
}

export function PhotoManager({ name, photos, setPhotos }: { name: string; photos: Photo[]; setPhotos: (fn: (p: Photo[]) => Photo[]) => void }) {
  const ui = useUI()
  const input = useRef<HTMLInputElement>(null)
  const [area, setArea] = useState("All")
  const shown = area === "All" ? photos : photos.filter((p) => p.area === area)
  const upload = (files: FileList | null) => {
    if (!files?.length) return
    const list = Array.from(files).filter((f) => f.type.startsWith("image/")).slice(0, 12)
    if (!list.length) return ui.toast("Choose image files (JPG, PNG or HEIC)")
    if (list.some((f) => f.size > 20 * 1024 * 1024)) return ui.toast("Each photo must be under 20 MB")
    Promise.all(
      list.map(
        (f, k) =>
          new Promise<Photo>((resolve) => {
            const r = new FileReader()
            r.onload = () => resolve({ id: `u${Date.now()}${k}`, src: String(r.result), caption: f.name.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").slice(0, 40) || "New photo", area: area === "All" ? "Space" : area })
            r.readAsDataURL(f)
          }),
      ),
    ).then((added) => {
      setPhotos((p) => [...p, ...added])
      ui.toast(`${added.length} photo${added.length === 1 ? "" : "s"} added. Guests can see ${added.length === 1 ? "it" : "them"} now.`)
    })
  }
  const open = (p: Photo) => {
    const index = photos.indexOf(p)
    ui.sheet({
      eyebrow: index === 0 ? "COVER PHOTO" : `PHOTO ${index + 1} OF ${photos.length}`,
      title: p.caption,
      body: (close) => (
        <PhotoSheet
          photo={p}
          index={index}
          count={photos.length}
          close={close}
          onSave={(np) => {
            setPhotos((list) => list.map((x) => (x.id === np.id ? np : x)))
            ui.toast("Photo details saved")
          }}
          onCover={() => {
            setPhotos((list) => [p, ...list.filter((x) => x.id !== p.id)])
            ui.toast("New cover photo set")
          }}
          onMove={(dir) =>
            setPhotos((list) => {
              const i = list.findIndex((x) => x.id === p.id)
              const j = i + dir
              if (j < 0 || j >= list.length) return list
              const next = [...list]
              ;[next[i], next[j]] = [next[j], next[i]]
              return next
            })
          }
          onDelete={() => {
            setPhotos((list) => list.filter((x) => x.id !== p.id))
            ui.toast("Photo deleted")
          }}
        />
      ),
    })
  }
  return (
    <section className="pm">
      <div className="pm-head card">
        <div>
          <strong>
            {photos.length} photo{photos.length === 1 ? "" : "s"}
          </strong>
          <small>{photos.length >= GOAL ? "Great. Guests can really picture the night." : `Add ${GOAL - photos.length} more. Venues with ${GOAL}+ photos get more bookings.`}</small>
        </div>
        <div className="progress">
          <i className={photos.length >= GOAL ? "complete" : ""} style={{ width: `${Math.min(100, (photos.length / GOAL) * 100)}%` }} />
        </div>
        <div className="dual-actions">
          <button className="secondary-action" disabled={!photos.length} onClick={() => ui.sheet({ eyebrow: "GUEST VIEW", title: name, body: () => <GuestPreview photos={photos} name={name} /> })}>
            Preview
          </button>
          <button className="primary-action" onClick={() => input.current?.click()}>
            <Icon name="plus" size={16} /> Add photos
          </button>
        </div>
        <input ref={input} id={`photos-${name.replace(/\s+/g, "-").toLowerCase()}`} type="file" accept="image/*" multiple hidden onChange={(e) => { upload(e.target.files); e.target.value = "" }} />
      </div>

      {photos.length > 0 && <Segmented2 items={["All", ...AREAS.filter((a) => photos.some((p) => p.area === a))]} active={area} onChange={setArea} />}

      {photos.length === 0 ? (
        <button className="pm-empty" onClick={() => input.current?.click()}>
          <Icon name="plus" size={26} />
          <strong>Add your first photos</strong>
          <small>Show the room, the bar, your best tables and a busy night.</small>
        </button>
      ) : (
        <div className="pm-grid">
          {shown.map((p) => {
            const i = photos.indexOf(p)
            return (
              <button key={p.id} onClick={() => open(p)} aria-label={`Edit photo: ${p.caption}`}>
                <img src={p.src} alt="" />
                {i === 0 && <b className="pm-cover">Cover</b>}
                <span>
                  <em>{p.caption}</em>
                  <small>{p.area}</small>
                </span>
              </button>
            )
          })}
          <button className="pm-add" onClick={() => input.current?.click()} aria-label="Add photos">
            <Icon name="plus" size={22} />
            <small>Add</small>
          </button>
        </div>
      )}
      <p className="status-explainer">Tap a photo to change its caption, move it, make it the cover or delete it. JPG, PNG or HEIC up to 20 MB.</p>
    </section>
  )
}

function Segmented2({ items, active, onChange }: { items: string[]; active: string; onChange: (s: string) => void }) {
  return (
    <div className="pm-filters">
      {items.map((x) => (
        <button key={x} className={x === active ? "on" : ""} onClick={() => onChange(x)}>
          {x}
        </button>
      ))}
    </div>
  )
}
