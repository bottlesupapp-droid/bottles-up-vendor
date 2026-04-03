-- Migration: Fix v_event_performance view to include user_id
-- Date: 2026-04-03
-- Purpose: Add user_id column to v_event_performance view for proper filtering

-- Drop and recreate the view with user_id column
CREATE OR REPLACE VIEW v_event_performance AS
SELECT
  e.id as event_id,
  e.name as event_name,
  e.user_id,
  e.max_capacity as total_tickets,
  e.current_bookings as sold_tickets,
  e.rsvp_count,
  COUNT(b.id) FILTER (WHERE b.checked_in = true) as checked_in_count,
  ROUND((e.current_bookings::NUMERIC / NULLIF(e.max_capacity, 0) * 100), 2) as conversion_rate,
  ROUND((COUNT(b.id) FILTER (WHERE b.checked_in = true)::NUMERIC / NULLIF(e.current_bookings, 0) * 100), 2) as attendance_rate,
  ROUND((e.revenue::NUMERIC / NULLIF(e.current_bookings, 0)), 2) as revenue_per_ticket
FROM events e
LEFT JOIN bookings b ON e.id = b.event_id
GROUP BY e.id, e.name, e.user_id, e.max_capacity, e.current_bookings, e.rsvp_count, e.revenue;
