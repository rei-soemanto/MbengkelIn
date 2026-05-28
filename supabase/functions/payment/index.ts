import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  authHeader,
  MIDTRANS_SERVER_KEY,
  SNAP_BASE_URL,
} from "../_shared/midtrans.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!MIDTRANS_SERVER_KEY) {
    return json({ error: "MIDTRANS_SERVER_KEY is not configured" }, 500);
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization) {
    return json({ error: "Missing Authorization header" }, 401);
  }

  // Authenticated client (resolves the calling user from their JWT).
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ error: "Unauthorized" }, 401);
  }
  const user = userData.user;

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = (payload.action as string) ?? "createTopup";
  if (action !== "createTopup") {
    return json({ error: "Unknown action" }, 400);
  }

  const amount = Math.floor(Number(payload.amount));
  if (!Number.isFinite(amount) || amount < 10000) {
    return json({ error: "Minimum top-up is Rp10.000" }, 400);
  }
  if (amount > 10000000) {
    return json({ error: "Maximum top-up is Rp10.000.000" }, 400);
  }

  // Service-role client for privileged writes (bypasses RLS).
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const orderId = `topup-${user.id.slice(0, 8)}-${Date.now()}`;

  const { error: insertError } = await adminClient.from("topups").insert({
    user_id: user.id,
    order_id: orderId,
    gross_amount: amount,
    status: "pending",
  });
  if (insertError) {
    return json({ error: insertError.message }, 400);
  }

  const customerName =
    (user.user_metadata?.name as string | undefined) ?? "MbengkelIn User";

  const snapBody = {
    transaction_details: {
      order_id: orderId,
      gross_amount: amount,
    },
    customer_details: {
      first_name: customerName,
      email: user.email ?? undefined,
    },
    item_details: [
      {
        id: "balance-topup",
        name: "Top Up Saldo MbengkelIn",
        price: amount,
        quantity: 1,
      },
    ],
  };

  const snapResponse = await fetch(SNAP_BASE_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: authHeader(),
    },
    body: JSON.stringify(snapBody),
  });

  const snapData = await snapResponse.json();
  if (!snapResponse.ok) {
    await adminClient
      .from("topups")
      .update({ status: "failed", updated_at: new Date().toISOString() })
      .eq("order_id", orderId);
    const message = Array.isArray(snapData?.error_messages)
      ? snapData.error_messages.join(", ")
      : (snapData?.status_message ?? "Midtrans request failed");
    return json({ error: message }, 400);
  }

  await adminClient
    .from("topups")
    .update({
      redirect_url: snapData.redirect_url,
      snap_token: snapData.token,
      updated_at: new Date().toISOString(),
    })
    .eq("order_id", orderId);

  return json({
    order_id: orderId,
    redirect_url: snapData.redirect_url,
    token: snapData.token,
  });
});
