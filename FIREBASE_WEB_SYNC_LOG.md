# Firebase Schema & Web Sync Log

This file tracks all Firebase database schema changes made during the Flutter app development. 
**Purpose:** You can share this document with your Next.js developer (or AI) to perfectly synchronize the website's features and database logic with the Flutter app. You do not need to explain the logic twice!

---

## 1. User Profile & Username System
**Collection:** `users`
**New Fields Added:**
- `username` (String): Unique username for the user. Only lowercase letters, numbers, and underscores are allowed.
- `usernameChanges` (Array of Timestamps): Tracks when the user changed their username. Max 2 changes allowed per 30 days.

**Next.js Implementation Prompt:**
> "On user signup, auto-generate a unique `username` using the prefix of their email + '_' + 4 random digits. In the Profile Settings, allow users to edit this username. Enforce a real-time uniqueness check (debounced 500ms) against the `users` collection. Only allow `a-z`, `0-9`, and `_`. Ensure users can only change their username twice every 30 days by checking the `usernameChanges` timestamp array."

---

## 2. Favorites / Wishlist System
**Collection:** `users`
**Field Changed:**
- `savedGigs` (Array of Strings): Stores the Document IDs of the gigs the user has favorited.

**Next.js Implementation Prompt:**
> "Ensure the Wishlist feature uses the `savedGigs` array inside the current user's document in the `users` collection. Do not use a separate `favorites` subcollection. Use `FieldValue.arrayUnion` to add a gig ID and `FieldValue.arrayRemove` to remove it."

---

## 3. Chat Presence (Online/Offline)
**Collection:** `users`
**New Fields Added:**
- `isOnline` (Boolean): True if the app is in the foreground, False if background/terminated.
- `lastSeen` (Timestamp): Updated whenever `isOnline` becomes false.

**Next.js Implementation Prompt:**
> "Use Firebase Realtime Database Presence API or `window.addEventListener('beforeunload')` / visibility changes to update `isOnline` and `lastSeen` in the user's Firestore document. In the chat UI, if the target user's `isOnline` is true, show a green 'Online' badge; otherwise, show 'Last seen at [time]'."

---

## 4. Chat Block & Report System
**Collection:** `users`
**New Field Added:**
- `blockedUsers` (Array of Strings): Contains UIDs of users that the current user has blocked.

**Collection:** `reports` (New Collection)
**Document Fields:**
- `reportedBy` (String): UID of the sender
- `reportedUser` (String): UID of the target user
- `reason` (String): e.g., 'Spam', 'Inappropriate Behavior'
- `createdAt` (Timestamp): Server timestamp
- `status` (String): 'pending'

**Next.js Implementation Prompt:**
> "In the Chat page, add a 3-dot dropdown menu with 'Report User' and 'Block User'. 
> Block: Add the target's UID to the current user's `blockedUsers` array using `arrayUnion`. If the current user is in the target's `blockedUsers` array OR vice versa, hide the message input and show 'You cannot reply to this conversation'.
> Report: Open a modal to select a reason, then save a document to the `reports` collection with `reportedBy`, `reportedUser`, `reason`, `createdAt`, and `status: 'pending'`."

---
*Note: Any future database modifications made for the Flutter app will be appended to this file automatically.*
