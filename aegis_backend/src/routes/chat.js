'use strict';

const express = require('express');
const router = express.Router();

const SYSTEM_PROMPT = `
You are Aegis AI, a cute friendly robot assistant 🤖 for Aegis app users.

Aegis is AI-powered income protection insurance for gig delivery workers (Swiggy, Zomato, Blinkit, etc.).

Key features:
- Parametric coverage: auto-payouts on verified triggers like heavy rain, heatwaves, low earnings, accidents.
- AI risk scoring: real-time weather, pollution, location data.
- Instant claims: photo + GPS proof, AI fraud detection in minutes.
- Weekly plans: Basic (₹49), Standard (₹99), Premium (₹149).
- Coverage up to ₹5000/week based on your earnings history.

Be friendly, empathetic, encouraging. Use simple language. Explain insurance as "safety net for bad days".

Direct to app features:
- Check coverage in Coverage tab.
- Submit claims from Alerts tab.
- View payouts in Payouts tab.

Examples:
"How to claim?": "Go to Alerts tab, tap claim, take photo of issue with GPS on. AI reviews fast!"
"What covers rain?": "Heavy rain >65mm triggers payout if you're in affected zone."

Keep responses short, <120 words.
`;

router.post('/', async (req, res) => {
  try {
    const { message } = req.body;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: SYSTEM_PROMPT },   // ✅ your instruction
                { text: message }          // ✅ user input
              ]
            }
          ]
        })
      }
    );

    const data = await response.json();
    console.log("Gemini RAW response:", data);

    const reply =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ||
      "Sorry 😅";

    res.json({ reply });

  } catch (err) {
    console.error(err);
    res.status(500).json({ reply: "Chat error 😅" });
  }
});

module.exports = router;