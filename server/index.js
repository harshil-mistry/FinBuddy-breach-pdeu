require("dotenv").config();
const express = require("express");
const cors = require("cors");
const multer = require("multer");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

// --- Firebase Admin Setup ---
const admin = require("firebase-admin");
try {
    let serviceAccount;
    // Attempt to load from base64 env variable if it exists
    if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
        const decodedKey = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
        serviceAccount = JSON.parse(decodedKey);
    } else {
        // Fallback to local json file if env variable isn't present
        serviceAccount = require("./serviceAccountKey.json");
    }

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
    console.log("✅ Firebase Admin initialized successfully (Push Notifications enabled).");
} catch (err) {
    console.warn("⚠️  Firebase Admin INIT FAILED: You need to set FIREBASE_SERVICE_ACCOUNT_BASE64 in your .env file or have a valid serviceAccountKey.json file.");
}

// --- CORS ---
app.use(cors());
app.use(express.json());

// --- Multer (temp file storage) ---
const upload = multer({ dest: path.join(__dirname, "uploads") });

// Ensure uploads dir exists
if (!fs.existsSync(path.join(__dirname, "uploads"))) {
    fs.mkdirSync(path.join(__dirname, "uploads"));
}

// --- Health check ---
app.get("/", (req, res) => {
    res.json({ status: "ok", message: "FinBuddy Receipt Scanner API is running" });
});

// --- POST /api/scan-receipt ---
app.post("/api/scan-receipt", upload.single("image"), async (req, res) => {
    try {
        if (!req.file) {
            console.log("❌ No file uploaded in request");
            return res.status(400).json({ status: false, error: "No image uploaded" });
        }

        console.log(`📸 Received file: ${req.file.originalname} (${req.file.size} bytes, mimetype: ${req.file.mimetype})`);

        // Read the uploaded file as base64
        const filePath = req.file.path;
        const imageBuffer = fs.readFileSync(filePath);
        const base64Image = imageBuffer.toString("base64");
        console.log(`📦 Base64 encoded length: ${base64Image.length} chars`);

        // Determine mime type from original filename or multer mimetype
        const mimeType = req.file.mimetype || "image/jpeg";

        // Clean up temp file
        fs.unlinkSync(filePath);
        console.log("🗑️  Temp file deleted");

        // Validate API key
        const apiKey = process.env.NVIDIA_API_KEY;
        if (!apiKey || apiKey === "your_nvidia_api_key_here") {
            console.log("❌ NVIDIA_API_KEY not set in .env");
            return res.status(500).json({ status: false, error: "NVIDIA_API_KEY not configured" });
        }
        console.log(`🔑 API Key present: ${apiKey.substring(0, 10)}...`);

        const systemPrompt = `You are a strict receipt scanner. Analyze the image carefully.

OUTPUT RULES — follow these exactly:
- If the image clearly shows a receipt, invoice, or bill with a readable total amount: respond with ONLY this JSON: {"status": true, "amount": <number>, "description": "<category>"}
- In ALL other cases (photo of people, food, scenery, blurry image, document without a total, anything ambiguous): respond with ONLY: {"status": false}

FOR AMOUNT:
- Extract the final grand total / amount payable / total due as a plain number. No currency symbols. No strings.
- NEVER return 0 as the amount. If amount is 0 or unknown, return {"status": false}

FOR DESCRIPTION — choose EXACTLY ONE from this fixed list based on the items on the receipt:
- "Food" — restaurants, cafes, food delivery, fast food
- "Groceries" — supermarket, grocery store, general provisions
- "Clothes" — clothing, apparel, footwear, fashion
- "Travel" — flights, trains, buses, taxis, hotels, accommodation
- "Fuel" — petrol, diesel, CNG, EV charging
- "Utilities" — electricity, water, gas, internet, phone bill
- "Medical" — pharmacy, hospital, clinic, lab tests
- "Entertainment" — movies, events, games, subscriptions
- "Electronics" — gadgets, appliances, computer parts
- "Stationery" — books, pens, office supplies
- "Other" — any other category

DO NOT explain your answer. Do NOT include markdown. Return ONLY the raw JSON object, nothing else.

Examples:
{"status": true, "amount": 450.50, "description": "Food"}
{"status": true, "amount": 1299, "description": "Clothes"}
{"status": false}`;

        const payload = {
            model: "meta/llama-3.2-11b-vision-instruct",
            messages: [
                {
                    role: "user",
                    content: [
                        {
                            type: "text",
                            text: `${systemPrompt}\n\nAnalyze this image. If it is a receipt or bill, extract the total amount and categorize it. Return only JSON.`,
                        },
                        {
                            type: "image_url",
                            image_url: {
                                url: `data:${mimeType};base64,${base64Image}`,
                            },
                        },
                    ],
                },
            ],
            max_tokens: 200,
            temperature: 0.1,
        };

        const nimUrl = "https://integrate.api.nvidia.com/v1/chat/completions";
        console.log(`🚀 Calling Nvidia NIM: ${nimUrl}`);
        console.log(`   Model: ${payload.model}`);

        const response = await fetch(nimUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${apiKey}`,
            },
            body: JSON.stringify(payload),
        });

        console.log(`📡 NIM API response status: ${response.status}`);

        if (!response.ok) {
            const errText = await response.text();
            console.error("❌ Nvidia NIM API error:", response.status, errText);
            return res.status(502).json({ status: false, error: `AI service error: ${response.status}` });
        }

        const data = await response.json();
        const content = data.choices?.[0]?.message?.content || "";
        console.log("🤖 Raw AI response:", content);

        // Try to parse the AI response as JSON
        let parsed;
        try {
            const jsonMatch = content.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                parsed = JSON.parse(jsonMatch[0]);
                console.log("✅ Parsed JSON:", parsed);
            } else {
                console.log("⚠️  No JSON found in AI response, returning status:false");
                parsed = { status: false };
            }
        } catch (parseErr) {
            console.error("❌ Failed to parse AI response:", parseErr.message);
            parsed = { status: false };
        }

        // Server-side guard: reject 0 amount or General category (false positives)
        const VALID_CATEGORIES = ["Food", "Groceries", "Clothes", "Travel", "Fuel", "Utilities", "Medical", "Entertainment", "Electronics", "Stationery"];
        if (parsed.status === true) {
            const amount = typeof parsed.amount === "number" ? parsed.amount : parseFloat(parsed.amount) || 0;
            const description = typeof parsed.description === "string" ? parsed.description.trim() : "";

            if (amount <= 0) {
                console.log("⚠️  Rejected: amount is 0 or invalid");
                return res.json({ status: false });
            }
            if (!VALID_CATEGORIES.includes(description)) {
                console.log(`⚠️  Rejected: invalid/General category "${description}"`);
                return res.json({ status: false });
            }

            const result = { status: true, amount, description };
            console.log("✅ Returning success:", result);
            return res.json(result);
        } else {
            console.log("ℹ️  Returning status:false (no receipt detected)");
            return res.json({ status: false });
        }
    } catch (err) {
        console.error("💥 Server error:", err);
        return res.status(500).json({ status: false, error: "Internal server error" });
    }
});

app.listen(PORT, "0.0.0.0", () => {
    console.log(`✅ FinBuddy Receipt Scanner running on http://0.0.0.0:${PORT}`);
    console.log(`   POST /api/scan-receipt  — Upload a receipt image`);
    console.log(`   POST /api/send-nudge    — Send a push notification (FCM)`);
});

// --- POST /api/send-nudge ---
app.post("/api/send-nudge", async (req, res) => {
    try {
        const { fcmToken, senderName, amount } = req.body;

        if (!fcmToken || !senderName || !amount) {
            return res.status(400).json({ status: false, error: "Missing required fields: fcmToken, senderName, or amount" });
        }

        const message = {
            token: fcmToken,
            notification: {
                title: "Payment Reminder 💸",
                body: `${senderName} nudged you to settle up ₹${amount}.`,
            },
            data: {
                type: "nudge",
            },
            android: {
                notification: {
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            }
        };

        const response = await admin.messaging().send(message);
        console.log(`🚀 Push notification sent to ${senderName}'s debtor:`, response);
        return res.json({ status: true, messageId: response });

    } catch (err) {
        console.error("❌ Send Nudge Error:", err.message);
        return res.status(500).json({ status: false, error: err.message });
    }
});
