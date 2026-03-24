# Session: Cloudflare R2 Upload Migration

**Date:** 2026-02-18
**Status:** Complete and deployed to production

## Summary

Migrated all file uploads from local filesystem storage to Cloudflare R2 (S3-compatible object storage). This decouples uploaded images from the application server's filesystem, making deployments cleaner and enabling future CDN/multi-server setups. The `ImageController` still handles on-the-fly resizing, but now fetches originals from R2 and caches resized versions in the system tmp directory.

## Changes

### Dependencies (`mix.exs`)

Added three new dependencies:

- `{:ex_aws, "~> 2.5"}` -- AWS/S3-compatible API client
- `{:ex_aws_s3, "~> 2.5"}` -- S3-specific operations (upload, get, delete)
- `{:sweet_xml, "~> 0.7"}` -- XML parsing for S3 API responses

### Configuration

**`config/config.exs`** -- Global R2 settings:

```elixir
config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req

config :ex_aws, :s3, %{
  scheme: "https://",
  host: "b253e6fbfd2f7757cadd0386de5bde3f.r2.cloudflarestorage.com",
  region: "auto"
}

config :spotlight, :r2_bucket, "spotlightwm"
```

**`config/dev.exs`** -- Dev environment prefix (replaces old `uploads_dir`):

```elixir
config :spotlight, :uploads_prefix, "dev"
```

**`config/runtime.exs`** -- Three additions:

1. `.env.dev` auto-loader for dev/test (parses KEY=VALUE lines, sets `System.put_env`)
2. R2 credentials from `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` env vars
3. Production uploads prefix: `"prod"`

Dev and prod uploads share the same R2 bucket (`spotlightwm`) but are separated by key prefix (`dev/` vs `prod/`).

### Upload Module (`lib/spotlight/uploads.ex`) -- Full Rewrite

Previous implementation wrote files to `priv/static/uploads/` on disk. New implementation:

- **`save/3`** -- Consumes a LiveView upload entry, streams it to R2 at `<prefix>/<subdir>/<uuid>.<ext>`, returns `/uploads/<subdir>/<filename>` URL path (same shape as before so DB values are unchanged)
- **`delete/1`** -- Deletes the object from R2, also cleans up any locally cached resized versions from the tmp directory
- **`get/1`** -- Downloads an object from R2 to a temp file, returns `{:ok, tmp_path}` for `ImageController` to resize

Internal helpers:
- `r2_key/2` -- Constructs the full R2 object key with environment prefix
- `url_path_to_key/1` -- Converts `/uploads/...` URL paths back to R2 keys

### Image Controller (`lib/spotlight_web/controllers/image_controller.ex`)

Updated to fetch originals from R2 instead of reading from disk:

- Cache directory moved from `uploads_dir` to `System.tmp_dir!() <> "/spotlight_image_cache"`
- On cache miss, calls `Spotlight.Uploads.get/1` to download the original from R2
- Resizes with ImageMagick `convert`, caches the result in tmp, cleans up the R2 download
- On cache hit, serves directly from tmp (no R2 round-trip)

### Endpoint (`lib/spotlight_web/endpoint.ex`)

Removed the second `Plug.Static` that served `/uploads` from the local filesystem. Only the standard static file plug remains.

### Admin Production LiveView (`lib/spotlight_web/live/admin/production_live/show.ex`)

- `save_main_image/2` and `save_photos/2` now use `Uploads.save(socket, entry, subdir)` instead of manual `File.cp!` to the uploads directory
- All `<img>` `src` attributes for production images and photos updated to route through `/images/w/<width>/uploads/...` instead of raw `/uploads/...` paths
- Added `min-h-24 bg-gray-100` to photo grid items so broken/loading image thumbnails still have a visible hover area for the delete button

### Public Productions Page (`lib/spotlight_web/controllers/page_html/productions.html.heex`)

Updated photo `src` attributes to route through the image controller (`/images/w/<width>/...`) instead of serving raw `/uploads/` paths.

### Git Ignore (`.gitignore`)

Added `.env*` pattern to prevent committing local credential files.

### Local Credentials (`.env.dev`)

Created (gitignored) with `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` for local development.

## Problems Encountered and Resolved

### 1. hackney HTTP client not available

**Symptom:** `ex_aws` defaulted to `:hackney` as its HTTP client, which wasn't in the dependency list.

**Fix:** Configured `http_client: ExAws.Request.Req` in `config.exs` since `req` was already a project dependency.

### 2. TLS handshake failure connecting to R2

**Symptom:** SSL/TLS errors when attempting to upload to R2.

**Root cause:** The R2 endpoint host was mistakenly set to the access key ID instead of the Cloudflare account ID.

**Fix:** Corrected the host to `b253e6fbfd2f7757cadd0386de5bde3f.r2.cloudflarestorage.com` (the actual Cloudflare account ID).

### 3. NoSuchBucket error

**Symptom:** S3 API returned `NoSuchBucket` when attempting uploads.

**Root cause:** The `spotlightwm` bucket had not yet been created in the Cloudflare R2 dashboard.

**Fix:** Created the bucket via the Cloudflare dashboard.

### 4. No route for `/uploads/*` after removing Plug.Static

**Symptom:** After removing the static file plug for `/uploads`, existing `<img src="/uploads/...">` tags returned 404s.

**Fix:** Updated all `<img>` `src` attributes across admin and public pages to route through `/images/w/<width>/uploads/...`, which hits the `ImageController` that fetches from R2.

### 5. Broken image thumbnails had no hover area for delete button

**Symptom:** In the admin photo grid, if an image failed to load, the container collapsed to zero height, making the delete button inaccessible.

**Fix:** Added `min-h-24 bg-gray-100` to the photo grid item container so there's always a visible area to hover over.

## Production Deployment

- R2 environment variables (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) added to `/var/www/www.spotlightwm.org/shared/.env` on the production server
- Deployed via `mix deploy production`
- Verified uploads and image serving working in production

## Files Modified

| File | Change |
|------|--------|
| `mix.exs` | Added ex_aws, ex_aws_s3, sweet_xml deps |
| `mix.lock` | Updated lockfile |
| `config/config.exs` | ExAws + R2 endpoint config |
| `config/dev.exs` | `uploads_prefix` replaces `uploads_dir` |
| `config/runtime.exs` | .env.dev loader, R2 credentials, prod prefix |
| `lib/spotlight/uploads.ex` | Full rewrite for R2 storage |
| `lib/spotlight_web/controllers/image_controller.ex` | Fetch from R2, tmp dir cache |
| `lib/spotlight_web/endpoint.ex` | Removed Plug.Static for /uploads |
| `lib/spotlight_web/live/admin/production_live/show.ex` | Uploads.save/3, image paths, min-h fix |
| `lib/spotlight_web/controllers/page_html/productions.html.heex` | Photo URLs through image controller |
| `.gitignore` | Added .env* pattern |
| `.env.dev` | Created (gitignored) for local R2 credentials |

## Architecture After Migration

```
Browser request for image
  |
  v
GET /images/w/800/uploads/productions/abc123.jpg
  |
  v
ImageController.show/2
  |
  +-- Cache hit? --> Serve from System.tmp_dir!/spotlight_image_cache/w800/...
  |
  +-- Cache miss:
        |
        +-- Uploads.get("/uploads/productions/abc123.jpg")
        |     --> ExAws.S3.get_object("spotlightwm", "prod/productions/abc123.jpg")
        |     --> Write to temp file
        |
        +-- ImageMagick convert (resize to 800px wide)
        |     --> Save to cache dir
        |
        +-- Clean up R2 temp download
        +-- Serve resized image
```

Upload flow:
```
LiveView file upload
  |
  v
Uploads.save(socket, entry, "productions")
  |
  +-- consume_uploaded_entry
  +-- ExAws.S3.Upload.stream_file (from tmp upload)
  +-- ExAws.S3.upload("spotlightwm", "dev/productions/<uuid>.jpg")
  +-- Return "/uploads/productions/<uuid>.jpg" (stored in DB)
```
