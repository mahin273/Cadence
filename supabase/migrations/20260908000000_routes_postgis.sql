-- Cadence PostGIS Routes Migration
-- Enables spatial geometries and creates the remote routes table with GiST indexing.

-- 1. Enable PostGIS Extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create Routes Table with Geometry Column
CREATE TABLE IF NOT EXISTS public.routes (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Outdoor Activity',
    activity_type TEXT NOT NULL DEFAULT 'walk',
    status TEXT NOT NULL DEFAULT 'completed',
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    total_distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    avg_pace_seconds_per_km DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    geometry geometry(Geometry, 4326),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create Spatial Index using GiST for fast geospatial search
CREATE INDEX IF NOT EXISTS idx_routes_geometry ON public.routes USING GIST (geometry);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
CREATE POLICY "Users can query their own routes"
    ON public.routes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own routes"
    ON public.routes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own routes"
    ON public.routes FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own routes"
    ON public.routes FOR DELETE
    USING (auth.uid() = user_id);
