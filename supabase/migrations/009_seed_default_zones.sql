-- Seed default zones for events
-- These zones represent common venue areas

INSERT INTO zones (id, name, description, capacity, ticket_price, zone_type, is_active, created_at, updated_at)
VALUES
  (gen_random_uuid(), 'General Admission', 'Standard entry area', 200, 25.00, 'general', true, now(), now()),
  (gen_random_uuid(), 'VIP Section', 'Premium area with exclusive amenities', 50, 75.00, 'vip', true, now(), now()),
  (gen_random_uuid(), 'Table Service', 'Reserved table with bottle service', 8, 150.00, 'table', true, now(), now()),
  (gen_random_uuid(), 'Dance Floor', 'Main dance area', 150, 30.00, 'general', true, now(), now()),
  (gen_random_uuid(), 'Rooftop', 'Open-air rooftop area', 100, 40.00, 'premium', true, now(), now())
ON CONFLICT DO NOTHING;
