# Firebase Firestore Workspace & Chat Sync Guide

**Prompt for Next.js Web Developer / AI:**
"We have implemented an advanced **Order Management Chat UI** and a **Workspace Timeline** in our Flutter mobile app. To ensure the Next.js website and the mobile app are perfectly synchronized, you must implement the exact same Firestore database schema and logic for the chat system and order management on the web platform."

### 1. The Orders Collection (`orders/{orderId}`)
The mobile app renders a visual Timeline Stepper based on the fields in this document. Ensure you update these fields during the order lifecycle:

- **`status` (String):** Must be one of: `"pending_payment"`, `"requirements"`, `"processing"`, `"delivered"`, `"completed"`, `"revision"`, `"disputed"`.
- **`price` (Number):** The order amount.
- **`projectDetails` (String):** Contains the submitted requirements text. (Populate this when buyer submits requirements).
- **`deliveryNote` (String):** The text message when the seller delivers the final work.
- **`deliveryLink` (String):** A URL to the delivered file/attachment.
- **`buyerReview` (Object):** When the order is completed and reviewed, save as `{ "rating": 5.0, "comment": "Great work!" }`.

### 2. The Chat Messages Collection (`conversations/{chatId}/messages`)
The chat interface now supports rich "System Cards" instead of normal chat bubbles for order events. When an event happens (e.g., payment is made, order is delivered), the web backend/frontend MUST push a message to Firestore in the following format:

**Base Structure for System Cards:**
```json
{
  "senderId": "system",
  "type": "system_notification",
  "createdAt": "Firebase Server Timestamp",
  "orderId": "ORD-123456"
}
```

#### Event 1: Payment Verified (Escrow Secured)
*Trigger: When buyer pays and order starts.*
```json
{
  "senderId": "system",
  "type": "system_notification",
  "actionType": "payment_verified",
  "text": "Funds of $150 have been secured in escrow. Please submit the requirements to start the order.",
  "price": 150
}
```

#### Event 2: Requirements Submitted
*Trigger: When buyer submits requirements.*
```json
{
  "senderId": "system",
  "type": "system_notification",
  "actionType": "requirements_submitted",
  "text": "The buyer has submitted the required information."
}
```

#### Event 3: Order Delivered
*Trigger: When freelancer delivers the work.*
```json
{
  "senderId": "system",
  "type": "system_notification",
  "actionType": "order_delivered",
  "text": "Here is the final delivery for your app design.",
  "metadata": {
    "deliveryLink": "https://url-to-attachment.com/file.zip"
  }
}
```

#### Event 4: Revision Requested
*Trigger: When buyer rejects delivery and asks for changes.*
```json
{
  "senderId": "system",
  "type": "system_notification",
  "actionType": "revision_requested",
  "text": "Please fix the color scheme on the home page."
}
```

#### Event 5: Order Completed & Reviewed
*Trigger: When order is approved and feedback is left.*
```json
{
  "senderId": "system",
  "type": "system_notification",
  "actionType": "order_completed",
  "text": "The order was completed successfully.",
  "rating": 5.0,
  "comment": "Amazing communication and great work!"
}
```

### 3. Implementation Rules for Web:
1. **Never use standard text bubbles for order events.** Always insert a message with `senderId: "system"` and the corresponding `actionType`.
2. **Update Order and Chat Together:** When an event occurs (like a delivery), update the `orders/{orderId}` document (set `status: "delivered"`, `deliveryNote: "..."`) AND simultaneously push the `actionType: "order_delivered"` message to the chat so the UI updates instantly.
