import { BottlePop } from "./BottlePop"
/* Launch screen from the BottlesUp Figma design: the logo stays still, only the thin orange cue rotates. */
export function LaunchScreen({ dark }: { dark: boolean }) {
  const still = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false
  return (
    <div className={`bu-launch ${dark ? "dark" : "light"}`} aria-busy="true" aria-label="Loading BottlesUp Business">
      <div className="bu-launch-identity">
        <div className="bu-lockup" role="img" aria-label="BottlesUp">
          <BottlePop width={104} className="bu-bottle" />
          <img className="bu-wordmark" src={dark ? "/launch/wordmark-dark.svg" : "/launch/wordmark-light.svg"} alt="" />
        </div>
        <span className="bu-sub">BUSINESS</span>
        {still ? <i className="bu-still-cue" aria-hidden="true" /> : <img className="bu-spinner" src="/launch/spinner.svg" alt="" />}
      </div>
    </div>
  )
}
