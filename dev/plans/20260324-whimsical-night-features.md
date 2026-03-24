# A Whimsical Night - Feature Additions

## Feature 1: Per-Performance Ticket URLs
- [x] Migration: `add_ticket_url_to_performances` adds `:ticket_url` string column
- [x] Performance schema: added `ticket_url` field + `validate_url/2`
- [x] Performance form component: added URL input field
- [x] Admin show page: added Tickets column to performances table
- [x] Public productions page: shows per-performance ticket buttons (date + time) when available, falls back to production-level ticket URL

## Feature 2: TinyMCE Rich Text Editor
- [x] TinyMCE loaded from CDN (`cdn.jsdelivr.net/npm/tinymce@7`) in admin_root layout
- [x] LiveView hook `TinyMCE` in app.js initializes editor on textarea, syncs content back
- [x] Production form: description textarea wrapped with `phx-hook="TinyMCE"` + `phx-update="ignore"`
- [x] Admin show page: renders description as HTML with `raw()`
- [x] Public pages: renders description as HTML with `raw()` + `.rich-text` CSS class
- [x] Added `.rich-text` CSS rules in app.css for paragraphs, lists, links

## Feature 3: Upcoming Production on Home Page
- [x] PageController `home/2` queries `list_upcoming_productions()` and passes first result
- [x] Home page template: shows production card between hero and "What Makes Us Special"
- [x] Includes main image, title, date range, description (rich text), and ticket buttons

## Data Entry for "A Whimsical Night"
After deploying, create the production via admin and add:
- Title: "A Whimsical Night!"
- Description: (use TinyMCE to format the event description with paragraphs)
- Location: Nortonville Gospel Chapel
- Address: 14528 Leonard Rd, Spring Lake, MI, 49456
- Admission: 0 (FREE)
- Status: Published
- Performances:
  - Fri Apr 24, 2026 6:30 PM — ticket_url: https://www.eventbrite.com/e/1984204401779?aff=oddtdtcreator
  - Sat Apr 25, 2026 2:00 PM — ticket_url: https://www.eventbrite.com/e/1984343357399?aff=oddtdtcreator
  - Sat Apr 25, 2026 6:30 PM — ticket_url: https://www.eventbrite.com/e/1984344170832?aff=oddtdtcreator
