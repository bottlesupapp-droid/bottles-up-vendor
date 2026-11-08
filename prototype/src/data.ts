// One source of truth for the demo night: Saturday 24 August at Nova Room, 9:42 PM.
// Every role reads these numbers so the owner, manager, door and server views agree.

export const NIGHT = {
  dayLabel: "Saturday, 24 August",
  eyebrow: "SATURDAY, 24 AUGUST",
  now: "9:42 PM",
  venue: "Nova Room",
  doorsOpened: "7:00 PM",
  expected: 186, // table guests + guest list + tickets
  arrived: 96,
  tablesTotal: 18,
  openOrders: 18,
  openOrdersValue: 3840,
  teamOnShift: 12,
  teamScheduled: 14,
  sales: 4340, // so far tonight
  card: 3180,
  cash: 560,
  prepaid: 600,
  salesChange: "+6.1%",
}

export const pct = (a: number, b: number) => Math.round((a / b) * 100)
export const usd = (n: number, decimals = false) =>
  "$" + n.toLocaleString("en-US", { minimumFractionDigits: decimals ? 2 : 0, maximumFractionDigits: decimals ? 2 : 0 })
export const avgSpend = () => usd(NIGHT.sales / NIGHT.arrived, true)

export type BookingStatus = "Arrived" | "Confirmed"
export type Booking = {
  id: string
  name: string
  time: string
  table: string
  guests: number
  payment: string
  status: BookingStatus
  server: string | null
}

export const SERVERS = ["Sam Patel", "Riley Chen", "Dana Ortiz"]

export const BOOKINGS: Booking[] = [
  { id: "b1", name: "Liam Carter", time: "8:00 PM", table: "Table 1", guests: 6, payment: "Paid", status: "Arrived", server: "Riley Chen" },
  { id: "b2", name: "Ava Thompson", time: "8:15 PM", table: "Table 2", guests: 4, payment: "Paid", status: "Arrived", server: "Riley Chen" },
  { id: "b3", name: "Emma Davis", time: "8:45 PM", table: "Table 5", guests: 6, payment: "$150 deposit", status: "Arrived", server: "Riley Chen" },
  { id: "b4", name: "Mia Wilson", time: "9:00 PM", table: "Table 8", guests: 6, payment: "Paid", status: "Arrived", server: "Dana Ortiz" },
  { id: "b5", name: "Lucas Brown", time: "9:00 PM", table: "Table 13", guests: 4, payment: "Paid", status: "Arrived", server: "Dana Ortiz" },
  { id: "b6", name: "Ethan Moore", time: "9:15 PM", table: "Table 9", guests: 6, payment: "$150 deposit", status: "Arrived", server: null },
  { id: "b7", name: "Zoe Martin", time: "9:15 PM", table: "Table 10", guests: 4, payment: "Paid", status: "Arrived", server: "Sam Patel" },
  { id: "b8", name: "Ryan Lee", time: "9:20 PM", table: "Table 11", guests: 8, payment: "$200 deposit", status: "Arrived", server: null },
  { id: "b9", name: "Maya Chen", time: "9:30 PM", table: "Table 4", guests: 6, payment: "$180 deposit", status: "Arrived", server: "Sam Patel" },
  { id: "b10", name: "Chloe Hall", time: "9:30 PM", table: "Table 12", guests: 6, payment: "Paid", status: "Arrived", server: "Sam Patel" },
  { id: "b11", name: "Noah Kim", time: "9:35 PM", table: "Table 15", guests: 8, payment: "Paid", status: "Arrived", server: "Dana Ortiz" },
  { id: "b12", name: "Owen Young", time: "9:40 PM", table: "Table 14", guests: 6, payment: "Paid", status: "Arrived", server: "Dana Ortiz" },
  { id: "b-jordan", name: "Jordan Ellis", time: "12:30 AM", table: "Halo Booth", guests: 6, payment: "Paid", status: "Confirmed", server: "Sam Patel" },
  { id: "b13", name: "Marcus Hill", time: "10:00 PM", table: "VIP Booth", guests: 8, payment: "Balance $620", status: "Confirmed", server: "Sam Patel" },
  { id: "b14", name: "Grace King", time: "10:15 PM", table: "Table 3", guests: 6, payment: "$150 deposit", status: "Confirmed", server: "Riley Chen" },
  { id: "b15", name: "Sofia Reyes", time: "10:30 PM", table: "Table 7", guests: 4, payment: "Paid", status: "Confirmed", server: "Sam Patel" },
  { id: "b16", name: "Leo Scott", time: "10:45 PM", table: "Table 16", guests: 6, payment: "Paid", status: "Confirmed", server: "Dana Ortiz" },
  { id: "b17", name: "Nora Green", time: "11:00 PM", table: "Table 17", guests: 8, payment: "$200 deposit", status: "Confirmed", server: "Riley Chen" },
  { id: "b18", name: "Isaac Adams", time: "11:30 PM", table: "Table 18", guests: 6, payment: "Paid", status: "Confirmed", server: "Dana Ortiz" },
]

export const bookingGuests = (list: Booking[]) => list.reduce((s, b) => s + b.guests, 0)

/** Main-floor tables shown on the owner's floor plan. */
export const FLOOR = [
  { name: "T1", table: "Table 1", seats: 6 },
  { name: "T2", table: "Table 2", seats: 4 },
  { name: "T3", table: "Table 3", seats: 6 },
  { name: "T4", table: "Table 4", seats: 6 },
  { name: "T5", table: "Table 5", seats: 6 },
  { name: "T6", table: "Table 6", seats: 4 },
]

export const tableState = (table: string, bookings: Booking[]) => {
  const b = bookings.find((x) => x.table === table)
  if (!b) return "available"
  return b.status === "Arrived" ? "seated" : "reserved"
}

export type Txn = { id: string; label: string; amount: number; method: string; time: string; flagged?: string }
export const TRANSACTIONS: Txn[] = [
  { id: "t1", label: "Table 5", amount: 1150, method: "Card", time: "9:40 PM", flagged: "Over the table's usual spend. Confirm with the server before approving." },
  { id: "t2", label: "Table 4", amount: 420, method: "Card", time: "9:38 PM" },
  { id: "t3", label: "Table 2", amount: 380, method: "Card", time: "9:31 PM" },
  { id: "t4", label: "VIP Booth deposit", amount: 600, method: "Prepaid", time: "Booked online" },
  { id: "t5", label: "Table 1", amount: 286, method: "Cash", time: "8:52 PM" },
]

export const RANGES = {
  Tonight: { sales: NIGHT.sales, card: NIGHT.card, cash: NIGHT.cash, prepaid: NIGHT.prepaid, change: NIGHT.salesChange, period: `7 PM–${NIGHT.now}` },
  "7 days": { sales: 68420, card: 50630, cash: 9580, prepaid: 8210, change: "+12.4%", period: "Aug 18–24" },
  "30 days": { sales: 246800, card: 182630, cash: 34550, prepaid: 29620, change: "+9.8%", period: "Jul 26–Aug 24" },
} as const
export type RangeKey = keyof typeof RANGES

export type NightReport = {
  id: string
  label: string
  short: string
  live: boolean
  sales: number
  card: number
  cash: number
  prepaid: number
  refunds: number
  tablesBooked: number
  tablesSeated: number
  expected: number
  arrived: number
  walkIns: number
  closedBy?: string
}

export const NIGHTS: NightReport[] = [
  { id: "may24", label: "Saturday, 24 August", short: "Sat, Aug 24", live: true, sales: NIGHT.sales, card: NIGHT.card, cash: NIGHT.cash, prepaid: NIGHT.prepaid, refunds: 0, tablesBooked: 18, tablesSeated: 12, expected: NIGHT.expected, arrived: NIGHT.arrived, walkIns: 9 },
  { id: "may18", label: "Saturday, 17 August", short: "Sat, Aug 17", live: false, sales: 14220, card: 10480, cash: 2340, prepaid: 1400, refunds: 0, tablesBooked: 20, tablesSeated: 19, expected: 340, arrived: 316, walkIns: 41, closedBy: "Jordan Blake" },
  { id: "may17", label: "Friday, 16 August", short: "Fri, Aug 16", live: false, sales: 11960, card: 8870, cash: 1890, prepaid: 1200, refunds: 0, tablesBooked: 17, tablesSeated: 16, expected: 290, arrived: 271, walkIns: 33, closedBy: "Jordan Blake" },
]

export const toCsv = (rows: (string | number)[][]) => rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(",")).join("\n")
