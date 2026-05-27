import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";
import { randomBytes, randomUUID } from "node:crypto";

const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, { auth: { persistSession: false } });

const lines = readFileSync("/tmp/seed/profiles.csv", "utf8").trim().split("\n");
const header = lines[0].split(";");
const col: Record<string, number> = {};
header.forEach((h, i) => (col[h] = i));

const wanted = new Set(["davismichael0055@gmail.com", "juwonfolorunsho01@gmail.com", "michaelvictor0014@gmail.com"]);
const rows: any[] = [];
for (let i = 1; i < lines.length; i++) {
  const p = lines[i].split(";");
  const email = p[col.email];
  if (!wanted.has(email)) continue;
  rows.push(p);
}

// Also one from screenshot only
rows.push(null); // sentinel for chineremfavour2023

const log: any[] = [];
for (const p of rows) {
  let id: string, email: string, full_name: string, meta: Record<string, any>;
  if (p === null) {
    id = randomUUID();
    email = "chineremfavour2023@gmail.com";
    full_name = "Chinemerem Favour";
    meta = { full_name };
  } else {
    id = p[col.id];
    email = p[col.email];
    full_name = p[col.full_name] || "";
    meta = { full_name };
  }

  const { data, error } = await admin.auth.admin.createUser({
    id, email, email_confirm: true,
    password: randomBytes(24).toString("hex"),
    user_metadata: meta,
  });
  if (error) { log.push({ email, err: error.message }); continue; }

  // Upsert profile with full CSV data when available
  if (p !== null) {
    const profile: Record<string, any> = {
      id,
      email,
      full_name,
      phone: p[col.phone] || null,
      discord_username: p[col.discord_username] || null,
      country: p[col.country] || null,
      server: p[col.server] || null,
      gang_name: p[col.gang_name] || null,
      gang_type: p[col.gang_type] || null,
      token_balance: parseInt(p[col.token_balance] || "0") || 0,
      ingame_name: p[col.ingame_name] || null,
      discord_full_name: p[col.discord_full_name] || null,
      referral_code: p[col.referral_code] || null,
      xp: parseInt(p[col.xp] || "0") || 0,
      vip_tier: p[col.vip_tier] || "bronze",
      accepted_terms: p[col.accepted_terms] === "true",
    };
    const { error: pe } = await admin.from("profiles").upsert(profile, { onConflict: "id" });
    if (pe) log.push({ email, profile_err: pe.message });
  }
  log.push({ email, id, ok: true });
}
console.log(JSON.stringify(log, null, 2));
