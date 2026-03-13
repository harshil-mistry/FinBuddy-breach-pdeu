# Smart Expense Splitting & Settlement System

## Context & Problem Statement
[cite_start]Group payments are common in everyday situations such as shared travel, restaurant bills, hostel expenses, and event planning. [cite: 1] [cite_start]Currently, most people rely on informal methods such as manually calculating expenses, using spreadsheets, or messaging apps to track who owes whom. [cite: 2] [cite_start]This often leads to confusion, delayed settlements, and inaccurate calculations. [cite: 3] [cite_start]While digital payment platforms allow quick money transfers, they do not effectively manage multi-person expense tracking and optimized settlement when multiple transactions occur among a group. [cite: 4] 

[cite_start]The challenge is to build a financial expense management platform that allows users to create groups, record shared expenses, track balances, and automatically calculate the minimum number of transactions required to settle all debts within the group. [cite: 5] [cite_start]The system should allow users to split bills using different methods (equal split, percentage split, custom split) and maintain a transparent ledger of transactions. [cite: 6] [cite_start]The platform should also integrate with digital payment systems to allow users to settle balances directly within the application. [cite: 7] [cite_start]The focus of this challenge is on financial transaction modeling, ledger management, and settlement optimization algorithms rather than Al. [cite: 8]

## Impact
* [cite_start]Reduces financial confusion in shared expense scenarios for college students, friends, and event organizers. [cite: 9]
* [cite_start]Minimizes number of settlement transactions, saving time and effort. [cite: 10]
* [cite_start]Promotes transparency in group finances through clear transaction ledgers. [cite: 11]
* [cite_start]Encourages responsible financial tracking and improves the digital payment experience. [cite: 11]

## Tech Stack
* [cite_start]**Frontend:** Flutter (Dart) [cite: 13]
* [cite_start]**Backend API:** Node.js with Express [cite: 13] (Designed for easy migration to AWS Lambda)
* **Database & Authentication:** Firebase (Firestore for the NoSQL transaction ledger, Firebase Auth for secure user management)
* **AI & Processing (Integrated in Express):**
  * **Speech-to-Text:** Deepgram API
  * **LLM / Parsing:** Google Gemini API
  * **OCR:** Tesseract.js (Running natively within the Node environment)
* [cite_start]**Algorithms:** Directed Graph algorithms for settlement optimization [cite: 13]
* [cite_start]**Integrations:** UPI Deep-linking for direct payments [cite: 13]

## System Architecture
The application follows a streamlined client-server architecture, utilizing a secure Node.js backend to protect third-party API keys and process AI tasks without needing separate microservices.

1. **Client Layer (Flutter App):** Manages local state, authenticates via Firebase SDK, captures audio/images for smart features, generates/scans QR codes, and renders the Debt Graph UI.
2. **Proxy & Logic API (Express):** Acts as the secure middleman. It verifies Firebase ID tokens, processes graph algorithms, and executes the heavy AI tasks (Deepgram, Gemini, Tesseract) using securely stored `.env` variables.
3. **Data Layer (Firebase):** Firestore maintains the immutable ledger of users, groups, and expenses. Firebase Auth handles secure sign-ups, logins, and token generation.

## User Flow
1. **Onboarding & Groups:** User logs in via Firebase Auth. The dashboard separates Personal and Shared expenses. The user can create a group and share a generated QR code.
2. **Joining:** Friends scan the QR code via the app to instantly join the Firestore group ledger.
3. **Logging an Expense (Manual/Smart):**
    * [cite_start]**Manual:** User inputs amount, category, and selects a split method (equal, percentage, custom). [cite: 6]
    * **Voice:** User holds the mic and speaks. The Express backend uses Deepgram to transcribe the audio, then passes the transcript to Gemini to extract the JSON payload (Amount, Payer, Split).
    * **OCR:** User uploads a receipt. The Express backend uses Tesseract.js to extract line items, allowing the user to assign specific items to specific friends.
4. **Ledger Update:** The system writes the transaction to Firestore. Personal portions of shared expenses are automatically tagged to the user's personal analytics.
5. **Settlement Optimization:** The user navigates to the "Settlement" tab. The app fetches the group's debts, runs the graph optimization algorithm, and displays the simplified debt routes (Debt Graph UI).
6. **Payment:** User clicks "Pay Now" next to a debt. The app triggers a UPI deep-link, opening the user's preferred UPI app with the exact amount and recipient details pre-filled.

## Core Logic & Data Flow
* [cite_start]**Debt Simplification (Graph Algorithm):** * Data from Firestore is modeled as a directed graph where nodes represent users and edges represent debts. [cite: 13]
    * The algorithm calculates the net balance for each node (Total In - Total Out).
    * It separates users into "Debtors" (negative balance) and "Creditors" (positive balance).
    * It iteratively matches the largest debtor with the largest creditor to create a new, simplified transaction edge, repeating until all balances are zero.
* **AI Proxy Data Flow (Express Integration):** * Flutter sends a base64 encoded audio file to `POST /api/smart-log/voice`. 
    * Express verifies the Firebase auth token.
    * Express calls Deepgram API with the audio payload and receives a text transcript.
    * Express immediately sends that transcript to the Gemini API with a strict system prompt to return a structured JSON object (e.g., `{"amount": 800, "payer": "Aman", "split": "equal"}`).
    * Express returns this JSON to Flutter to populate the UI before the user confirms the final write to Firestore.