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
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, "uploads"));
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const ext = path.extname(file.originalname) || '.m4a';
    cb(null, `voice_${timestamp}${ext}`);
  }
});
const upload = multer({ storage: storage });

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

// --- POST /api/send-expense-notification ---
app.post("/api/send-expense-notification", async (req, res) => {
    try {
        const { fcmToken, adderName, amount, groupName } = req.body;

        if (!fcmToken || !adderName || amount == null || !groupName) {
            return res.status(400).json({ status: false, error: "Missing fields" });
        }

        const message = {
            token: fcmToken,
            notification: {
                title: "New Group Expense 🧾",
                body: `${adderName} added a ₹${amount} expense in "${groupName}".`,
            },
            data: {
                type: "new_expense",
            },
            android: {
                notification: {
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            }
        };

        const response = await admin.messaging().send(message);
        console.log(`🚀 Expense push notification sent to a group member:`, response);
        return res.json({ status: true, messageId: response });

    } catch (err) {
        console.error("❌ Send Expense Notification Error:", err.message);
        return res.status(500).json({ status: false, error: err.message });
    }
});

// --- POST /api/voice-expense ---
// Receives: multipart audio file + "members" JSON string [{ uid, name }]
// Returns: { status: true, description, amount, participantUids }
// OR { status: false, error }
app.post("/api/voice-expense", upload.single("audio"), async (req, res) => {
  const startTime = Date.now();
  const audioPath = req.file?.path;
  const requestId = `voice-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  console.log(`\n🎙️ [${requestId}] === VOICE EXPENSE REQUEST STARTED ===`);
  
  try {
    // ── Step 1: Validate request ──────────────────────────────────────
    console.log(`[${requestId}] Step 1/8: Validating request...`);
    
    if (!req.file) {
      console.log(`[${requestId}] ❌ Validation failed: No audio file uploaded`);
      return res.status(400).json({ status: false, error: "No audio file uploaded." });
    }
    console.log(`[${requestId}] ✅ Audio file received: ${req.file.originalname} (${req.file.size} bytes, mimetype: ${req.file.mimetype})`);

    let members = [];
    try {
      members = JSON.parse(req.body.members || "[]");
      console.log(`[${requestId}] ✅ Members JSON parsed: ${members.length} member(s)`);
      if (members.length > 0) {
        console.log(`[${requestId}]    Members: ${members.map(m => m.name).join(', ')}`);
      }
    } catch (_) {
      console.log(`[${requestId}] ❌ Validation failed: Invalid members JSON`);
      return res.status(400).json({ status: false, error: "Invalid members JSON." });
    }

    if (!Array.isArray(members) || members.length === 0) {
      console.log(`[${requestId}] ❌ Validation failed: Members list empty or invalid`);
      return res.status(400).json({ status: false, error: "members list is empty or invalid." });
    }

    // ── Step 2: Check Deepgram API Key ──────────────────────────────────────────
    console.log(`[${requestId}] Step 2/8: Checking Deepgram API key...`);
    const deepgramKey = process.env.DEEPGRAM_API_KEY;
    if (!deepgramKey) {
      console.log(`[${requestId}] ❌ Configuration error: DEEPGRAM_API_KEY not set in environment`);
      return res.status(500).json({ status: false, error: "DEEPGRAM_API_KEY not configured." });
    }
    console.log(`[${requestId}] ✅ Deepgram API key found (${deepgramKey.substring(0, 8)}...)`);

    // ── Step 3: Read audio file ──────────────────────────────────────────
    console.log(`[${requestId}] Step 3/8: Reading audio file from disk...`);
    let audioBuffer;
    try {
      audioBuffer = fs.readFileSync(audioPath);
      console.log(`[${requestId}] ✅ Audio file read: ${audioBuffer.length} bytes`);
    } catch (err) {
      console.log(`[${requestId}] ❌ Failed to read audio file: ${err.message}`);
      return res.status(500).json({ status: false, error: "Failed to read audio file." });
    }
    
    const mimeType = req.file.mimetype || "audio/m4a";
    console.log(`[${requestId}]    MIME type: ${mimeType}`);

    // ── Step 4: Call Deepgram STT ──────────────────────────────────────────
    console.log(`[${requestId}] Step 4/8: Sending audio to Deepgram STT...`);
    const deepgramUrl = "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&language=en";
    console.log(`[${requestId}]    Deepgram URL: ${deepgramUrl}`);
    
    const dgResponse = await fetch(deepgramUrl, {
      method: "POST",
      headers: {
        "Authorization": `Token ${deepgramKey}`,
        "Content-Type": mimeType,
      },
      body: audioBuffer,
    });

    console.log(`[${requestId}]    Deepgram response status: ${dgResponse.status} ${dgResponse.statusText}`);

    if (!dgResponse.ok) {
      const dgErr = await dgResponse.text();
      console.log(`[${requestId}] ❌ Deepgram STT failed: ${dgErr}`);
      return res.status(502).json({ status: false, error: "Speech-to-text service error. Please try again." });
    }

    const dgData = await dgResponse.json();
    const transcript = dgData?.results?.channels?.[0]?.alternatives?.[0]?.transcript?.trim();
    
    console.log(`[${requestId}] ✅ Deepgram transcript: "${transcript || '[EMPTY]' }"`);

    if (!transcript || transcript.length < 3) {
      console.log(`[${requestId}] ❌ Transcript too short or empty (length: ${transcript?.length || 0})`);
      console.log(`[${requestId}]    Full Deepgram response: ${JSON.stringify(dgData, null, 2).substring(0, 1000)}`);
      console.log(`[${requestId}]    Audio file kept at: ${audioPath}`);
      return res.json({ status: false, error: "Could not understand the recording. Please speak clearly and try again." });
    }

    // ── Step 5: Check NVIDIA API Key ──────────────────────────────────────────
    console.log(`[${requestId}] Step 5/8: Checking NVIDIA API key...`);
    const nimKey = process.env.NVIDIA_API_KEY;
    if (!nimKey) {
      console.log(`[${requestId}] ❌ Configuration error: NVIDIA_API_KEY not set in environment`);
      return res.status(500).json({ status: false, error: "NVIDIA_API_KEY not configured." });
    }
    console.log(`[${requestId}] ✅ NVIDIA API key found (${nimKey.substring(0, 8)}...)`);

    const membersStr = members.map(m => `{ "uid": "${m.uid}", "name": "${m.name}" }`).join(", ");
    const allUids = members.map(m => m.uid);
    console.log(`[${requestId}]    Prepared ${allUids.length} member UIDs for LLM`);

    const systemPrompt = `You are a precise expense-parsing assistant for a bill-splitting app.

Pool members: [${membersStr}]

Your task: Parse the user's spoken transcript and extract expense details.

Rules:
1. Return ONLY a valid JSON object — no markdown, no explanation, no extra text.
2. "description": a short title (2-4 words) for the expense. Capitalize first letter.
3. "amount": a number (no currency symbol). If not mentioned, use null.
4. "participantUids": array of uid strings from the members list who should share the expense.
   - Match names mentioned in the transcript to members by name (case-insensitive, partial match ok).
   - If no specific names are mentioned, or the word "everyone"/"all" is used, include ALL member uids.
   - If you cannot identify any member names, include ALL member uids.
5. "paidByUid": uid of the person who paid. Match "I" to the first member, or match a name. If unclear, use null.

Output format (strict):
{"description":"<string>","amount":<number or null>,"participantUids":[<uids>],"paidByUid":<uid or null>}`;

    const userMessage = `Transcript: "${transcript}"`;

    // ── Step 6: Call NVIDIA NIM LLM ──────────────────────────────────────────
    console.log(`[${requestId}] Step 6/8: Sending request to NVIDIA NIM LLM...`);
    // Try different model names - if one fails, the API will return an error
    const modelName = "meta/llama-3.1-70b-instruct";
    console.log(`[${requestId}]    Model: ${modelName}`);
    console.log(`[${requestId}]    Temperature: 0.1, Max tokens: 256`);
    console.log(`[${requestId}]    System prompt length: ${systemPrompt.length} chars`);
    console.log(`[${requestId}]    User message: "${userMessage}"`);
    
    const nimResponse = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${nimKey}`,
      },
      body: JSON.stringify({
        model: modelName,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userMessage },
      ],
      max_tokens: 256,
      temperature: 0.1,
    }),
  });

  console.log(`[${requestId}]    NIM response status: ${nimResponse.status} ${nimResponse.statusText}`);
  console.log(`[${requestId}]    NIM response headers: ${JSON.stringify(Object.fromEntries(nimResponse.headers.entries()))}`);

  if (!nimResponse.ok) {
    const nimErr = await nimResponse.text();
    console.log(`[${requestId}] ❌ NVIDIA NIM API error: ${nimErr.substring(0, 200)}...`);
    return res.status(502).json({ status: false, error: "AI parsing failed. Please try again." });
  }

  // ── Step 7: Parse LLM response ──────────────────────────────────────────
  console.log(`[${requestId}] Step 7/8: Parsing LLM response...`);
  
  // Get raw response first for debugging
  const nimResponseText = await nimResponse.text();
  console.log(`[${requestId}]    Raw response length: ${nimResponseText.length} chars`);
  console.log(`[${requestId}]    Raw response preview: "${nimResponseText.substring(0, 500)}"`);
  
  let nimData;
  try {
    nimData = JSON.parse(nimResponseText);
  } catch (parseErr) {
    console.log(`[${requestId}] ❌ Failed to parse NIM response as JSON: ${parseErr.message}`);
    return res.status(502).json({ status: false, error: "AI parsing failed. Invalid response format." });
  }
  
  console.log(`[${requestId}]    NIM response structure: ${JSON.stringify(Object.keys(nimData))}`);
  console.log(`[${requestId}]    Has 'choices' key: ${nimData.hasOwnProperty('choices')}`);
  if (nimData.choices) {
    console.log(`[${requestId}]    Number of choices: ${nimData.choices.length}`);
    if (nimData.choices.length > 0) {
      console.log(`[${requestId}]    First choice keys: ${JSON.stringify(Object.keys(nimData.choices[0]))}`);
      if (nimData.choices[0].message) {
        console.log(`[${requestId}]    Message content: "${nimData.choices[0].message.content}"`);
      }
    }
  }
  
  const rawText = nimData?.choices?.[0]?.message?.content?.trim() ?? "";
  
  console.log(`[${requestId}]    LLM raw response: "${rawText.substring(0, 200)}${rawText.length > 200 ? '...' : ''}"`);

  let parsed;
  try {
    // Strip accidental markdown code fences
    const cleaned = rawText.replace(/```json|```/g, "").trim();
    // Extract first JSON object from response (handles extra text)
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.log(`[${requestId}]    No JSON found in response, attempting fallback`);
      throw new Error("No JSON found in response");
    }
    parsed = JSON.parse(jsonMatch[0]);
    console.log(`[${requestId}] ✅ JSON parsed successfully`);
    console.log(`[${requestId}]    Parsed data: ${JSON.stringify(parsed).substring(0, 200)}`);
  } catch (parseErr) {
    console.log(`[${requestId}] ⚠️ JSON parse failed: ${parseErr.message}`);
    console.log(`[${requestId}]    Raw text: "${rawText.substring(0, 500)}"`);
    console.log(`[${requestId}]    Falling back to transcript-based response`);
    
    // Fallback: return transcript as description with no amount
    const fallbackResult = {
      status: true,
      description: transcript.substring(0, 50),
      amount: null,
      participantUids: allUids,
      paidByUid: null,
      transcript,
    };
    const duration = Date.now() - startTime;
    console.log(`[${requestId}] ✅ Fallback response created (${duration}ms total)`);
    return res.json(fallbackResult);
  }

  // ── Step 8: Validate and sanitize ──────────────────────────────────────────
  console.log(`[${requestId}] Step 8/8: Validating and sanitizing response...`);

  const description = typeof parsed.description === "string" && parsed.description.trim().length > 0
    ? parsed.description.trim()
    : transcript.substring(0, 50);
  console.log(`[${requestId}]    Description: "${description}"`);

  const amount = typeof parsed.amount === "number" && parsed.amount > 0
    ? parsed.amount
    : null;
  console.log(`[${requestId}]    Amount: ${amount ?? 'null'}`);

  // Ensure all returned uids actually exist in the members list
  let participantUids = Array.isArray(parsed.participantUids)
    ? parsed.participantUids.filter(uid => allUids.includes(uid))
    : [];
  if (participantUids.length === 0) {
    participantUids = allUids; // fallback to all
    console.log(`[${requestId}]    ⚠️ No valid participant UIDs found, falling back to all members`);
  }
  console.log(`[${requestId}]    Participants: ${participantUids.length} member(s)`);

  const paidByUid = allUids.includes(parsed.paidByUid) ? parsed.paidByUid : null;
  console.log(`[${requestId}]    Paid by: ${paidByUid ?? 'not specified'}`);

  const result = { status: true, description, amount, participantUids, paidByUid, transcript };
  const duration = Date.now() - startTime;
  console.log(`[${requestId}] ✅ VOICE EXPENSE SUCCESS (${duration}ms)`);
  console.log(`[${requestId}]    Result: ${JSON.stringify(result)}`);
  return res.json(result);

  } catch (err) {
    const duration = Date.now() - startTime;
    console.log(`[${requestId}] 💥 SERVER ERROR after ${duration}ms: ${err.message}`);
    console.log(`[${requestId}]    Stack trace: ${err.stack}`);
    return res.status(500).json({ status: false, error: "Internal server error. Please try again." });
  } finally {
    // Always clean up temp audio file
    console.log(`[${requestId}] Step 9: Cleaning up temporary files...`);
    if (audioPath && fs.existsSync(audioPath)) {
      try {
        fs.unlinkSync(audioPath);
        console.log(`[${requestId}] ✅ Temp audio file deleted: ${audioPath}`);
      } catch (cleanupErr) {
        console.log(`[${requestId}] ⚠️ Failed to delete temp file: ${cleanupErr.message}`);
      }
    } else {
      console.log(`[${requestId}]    No temp file to clean up`);
    }
    console.log(`[${requestId}] === VOICE EXPENSE REQUEST COMPLETE ===\n`);
  }
});
