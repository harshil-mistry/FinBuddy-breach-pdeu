# FinBuddy - Codebase Analysis

## Project Overview
**FinBuddy** is a Smart Expense Splitting & Settlement System built for PDEU. It helps groups of people (friends, students, event organizers) manage shared expenses, track debts, and settle payments efficiently using AI-powered features.

---

## Architecture

The application follows a **client-server architecture** with three main layers:

1. **Flutter Mobile App** (`/finbuddy`) - Cross-platform frontend
2. **Node.js Express API** (`/server`) - AI processing and push notifications proxy
3. **Firebase** - Database, Authentication, and Cloud Messaging

---

## Directory Structure

```
Breach PDEU/
├── finbuddy/              # Flutter Android app
│   ├── lib/
│   │   ├── main.dart              # App entry point
│   │   ├── models/                # Data models
│   │   ├── screens/               # UI screens
│   │   ├── services/              # Business logic & Firebase
│   │   ├── utils/                 # Helper utilities
│   │   ├── theme/                 # App styling
│   │   └── widgets/               # Reusable components
│   └── pubspec.yaml               # Flutter dependencies
├── server/                # Node.js Express backend
│   ├── index.js                   # API routes & AI processing
│   └── package.json               # Node dependencies
├── Docs/                  # Documentation
├── final-apk/             # Built APK files
└── README.md              # Project documentation
```

---

## Frontend (Flutter App)

### Technology Stack
- **Framework:** Flutter (Dart SDK ^3.8.1)
- **State Management:** Provider
- **Authentication:** Firebase Auth + Google Sign-In
- **Database:** Cloud Firestore
- **UI Components:** Material Design + Custom Theme

### Key Dependencies
```yaml
# Core Firebase
firebase_core: ^3.13.0
firebase_auth: ^5.5.2
cloud_firestore: ^5.6.6
firebase_messaging: ^15.2.10

# UI & Utilities
google_sign_in: ^6.2.2
qr_flutter: ^4.1.0          # QR code generation
mobile_scanner: ^7.2.0       # QR code scanning
image_picker: ^1.2.1         # Camera/gallery access
record: ^5.2.0              # Voice recording
pdf: ^3.11.3                # PDF generation
printing: ^5.14.2           # Print/Save PDF
url_launcher: ^6.3.2        # UPI deep-linking
```

### Core Functionality

#### 1. Authentication Flow (`lib/services/auth_service.dart`)
- Google Sign-In via Firebase Auth
- Creates user profile in Firestore on first login
- Stores FCM token for push notifications
- Tracks login timestamps

#### 2. User Model (`lib/models/user_model.dart`)
```dart
UserModel {
  uid, displayName, email, photoUrl,
  upiId, isSetupComplete, fcmToken,
  recurringIncomes: [source, amount, dayOfMonth],
  recurringExpenses: [name, amount, tag, dayOfMonth]
}
```

#### 3. Pool System (Groups)
- **PoolModel**: Groups with invite codes, members, and join requests
- Users create pools with auto-generated invite codes
- Others join via QR code scan or manual invite code
- Admin approval workflow for join requests
- Admin can kick members or delete entire pool

#### 4. Expense Management
- **Personal Expenses:** Individual transactions with categories
- **Shared Expenses:** Split bills among pool members
- **Split Methods:**
  - Equal split (default)
  - Custom split (manually specify amounts)
  - Voice input (AI-powered)

#### 5. AI-Powered Features

**Receipt Scanning (OCR):**
- User uploads receipt image
- Server sends to NVIDIA NIM (LLaMA Vision model)
- Returns extracted amount + auto-categorized (Food, Travel, etc.)

**Voice Expense Logging:**
- User records voice describing expense
- Server sends to Deepgram (Speech-to-Text)
- Transcript sent to NVIDIA NIM (GPT-like model)
- Returns structured JSON: `{description, amount, paidBy, splitAmong}`

#### 6. Debt Settlement Algorithm (`lib/utils/debt_simplifier.dart`)
```dart
// Calculates net balances for each member
// Separates into debtors (owe money) and creditors (owed money)
// Uses greedy algorithm to minimize transaction count

SettlementTransfer { from, to, amount }

Example:
  Raw debts: A→B ₹100, B→C ₹100, C→A ₹50
  Simplified: A→C ₹50 (optimized from 3 to 1 transaction)
```

#### 7. UPI Payment Integration
- Uses Android URL launcher with UPI deep-links
- Format: `upi://pay?pa=<UPI_ID>&am=<amount>&cu=INR`
- Pre-fills recipient and amount from settlement view

---

## Backend (Node.js Express)

### Technology Stack
- **Runtime:** Node.js
- **Framework:** Express.js
- **File Upload:** Multer
- **Push Notifications:** Firebase Admin SDK

### API Endpoints

#### 1. Receipt Scanning
```
POST /api/scan-receipt
Body: multipart/form-data with "image" field
Response: { status: true/false, amount: number, description: string }

AI Processing:
- NVIDIA NIM API (meta/llama-3.2-11b-vision-instruct)
- System prompt enforces strict JSON output
- Categories: Food, Groceries, Clothes, Travel, Fuel, Utilities, Medical, Entertainment, Electronics, Stationery
```

#### 2. Voice Expense Parsing
```
POST /api/voice-expense
Body: multipart/form-data with "audio" + "members" JSON
Response: { status: true, description, amount, participantUids, paidByUid, transcript }

AI Processing:
- Step 1: Deepgram STT (nova-2 model)
- Step 2: NVIDIA NIM LLM (openai/gpt-oss-120b)
- Matches spoken names to pool member UIDs
```

#### 3. Push Notifications
```
POST /api/send-nudge          # Payment reminder
POST /api/send-expense-notification  # New expense added

Uses Firebase Cloud Messaging (FCM)
Trigger: In-app actions call these endpoints with FCM tokens
```

---

## Database Schema (Firestore)

### Collections:

**users** `/users/{uid}`
```
- displayName, email, photoUrl, upiId
- isSetupComplete (boolean)
- recurringIncomes[]: {source, amount, dayOfMonth}
- recurringExpenses[]: {name, amount, tag, dayOfMonth}
- fcmToken: string
- createdAt, lastLogin (timestamps)
```

**pools** `/pools/{poolId}`
```
- name, description, inviteCode (unique string)
- ownerId (uid of creator)
- members[]: array of uids
- joinRequests[]: array of pending uids
- totalExpenses (running total)
- createdAt (timestamp)
```

**shared_expenses** `/shared_expenses/{expenseId}`
```
- poolId (reference)
- description, amount, paidBy (uid)
- splits: Map<uid, amount>
- date (timestamp)
```

**transactions** `/transactions/{transactionId}`
```
- uid (owner), amount, description, category
- date, isPersonal (boolean)
```

**notifications** `/notifications/{notificationId}`
```
- toUid, fromUid, poolId
- amount, type ('nudge' | 'new_expense')
- isRead (boolean), createdAt (timestamp)
```

---

## Key Features Implemented

### Completed Features
1. ✅ Firebase Google Authentication
2. ✅ Onboarding with UPI ID setup
3. ✅ Pool creation with invite codes
4. ✅ QR code generation and scanning
5. ✅ Join request workflow (request → approve)
6. ✅ Manual expense entry with splits
7. ✅ Receipt scanning (AI-powered OCR)
8. ✅ Voice expense logging (STT + LLM)
9. ✅ Debt simplification algorithm
10. ✅ UPI payment deep-linking
11. ✅ Push notifications (FCM)
12. ✅ Personal recurring income/expense tracking
13. ✅ Transaction history and statistics
14. ✅ PDF export for pool reports
15. ✅ Nudge/reminder system

### Planned/Context Mentions (from CONTEXT.md)
- AWS Lambda migration readiness
- Tesseract.js OCR (switched to NVIDIA NIM)
- Directed graph visualization for debt graph UI

---

## Deployment

### Backend
- **Hosting:** Render.com
- **URL:** `https://finbuddy-breach-pdeu.onrender.com`
- **Environment Variables:**
  - `NVIDIA_API_KEY` - For NIM AI services
  - `DEEPGRAM_API_KEY` - For speech-to-text
  - `FIREBASE_SERVICE_ACCOUNT_BASE64` - For FCM push notifications

### Mobile App
- **Platform:** Android
- **APK Location:** `/final-apk/`
- **Min SDK:** 23 (Android 6.0)

---

## Code Quality & Structure

### Patterns Used
- **Provider Pattern:** For state management
- **Repository Pattern:** FirestoreService abstracts database operations
- **Model Classes:** Type-safe data with toMap/fromMap serialization
- **Stream-based:** Real-time UI updates via Firestore snapshots

### Security
- Firebase Auth ID tokens verified on backend
- Firestore security rules (assumed, not in repo)
- API keys stored in environment variables
- No hardcoded secrets in source code

---

## Files Summary

| File | Purpose | Lines |
|------|---------|-------|
| `main.dart` | App initialization, auth routing | 166 |
| `auth_service.dart` | Google Sign-In, user creation | 104 |
| `firestore_service.dart` | All database operations | 443 |
| `debt_simplifier.dart` | Settlement optimization algorithm | 107 |
| `user_model.dart` | User data structure | 125 |
| `pool_model.dart` | Group/pool data structure | 53 |
| `server/index.js` | AI APIs, push notifications | 446 |

---

## Notable Implementation Details

1. **Client-side sorting:** Done to avoid Firestore composite index requirements
2. **Batch writes:** Used for atomic pool+expense updates
3. **Graceful degradation:** Voice expense falls back to raw transcript if AI parsing fails
4. **Server-side validation:** Receipt amounts of 0 rejected; invalid categories rejected
5. **Duplicate nudge prevention:** Unread nudges block new ones between same users
6. **Notification triggers:** HTTP calls to Node server for FCM delivery

---

## Generated: March 2026
**Analysis by:** AI Code Review
**Project:** FinBuddy - PDEU Hackathon Submission
