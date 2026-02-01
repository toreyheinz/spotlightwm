# Feature Plan: Production Event Management

**Status**: Planning
**Created**: 2026-02-01
**Author**: Claude

## Overview

Enable Debbie (and future admins) to manage production events through a web interface. This replaces the current hardcoded production data with a database-driven system. The focus is content management only—ticket sales/checkins are out of scope for now.

## Requirements

### Content Management
- [ ] Create/edit/delete productions
- [ ] Set production details: title, description, dates, location, price, ticket link
- [ ] Upload main production image
- [ ] Upload gallery photos (multiple)
- [ ] Display location with embedded map
- [ ] Mark productions as current/upcoming/past

### Authentication
- [ ] Admin login (small team: ~3 users)
- [ ] Protected admin routes
- [ ] No public registration - admins manually invite/add users
- [ ] Simple user management in admin panel

### Image Hosting
- [ ] Host images on Cloudflare R2 (S3-compatible)
- [ ] Direct browser upload to avoid server load
- [ ] Image optimization/resizing

## Technical Approach

### Architecture Decisions

1. **Phoenix LiveView for Admin UI**
   - Already included in the project
   - Real-time form validation and uploads
   - No separate frontend framework needed

2. **Cloudflare R2 for Image Storage**
   - S3-compatible API works with existing Elixir libraries
   - Use `ex_aws` + `ex_aws_s3` for uploads
   - Direct browser uploads via presigned URLs to reduce server load

3. **phx.gen.auth for Authentication**
   - Built into Phoenix, no external dependencies
   - Generates secure, well-tested auth code
   - Customize for invite-only: remove registration routes, add admin user creation
   - Small team (~3 users), manually added via admin panel

4. **Soft Launch Approach**
   - Build admin system first
   - Keep static pages working during development
   - Switch to dynamic rendering once admin is stable

### Database Schema

```
productions
├── id (uuid)
├── title (string)
├── description (text)
├── location_name (string, e.g., "Spotlight Theater")
├── location_query (string, e.g., "Spotlight Theater, Grand Rapids MI")
├── price (string, e.g., "$15 adults / $10 students")
├── ticket_url (string)
├── main_image_url (string)
├── status (enum: draft/published/archived)
├── inserted_at
└── updated_at

performances (individual show times)
├── id (uuid)
├── production_id (references productions)
├── starts_at (datetime)
├── ends_at (datetime, nullable)
├── notes (string, nullable, e.g., "Preview Night", "Matinee")
├── inserted_at
└── updated_at

production_photos
├── id (uuid)
├── production_id (references productions)
├── url (string)
├── caption (string, nullable)
├── position (integer, for ordering)
├── inserted_at
└── updated_at

users
├── id (uuid)
├── email (string)
├── name (string)
├── hashed_password (string)
├── confirmed_at (datetime)
├── inserted_at
└── updated_at
```

### Display Logic

- **Opening night**: First performance `starts_at`
- **Closing night**: Last performance `starts_at`
- **Date range display**: "Feb 7-8, 14-15" computed from performances
- **Visibility**: Productions visible for 180 days after last performance, then auto-archived
- **Map**: Google Maps Embed API using `location_query` (e.g., `?q=Spotlight+Theater,+Grand+Rapids+MI`)
- **Images**: Cropped client-side (Cropper.js), resized before upload, stored on Cloudflare R2

## Implementation Tasks

### Phase 1: Foundation
- [ ] Run `mix phx.gen.auth Accounts User users` for authentication
- [ ] Add `name` field to User schema
- [ ] Create admin scope in router with auth requirement
- [ ] Create `Spotlight.Productions` context
- [ ] Generate Production schema and migration
- [ ] Generate Performance schema and migration (show times)
- [ ] Generate ProductionPhoto schema and migration
- [ ] Seed database with current production data

### Phase 2: Cloudflare R2 Integration
- [ ] Add `ex_aws` and `ex_aws_s3` dependencies
- [ ] Configure R2 credentials (via runtime config/.env)
- [ ] Create `Spotlight.Uploads` context for presigned URLs
- [ ] Build upload component with LiveView uploads
- [ ] Add Cropper.js for client-side image cropping (LiveView hook)
- [ ] Add client-side image resize before upload
- [ ] Test direct browser upload flow

### Phase 3: Admin Interface
- [ ] Create admin layout (simple, functional)
- [ ] Build production list view (`/admin/productions`)
- [ ] Build production form (new/edit)
- [ ] Build performance scheduler (add/edit/remove show times)
- [ ] Add image upload to production form
- [ ] Build photo gallery management (reorder, delete)
- [ ] Add location picker with Google Maps preview
- [ ] Build user management (`/admin/users`) - invite/add users

### Phase 4: Public Site Integration
- [ ] Update `PageController.productions` to query database
- [ ] Update productions template to render dynamic data
- [ ] Implement image URLs from Cloudflare R2
- [ ] Add map embed for production location

### Phase 5: Polish
- [ ] Add flash messages for admin actions
- [ ] Implement draft/publish workflow
- [ ] Auto-archive productions 180 days after last performance
- [ ] Create simple dashboard showing upcoming/current productions
- [ ] Add date range display helper (e.g., "Feb 7-8, 14-15")

## Files to Modify/Create

### New Files
- `lib/spotlight/accounts.ex` - User context (generated)
- `lib/spotlight/accounts/user.ex` - User schema (generated)
- `lib/spotlight/productions.ex` - Productions context
- `lib/spotlight/productions/production.ex` - Production schema
- `lib/spotlight/productions/performance.ex` - Performance/show times schema
- `lib/spotlight/productions/production_photo.ex` - Photo schema
- `lib/spotlight/uploads.ex` - Cloudflare R2 integration
- `lib/spotlight_web/live/admin/` - Admin LiveView modules
- `lib/spotlight_web/live/admin/production_live/` - Production CRUD views
- `lib/spotlight_web/live/admin/user_live/` - User management views
- `priv/repo/migrations/*` - Database migrations

### Modified Files
- `lib/spotlight_web/router.ex` - Add admin routes, auth plugs
- `lib/spotlight_web/controllers/page_controller.ex` - Query productions
- `lib/spotlight_web/controllers/page_html/productions.html.heex` - Dynamic rendering
- `mix.exs` - Add ex_aws dependencies
- `config/runtime.exs` - R2 credentials from env

## Dependencies to Add

```elixir
# mix.exs
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.5"},
{:hackney, "~> 1.20"},      # HTTP client for ex_aws
{:sweet_xml, "~> 0.7"},     # XML parsing for S3 responses
```

```javascript
// package.json or vendor
// Cropper.js - for image cropping in admin UI
// Install via npm or copy to assets/vendor/
```

## Configuration

### Cloudflare R2 Setup
1. Create R2 bucket in Cloudflare dashboard
2. Generate API token with R2 read/write permissions
3. Note the account ID and bucket name
4. Configure public access for image serving

### Environment Variables
```bash
# .env
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_BUCKET=spotlight-images
R2_PUBLIC_URL=https://images.spotlightwm.org  # or R2 public URL

# Google Maps Embed API (free tier)
GOOGLE_MAPS_API_KEY=xxx
```

## Testing Strategy

### Unit Tests
- Test Production changeset validations
- Test ProductionPhoto associations
- Test Uploads context (mock HTTP calls)

### Integration Tests
- Test admin authentication flow
- Test production CRUD operations
- Test image upload flow (with test fixtures)

### Manual Testing
- Verify Debbie can log in
- Verify full production creation workflow
- Test image uploads on slow connection
- Verify public site displays database content

## Edge Cases & Error Handling

- **Upload fails**: Show error, keep form data, allow retry
- **Large images**: Client-side resize before upload (optional)
- **Invalid coordinates**: Default to theater location
- **Missing ticket URL**: Hide "Get Tickets" button
- **Past productions**: Visible in "Past" section for 180 days after last performance, then auto-archived
- **No performances**: Production stays in draft until at least one show time added
- **Production with no photos**: Show placeholder or main image only

## Resolved Decisions

- [x] **Multiple performance dates**: Yes - store all show times in `performances` table, display opening night + computed date ranges
- [x] **Past production visibility**: Show for 180 days after last performance, then auto-archive
- [x] **Map provider**: Google Maps Embed API (free tier, requires API key for place search by name)
- [x] **User management**: Support ~3 admin users, manually invited (no public registration)
- [x] **Image cropping**: Yes - use Cropper.js via LiveView hooks for client-side cropping
- [x] **Image resizing**: Client-side resize before upload + server-side optimization
- [x] **Location input**: Place name search (not lat/long) - uses Maps Embed API `?q=` parameter
- [x] **Crop aspect ratios**: Flexible per use case - main/hero images 16:9, production photos 4:3

## Open Questions

None - all decisions resolved.

## Future Considerations

- Ticket sales integration (Stripe, Square)
- Check-in system for door management
- Email notifications for new productions
- SEO metadata per production
- Social media sharing images (auto-generated)

## Documentation Plan

After implementation, create `dev/docs/20260201-production-management.md` with:
- Admin user guide for Debbie
- Cloudflare R2 configuration reference
- Production workflow (draft → publish → archive)
- Troubleshooting common issues

## References

- [Phoenix LiveView Uploads](https://hexdocs.pm/phoenix_live_view/uploads.html)
- [Cloudflare R2 with Elixir](https://elixirforum.com/t/heres-how-to-upload-to-cloudflare-r2-tweaks-from-original-s3-implementation-code/58686)
- [Direct uploads to R2 from LiveView](https://elixirforum.com/t/direct-file-uploads-with-phoenix-liveview-and-cloudflare-r2/60908)
- [Phoenix File Uploads](https://hexdocs.pm/phoenix/file_uploads.html)
- [Cropper.js](https://fengyuanchen.github.io/cropperjs/) - Image cropping library
- [Resize Image Uploads with LiveView](https://abjork.land/articles/elixir/resize-image-uploads-with-liveview/) - Client-side resize pattern
- [Google Maps Embed API](https://developers.google.com/maps/documentation/embed/embedding-map) - Free tier for place embeds
