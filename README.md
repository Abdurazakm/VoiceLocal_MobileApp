# VoiceLocal

Community issue reporting and voting app built with Flutter. Residents can submit problems with evidence, vote on priorities, and see status updates. Admins moderate by sector/region and track progress in real time.

## Features

- Email/password and Google sign-in with role-based routing (user, sector_admin, super_admin)
- Report issues with photos or videos, sector and region tagging, and street-level details
- Real-time feed with search, pagination, vote toggling, and comment counts
- Admin console with per-sector filters, live stats, and status updates
- Push-style inbox powered by Firestore notifications collection
- Cloudinary media uploads plus Firebase Storage/Firestore integration

## Tech Stack

- Flutter 3.9+, Dart 3.9
- Firebase: Auth, Firestore, Storage
- Cloudinary for media uploads (see lib/services/issue_service.dart)
- UI: Material 3, Google Fonts, Shimmer, Chewie/Video Player

## Project Structure (high level)

- lib/main.dart – app bootstrap and AuthGate
- lib/screens/auth – login/registration flows
- lib/screens/user – feed, add issue, detail, profile
- lib/screens/admin – dashboards, user management, status updates
- lib/services – auth, issue CRUD/upload helpers
- lib/models – issue, user, comment models

## Prerequisites

- Flutter SDK installed and in PATH
- Firebase project with iOS, Android, and Web apps created
- Optional: Cloudinary account (cloud name and unsigned upload preset)

## Setup

1. Install packages

```
flutter pub get
```

2. Configure Firebase

- Enable Email/Password and Google providers in Firebase Auth.
- Create Firestore in production or test mode (rules per your needs).
- Add platform configs:
  - Android: place google-services.json in android/app/.
  - iOS: place GoogleService-Info.plist in ios/Runner/.
  - Web: ensure web/firebase-messaging-sw.js if using messaging (not required for current features).
- Generate lib/firebase_options.dart with FlutterFire CLI:

```
dart pub global activate flutterfire_cli
flutterfire configure
```

3. Cloudinary (media uploads)

- Update the cloud name and preset in lib/services/issue_service.dart if different from the sample values.

4. Run the app

```
flutter run        # Android/iOS/desktop if enabled
flutter run -d chrome   # Web
```

## Data Model (Firestore)

- Users: uid, name, email, region, street, role (user|sector_admin|super_admin), assignedSector, assignedRegion, profilePic, bio
- Issues: title, description, category/sector, region, street, status, voteCount, commentCount, attachmentUrl, createdBy, createdAt, votedUids
- Comments: issueId, userId, userName, text, parentId, replyToName, createdAt, isEdited
- Notifications: title, body, sector, region, issueId, type, timestamp, readBy

## Roles and Access

- Default registrants are users.
- Promote admins by updating Users/{uid} with role=sector_admin or super_admin and setting assignedSector/assignedRegion for sector admins.
- AuthGate routes admins to the dashboard and users to the community feed.

## Quality Checks

```
flutter analyze
flutter test
```

## Building Releases

```
flutter build apk --release
flutter build appbundle --release
flutter build ios --release   # requires macOS
flutter build web --release
```

## Troubleshooting

- Seeing an auth loop? Verify Firebase Auth providers and that Users documents exist for signed-in accounts.
- Media upload failures: confirm Cloudinary credentials and network access.
- Missing assets: run flutter clean && flutter pub get if the logo or fonts are not found.
