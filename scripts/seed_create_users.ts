// Creates auth.users rows with exact UUIDs+emails from profiles.csv
// Uses Supabase admin API. Users get random throwaway passwords;
// real users will reset via "forgot password".
import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";

const url = process.env.SUPABASE_URL!;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const admin = createClient(url, key, { auth: { persistSession: false } });

const csv = readFileSync("/tmp/seed/profiles.clean.csv", "utf8").trim().split("\n");
const header = csv[0].split(";");
const idx = (n: string) => header.indexOf(n);
const I = { id: idx("id"), email: idx("email"), full: idx("full_name") };

let created = 0, skipped = 0, failed = 0;
const fails: string[] = [];

for (let i = 1; i < csv.length; i++) {
  // simple split (no quoted commas in id/email/full_name expected)
  const parts = csv[i].split(";");
  const id = parts[I.id]?.trim();
  const email = parts[I.email]?.trim();
  const full = parts[I.full]?.trim() || "";
  if (!id || !email || !email.includes("@")) { skipped++; continue; }

  const { error } = await admin.auth.admin.createUser({
    id,
    email,
    email_confirm: true,
    password: randomBytes(24).toString("hex"),
    user_metadata: { full_name: full },
  });
  if (error) {
    if (/already|exists|registered/i.test(error.message)) { skipped++; }
    else { failed++; fails.push(`${email}: ${error.message}`); }
  } else {
    created++;
  }
}
console.log(JSON.stringify({ created, skipped, failed, fails: fails.slice(0, 10) }, null, 2));
