# Pixel Host App

Flutter app to manage Pterodactyl servers from a mobile-friendly UI.

## Features

- Sign in with a Pterodactyl panel URL and client API token
- View all accessible servers
- Open server details with live resource data
- Send power actions like start, stop, restart, and kill

## Setup

1. Install Flutter.
2. Run `flutter pub get`.
3. Launch the app with `flutter run`.

## GitHub Pages

The workflow in [.github/workflows/deploy-pages.yml](.github/workflows/deploy-pages.yml) builds the Android APK on pushes to `main` and publishes a simple download page on GitHub Pages.

## Notes

- The app uses the Pterodactyl client API, so you need a client API token from your panel account.
- If you want the native Android, iOS, desktop, or web folders generated, run `flutter create .` in this directory before building.