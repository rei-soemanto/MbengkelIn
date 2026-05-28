import Foundation

// Sent to the `payment` edge function to start a top-up.
struct CreateTopupRequest: Encodable {
    let action: String
    let amount: Int
}

// Returned by the `payment` edge function.
struct CreateTopupResponse: Decodable {
    let order_id: String
    let redirect_url: String
    let token: String
}
