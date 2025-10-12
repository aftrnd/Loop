# Badge System Documentation

## Overview
The badge system allows users to have verification badges displayed next to their display name in their profile.

## Badge Types

### 1. **Verified** (Blue Checkmark)
- Field value: `"verified"`
- Color: Blue
- Use case: Verified/authenticated users

### 2. **Premium** (Gold Checkmark)
- Field value: `"premium"`
- Color: Gold (#FFD700)
- Use case: Premium/paid subscribers

### 3. **None** (No Badge)
- Field value: `null` or field not present
- No badge displayed

## Implementation

### Database Structure
In Firestore, badges are stored as a string field in the user document:

```
users/{userId}/
  ├─ displayName: "John Doe"
  ├─ username: "johndoe"
  ├─ badgeType: "verified"  // or "premium" or null
  └─ ... other fields
```

### ⚠️ Migration Note
**No migration required!** The `badgeType` field is optional (`BadgeType?` in code). Existing users without this field will work perfectly fine - they just won't have a badge displayed. The app gracefully handles missing badge data.

However, if you want to explicitly set badges for users or ensure the field exists, use one of the methods below.

### Setting a Badge in Firestore

### Option 1: Using Firebase Console (Manual)
1. Go to [Firebase Console](https://console.firebase.google.com) → Firestore Database
2. Navigate to `users/{userId}`
3. Add or edit the `badgeType` field
4. Set value to `"verified"` or `"premium"` (or leave empty/null for no badge)

### Option 2: Using the Update Script (Bulk Updates)
A Node.js script (`update_badges.js`) is included for bulk operations:

**Setup:**
```bash
npm install firebase-admin
```

**Download Service Account Key:**
1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save as `serviceAccountKey.json` in your project root

**Run the script:**
```bash
node update_badges.js
```

**Available Functions:**
- `listAllUserBadges()` - View all users and their current badges
- `initializeBadgeFieldForAllUsers()` - Add `badgeType: null` to all users
- `grantVerifiedBadges([userId1, userId2])` - Give verified badges
- `grantPremiumBadges([userId1, userId2])` - Give premium badges
- `removeBadges([userId1])` - Remove badges

### Option 3: Using Firebase CLI or Admin SDK
```javascript
// Grant verified badge
db.collection('users').doc(userId).update({
  badgeType: 'verified'
});

// Grant premium badge
db.collection('users').doc(userId).update({
  badgeType: 'premium'
});

// Remove badge
db.collection('users').doc(userId).update({
  badgeType: null
});
```

## UI Display

### Profile View
- Badge appears inline with the display name (right side)
- Larger text for display name (.title2 vs .title3)
- Badge size matches the heading (.title3)
- Username and location have consistent styling

### Example Layout
```
John Doe ✓    ← Display name + badge (blue or gold)
@johndoe • San Francisco    ← Username and location (consistent styling)
```

## Code Structure

### Model (`User.swift`)
```swift
enum BadgeType: String, Codable {
    case verified = "verified"
    case premium = "premium"
    
    var color: Color { ... }
    var iconName: String { ... }
}

struct User {
    let badgeType: BadgeType?
    // ... other fields
}
```

### Service (`FirebaseService.swift`)
Automatically parses `badgeType` string from Firestore into the `BadgeType` enum when fetching user data.

### View (`ProfileView.swift`)
Conditionally displays badge next to display name:
```swift
if let badgeType = currentUser?.badgeType {
    Image(systemName: badgeType.iconName)
        .foregroundStyle(badgeType.color)
}
```

## Future Enhancements

Potential badge types to add:
- `admin` - Red/orange badge for administrators
- `creator` - Purple badge for content creators
- `partner` - Special badge for partners
- `early_adopter` - Badge for early users

To add a new badge type, simply:
1. Add case to `BadgeType` enum
2. Define color and icon
3. Set in Firestore database

