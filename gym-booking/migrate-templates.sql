-- ============================================================
-- FUSE Fitness - Migration: Add Class Templates
-- Run this in the Supabase SQL Editor on an EXISTING database
-- that already has supabase-setup.sql applied.
--
-- This is safe to re-run: all statements use IF NOT EXISTS
-- or CREATE OR REPLACE where applicable.
-- ============================================================

-- 1. Create class_templates table
-- ----------------------------------------------------------
create table if not exists public.class_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructor text not null default 'TBC',
  description text,
  day_of_week integer not null check (day_of_week between 1 and 7), -- ISO: 1=Mon, 7=Sun
  start_time time not null,
  end_time time not null,
  capacity integer not null default 20 check (capacity > 0),
  location text not null default 'Studio',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 2. Add template_id column to classes (skip if already exists)
-- ----------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'classes' AND column_name = 'template_id'
  ) THEN
    ALTER TABLE public.classes
      ADD COLUMN template_id uuid REFERENCES public.class_templates(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Index on template_id
CREATE INDEX IF NOT EXISTS idx_classes_template_id ON public.classes(template_id);

-- Allow instructor to default to 'TBC' for template-generated classes
ALTER TABLE public.classes ALTER COLUMN instructor SET DEFAULT 'TBC';

-- 3. Enable RLS on class_templates
-- ----------------------------------------------------------
ALTER TABLE public.class_templates ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies (drop first to make re-runnable)
-- ----------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can view class templates" ON public.class_templates;
CREATE POLICY "Anyone can view class templates"
  ON public.class_templates FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can insert class templates" ON public.class_templates;
CREATE POLICY "Admins can insert class templates"
  ON public.class_templates FOR INSERT
  WITH CHECK ( public.is_admin() );

DROP POLICY IF EXISTS "Admins can update class templates" ON public.class_templates;
CREATE POLICY "Admins can update class templates"
  ON public.class_templates FOR UPDATE
  USING ( public.is_admin() );

DROP POLICY IF EXISTS "Admins can delete class templates" ON public.class_templates;
CREATE POLICY "Admins can delete class templates"
  ON public.class_templates FOR DELETE
  USING ( public.is_admin() );

-- 5. Class generation function
-- ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_classes_for_week(p_week_start date)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_template record;
  v_class_date date;
  v_count integer := 0;
BEGIN
  -- Block non-admin authenticated users; allow pg_cron (no auth context)
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can generate classes.';
  END IF;

  -- Use UK timezone so class times are correct across GMT/BST
  PERFORM set_config('timezone', 'Europe/London', true);

  FOR v_template IN
    SELECT * FROM public.class_templates WHERE is_active = true
  LOOP
    -- day_of_week: 1=Mon(+0), 2=Tue(+1), ..., 7=Sun(+6)
    v_class_date := p_week_start + (v_template.day_of_week - 1);

    -- Skip if a class from this template already exists on this date
    IF NOT EXISTS (
      SELECT 1 FROM public.classes
      WHERE template_id = v_template.id
        AND (start_time AT TIME ZONE 'Europe/London')::date = v_class_date
    ) THEN
      INSERT INTO public.classes (
        title, instructor, description, start_time, end_time,
        capacity, location, template_id
      ) VALUES (
        v_template.title,
        v_template.instructor,
        v_template.description,
        (v_class_date + v_template.start_time) AT TIME ZONE 'Europe/London',
        (v_class_date + v_template.end_time) AT TIME ZONE 'Europe/London',
        v_template.capacity,
        v_template.location,
        v_template.id
      );
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

-- ── OPTIONAL: Automated weekly generation with pg_cron ──────────
-- To automatically generate the next week's classes every Sunday at 22:00:
--
--   SELECT cron.schedule(
--     'generate-weekly-classes',
--     '0 22 * * 0',  -- Sunday at 22:00 UTC
--     $$SELECT public.generate_classes_for_week(
--       (date_trunc('week', CURRENT_DATE) + interval '7 days')::date
--     )$$
--   );
--
-- Enable pg_cron in: Supabase Dashboard > Database > Extensions > pg_cron
