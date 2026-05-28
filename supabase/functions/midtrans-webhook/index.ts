import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  mapTransactionStatus,
  MIDTRANS_SERVER_KEY,
  verifySignature,
} from "../_shared/midtrans.ts";

// This endpoint is called server-to-server by Midtrans, not by the app.
// It has verify_jwt disabled; authenticity is enforced via the signature_key.

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!MIDTRANS_SERVER_KEY) {
    return json({ error: "MIDTRANS_SERVER_KEY is not configured" }, 500);
  }

  let n: Record<string, unknown>;
  try {
    n = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const orderId = String(n.order_id ?? "");
  const statusCode = String(n.status_code ?? "");
  const grossAmount = String(n.gross_amount ?? "");
  const signatureKey = String(n.signature_key ?? "");
  const transactionStatus = String(n.transaction_status ?? "");
  const fraudStatus = n.fraud_status ? String(n.fraud_status) : undefined;
  const paymentType = n.payment_type ? String(n.payment_type) : null;

  const valid = await verifySignature(orderId, statusCode, grossAmount, signatureKey);
  if (!valid) {
    return json({ error: "Invalid signature" }, 403);
  }

  const newStatus = mapTransactionStatus(transactionStatus, fraudStatus);

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: topup, error: fetchError } = await adminClient
    .from("topups")
    .select("id, user_id, gross_amount, status")
    .eq("order_id", orderId)
    .single();

  if (fetchError || !topup) {
    return json({ error: "Top-up not found" }, 404);
  }

  // Credit the balance exactly once, on the transition into "success".
  if (newStatus === "success" && topup.status !== "success") {
    const { error: creditError } = await adminClient.rpc("increment_user_balance", {
      p_user_id: topup.user_id,
      p_amount: topup.gross_amount,
    });
    if (creditError) {
      return json({ error: creditError.message }, 500);
    }
  }

  const { error: updateError } = await adminClient
    .from("topups")
    .update({
      status: newStatus,
      payment_type: paymentType,
      updated_at: new Date().toISOString(),
    })
    .eq("order_id", orderId);

  if (updateError) {
    return json({ error: updateError.message }, 500);
  }

  return json({ received: true, status: newStatus });
});
