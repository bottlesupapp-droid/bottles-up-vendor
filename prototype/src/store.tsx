import { usePersisted } from "./kit"
import { createContext, useContext, useState, type ReactNode } from "react"
import { EXTRA_PARTIES } from "./DoorGuests"
import { BOOKINGS, NIGHT, TRANSACTIONS, type Booking, type Txn } from "./data"

export type AgreementStatus = "Pending approval" | "Approved" | "Changes requested" | "Withdrawn"
export type Member = { name: string; role: string; status: string }
export type DoorParty = { id: string; name: string; type: string; size: number; inside: number }
export type OrgProfile = {
  name: string
  tagline: string
  bio: string
  city: string
  genres: string
  instagram: string
  tiktok: string
  website: string
  email: string
  showPast: boolean
  showReviews: boolean
  allowMessages: boolean
  cover: number
  coverImg?: string
  coverY?: number
  coverZoom?: number
  logoImg?: string
  featuredId?: string
}
export type OrgPost = { id: string; caption: string; cover: number; kind: "Photo" | "Reel"; likes: number; comments: number; reach: number; pinned: boolean; event: string; audience?: "Public" | "Followers" | "Members Only"; allowRepost?: boolean }
export type OrgHighlight = { id: string; name: string; cover: number; items: number }
export type WalkIn = { name: string; guests: number; method: string; amount: number; time: string }

type Store = {
  bookings: Booking[]
  setBookings: (fn: (b: Booking[]) => Booking[]) => void
  txns: Txn[]
  setTxns: (fn: (t: Txn[]) => Txn[]) => void
  agreement: AgreementStatus
  setAgreement: (a: AgreementStatus) => void
  doorTeam: Member[]
  setDoorTeam: (fn: (m: Member[]) => Member[]) => void
  arrived: number
  setArrived: (fn: (n: number) => number) => void
  parties: DoorParty[]
  setParties: (fn: (p: DoorParty[]) => DoorParty[]) => void
  walkIns: WalkIn[]
  org: OrgProfile
  posts: OrgPost[]
  setPosts: (fn: (p: OrgPost[]) => OrgPost[]) => void
  highlights: OrgHighlight[]
  setHighlights: (fn: (h: OrgHighlight[]) => OrgHighlight[]) => void
  setOrg: (o: OrgProfile) => void
  setWalkIns: (fn: (w: WalkIn[]) => WalkIn[]) => void
}

const Ctx = createContext<Store | null>(null)

export function useStore() {
  const s = useContext(Ctx)
  if (!s) throw new Error("useStore outside StoreProvider")
  return s
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [bookings, setBookings] = usePersisted<Booking[]>("bu-biz-store-bookings", BOOKINGS)
  const [txns, setTxns] = usePersisted<Txn[]>("bu-biz-store-txns", TRANSACTIONS)
  const [agreement, setAgreement] = useState<AgreementStatus>("Pending approval")
  const [doorTeam, setDoorTeam] = usePersisted<Member[]>("bu-biz-store-doorTeam", [
    { name: "Jamie Fox", role: "Door lead", status: "Accepted" },
    { name: "Morgan Lee", role: "Door staff", status: "Pending" },
  ])
  const [arrived, setArrived] = usePersisted("bu-biz-store-arrived", NIGHT.arrived)
  const [parties, setParties] = usePersisted<DoorParty[]>("bu-biz-store-parties", [
    { id: "p1", name: "Maya Chen", type: "Table 4", size: 6, inside: 6 },
    { id: "p2", name: "Marcus Hill", type: "VIP Booth · 10:00 PM", size: 8, inside: 0 },
    { id: "p3", name: "Sofia Reyes", type: "Table 7 · 10:30 PM", size: 4, inside: 0 },
    { id: "p4", name: "Alex Turner", type: "Guest list", size: 2, inside: 2 },
    { id: "p5", name: "Priya Shah", type: "Guest list", size: 3, inside: 0 },
    { id: "p6", name: "Grace King", type: "Table 3 · 10:15 PM", size: 6, inside: 0 },
    ...EXTRA_PARTIES,
  ])
  const [walkIns, setWalkIns] = usePersisted<WalkIn[]>("bu-biz-store-walkIns", [
    { name: "Chris Morgan", guests: 2, method: "Card", amount: 40, time: "9:34 PM" },
    { name: "Taylor Kim", guests: 1, method: "Cash", amount: 20, time: "9:28 PM" },
  ])
  const [org, setOrg] = usePersisted<OrgProfile>("bu-biz-store-org", {
    name: "Midnight Social",
    tagline: "Late nights, good people",
    bio: "We throw immersive late-night parties with house, disco and live visuals across Toronto.",
    city: "Toronto",
    genres: "House, Disco, Live visuals",
    instagram: "@midnightsocial",
    tiktok: "",
    website: "midnightsocial.example",
    email: "hello@midnightsocial.example",
    showPast: true,
    showReviews: true,
    allowMessages: true,
    cover: 0,
  })
  const [posts, setPosts] = usePersisted<OrgPost[]>("bu-biz-store-posts", [
    { id: "p1", caption: "Neon Garden is on sale. Sat, 31 August at Nova Room.", cover: 0, kind: "Photo", likes: 1240, comments: 86, reach: 9800, pinned: true, event: "Neon Garden" },
    { id: "p2", caption: "Spring Social recap. 188 of you came through.", cover: 3, kind: "Reel", likes: 2310, comments: 140, reach: 18400, pinned: true, event: "" },
    { id: "p3", caption: "Lineup reveal for Neon Garden.", cover: 1, kind: "Photo", likes: 980, comments: 61, reach: 7200, pinned: false, event: "Neon Garden" },
    { id: "p4", caption: "Building the garden: set design sneak peek.", cover: 2, kind: "Reel", likes: 1610, comments: 47, reach: 12900, pinned: false, event: "" },
    { id: "p5", caption: "Summer Signal, 11 October. Save the date.", cover: 3, kind: "Photo", likes: 640, comments: 22, reach: 5100, pinned: false, event: "Summer Signal" },
    { id: "p6", caption: "Thank you Nova Room for an unreal spring.", cover: 1, kind: "Photo", likes: 720, comments: 18, reach: 4800, pinned: false, event: "" },
  ])
  const [highlights, setHighlights] = usePersisted<OrgHighlight[]>("bu-biz-store-highlights", [
    { id: "h1", name: "Neon Garden", cover: 0, items: 6 },
    { id: "h2", name: "Recaps", cover: 3, items: 12 },
    { id: "h3", name: "Lineups", cover: 1, items: 4 },
    { id: "h4", name: "Backstage", cover: 2, items: 8 },
  ])
  return (
    <Ctx.Provider
      value={{
        bookings,
        setBookings: (fn) => setBookings(fn),
        txns,
        setTxns: (fn) => setTxns(fn),
        agreement,
        setAgreement,
        doorTeam,
        setDoorTeam: (fn) => setDoorTeam(fn),
        arrived,
        setArrived: (fn) => setArrived(fn),
        parties,
        setParties: (fn) => setParties(fn),
        walkIns,
        org,
        posts,
        setPosts: (fn) => setPosts(fn),
        highlights,
        setHighlights: (fn) => setHighlights(fn),
        setOrg,
        setWalkIns: (fn) => setWalkIns(fn),
      }}
    >
      {children}
    </Ctx.Provider>
  )
}
