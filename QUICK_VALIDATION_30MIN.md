# Quick Validation Checklist (30 Minutes)

Fast validation of all key features. Perfect for quick regression testing.

---

## Prerequisites (Do Once)
```bash
✅ Run migration 002 (subscription plans)
✅ Run migration 007 (fix event status)
✅ Restart app completely
```

---

## 1. Subscriptions (2 min)
- [ ] Profile → Subscription
- [ ] See 4 plans: Free, Starter ($29.99), Professional ($79.99), Enterprise ($199.99)
- [ ] Starter plan shows "POPULAR" badge

---

## 2. Create Event (8 min)
- [ ] Events → + Button
- [ ] Fill in:
  - Event Name: "Test Party 2027"
  - Description: "Test description"
  - Category, Club, Zone: Select any
  - Date: Future date
  - Start Time: 8:00 PM
  - End Time: 2:00 AM
  - Ticket Price: 50
  - Max Capacity: 200
  - **Dress Code**: "Smart Casual"
  - **Min Age**: 21
- [ ] Upload flyer image
- [ ] Tap "Create Event"
- [ ] Event appears in Active tab

---

## 3. Ticket Tiers (8 min)
- [ ] Tap on your event → Ticket Tiers
- [ ] Add Tier 1:
  - Name: "Early Bird"
  - Price: 35
  - Capacity: 50
- [ ] Add Tier 2:
  - Name: "General"
  - Price: 50
  - Capacity: 100
- [ ] Add Tier 3:
  - Name: "VIP"
  - Price: 100
  - Capacity: 30
- [ ] All 3 tiers display correctly

---

## 4. Team & Lineup (8 min)
- [ ] Event Details → Team & Lineup
- [ ] Add DJ 1:
  - Name: "DJ Spinmaster"
  - Role: DJ
  - Set Time: 9PM - 11PM
- [ ] Add DJ 2:
  - Name: "DJ Nova"
  - Role: DJ
  - Set Time: 11PM - 1AM
- [ ] Add Security:
  - Name: "Mike Johnson"
  - Role: Security
- [ ] All members display in lineup

---

## 5. Edit Event (2 min)
- [ ] Event Details → Edit icon
- [ ] Change ticket price to 60
- [ ] Save
- [ ] Price updated successfully

---

## 6. Business Profile (2 min)
- [ ] Profile → Edit Profile
- [ ] Update Business Name: "Test Nightlife LLC"
- [ ] Add phone, address
- [ ] Save
- [ ] Changes persist

---

## Quick Test Result

**Pass Criteria**: All 6 sections complete without errors

✅ **PASS** - All features working
⚠️ **PARTIAL** - Some features need attention
❌ **FAIL** - Critical issues found

**Your Result**: _________

---

## If Tests Fail

**Events not showing?**
→ Run migration 007, restart app

**Image upload fails?**
→ Check event-images bucket exists

**Only 1 subscription plan?**
→ Run migration 002, restart app

**Ticket tiers don't save?**
→ Run migration 004

**Team members missing?**
→ Run migration 005

---

## Feature Coverage

This quick test validates:
- ✅ Subscription management
- ✅ Create event (with description, dress code, age restriction)
- ✅ Upload flyer
- ✅ Edit event
- ✅ Ticket tier creation & limits
- ✅ Add DJs/staff to lineup
- ✅ Business registration

**Not tested** (requires additional setup):
- Bank payout (needs Stripe API keys)
- Identity verification (needs Stripe Connect)
- Staff permissions (needs multiple users)
