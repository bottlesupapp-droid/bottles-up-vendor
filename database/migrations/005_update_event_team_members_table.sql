-- Migration: Ensure event_team_members table exists
-- Date: 2026-04-29
-- Description: Creates or updates event_team_members table for team/DJ management

-- Create event_team_members table if not exists
CREATE TABLE IF NOT EXISTS event_team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    role TEXT NOT NULL CHECK (role IN ('Coordinator', 'Security', 'Bartender', 'Host', 'Manager', 'Staff', 'Photographer', 'DJ')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_team_members_event_id ON event_team_members(event_id);
CREATE INDEX IF NOT EXISTS idx_event_team_members_role ON event_team_members(role);

-- Create trigger for updated_at
CREATE TRIGGER trigger_event_team_members_updated_at
    BEFORE UPDATE ON event_team_members
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_updated_at(); -- Reuse existing function

-- Add comments
COMMENT ON TABLE event_team_members IS 'Team members assigned to events including DJs, coordinators, security, etc.';
COMMENT ON COLUMN event_team_members.role IS 'Role of team member: Coordinator, Security, Bartender, Host, Manager, Staff, Photographer, DJ';
