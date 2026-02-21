# FUSE Fitness - Class Booking App

## Overview
A static frontend web app for FUSE Fitness, allowing members to view and book fitness classes. Staff can manage schedules and bookings via an admin panel. HYROX & ATHX affiliated training.

## Tech Stack
- **Frontend:** Vanilla HTML/CSS/JavaScript (no frameworks, no build tools)
- **Backend/Database:** Supabase (auth + Postgres)
- **Hosting:** Static files compatible with Netlify / Cloudflare Pages
- **Supabase JS:** Loaded via CDN (v2)

## Supabase Credentials
- URL: `https://zszqwhmjwjnhfgpentyj.supabase.co`
- Anon Key: `sb_publishable_w48KQDyj-RGEWQbvhqlJOw_cDlN197C`

## Supabase Configuration
- **Email verification:** Disabled. In Supabase Dashboard go to Authentication > Providers > Email > Turn OFF "Confirm email".

## Database Tables
1. **profiles** - extends auth.users (id, full_name, phone, membership_type, is_admin, created_at)
2. **classes** - gym classes/sessions (id, title, instructor, description, start_time, end_time, capacity, location, is_cancelled, created_at)
3. **bookings** - member bookings (id, class_id, member_id, status, booked_at)

## RLS Policies
- profiles: users read/update own row only
- classes: anyone can read, admins insert/update
- bookings: users manage own bookings, admins read all

## Pages
| File | Purpose |
|------|---------|
| index.html | Landing page with branding |
| login.html | Email/password login |
| register.html | Sign up form (no email verification) |
| schedule.html | Weekly class schedule (public) |
| dashboard.html | Member dashboard (authenticated) |
| book.html | Class detail + booking |
| admin.html | Admin panel (admin only) |

## Key Features
- Weekly schedule view with live availability
- Book / cancel classes with capacity management
- Waitlist with auto-promotion on cancellation
- Admin CRUD for classes + booking viewer
- Mobile-first responsive design
- No email verification — instant account activation

## Brand
- **Name:** FUSE Fitness
- **Palette:** Copper (#D4894A) accent + Dark Denim Blue (#1B2D44) header
- **Website:** https://fuse-fitness.co.uk

## File Structure
```
gym-booking/
  index.html, login.html, register.html, schedule.html,
  dashboard.html, book.html, admin.html
  css/style.css, css/admin.css
  js/supabase.js, js/auth.js, js/schedule.js,
  js/bookings.js, js/admin.js, js/utils.js
  BRIEF.md
  supabase-setup.sql
  seed-classes.sql
```
