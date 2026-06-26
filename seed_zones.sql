-- ✅ ZONES ALREADY SEEDED - NO ACTION NEEDED
-- Database already has 6 zones configured correctly

-- CORRECT zone_type values (database constraint):
-- 'general', 'vip', 'premium', 'balcony', 'floor', 'bar_area'

-- Current zones in database:
-- 1. General Admission (general) - 200 capacity - ₹5,000
-- 2. Bar Area (bar_area) - 80 capacity - ₹6,000
-- 3. Main Dance Floor (floor) - 150 capacity - ₹7,500
-- 4. Premium Balcony (premium) - 30 capacity - ₹10,000
-- 5. VIP Section (vip) - 50 capacity - ₹15,000
-- 6. Ultra VIP (vip) - 20 capacity - ₹25,000

-- To verify zones in database:
SELECT id, name, zone_type, capacity, ticket_price
FROM zones
WHERE is_active = true
ORDER BY ticket_price;
