-- Cadence Polymorphic Entries Migration
-- Creates the entries table for sync with offline-first Drift database and LWW conflict resolution.

CREATE TABLE IF NOT EXISTS public.entries (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    unit TEXT,
    note TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Indexing for user queries, type filtering, and delta sync cursor
CREATE INDEX IF NOT EXISTS idx_entries_user_id ON public.entries (user_id);
CREATE INDEX IF NOT EXISTS idx_entries_updated_at ON public.entries (updated_at);
CREATE INDEX IF NOT EXISTS idx_entries_occurred_at ON public.entries (occurred_at);
CREATE INDEX IF NOT EXISTS idx_entries_type ON public.entries (type);

-- Enable Row Level Security (RLS)
ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can query their own entries" ON public.entries;
CREATE POLICY "Users can query their own entries"
    ON public.entries FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own entries" ON public.entries;
CREATE POLICY "Users can insert their own entries"
    ON public.entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own entries" ON public.entries;
CREATE POLICY "Users can update their own entries"
    ON public.entries FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own entries" ON public.entries;
CREATE POLICY "Users can delete their own entries"
    ON public.entries FOR DELETE
    USING (auth.uid() = user_id);
