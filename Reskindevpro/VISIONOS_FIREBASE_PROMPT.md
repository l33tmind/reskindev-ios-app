Task: Reorganize the visionOS app in `Reskindevpro/` and connect it fully to the same Firebase (Firestore + Auth) backend as the Next.js website in `next-frontend/`, so every buyer/seller flow on the website also works in the Vision Pro app. Keep the current spatial design (3 panels: left sidebar, center 3D gig carousel, right "My Orders" panel, bottom dock ornament, glass cards, brand green #10B981).

## Current state (already done)
- SwiftUI visionOS app, Firebase SPM (FirebaseAuth, FirebaseCore, FirebaseFirestore), `GoogleService-Info.plist` present, Swift 5 mode with default MainActor isolation. The Xcode project uses file-system synchronized groups, so new folders/files on disk are picked up automatically (keep `Info.plist`, `GoogleService-Info.plist` and `Assets.xcassets` at the target root).
- `GigStore.swift`: live `services` collection + categories from `admin_settings/categories` (`list`), search/category filter.
- `SessionStore.swift`: email sign-in, `users/{uid}` listener, buyer/seller mode, orders listener (buyer: `userId == uid OR clientUid == uid`; seller: `authorId == uid`), inbox unread badge.
- `ContentView.swift` (~950 lines, everything in one file), `GigDetailView.swift`, `DesignSystem.swift`, `ImmersiveView.swift` + `ToggleImmersiveSpaceButton.swift` + `AppModel.swift` (no ImmersiveSpace scene is registered yet).
- Problems: Profile window is hardcoded ("Robius Sani", fake email); dock tabs, Saved Services, Settings, orders ✕, "Continue" and "Contact Seller" do nothing; GigDetail/Profile windows don't get `SessionStore` in the environment; the timeline uses a 10pt font (too small for visionOS); `in_progress` is mapped but the website uses `processing`/`revision`.

## 1. Reorganize into folders
```
Reskindevpro/Reskindevpro/
  App/            ReskindevproApp.swift, AppModel.swift (also holds UI routing: showOrders, profileTab, focusSearch)
  Models/         FirestoreReaders.swift (loose readers: string/double/int/date from Timestamp|Date|ms), Gig.swift, Order.swift, Chat.swift, Review.swift
  Services/       GigStore.swift, SessionStore.swift, ChatStore.swift, OrderService.swift
  DesignSystem/   DesignSystem.swift
  Views/Home/     ContentView.swift, CenterStageView, GigCards.swift, FilterPill, SpatialBottomDock.swift, AIAssistant.swift
  Views/Sidebar/  LeftSidebarView.swift
  Views/Auth/     SignInView.swift (sign in + sign up)
  Views/Orders/   RightOrdersView.swift, OrderCard, OrderTimeline.swift, OrderDetailView.swift (actions)
  Views/GigDetail/ GigDetailView.swift, CheckoutView.swift, GigReviewsSection.swift
  Views/Inbox/    InboxView.swift (NavigationSplitView), ChatView.swift, MessageViews.swift
  Views/Profile/  ProfileView.swift (Profile / Settings / Saved / Wallet tabs)
  Immersive/      ImmersiveView.swift, ToggleImmersiveSpaceButton.swift, Delivery3DView.swift
```
Inject all stores (GigStore, SessionStore, ChatStore, AppModel) into every WindowGroup. Windows: main (give it `.defaultSize`), `GigDetail` (value: gig id), `Inbox` (value: fixed "main" so it is reused; active chat via `ChatStore.activeChatID`), `Profile` (value: "me"), `DeliveryBox` (volumetric).

## 2. Firestore schema — copy exactly what the website writes
Read these website files for reference: `next-frontend/src/context/AuthContext.js`, `app/order/[gigId]/[pkg]/page.js`, `app/profile/orders/page.js`, `app/inbox/page.js`, `lib/sendSystemMessage.js`, `components/ContactSellerButton.js`, `components/SaveButton.js`, `components/GigReviews.js`, `app/profile/settings/page.js`.

**users/{uid}**: uid, email, displayName, photoURL (Flutter used `photoUrl`, read both), role ("buyer"/"freelancer"/"admin"), username (`<emailprefix>_<random 0-9999>`), createdAt, lastLogin, isOnline, phone, country, bio, walletBalance, savedGigs [gigId].
- Sign up: createUser → updateProfile(displayName, photoURL `https://ui-avatars.com/api/?name=<name>`) → setDoc user doc as above. If the user doc is missing on login, create it (fallback in AuthContext). Set `isOnline: true, lastLogin` on login, `isOnline: false` on logout.
- Save/unsave gig: `savedGigs` arrayUnion / arrayRemove.
- Settings: update displayName, username (check uniqueness: query `username ==`, reject if another uid), phone, country, bio.

**services/{id}** (+ `services/{id}/reviews` ordered by createdAt desc: userName|buyerName, userImage|buyerImage, rating, comment, createdAt, sellerReply.comment).

**settings/global**: `serviceFee` (percent, default 5).
**coupons**: query `code == CODE.uppercased()`; fields discount, usageLimit, usageCount (increment on use).

**orders/{id}** — checkout (port `handleOrder`):
gigId, gigTitle, packageId (package name lowercased), packageName, price (= max(0, base − discount) × (1 + fee%)), basePrice, discountAmount, serviceFee (amount), status ("pending_payment", or "requirements" when paid by wallet), deliveryDays, userId, userName, userEmail, phone (required), company, address, requirements, authorId, freelancerId, freelancerName, createdAt.
Wallet payment: only if walletBalance ≥ total; batch: set order + `walletBalance -= total`.
After creating: sendSystemMessage(actionType "payment_verified" or "order_placed", text "Order Placed: $X for <title>") and open that chat in the Inbox window.

Order status flow & actions (each also posts a system message in the order's chat):
- Timeline steps: payment(pending_payment) → requirements(requirements, pending) → processing(processing, in_progress, revision) → delivered → completed. Others: cancel_requested_by_buyer, cancel_requested_by_freelancer, cancelled, disputed.
- Buyer submit requirements: status "processing", requirementsText, requirementsProvided true, updatedAt → "requirements_submitted".
- Seller deliver: status "delivered", deliveryMessage, deliveryLink, deliveredAt → "order_delivered".
- Buyer request revision: status "revision", revisionNote → "revision_requested".
- Request cancel: status cancel_requested_by_buyer / _by_freelancer, cancelReason → "cancel_requested" (requestedBy uid).
- Respond to cancel: accept → "cancelled" ("cancel_accepted"; the website refunds the wallet through a server action — don't do refunds client-side), decline → "processing" ("cancel_declined").
- Buyer accept + review (port `submitReview`): status "completed", hasReview, completedAt, buyerReview {userId, userName, userImage, rating, comment, createdAt}, isReviewPublic = sellerReview already exists. If public: add to `services/{gigId}/reviews`, recompute gig `reviewCount`, `averageRating`, `rating`; add to `users/{sellerId}/reviews`; add sellerReview to `users/{buyerId}/reviews`. Message "order_completed" with rating/comment only if public.
- Seller review of buyer (port `submitReviewAndComplete`): sellerReview {freelancerId, freelancerName, freelancerImage, rating, comment, createdAt, buyerName, buyerImage}, same publish-both rule.

**conversations/{id}**: participants [uid, uid], participantDetails {uid: {name}}, clientId, freelancerId, orderId (order chats only), gigTitle, lastMessage, updatedAt, unreadCount {uid: n}, lastReadTime {uid}, typing {uid: bool}, msgCount.
- List: `participants array-contains uid`, orderBy updatedAt desc. Title = other participant's name.
- Messages: `conversations/{id}/messages` orderBy createdAt asc.
  - text: {text, senderId, senderName, createdAt, type "text", replyToId/replyToText/replyToSender optional}; then update conversation lastMessage, updatedAt, `unreadCount.<other>` +1, `typing.<me>` false, msgCount +1.
  - system: {type "system_notification", senderId "system", actionType, text, orderId, gigTitle, price, deliveryMessage, deliveryLink, rating, comment, cancelReason, createdAt}. Render as full-width cards (title + icon per actionType: order_placed, payment_verified, requirements_submitted, order_delivered (show message + link button), order_completed, revision_requested, cancel_requested/accepted/declined, escalated_to_admin, extension_requested/accepted/declined).
  - offer: {type "offer", offerPrice, offerDays, offerDescription, offerStatus "pending"/"accepted"}. Buyer can accept → create order {gigId "custom", gigTitle "Custom Offer", status "processing", ...} (port `acceptOffer`), set offerStatus "accepted", sendSystemMessage "order_placed".
- Open chat: set `unreadCount.<me>` = 0 and `lastReadTime.<me>`. Typing: set `typing.<me>` true while typing, false after 2s idle; show "typing…" for the other user.
- Contact Seller (port ContactSellerButton): reuse the general chat (participants include seller and there is no orderId), or create it; post "Hi! I'm interested in your service:\n<title>\nhttps://reskindev.com/gig/<id>"; increment the seller's unread; open the Inbox window on that chat. Block messaging yourself.
- sendSystemMessage: port `lib/sendSystemMessage.js` exactly (order chats are found by orderId; create one if missing).

## 3. UI wiring
- Dock: Home, Search (focus the search field), Orders (show the right panel), Inbox (open the Inbox window, red badge = total unread), Profile (open the Profile window).
- Sidebar: real user/avatar, Sign In / Sign Up sheet, Switch to Seller/Buyer (only role freelancer/admin), My Orders, Saved Services, Settings, Inbox, Delete Account (confirm), Log Out.
- Orders panel: ✕ hides it; tapping an order opens OrderDetailView with the actions available for the current role and status, plus "Open Chat".
- Gig detail: heart save button, package switcher, reviews section, Continue → CheckoutView sheet (fee, coupon, wallet/offline, phone/company/address/requirements, Confirm Order • $total), Contact Seller.
- Profile window: real data (no hardcoded values), wallet balance, editable settings, saved gigs grid (opens GigDetail).
- visionOS rules: minimum 60pt hit targets, hover effects, nothing smaller than `.caption`, glass backgrounds, show errors to the user (alerts) instead of only printing them.

## 4. Build & verify
Firestore's binary SPM build doesn't support visionOS, so build with the source distribution:
`FIREBASE_SOURCE_FIRESTORE=1 xcodebuild -project Reskindevpro/Reskindevpro.xcodeproj -scheme Reskindevpro -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build`
(In Xcode: quit, then `open --env FIREBASE_SOURCE_FIRESTORE Reskindevpro/Reskindevpro.xcodeproj`.) Fix every compile error. Don't touch the website, the Flutter app or `firestore.rules`. Commit on a new branch when it builds.
