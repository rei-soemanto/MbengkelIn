import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  mapTransactionStatus,
  MIDTRANS_SERVER_KEY,
  verifySignature,
} from "../_shared/midtrans.ts";

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

  // Single atomic settlement: credits the balance (idempotently, never
  // double-crediting an already-successful topup) AND flips the topup status
  // in one transaction.
  const { error } = await adminClient.rpc("settle_topup", {
    p_order_id: orderId,
    p_status: newStatus,
    p_payment_type: paymentType,
  });

  if (error) {
    const notFound = (error.message ?? "").toLowerCase().includes("not found");
    return json({ error: error.message }, notFound ? 404 : 500);
  }

  return json({ received: true, status: newStatus });
});
