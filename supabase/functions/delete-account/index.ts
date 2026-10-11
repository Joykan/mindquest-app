// Delete-account Edge Function ("Delete my data" in the app).
//
// POST with the signed-in user's access token. Deletes that user from
// Supabase Auth. Every table that belongs to a user (profiles, chats, moods,
// XP, badges, reads, quests) is removed with it through ON DELETE CASCADE.
// Crisis events keep only an anonymous count (user_id is set to null).
// Needs the service role key, so it can only run here, never in the app.

import { createClient } from "@supabase/supabase-js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "not signed in" }, 401);
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) return json({ error: "not signed in" }, 401);

  // Users can only ever delete themselves: the id comes from their own token.
  const { error: deleteError } = await admin.auth.admin.deleteUser(data.user.id);
  if (deleteError) {
    console.error("delete failed", deleteError.message);
    return json({ error: "could not delete the account" }, 500);
  }
  return json({ deleted: true });
});
