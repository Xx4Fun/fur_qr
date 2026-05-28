# Project Overview: Fur Parent Bridge (Smart Pet Tag System)

## 🎯 The Goal
Build a privacy-first, full-stack smart pet tag application. Pet owners use a mobile app to register their pets and generate a unique QR code. When a lost pet is found, the finder scans the QR code with their native phone camera, which opens an instant, app-free web portal. The finder can read the pet's public information and click "Contact Owner," which instantly sends a push notification to the owner's mobile app *without* exposing the owner's phone number or home address.

---

## 🛠️ The Tech Stack

### 1. Frontend: Mobile App (For Pet Owners)
*   **Framework:** Flutter (Dart)
*   **Core Packages:**
    *   `supabase_flutter`: For Auth, Database CRUD, and Realtime listeners.
    *   `qr_flutter`: To generate the QR code visually on the screen.
    *   `isar`: For offline-first local caching of the owner's pet profiles.
    *   `firebase_messaging`: To receive push notifications when a tag is scanned.

### 2. Frontend: Web View (For Finders)
*   **Framework:** Vanilla JS + HTML + Tailwind CSS (or Flutter Web)
*   **Hosting:** Firebase Hosting
*   **Purpose:** A hyper-fast, lightweight page located at `https://fur-qr-project.web.app/tag/[tag_id]` that reads public pet data from Supabase.

### 3. Backend & Database (The Engine)
*   **Platform:** Supabase
*   **Database:** PostgreSQL (with JSONB support for flexible pet attributes)
*   **Security:** Strict Row Level Security (RLS) to separate public pet data from private owner data.
*   **Logic:** Supabase Edge Functions (Deno/TypeScript) to bridge the web-view button click to the Firebase Cloud Messaging (FCM) push notification.

---

## 🗄️ Database Architecture & RLS Security

The database must be structured to ensure absolute privacy for the owner. 

### Tables Required:
1.  **`owners`**: 
    *   `id` (UUID, references `auth.users`)
    *   `full_name` (Text)
    *   `phone_number` (Text)
    *   *RLS Policy:* ONLY the authenticated owner can read/write their own row. No public access.
2.  **`pets`**:
    *   `id` (UUID)
    *   `owner_id` (UUID, references `owners.id`)
    *   `name` (Text)
    *   `photo_url` (Text)
    *   `public_notes` (Text)
    *   `attributes` (JSONB - for flexible data like diet, microchip, etc.)
    *   *RLS Policy:* Public can `SELECT` (read-only). Only the `owner_id` can `UPDATE` or `DELETE`.
3.  **`tags`**:
    *   `id` (UUID - This is the URL parameter)
    *   `pet_id` (UUID, references `pets.id`)
    *   `is_active` (Boolean)
    *   *RLS Policy:* Public can `SELECT` where `is_active = true`. Only owner can modify.
4.  **`scans`** (Optional tracking table):
    *   `id` (UUID)
    *   `tag_id` (UUID)
    *   `scan_location` (PostGIS / LatLng)
    *   `created_at` (Timestamp)

---

## 🚀 Execution Roadmap for Gemini CLI

**Instructions for the AI Agent:** Read these phases sequentially. Do not proceed to the next phase until the current phase is fully implemented and tested.

### Phase 1: Backend Scaffolding (Supabase MCP)
1.  Use the Supabase MCP to execute the SQL needed to create the `owners`, `pets`, `tags`, and `scans` tables.
2.  Apply the exact Row Level Security (RLS) policies defined above.
3.  Set up a Supabase Storage bucket named `pet_avatars` and apply a policy allowing public reads, but authenticated uploads.

### Phase 2: Edge Function Setup (Notifications)
1.  Create a Supabase Edge Function named `notify-owner`.
2.  Write the Deno/TypeScript code to accept a POST request containing a `tag_id`.
3.  Query the database to find the `owner_id` linked to that `tag_id`.
4.  Securely trigger the Firebase Cloud Messaging (FCM) API using the server-side credentials stored in Supabase Secrets to push an alert to the owner.

### Phase 3: The Flutter Owner App
1.  Initialize a new Flutter project and inject the necessary dependencies (`supabase_flutter`, `qr_flutter`, `isar`, `firebase_messaging`).
2.  Generate the Isar schema for local offline caching of the `pets` table.
3.  Build the Auth flow (Login/Sign up via Supabase).
4.  Build the Pet Dashboard UI:
    *   A form to add a pet (uploads photo to Supabase Storage, saves data to Postgres).
    *   A detail screen that automatically generates and displays the `qr_flutter` widget based on the pet's generated `tag_id`.
5.  Implement FCM listener in the background to handle incoming "Tag Scanned" alerts.

### Phase 4: The Finder Web View
1.  Generate a simple, mobile-responsive HTML/JS page (or Flutter Web project).
2.  Implement the logic to extract the `tag_id` from the URL parameters.
3.  Use the Supabase JS client to query the `pets` and `tags` table securely (read-only). Display the pet's photo and name.
4.  Create the "Contact Owner" button. Attach an event listener that POSTs to the `notify-owner` Supabase Edge Function created in Phase 2.