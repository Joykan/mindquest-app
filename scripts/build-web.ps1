# Builds the MindQuest website and the admin dashboard for uploading to a
# web host (e.g. Netlify: drag each folder onto app.netlify.com/drop, or onto
# the site's Deploys page to update it).
#
# Run from the project folder:   .\scripts\build-web.ps1
# Result:   build\site-app     the student app (MindQuest)
#           build\site-admin   the admin dashboard
#
# Uses the keys in config\dev.json (only the publishable key goes into the
# website, as in the APK; never put the service_role key there).

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path config\dev.json)) {
    Write-Error "No config\dev.json. Copy config\dev.json.example and fill it in first."
}

flutter pub get

Write-Host "Building the student app..."
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/dev.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (Test-Path build\site-app) { Remove-Item -Recurse -Force build\site-app }
Copy-Item -Recurse build\web build\site-app

Write-Host "Building the admin dashboard..."
flutter build web --release --no-web-resources-cdn -t lib/main_admin.dart --dart-define-from-file=config/dev.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (Test-Path build\site-admin) { Remove-Item -Recurse -Force build\site-admin }
Copy-Item -Recurse build\web build\site-admin

Write-Host ""
Write-Host "Done. Upload build\site-app (MindQuest) and build\site-admin (admin dashboard)."
Write-Host "To try it on this computer first:  cd build\site-app; python -m http.server 8080  then open http://localhost:8080"
