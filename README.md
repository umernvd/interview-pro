# Interview Pro

A Flutter app for running structured technical interviews — record audio, score candidates, generate PDF reports, and sync everything to Google Drive.

---

## What it does

You open the app, connect your Google account, pick a role and experience level, then run through a question bank with the candidate. The app records the session, transcribes it with Gemini AI in the background, and lets you fill out a soft skills evaluation at the end. Hit generate and you get a full PDF report you can share or store.

All interview data lives in Appwrite (cloud backend). Audio recordings and CVs go straight to your Google Drive.

---

## Features

- Google Sign-In + Google Drive integration for audio/CV storage
- Dynamic role and experience level selection (fetched from Appwrite)
- Question bank per role/level with randomized question sets
- Voice recording during interview sessions
- Background AI transcription via Gemini
- Soft skills evaluation form (communication, problem solving, cultural fit)
- PDF report generation and sharing
- Interview history with search
- Offline upload queue — recordings sync when connection is restored
- Dashboard with weekly stats and average scores

---

## Tech stack

| Area | Library |
|---|---|
| Framework | Flutter 3.10+ |
| State management | Provider |
| Navigation | Go Router |
| Backend | Appwrite |
| Auth + Drive | Google Sign-In, googleapis |
| AI transcription | google_generative_ai (Gemini) |
| Audio recording | record |
| PDF | pdf + printing |
| Local storage | Hive, shared_preferences, flutter_secure_storage |
| Networking | http, connectivity_plus |
| DI | get_it |

---

## Project structure

```
lib/
├── core/
│   ├── config/          # API config, env vars
│   ├── constants/       # Colors, strings
│   ├── providers/       # Auth provider
│   ├── services/        # Session manager, upload service, transcription, voice recording
│   ├── theme/           # App theme
│   └── utils/           # Router, formatters
├── features/
│   ├── auth/            # Login screen
│   ├── dashboard/       # Home, history, settings tabs
│   ├── history/         # Interview history list
│   ├── interview/       # Setup → level → questions → evaluation → report
│   ├── settings/        # App settings
│   └── splash/          # Splash screen
└── shared/
    ├── data/            # Datasources, repositories impl
    ├── domain/          # Entities, repository interfaces
    └── presentation/    # Shared widgets
```

---

## Setup

### 1. Clone and install

```bash
git clone <repo-url>
cd interview_pro_app
flutter pub get
```

### 2. Environment variables

Create a `.env` file in the project root:

```env
APPWRITE_ENDPOINT=https://your-appwrite-instance/v1
APPWRITE_PROJECT_ID=your_project_id
APPWRITE_DATABASE_ID=your_database_id
APPWRITE_INTERVIEWS_COLLECTION_ID=your_collection_id
APPWRITE_ROLES_COLLECTION_ID=your_roles_collection_id
APPWRITE_LEVELS_COLLECTION_ID=your_levels_collection_id
APPWRITE_QUESTIONS_COLLECTION_ID=your_questions_collection_id
BACKEND_BASE_URL=https://your-backend-url
GEMINI_API_KEY=your_gemini_api_key
```

### 3. Google Sign-In

- Create a project in [Google Cloud Console](https://console.cloud.google.com)
- Enable Google Drive API and Google Sign-In
- Add your SHA-1 fingerprint for Android
- Download `google-services.json` and place it in `android/app/`

### 4. Appwrite

- Set up an Appwrite project with collections matching the env vars above
- Configure tenant isolation rules on your collections
- Make sure your backend (Next.js) is running and accessible

### 5. Run

```bash
flutter run
```

---

## Interview flow

```
Login → Dashboard → Select Role → Select Level → Interview Questions (with recording)
  → Candidate Evaluation (soft skills + AI transcript) → PDF Report
```

---

## Backend

The app talks to a separate Next.js backend for:
- JWT generation for secure uploads
- Google Drive folder creation and file upload
- CV processing

The backend URL is set via `BACKEND_BASE_URL` in `.env`. For local dev, use ngrok or similar to expose it.

---

## Running tests

```bash
flutter test
```

---

## Notes

- The app requires Google Sign-In to start an interview (Drive is used for storage)
- Transcription runs in the background — you don't have to wait for it before submitting evaluation
- If you're offline, recordings are queued and uploaded automatically when connection returns
- Ghost detection debug prints (`🛑🛑🛑`, `🎯🎯🎯`) are intentional — they help trace duplicate datasource calls
