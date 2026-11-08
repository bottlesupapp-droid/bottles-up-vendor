import React, { useEffect, useState, type ReactNode } from "react"

// iPhone 18 Pro Max-class display: 440 × 956 points, ~55pt corner radius.
const W = 440
const H = 956
const BEZEL = 13
// Frame everywhere except on a real phone (touch screen, phone-sized).
const PHONE = "(hover: none) and (pointer: coarse) and (max-width: 520px)"

// When framed, the app scrolls inside the phone screen instead of the window.
if (typeof window !== "undefined" && !(window as unknown as { __deviceScrollPatched?: boolean }).__deviceScrollPatched) {
  ;(window as unknown as { __deviceScrollPatched?: boolean }).__deviceScrollPatched = true
  const original = window.scrollTo.bind(window)
  window.scrollTo = ((a?: ScrollToOptions | number, b?: number) => {
    const el = document.querySelector<HTMLElement>(".device-scroll")
    if (el) {
      if (typeof a === "object") el.scrollTo(a)
      else el.scrollTo(a ?? 0, b ?? 0)
      return
    }
    if (typeof a === "object") original(a)
    else original(a ?? 0, b ?? 0)
  }) as typeof window.scrollTo
}

export const deviceScrollTop = () => document.querySelector<HTMLElement>(".device-scroll")?.scrollTop ?? 0

function useFramed() {
  const [on, setOn] = useState(() => !(window.matchMedia?.(PHONE).matches ?? false))
  useEffect(() => {
    const m = window.matchMedia?.(PHONE)
    if (!m) return
    const f = (e: MediaQueryListEvent) => setOn(!e.matches)
    m.addEventListener("change", f)
    return () => m.removeEventListener("change", f)
  }, [])
  return on
}

function StatusBar() {
  return (
    <div className="device-status" aria-hidden="true">
      <span className="ds-time">9:41</span>
      <span className="ds-icons">
        <svg width="19" height="12" viewBox="0 0 19 12">
          <rect x="0" y="8" width="3.2" height="4" rx="1" fill="currentColor" />
          <rect x="5" y="5.5" width="3.2" height="6.5" rx="1" fill="currentColor" />
          <rect x="10" y="3" width="3.2" height="9" rx="1" fill="currentColor" />
          <rect x="15" y="0" width="3.2" height="12" rx="1" fill="currentColor" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12">
          <path d="M8.5 2.2c2.5 0 4.8 1 6.5 2.6l1.2-1.2C14.2 1.6 11.5.5 8.5.5S2.8 1.6.8 3.6L2 4.8c1.7-1.6 4-2.6 6.5-2.6Z" fill="currentColor" />
          <path d="M8.5 5.6c1.6 0 3 .6 4.1 1.6l1.2-1.2C12.4 4.7 10.5 3.9 8.5 3.9S4.6 4.7 3.2 6l1.2 1.2c1.1-1 2.5-1.6 4.1-1.6Z" fill="currentColor" />
          <path d="M8.5 9 10.9 10.2 8.5 12 6.1 10.2Z" fill="currentColor" />
          <path d="M8.5 7.4c.8 0 1.6.3 2.2.9L8.5 10.5 6.3 8.3c.6-.6 1.4-.9 2.2-.9Z" fill="currentColor" />
        </svg>
        <span className="ds-battery">
          <i />
        </span>
      </span>
    </div>
  )
}

/** Shows the app inside an iPhone 18 Pro Max frame on wider screens; full-bleed on real phones. */
export function DeviceFrame({ dark, children, surface }: { dark: boolean; children: ReactNode; surface?: string }) {
  const framed = useFramed()
  const [scale, setScale] = useState(1)
  useEffect(() => {
    document.documentElement.classList.toggle("is-framed", framed)
    if (!framed) return
    const fit = () => setScale(Math.max(0.3, Math.min(1, (window.innerWidth - 24) / (W + BEZEL * 2 + 10), (window.innerHeight - 24) / (H + BEZEL * 2))))
    fit()
    window.addEventListener("resize", fit)
    return () => window.removeEventListener("resize", fit)
  }, [framed])
  if (!framed) return <>{children}</>
  return (
    <div className={`device-stage ${dark ? "is-dark" : "is-light"}`} style={surface ? ({ ["--surface-override" as string]: surface } as React.CSSProperties) : undefined}>
      <div className="device-sizer" style={{ width: (W + BEZEL * 2) * scale, height: (H + BEZEL * 2) * scale }}>
        <div className="device" style={{ transform: `scale(${scale})` }}>
          <i className="db db-action" />
          <i className="db db-vol-up" />
          <i className="db db-vol-down" />
          <i className="db db-power" />
          <i className="db db-camera" />
          <div className="device-screen">
            <StatusBar />
            <div className="device-island" aria-hidden="true" />
            <div className="device-scroll">{children}</div>
            <div className="device-home" aria-hidden="true" />
          </div>
        </div>
      </div>
    </div>
  )
}
