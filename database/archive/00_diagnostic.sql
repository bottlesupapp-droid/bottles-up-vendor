-- =====================================================
-- DIAGNOSTIC QUERY
-- Run this FIRST to check your schema structure
-- =====================================================

-- Check columns in events table
SELECT 'EVENTS TABLE COLUMNS:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- Check columns in events_bookings table
SELECT 'EVENTS_BOOKINGS TABLE COLUMNS:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'events_bookings'
ORDER BY ordinal_position;

-- Check columns in clubs table
SELECT 'CLUBS TABLE COLUMNS:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'clubs'
ORDER BY ordinal_position;

-- Check columns in venues table
SELECT 'VENUES TABLE COLUMNS:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'venues'
ORDER BY ordinal_position;

-- Sample data from events table
SELECT 'SAMPLE EVENT RECORD:' as info;
SELECT * FROM events LIMIT 1;

-- Sample data from events_bookings table
SELECT 'SAMPLE BOOKING RECORD:' as info;
SELECT * FROM events_bookings LIMIT 1;
