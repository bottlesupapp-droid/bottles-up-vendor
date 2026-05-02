# Complete Feature Validation Guide

This guide provides step-by-step instructions to validate all implemented features in the Bottles Up Vendor app.

**Estimated Time**: 90-120 minutes
**Prerequisites**:
- ✅ Run migration 002 (subscription plans)
- ✅ Run migration 007 (fix event status)
- ✅ Storage bucket `event-images` exists
- ✅ App restarted after migrations

---

## Quick Start Checklist

Before testing, ensure:
- [ ] Database migrations are executed
- [ ] App is fully restarted (not just hot reload)
- [ ] You're logged in as a vendor
- [ ] Internet connection is stable

---

## 1. Subscription Management (5 min)

**What**: View and select from 4 subscription tiers (Free, Starter, Professional, Enterprise)

**Steps**:
1. Open the app
2. Tap **Profile** tab (bottom navigation)
3. Tap **Subscription** (under Account section)
4. ✅ **Verify**: You see 4 subscription plans:
   - **Free**: $0/month - "Perfect for getting started"
   - **Starter**: $29.99/month - "Great for small event organizers" (marked as POPULAR)
   - **Professional**: $79.99/month - "For growing event businesses"
   - **Enterprise**: $199.99/month - "For large-scale operations"

**Expected Behavior**:
- Each plan shows price, features list, and benefits
- "POPULAR" badge appears on Starter plan
- Features are clearly listed with checkmarks
- Free plan shows "Current Plan" (default for all users)

**Screenshots to Take**: Subscription plans screen

---

## 2. Create Event - Basic Info (10 min)

**What**: Create a new event with all required fields

**Steps**:
1. Tap **Events** tab (bottom navigation)
2. Tap **+ (Plus icon)** in top right
3. Fill in event details:
   - **Event Name**: "New Year's Eve Party 2027"
   - **Description**: "Join us for the biggest celebration of the year!"
   - **Select Category**: Choose any available category
   - **Select Venue/Club**: Choose any available club
   - **Select Zone**: Choose any available zone
   - **Date**: Select a future date (e.g., December 31, 2026)
   - **Start Time**: 8:00 PM
   - **End Time**: 2:00 AM
   - **Ticket Price**: 50
   - **Max Capacity**: 200

4. ✅ **Verify**: All fields accept input correctly
5. Scroll down to continue...

**Expected Behavior**:
- Date picker only allows future dates
- Time pickers show 12/24 hour format
- Price accepts decimal values
- Capacity accepts integers only

---

## 3. Set Dress Code (2 min)

**What**: Add dress code requirements to event

**Steps** (continuing from Create Event):
1. Scroll to **Dress Code** field
2. Enter: "Smart Casual - No sneakers or athletic wear"
3. ✅ **Verify**: Text is accepted and displays properly

**Expected Behavior**:
- Multi-line text input supported
- Optional field (can be left blank)

---

## 4. Set Age Restriction (2 min)

**What**: Set minimum age for event entry

**Steps** (continuing from Create Event):
1. Scroll to **Minimum Age** field
2. Enter: 21
3. ✅ **Verify**: Only numbers are accepted

**Expected Behavior**:
- Numeric keyboard appears
- Only integer values accepted
- Optional field (can be left blank)

**Common Values**: 18, 21, 25

---

## 5. Upload Flyer (3 min)

**What**: Upload event flyer/poster image

**Steps** (continuing from Create Event):
1. Scroll to **Event Flyer** section
2. Tap **Upload Flyer** button
3. Select an image from:
   - Camera (take new photo), OR
   - Gallery (choose existing image)
4. ✅ **Verify**:
   - Image preview appears after selection
   - Image size is reasonable (under 10MB)

**Expected Behavior**:
- Permissions requested for camera/gallery (first time only)
- Image preview shows selected image
- Upload happens when you save the event
- Accepted formats: JPEG, PNG, WebP

**Troubleshooting**: If upload fails, ensure `event-images` storage bucket exists and has proper RLS policies

---

## 6. Save Event & Verify Display (5 min)

**Steps** (continuing from Create Event):
1. Scroll to bottom
2. Tap **Create Event** button
3. ✅ **Verify**: Success message appears
4. Return to **Events** tab
5. Tap **Active** tab
6. ✅ **Verify**: Your new event appears in the list with:
   - Event name
   - Date and time
   - Venue/location
   - Flyer image (if uploaded)

**Expected Behavior**:
- Event appears immediately in Active tab
- Event card shows all key information
- Flyer image displays if uploaded
- No events in Draft tab (unless you explicitly saved as draft)

**If event doesn't appear**:
- Check you ran migration 007
- Verify event date is in the future
- Restart the app completely

---

## 7. Edit Event (5 min)

**What**: Modify existing event details

**Steps**:
1. From **Events** tab → **Active**
2. Tap on your newly created event
3. Tap **Edit Event** icon (pencil icon, top right)
4. Modify any field (e.g., change ticket price to 60)
5. Tap **Save Changes**
6. ✅ **Verify**:
   - Success message appears
   - Changes are reflected in event details
   - Event still appears in Active tab

**Expected Behavior**:
- All fields are editable
- Image can be changed/replaced
- Save updates database immediately

---

## 8. Ticket Tier Creation (15 min)

**What**: Create multiple ticket pricing tiers for an event

**Steps**:
1. From **Events** tab → **Active**
2. Tap on your event
3. In **Quick Actions**, tap **Ticket Tiers**
4. Tap **+ Add Ticket Tier** button
5. Create **Tier 1 - Early Bird**:
   - **Name**: "Early Bird"
   - **Description**: "Limited time discount"
   - **Price**: 35.00
   - **Capacity**: 50
   - **Sales Start**: Today
   - **Sales End**: 1 week from today
   - Toggle **Active**: ON
6. Tap **Save**
7. ✅ **Verify**: Tier appears in list

8. Repeat to create **Tier 2 - General Admission**:
   - **Name**: "General Admission"
   - **Price**: 50.00
   - **Capacity**: 100
   - **Sales Start**: 1 week from today
   - **Sales End**: Event date
   - Toggle **Active**: ON

9. Create **Tier 3 - VIP**:
   - **Name**: "VIP"
   - **Description**: "Premium access with perks"
   - **Price**: 100.00
   - **Capacity**: 30
   - Toggle **Active**: ON

10. ✅ **Verify**: All 3 tiers display with:
    - Correct names and prices
    - Capacity limits
    - Active/inactive status
    - Sales date ranges

**Expected Behavior**:
- Can create unlimited tiers
- Each tier is independent
- Can edit/delete tiers
- Active toggle controls availability
- Total capacity shouldn't exceed event max capacity (warning may appear)

---

## 9. Add DJs / Team & Lineup (15 min)

**What**: Add DJs, security, and staff to event

**Steps**:
1. From event details screen
2. In **Quick Actions**, tap **Team & Lineup**
3. Tap **+ Add Team Member** button

**Add DJ #1**:
4. Fill in:
   - **Name**: "DJ Spinmaster"
   - **Role**: Select "DJ"
   - **Set Time**: 9:00 PM - 11:00 PM
   - **Bio**: "World-renowned DJ specializing in house music"
   - **Social Media**: "@djspinmaster" (optional)
5. Tap **Save**
6. ✅ **Verify**: DJ appears in lineup with time slot

**Add DJ #2**:
7. Tap **+ Add Team Member**
8. Fill in:
   - **Name**: "DJ Nova"
   - **Role**: "DJ"
   - **Set Time**: 11:00 PM - 1:00 AM
   - **Bio**: "Rising star in techno scene"
9. Tap **Save**

**Add Security Staff**:
10. Tap **+ Add Team Member**
11. Fill in:
    - **Name**: "Mike Johnson"
    - **Role**: Select "Security"
    - **Contact**: "555-0123" (optional)
12. Tap **Save**

**Add Other Staff**:
13. Add at least 1 more team member with role:
    - "Bartender", "Host", or "Manager"

14. ✅ **Verify**: Team list shows:
    - All team members grouped by role
    - DJ set times displayed
    - Edit/delete options available
    - Members can be reordered

**Expected Behavior**:
- DJs show with time slots
- Other roles show without time requirements
- Can add unlimited team members
- Can edit/delete members
- Photos optional for all members

---

## 10. Ticket Limits & Capacity Management (5 min)

**What**: Verify ticket limits are enforced

**Steps**:
1. Go to your event details
2. Check **Event Statistics** section
3. ✅ **Verify** it shows:
   - **Max Capacity**: (Your set limit, e.g., 200)
   - **Tickets Sold**: 0
   - **Available**: (Max capacity - sold)

4. Go to **Ticket Tiers** screen
5. ✅ **Verify**:
   - Sum of all tier capacities ≤ Event max capacity
   - Warning appears if tier total exceeds event capacity

6. Try to create a ticket tier with capacity > remaining event capacity
7. ✅ **Verify**: Validation warning appears

**Expected Behavior**:
- Capacity tracking is accurate
- Can't oversell tickets
- Real-time capacity updates
- Clear warnings for capacity issues

---

## 11. Staff Roles & Permissions (Conceptual - 3 min)

**What**: Understand role-based access control

**Roles Defined**:
1. **Owner**: Full access to all features
2. **Manager**: Can manage events, tickets, team
3. **Staff**: Limited access to check-ins only
4. **DJ**: View-only access to their assigned events

**Steps to Verify** (if multi-user testing available):
1. Check your current role in **Profile** screen
2. ✅ **Verify**: Your account shows "Owner" or appropriate role
3. Note: Full role testing requires multiple user accounts

**Expected Behavior**:
- Owners see all features
- Other roles have restricted access
- Role displayed in profile
- Permissions enforced at API level

**Note**: For full validation, create test accounts with different roles via Supabase dashboard

---

## 12. Business Registration (10 min)

**What**: Complete business profile for vendor account

**Steps**:
1. Go to **Profile** tab
2. Tap **Edit Profile**
3. Fill in business information:
   - **Business Name**: "Nightlife Events LLC"
   - **Business Email**: (your email)
   - **Business Phone**: "+1-555-0100"
   - **Business Address**: "123 Main St, City, State 12345"
   - **Business Description**: "Premier event management company"
   - **Tax ID/EIN**: "12-3456789" (optional)
   - **Website**: "https://example.com" (optional)
4. Upload **Business Logo** (optional)
5. Tap **Save Changes**
6. ✅ **Verify**:
   - Profile updates successfully
   - Business name displays in header
   - Logo appears if uploaded

**Expected Behavior**:
- All fields save properly
- Changes reflect immediately
- Logo updates throughout app
- Required fields validated

---

## 13. Bank Payout Setup - Stripe Connect (10 min)

**What**: Connect bank account for receiving payouts

**Note**: This requires Stripe Connect integration to be fully configured with API keys

**Steps**:
1. Go to **Profile** tab
2. Look for **Bank/Payout Settings** option
3. Tap **Connect Bank Account** or **Setup Payouts**
4. ✅ **Expected**: Redirects to Stripe Connect onboarding

**Stripe Connect Flow** (if configured):
1. Enter bank details:
   - Bank account number
   - Routing number
   - Account holder name
2. Verify identity:
   - SSN/EIN
   - Business verification documents
3. Complete onboarding
4. ✅ **Verify**:
   - Account status shows "Connected"
   - Bank details stored securely
   - Payout schedule displayed

**If Not Configured**:
- ✅ **Verify**: "Coming Soon" message or setup instructions appear
- Feature framework is in place
- No errors when accessing the screen

**Expected Behavior** (when fully configured):
- Secure redirect to Stripe
- Identity verification required
- Bank account validated
- Payout schedule (daily/weekly/monthly)
- Transaction history visible

---

## 14. Identity Verification (5 min)

**What**: Verify identity for compliance and security

**Note**: Full identity verification requires Stripe Connect to be configured

**Steps**:
1. During **Bank Payout Setup** (Step 13)
2. Stripe will request:
   - Government-issued ID (Driver's license, Passport)
   - SSN or EIN
   - Business verification documents
   - Proof of address
3. Upload required documents
4. Submit for review
5. ✅ **Verify**: Status shows "Pending Review" or "Verified"

**Alternative Path** (if Stripe not configured):
1. Go to **Profile** → **Settings**
2. Look for **Identity Verification** section
3. ✅ **Verify**: Shows current verification status

**Expected Behavior**:
- Secure document upload
- Clear instructions for each document type
- Status tracking (Pending, Under Review, Verified, Rejected)
- Email notifications on status changes
- Re-submission allowed if rejected

**Verification Levels**:
- ⚪ **Unverified**: Limited features
- 🟡 **Pending**: Documents submitted, awaiting review
- 🟢 **Verified**: Full access, can receive payouts
- 🔴 **Rejected**: Need to resubmit with corrections

---

## Feature Summary & Quick Test Matrix

| Feature | Location | Expected Result | Status |
|---------|----------|----------------|--------|
| **Subscription Management** | Profile → Subscription | See 4 plans (Free, Starter, Pro, Enterprise) | ⬜ |
| **Create Event** | Events → + Button | Event created successfully | ⬜ |
| **Set Description** | Create/Edit Event | Description saves and displays | ⬜ |
| **Set Dress Code** | Create/Edit Event | Dress code appears on event details | ⬜ |
| **Set Age Restriction** | Create/Edit Event | Min age displayed on event | ⬜ |
| **Upload Flyer** | Create/Edit Event | Image uploads and displays | ⬜ |
| **Edit Event** | Event Details → Edit | Changes save successfully | ⬜ |
| **Ticket Tier Creation** | Event → Ticket Tiers | Multiple tiers created | ⬜ |
| **Ticket Limits** | Event Statistics | Capacity tracking accurate | ⬜ |
| **Add DJs** | Event → Team & Lineup | DJs added with set times | ⬜ |
| **Add Staff** | Event → Team & Lineup | Staff members added | ⬜ |
| **Staff Roles** | Profile | Role displayed correctly | ⬜ |
| **Business Registration** | Profile → Edit Profile | Business info saved | ⬜ |
| **Bank Payout Setup** | Profile → Payouts | Stripe Connect flow works | ⬜ |
| **Identity Verification** | Stripe Onboarding | Verification status tracked | ⬜ |

---

## Common Issues & Solutions

### Events Not Showing
**Problem**: Created event doesn't appear in Active tab
**Solution**:
1. Run migration 007
2. Restart app completely (not hot reload)
3. Check event date is in the future

### Image Upload Fails
**Problem**: Flyer upload fails with error
**Solution**:
1. Verify `event-images` storage bucket exists
2. Check bucket is public
3. Verify RLS policies allow authenticated uploads
4. Check image size < 10MB

### Subscription Plans Missing
**Problem**: Only Free plan shows, others missing
**Solution**:
1. Run migration 002 (safe version)
2. Restart app
3. Verify subscription_plans table has 4 rows

### Ticket Tiers Not Saving
**Problem**: Ticket tier doesn't save or disappears
**Solution**:
1. Run migration 004 (ticket_types table)
2. Check capacity doesn't exceed event max
3. Verify sales dates are valid

### Team Members Not Showing
**Problem**: Added DJs/staff don't appear
**Solution**:
1. Run migration 005 (event_team_members table)
2. Restart app
3. Check role field is filled

---

## Testing Checklist Summary

**Before You Start**:
- [ ] All migrations executed (002, 004, 005, 006 policies, 007)
- [ ] App fully restarted
- [ ] Storage bucket created
- [ ] Internet connection stable

**Quick 30-Minute Test** (Core Features):
1. [ ] View subscriptions (2 min)
2. [ ] Create event with flyer (8 min)
3. [ ] Add 2 ticket tiers (8 min)
4. [ ] Add 2 DJs to lineup (8 min)
5. [ ] Edit business profile (4 min)

**Full 90-Minute Test** (All Features):
- Follow all 14 sections above
- Check off each item in Feature Summary table
- Take screenshots for documentation
- Note any issues or unexpected behavior

---

## Success Criteria

✅ **All features working** if:
- Events create and display correctly
- Images upload successfully
- Ticket tiers save with proper validation
- Team members appear in lineup
- Subscriptions show all 4 plans
- Business profile updates persist
- No critical errors or crashes

🟡 **Partial success** if:
- Core features work (events, tickets, team)
- Stripe features show "Coming Soon" (expected if not configured)
- Minor UI issues but functionality works

🔴 **Needs attention** if:
- Events don't display after creation
- Database errors on save operations
- Images fail to upload
- App crashes on any feature

---

## Next Steps After Validation

1. **Document Issues**: Note any failing tests
2. **Take Screenshots**: Capture successful features
3. **Report Bugs**: List any errors encountered
4. **Request Fixes**: Share validation results for debugging
5. **Plan Deployment**: If all tests pass, prepare for production

---

**Questions or Issues?**
If you encounter problems during validation, note:
- Which step failed
- Error message (if any)
- Screenshots of the issue
- Expected vs actual behavior

This helps quickly identify and fix issues!
