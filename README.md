# FinBuddy

FinBuddy is a smart expense tracking and bill-splitting app built to make both **personal finance** and **group spending** easier to manage.

Whether you are splitting a trip with friends, managing shared flat expenses, or simply trying to stay on top of your own spending, FinBuddy helps you track money clearly, reduce confusion, and settle faster.

## What FinBuddy Does

FinBuddy brings together two important parts of everyday money management:

- **Personal finance tracking** for recording your income and expenses
- **Shared expense management** for splitting bills and settling group balances

It is designed to reduce the awkward and messy parts of money sharing, like remembering who paid, calculating who owes what, and figuring out the easiest way to settle up.

## Why It's Useful

FinBuddy is built to give users practical value in real situations.

### For individuals

- Track daily spending and income in one place
- Get a clearer view of your monthly balance
- Record recurring income and fixed monthly expenses
- Review and edit your transaction history easily

### For groups

- Create pools for trips, outings, roommates, or shared events
- Add shared expenses with flexible split options
- See exactly who owes whom
- Reduce the number of settlement transactions using smart debt simplification
- Send payment reminders when someone has not settled yet

### For faster expense entry

- Scan receipts to pre-fill expense details
- Use voice input to quickly log shared expenses
- Invite members with QR codes or invite codes
- Settle payments through UPI links

## Typical Use Cases

FinBuddy works especially well for:

- friends going on trips
- roommates sharing rent, groceries, and bills
- students managing shared expenses
- event organizers handling pooled spending
- anyone who wants a simple personal finance companion alongside group expense tracking

## Key Benefits

- **Less confusion**: everyone can see the same shared expense history
- **Less manual calculation**: balances and settlements are computed automatically
- **Less friction**: smart input features reduce typing
- **More transparency**: every pool keeps a clear expense record
- **Faster settlements**: users can move from "who owes whom?" to "done"

## Main Features

- Google sign-in
- Personal income and expense tracking
- Monthly balance summary
- Recurring income and recurring expense setup
- Group pools for shared spending
- Equal, exact, and percentage-based splitting
- QR-based pool invites and joining
- Receipt scanning
- Voice-based expense entry
- Debt simplification for optimized settlements
- UPI-based payment flow
- In-app notifications and nudges
- Pool PDF report export

## User Experience at a Glance

The experience is designed to stay simple:

1. Sign in and complete a quick setup
2. Start tracking your own transactions
3. Create or join a pool for shared expenses
4. Add expenses manually or with smart tools
5. Let FinBuddy calculate balances automatically
6. Settle up with minimal back-and-forth

## Tech Overview

FinBuddy is built with a modern mobile-first stack that supports real-time data, secure authentication, and AI-assisted workflows.

### Core technologies

- **Flutter** for the mobile app experience
- **Dart** for application logic
- **Firebase Authentication** for user sign-in
- **Cloud Firestore** for real-time data storage
- **Firebase Cloud Messaging** for notifications
- **Node.js + Express** for backend API endpoints

### Smart features and integrations

- **Deepgram** for speech-to-text in voice expense flow
- **NVIDIA NIM** for AI-powered parsing of receipts and spoken expense input
- **UPI deep linking** for payments
- **QR scanning and QR generation** for group invites
- **PDF generation** for pool reports

## Tech Stack Summary

- Frontend: Flutter, Dart
- Backend: Node.js, Express
- Database: Cloud Firestore
- Authentication: Firebase Auth, Google Sign-In
- Notifications: Firebase Cloud Messaging
- AI features: Deepgram, NVIDIA NIM
- Mobile integrations: Camera, Microphone, QR Scanner, UPI deep links

## Project Structure

This repository mainly contains:

- `finbuddy/` for the Flutter mobile app
- `server/` for the backend services used by AI and notifications
- `Docs/` for project documentation assets

## Setup Overview

To run the project fully, you will need:

- Flutter SDK
- Firebase project configuration
- Android and/or iOS mobile setup
- Backend environment variables for AI and Firebase Admin services

At a high level:

1. Set up Firebase credentials for the mobile app
2. Install Flutter dependencies in `finbuddy/`
3. Install Node dependencies in `server/`
4. Configure backend environment variables
5. Run the backend server
6. Launch the Flutter app

## Final Note

FinBuddy is best understood as a **smart shared-expense and personal finance companion**. It helps users stay organized, settle faster, and avoid the usual confusion that comes with managing money alone or in groups.

