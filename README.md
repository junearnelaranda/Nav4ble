# NavAble

NavAble is a Flutter accessibility reporting app backed by one Supabase project. The mobile app uses Supabase Auth, Postgres, and private Storage. A Cloudflare Worker verifies Supabase access tokens before forwarding photos to the existing Roboflow object detection workflow. AI detections are suggestions; reports begin with `pending` status for human review.

## Configure Supabase

Create or choose the same Supabase project that the separate admin web app will use. In the Supabase SQL editor, review and apply [supabase/navable_schema.sql](supabase/navable_schema.sql). The script is a bootstrap schema for a new project; adapt it to any existing tables before running it. It creates the `report-photos` private bucket and policies for users and moderators. Assign moderator access using trusted `app_metadata.role` values `admin` or `moderator` from a server side administrative operation. Never put a secret or service role key in Flutter or the Worker.

Enable email/password authentication in Supabase. If email confirmation is enabled, newly registered users must confirm their email before signing in. Add `navable://auth-callback/` to Supabase Auth's allowed Redirect URLs for Android and iOS password recovery. For web, add your deployed app origin too. The app opens a new password form when Supabase completes a recovery callback.

Copy `dart_defines.example.json` to `dart_defines.json` and fill in the project URL and publishable key from Supabase Project Settings > API. `dart_defines.json` is git-ignored. Then run:

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

In Android Studio, add `--dart-define-from-file=dart_defines.json` to the run configuration's *Additional run args*. Without these settings the app only shows "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to start NavAble."

Pass the same defines to release builds. The publishable key may be in a client build; the Supabase service role or secret key must stay on trusted servers. If you omit the Worker URL, users can still submit photos for human review.

The app stores each submitted photo under `report-photos/<user-id>/<report-id>/photo_<index>.<extension>`. A report row in `reports` and associated rows in `photo_submissions` share the same Supabase database as the admin app. The app accepts up to five JPEG, PNG, or WebP photos, each at most 700 KiB.

## AI photo detection (Roboflow)

Photos are analyzed by the `roboflow-infer` Supabase Edge Function ([supabase/functions/roboflow-infer](supabase/functions/roboflow-infer)), which checks the user is signed in and calls the NavAble Roboflow workflow. Add your Roboflow API key once in the Supabase dashboard under **Edge Functions > Secrets** as `ROBOFLOW_API_KEY`. Until then, scanning reports "Roboflow inference is not configured yet" and reports can still be submitted for admin review.

Submitted reports are saved where the admin app reads them: photos in the public `report-photos` bucket and the `images` table, the report in `reports`, and each AI detection in `ai_results` as "Needs Verification". Reports must be for a Verified NavAble location. See [supabase/migrations](supabase/migrations).

## AI Worker (optional, Cloudflare)

The Cloudflare Worker below does the same job. The app uses it instead of the Edge Function only when `NAVABLE_REPORTS_API_URL` is set.

Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as Cloudflare Worker variables and `ROBOFLOW_API_KEY` as a Worker secret. The Worker calls Supabase Auth's `/auth/v1/user` endpoint to validate each user's access token, then sends the image to Roboflow. Configure the same Supabase project URL in Flutter and the Worker.

```powershell
npx wrangler@4 deploy --config worker/wrangler.toml --var SUPABASE_URL:https://<project-ref>.supabase.co --var SUPABASE_PUBLISHABLE_KEY:<publishable-key>
npx wrangler@4 secret put ROBOFLOW_API_KEY --config worker/wrangler.toml
```

Cloudflare and Roboflow have separate free plan limits; check their current dashboards before wider deployment. The app allows manual submission when scanning is unavailable. The Worker tests run with `node --test` from `worker/`. A live smoke test requires `NAVABLE_WORKER_URL` and `SUPABASE_ACCESS_TOKEN`, then `npm run smoke -- C:\path\to\sample.jpg`.

The map uses OpenStreetMap tiles through `flutter_map`; it does not need a Google Maps key. Keep OpenStreetMap attribution visible and follow the [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).
