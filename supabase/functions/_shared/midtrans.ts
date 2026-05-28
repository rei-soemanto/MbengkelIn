// ─────────────────────────────────────────────────────────────────────────────
// Midtrans configuration — the ONE place to configure the integration.
//
// Set these as Supabase Edge Function secrets (NEVER commit the server key):
//
//   supabase secrets set MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxx
//   supabase secrets set MIDTRANS_IS_PRODUCTION=false   # optional, defaults to false
//
// Or via the dashboard: Project Settings → Edge Functions → Secrets.
//
// The webhook must also be registered in the Midtrans dashboard
// (Settings → Configuration → Payment Notification URL):
//
//   https://nerrnpbopdfrdcfvjowx.supabase.co/functions/v1/midtrans-webhook
// ─────────────────────────────────────────────────────────────────────────────

export const MIDTRANS_SERVER_KEY = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";

export const IS_PRODUCTION =
  (Deno.env.get("MIDTRANS_IS_PRODUCTION") ?? "false").toLowerCase() === "true";

// Snap API — used to create a transaction and obtain a redirect_url.
export const SNAP_BASE_URL = IS_PRODUCTION
  ? "https://app.midtrans.com/snap/v1/transactions"
  : "https://app.sandbox.midtrans.com/snap/v1/transactions";

// HTTP Basic auth header: base64(serverKey + ":").
export function authHeader(): string {
  return "Basic " + btoa(MIDTRANS_SERVER_KEY + ":");
}

// Verifies the Midtrans notification signature:
//   sha512(order_id + status_code + gross_amount + serverKey)
export async function verifySignature(
  orderId: string,
  statusCode: string,
  grossAmount: string,
  signatureKey: string,
): Promise<boolean> {
  const raw = orderId + statusCode + grossAmount + MIDTRANS_SERVER_KEY;
  const bytes = new TextEncoder().encode(raw);
  const digest = await crypto.subtle.digest("SHA-512", bytes);
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hex === signatureKey;
}

// Maps a Midtrans transaction_status (+ fraud_status) to our internal topup status.
export function mapTransactionStatus(
  transactionStatus: string,
  fraudStatus?: string,
): "success" | "pending" | "failed" | "expired" | "cancelled" {
  switch (transactionStatus) {
    case "capture":
      return fraudStatus === "challenge" ? "pending" : "success";
    case "settlement":
      return "success";
    case "pending":
      return "pending";
    case "deny":
    case "failure":
      return "failed";
    case "cancel":
      return "cancelled";
    case "expire":
      return "expired";
    default:
      return "pending";
  }
}
