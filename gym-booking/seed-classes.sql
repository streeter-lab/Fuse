-- ============================================================
-- FUSE Fitness - Seed Classes
-- Run this in the Supabase SQL Editor AFTER supabase-setup.sql.
-- Populates the weekly timetable for the next 4 weeks.
-- ============================================================

-- Helper: generate classes for a given week starting on Monday.
-- We use a DO block to loop over 4 weeks starting from the next Monday.

DO $$
DECLARE
  week_start date;
  i integer;
BEGIN
  -- Start from the Monday of this week (or next Monday if today is after Monday)
  week_start := date_trunc('week', CURRENT_DATE)::date;

  FOR i IN 0..3 LOOP

    -- ── MONDAY ──────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('Spin',       'Sarah J.', 'High-energy indoor cycling session. All levels welcome.',
      (week_start + i*7)::timestamp + interval '6 hours',
      (week_start + i*7)::timestamp + interval '6 hours 45 minutes', 20, 'Studio 1'),
    ('Yoga',       'Mike R.',  'Vinyasa flow to build flexibility and strength.',
      (week_start + i*7)::timestamp + interval '9 hours 30 minutes',
      (week_start + i*7)::timestamp + interval '10 hours 30 minutes', 25, 'Studio 2'),
    ('HIIT',       'Sarah J.', 'Fast-paced high-intensity interval training. Torch calories.',
      (week_start + i*7)::timestamp + interval '12 hours 15 minutes',
      (week_start + i*7)::timestamp + interval '12 hours 45 minutes', 30, 'Main Floor'),
    ('Body Pump',  'Chris T.', 'Barbell-based strength workout targeting all major muscle groups.',
      (week_start + i*7)::timestamp + interval '17 hours 30 minutes',
      (week_start + i*7)::timestamp + interval '18 hours 15 minutes', 25, 'Studio 1'),
    ('Spin',       'Sarah J.', 'Evening cycling session to close out the day strong.',
      (week_start + i*7)::timestamp + interval '18 hours 30 minutes',
      (week_start + i*7)::timestamp + interval '19 hours 15 minutes', 20, 'Studio 1');

    -- ── TUESDAY ─────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('HIIT',       'Chris T.', 'Early morning HIIT to kickstart your day.',
      (week_start + i*7 + 1)::timestamp + interval '6 hours',
      (week_start + i*7 + 1)::timestamp + interval '6 hours 30 minutes', 30, 'Main Floor'),
    ('Pilates',    'Emma L.',  'Core-focused mat Pilates for posture and stability.',
      (week_start + i*7 + 1)::timestamp + interval '9 hours 30 minutes',
      (week_start + i*7 + 1)::timestamp + interval '10 hours 15 minutes', 20, 'Studio 2'),
    ('Spin',       'Sarah J.', 'Lunchtime ride to keep your energy up.',
      (week_start + i*7 + 1)::timestamp + interval '12 hours 15 minutes',
      (week_start + i*7 + 1)::timestamp + interval '13 hours', 20, 'Studio 1'),
    ('Yoga',       'Mike R.',  'Evening wind-down yoga session.',
      (week_start + i*7 + 1)::timestamp + interval '17 hours 30 minutes',
      (week_start + i*7 + 1)::timestamp + interval '18 hours 30 minutes', 25, 'Studio 2'),
    ('BoxFit',     'Chris T.', 'Boxing-inspired cardio and conditioning.',
      (week_start + i*7 + 1)::timestamp + interval '18 hours 45 minutes',
      (week_start + i*7 + 1)::timestamp + interval '19 hours 30 minutes', 25, 'Main Floor');

    -- ── WEDNESDAY ───────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('Spin',       'Sarah J.', 'Midweek morning spin to keep the momentum going.',
      (week_start + i*7 + 2)::timestamp + interval '6 hours',
      (week_start + i*7 + 2)::timestamp + interval '6 hours 45 minutes', 20, 'Studio 1'),
    ('Body Pump',  'Chris T.', 'Full-body barbell workout — push your limits.',
      (week_start + i*7 + 2)::timestamp + interval '9 hours 30 minutes',
      (week_start + i*7 + 2)::timestamp + interval '10 hours 15 minutes', 25, 'Studio 1'),
    ('Yoga',       'Mike R.',  'Lunchtime stretch and flow.',
      (week_start + i*7 + 2)::timestamp + interval '12 hours 15 minutes',
      (week_start + i*7 + 2)::timestamp + interval '13 hours', 25, 'Studio 2'),
    ('HIIT',       'Sarah J.', 'Evening HIIT blast — 30 minutes, max effort.',
      (week_start + i*7 + 2)::timestamp + interval '17 hours 30 minutes',
      (week_start + i*7 + 2)::timestamp + interval '18 hours', 30, 'Main Floor'),
    ('Pilates',    'Emma L.',  'Evening Pilates for core and flexibility.',
      (week_start + i*7 + 2)::timestamp + interval '18 hours 15 minutes',
      (week_start + i*7 + 2)::timestamp + interval '19 hours', 20, 'Studio 2');

    -- ── THURSDAY ────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('HIIT',       'Chris T.', 'Early riser HIIT to get the blood pumping.',
      (week_start + i*7 + 3)::timestamp + interval '6 hours',
      (week_start + i*7 + 3)::timestamp + interval '6 hours 30 minutes', 30, 'Main Floor'),
    ('Spin',       'Sarah J.', 'Mid-morning cycling session.',
      (week_start + i*7 + 3)::timestamp + interval '9 hours 30 minutes',
      (week_start + i*7 + 3)::timestamp + interval '10 hours 15 minutes', 20, 'Studio 1'),
    ('Pilates',    'Emma L.',  'Lunchtime Pilates — strengthen and lengthen.',
      (week_start + i*7 + 3)::timestamp + interval '12 hours 15 minutes',
      (week_start + i*7 + 3)::timestamp + interval '13 hours', 20, 'Studio 2'),
    ('BoxFit',     'Chris T.', 'Punch your way to fitness.',
      (week_start + i*7 + 3)::timestamp + interval '17 hours 30 minutes',
      (week_start + i*7 + 3)::timestamp + interval '18 hours 15 minutes', 25, 'Main Floor'),
    ('Body Pump',  'Chris T.', 'Evening strength session with barbells.',
      (week_start + i*7 + 3)::timestamp + interval '18 hours 30 minutes',
      (week_start + i*7 + 3)::timestamp + interval '19 hours 15 minutes', 25, 'Studio 1');

    -- ── FRIDAY ──────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('Spin',       'Sarah J.', 'Friday morning spin — ride into the weekend.',
      (week_start + i*7 + 4)::timestamp + interval '6 hours',
      (week_start + i*7 + 4)::timestamp + interval '6 hours 45 minutes', 20, 'Studio 1'),
    ('HIIT',       'Chris T.', 'Quick HIIT to finish the working week.',
      (week_start + i*7 + 4)::timestamp + interval '9 hours 30 minutes',
      (week_start + i*7 + 4)::timestamp + interval '10 hours', 30, 'Main Floor'),
    ('Body Pump',  'Chris T.', 'Lunchtime pump — lift heavy, feel strong.',
      (week_start + i*7 + 4)::timestamp + interval '12 hours 15 minutes',
      (week_start + i*7 + 4)::timestamp + interval '13 hours', 25, 'Studio 1'),
    ('Yoga',       'Mike R.',  'Slow-flow Friday evening yoga.',
      (week_start + i*7 + 4)::timestamp + interval '17 hours 30 minutes',
      (week_start + i*7 + 4)::timestamp + interval '18 hours 30 minutes', 25, 'Studio 2');

    -- ── SATURDAY ────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('HIIT',       'Chris T.', 'Weekend warrior HIIT.',
      (week_start + i*7 + 5)::timestamp + interval '8 hours',
      (week_start + i*7 + 5)::timestamp + interval '8 hours 45 minutes', 30, 'Main Floor'),
    ('Spin',       'Sarah J.', 'Saturday morning ride.',
      (week_start + i*7 + 5)::timestamp + interval '9 hours',
      (week_start + i*7 + 5)::timestamp + interval '9 hours 45 minutes', 20, 'Studio 1'),
    ('Yoga',       'Mike R.',  'Weekend yoga to recharge.',
      (week_start + i*7 + 5)::timestamp + interval '10 hours',
      (week_start + i*7 + 5)::timestamp + interval '11 hours', 25, 'Studio 2'),
    ('Body Pump',  'Chris T.', 'Saturday strength session.',
      (week_start + i*7 + 5)::timestamp + interval '11 hours 15 minutes',
      (week_start + i*7 + 5)::timestamp + interval '12 hours', 25, 'Studio 1');

    -- ── SUNDAY ──────────────────────────────────
    INSERT INTO public.classes (title, instructor, description, start_time, end_time, capacity, location) VALUES
    ('Yoga',       'Mike R.',  'Sunday morning slow yoga.',
      (week_start + i*7 + 6)::timestamp + interval '9 hours',
      (week_start + i*7 + 6)::timestamp + interval '10 hours', 25, 'Studio 2'),
    ('Pilates',    'Emma L.',  'Sunday Pilates to stretch and recover.',
      (week_start + i*7 + 6)::timestamp + interval '10 hours 15 minutes',
      (week_start + i*7 + 6)::timestamp + interval '11 hours', 20, 'Studio 2'),
    ('Spin',       'Sarah J.', 'Sunday spin to close out the week.',
      (week_start + i*7 + 6)::timestamp + interval '11 hours 15 minutes',
      (week_start + i*7 + 6)::timestamp + interval '12 hours', 20, 'Studio 1');

  END LOOP;
END $$;
