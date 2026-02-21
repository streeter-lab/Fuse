-- ============================================================
-- FUSE Fitness - Seed Classes
-- Run this in the Supabase SQL Editor AFTER supabase-setup.sql.
--
-- 1. Inserts the recurring weekly class templates
-- 2. Generates the first 4 weeks of bookable class instances
-- ============================================================

-- Clear existing data (safe for initial setup / re-seeding)
DELETE FROM public.bookings;
DELETE FROM public.classes;
DELETE FROM public.class_templates;

-- ── INSERT CLASS TEMPLATES ────────────────────────────────
-- day_of_week: 1=Monday, 2=Tuesday, ..., 7=Sunday
-- Default capacity: 20 | Default location: Studio | Instructor: TBC

INSERT INTO public.class_templates
  (title, instructor, description, day_of_week, start_time, end_time, capacity, location)
VALUES
  -- Monday
  ('Lower Body Conditioning', 'TBC',
    'Targeted lower body strength and conditioning workout.',
    1, '17:45', '18:30', 20, 'Studio'),
  ('Spinning', 'TBC',
    'High-energy indoor cycling session.',
    1, '18:30', '19:15', 20, 'Studio'),

  -- Tuesday
  ('Dumbbell Shred', 'TBC',
    'Full-body dumbbell workout to build strength and burn fat.',
    2, '18:00', '19:00', 20, 'Studio'),
  ('Upper Body Conditioning', 'TBC',
    'Focused upper body strength and conditioning.',
    2, '19:00', '19:45', 20, 'Studio'),

  -- Wednesday
  ('Spinning', 'TBC',
    'Midweek indoor cycling session.',
    3, '18:00', '18:45', 20, 'Studio'),
  ('ATHX Strength', 'TBC',
    'Athletic strength training session.',
    3, '18:50', '19:50', 20, 'Studio'),

  -- Thursday
  ('HYROX', 'TBC',
    'HYROX-style functional fitness training.',
    4, '18:15', '19:30', 20, 'Studio'),

  -- Friday
  ('Boxfit Circuit', 'TBC',
    'Boxing-inspired circuit training for cardio and strength.',
    5, '18:15', '19:15', 20, 'Studio'),

  -- Saturday
  ('Spinning', 'TBC',
    'Weekend morning cycling session.',
    6, '09:00', '09:45', 20, 'Studio'),

  -- Sunday
  ('Sweat Workout of the Day', 'TBC',
    'High-intensity workout of the day.',
    7, '09:30', '10:30', 20, 'Studio');

-- ── GENERATE FIRST 4 WEEKS OF CLASSES ─────────────────────
-- Creates bookable class instances from the templates above,
-- starting from the Monday of the current week.

DO $$
DECLARE
  week_start date;
  i integer;
  v_template record;
  v_class_date date;
BEGIN
  -- Use UK timezone so class times are correct across GMT/BST
  PERFORM set_config('timezone', 'Europe/London', true);

  -- Start from the Monday of the current week
  week_start := date_trunc('week', CURRENT_DATE)::date;

  FOR i IN 0..3 LOOP
    FOR v_template IN
      SELECT * FROM public.class_templates WHERE is_active = true
    LOOP
      -- Calculate the actual date for this template's day in the given week
      v_class_date := week_start + (i * 7) + (v_template.day_of_week - 1);

      -- Only insert if not already existing (duplicate-safe)
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
      END IF;
    END LOOP;
  END LOOP;
END $$;
