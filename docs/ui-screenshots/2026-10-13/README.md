# Reskindev app: UI screenshots, 13 Oct 2026

Taken while testing the order flow on the iOS Simulator (iPhone 17 Pro, dark mode) and the Android emulator (Pixel 10, light mode):
a guest buyer on iOS orders from a guest seller on Android, then delivery, a revision, another delivery and accept.
`BEFORE` = a problem we saw (since fixed). `FINAL` = how it looks after the fixes.

## Login and profile
| File | What it shows | Status |
|---|---|---|
| ios-01-home-guest | Home for a signed-out visitor | – |
| ios-02-profile-not-signed-in | Profile only offers "Sign In / Register" | **Open:** add "Continue as Guest" here too |
| ios-03-login-continue-as-guest | Login with the new "Continue as Guest" button | Done |

## Browsing and ordering
| File | What it shows | Status |
|---|---|---|
| ios-04-explore-gig-without-thumbnail | A gig with no image shows a grey placeholder | **Open:** generated cover (initials / category color) |
| ios-05-gig-detail | Gig page, "Continue · $5" | – |
| ios-06-confirm-order-top | Order summary: $5 + 5% fee = $5.25 | – |
| ios-07-confirm-order-keyboard-and-price-label | Button says "$5" but the total is $5.25; the phone keypad has no Done key and covers the form | **Open** |
| ios-08-order-placed-dialog | Success dialog, main button "View My Orders" | **Open:** "Open order chat" would lead straight to next steps |

## My Orders
| File | What it shows | Status |
|---|---|---|
| ios-09-BEFORE-my-orders-no-active-orders-bug | "No active orders" while a delivery waits for approval | Fixed |
| ios-10-order-details-timeline-label-wrap | Timeline label breaks into "REQUIREME / NTS" | **Open** |
| ios-13-my-orders-delivery-waiting | "1 delivery is waiting for your approval" + delivery note on the card | Done |
| ios-17-my-orders-review-delivery-button | Card button "Review delivery" opens the order chat | Done |

## Dialogs in dark mode
| File | What it shows | Status |
|---|---|---|
| ios-11-BEFORE-approve-dialog-title-invisible | "Approve Final Delivery" title dark on dark | Fixed |
| ios-12-BEFORE-order-completed-title-invisible | "Order Completed!" title dark on dark | Fixed |
| ios-19-BEFORE-review-dialog-title-invisible | "Rate Your Experience" title dark on dark | Fixed (other screens' dialogs not all checked yet) |

## Order chat (the main redesign)
| File | What it shows | Status |
|---|---|---|
| ios-14-BEFORE-chat-big-panel-big-cards | A big panel plus huge order cards: one event filled the screen | Replaced |
| ios-15-BEFORE-chat-same-button-twice | Accept / Request revision in the panel AND in the card (and in Details) | Replaced: one place only |
| ios-16-chat-compact-cards | Compact history cards: 6–7 events per screen | Done |
| android-01-chat-compact-seller-working | Same on Android, seller side, with the old always-on quick-reply row | Row removed later |
| ios-18-order-details-sheet-info-only | Details sheet: information only, no buttons | Done |
| ios-20-FINAL-chat-folded-bar-accept | Order bar folded to one line: status + "Accept" + ▾, thin progress line | Done |
| ios-21-FINAL-chat-bar-expanded | Bar opened: note, 4 steps, Order details, both buttons | Done |
| ios-22-FINAL-chat-completed-review | Completed: "Review" in the folded bar | Done |
| android-02-FINAL-chat-menu-order-details | "Order details" in the ⋮ menu; ⚡ quick replies in the input bar | Done |

## Rules we agreed on
- One place to manage an order: the bar at the top of the order chat. No order buttons in the chat cards or the Details sheet. Other screens only link to the chat.
- Keep the chat clean: nothing big stays above or below the messages. The bar is one line until opened, and quick replies are behind ⚡.
- Calm wording and timing: "Due in 2d 23h", not a seconds counter. Each state says what is happening and what comes next, for buyer and seller separately.
- Every dialog title sets its color, so it stays readable in dark mode.

## Home and notifications (added later the same day)
| File | What it shows | Status |
|---|---|---|
| ios-23-BEFORE-home | Big "Welcome, Guest!" header, big category tiles, a teal badge that looks like a brand color | Replaced |
| ios-24-BEFORE-notifications-big-cards | Notification cards ~150pt tall, 6 per screen; tapping opened a sheet, not the chat | Replaced |
| ios-25-FINAL-home-your-turn | Compact header, red badge, "Your turn" (orders waiting on you) under the search bar, category chips | Done |
| ios-26-FINAL-notifications-compact-read-unread | Compact rows, 8+ per screen; unread = tint + bold + dot, read = quiet; tap opens the order chat, press and hold shows the full text | Done |
| android-03-FINAL-home-your-turn-light | The same Home on Android in light mode, seller side ("Rate your buyer") | Done |

Rules: "Your turn" always says what to do ("Rate your order"), not what happened. The badge is red and counts only unread items. Opening an order chat marks that order's notifications as read.

## Gig description (added later the same day)
| File | What it shows | Status |
|---|---|---|
| ios-27-BEFORE-description-sheet-bullets-in-one-line | "Read more" opened a separate sheet; "• a • b • c" squeezed into one line; no order button in the sheet | Replaced |
| ios-28-FINAL-description-folded-checklist | Paragraph, a "My services include:" heading and ✓ rows; the preview never ends on a heading | Done |
| ios-29-FINAL-description-expanded-inline | Opens in place with "Show less"; Continue stays at the bottom | Done |

## Custom offer
| File | What it shows | Status |
|---|---|---|
| ios-30-FINAL-create-offer-features | Seller sheet: headline, description, features added one at a time (✓ rows), price, days, "Send offer · $150" | Done |
| ios-31-FINAL-offer-seller-waiting | Seller card: price, ✓ list, "Waiting for the buyer to respond" | Done |
| android-04-FINAL-offer-buyer-accepted-declined | Buyer: accepted offer (green, Open order) and declined offer; pending offers show Decline (black/white) + Accept (green) | Done |
