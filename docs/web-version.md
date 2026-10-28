# MindQuest on the web

MindQuest is a Flutter app, so the same code runs as a website: the same
screens, accounts, data, chatbot and rewards as the Android app. Students can
use it in any modern browser (Chrome, Edge, Firefox, Safari) on a phone or a
computer, and install it like an app.

## What is different on the web

| | Android app | Website |
|---|---|---|
| Layout | Bottom tabs | Phones: bottom tabs. Screens 840 px or wider (laptops, tablets): a side menu, and pages kept to 720 px in the middle so lines stay readable |
| Google sign-in, email confirmation | Come back to the app (`ke.ac.maseno.mindquest://login-callback`) | Come back to the website itself |
| Offline | Saved data and a sync queue (step 10) | The same, plus the website's own files are kept by a service worker (`web/sw.js`), so it opens without internet after the first visit |
| Install | APK | "Install app" / "Add to Home screen" in the browser (web app manifest) |
| Daily reminders and badge notifications | Yes | Not on the web (browsers need a server for scheduled notifications); the reminder settings are hidden. Badge pop-ups still show |
| Call buttons for helplines | Open the dialer | Open the dialer on phones; on a computer the browser offers an app for calling, and the number is always shown on screen |

This also meets NFR 6 as the proposal wrote it ("efficient under low
bandwidth using PWA caching"): the website is a progressive web app.

## Files

- `web/index.html`: title, description, theme colour, a loading screen (in
  English and Kiswahili, light and dark) while the app downloads.
- `web/flutter_bootstrap.js`: starts the app, removes the loading screen and
  registers the offline cache instead of Flutter's own service worker.
- `web/sw.js`: the offline cache. Network first: with internet every file is
  fetched fresh (so a new version shows at once) and a copy is saved; without
  internet the saved copy is used. Files loaded before the cache was ready
  are saved a few seconds after start-up. Supabase requests are never cached
  here: the app's own offline store handles data.
- `web/manifest.json`, `web/icons/`, `web/favicon.png`: name, colours and
  icons for installing.
- `lib/core/widgets/web_layout.dart` and `lib/core/router/app_shell.dart`:
  the layout for big screens.
- Built with `--no-web-resources-cdn`, so CanvasKit (Flutter's drawing
  engine) comes from the site itself and can be cached.

## Putting it online (Netlify, free)

### One time

1. **Supabase → Authentication → URL Configuration → Redirect URLs**: add the
   website's address, e.g. `https://mindquest-ke.netlify.app` and
   `https://mindquest-ke.netlify.app/**` (and the admin site's address). Keep
   `ke.ac.maseno.mindquest://login-callback` for the Android app.
2. Create a free account at netlify.com (sign up with GitHub is easiest).

### Option A: upload by hand

1. On your PC: `.\scripts\build-web.ps1`. It makes `build\site-app` and
   `build\site-admin`.
2. Go to app.netlify.com/drop and drag the `build\site-app` folder onto the
   page. Netlify gives the site an address; rename it under Site
   configuration → Change site name (e.g. `mindquest-ke`).
3. Do the same with `build\site-admin` for the admin dashboard (e.g.
   `mindquest-admin`).
4. To update later: build again, then drag the folder onto the site's
   **Deploys** page.

### Option B: automatic after every push

The CI workflow has a "Deploy website" job that builds and uploads both sites
after every change to `main` that passes the checks. It is skipped until
these are added in GitHub → Settings → Secrets and variables → Actions:

| Secret | Where to find it |
|---|---|
| `NETLIFY_AUTH_TOKEN` | Netlify → User settings → Applications → Personal access tokens → New access token |
| `NETLIFY_SITE_ID` | The MindQuest site → Site configuration → Site ID (create the site first with option A) |
| `NETLIFY_ADMIN_SITE_ID` | The admin site's Site ID (optional) |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase → Project Settings → API Keys → publishable key (the same as in `config/dev.json`) |

Optional variable (Variables tab): `FEEDBACK_URL`, the Google Form link.

Never add the `service_role` key: the website only needs the publishable key,
like the APK, and the database's row-level security protects the data.

## Trying it locally

```
flutter run -d chrome --dart-define-from-file=config/dev.json
```

The offline cache only works on a built site (`.\scripts\build-web.ps1`,
then `cd build\site-app` and `python -m http.server 8080`, open
http://localhost:8080). For Google sign-in on localhost, add
`http://localhost:8080` to the Supabase redirect URLs.

## Tests

- `test/web_test.dart`: the sign-in return address, the side menu and
  readable width on a laptop screen, the bottom tabs on a phone.
- `web/sw.js` was tried in Chromium: online the page loads and is cached;
  offline a reload still opens it; after an update online the new version
  shows at once.
- CI builds the website on every push and checks that the offline cache,
  the start-up script and the local CanvasKit are in the build.
- System tests ST-62 to ST-66 in the workbook (website in a browser).
