# Firebase Storage Setup for Loop

## Overview
Firebase Storage is used to store user profile images (avatars and banners) and loop media (post images). This guide covers setup, security rules, and implementation.

## ⚠️ Important: Complete Setup Required

You need **BOTH** Firestore and Storage rules for full security:
1. **Firestore Rules** - See `FIRESTORE_SECURITY_RULES.md` for database security
2. **Storage Rules** - This document covers file storage security

## ✅ What's Already Implemented

Your app now has:
- ✅ `avatarURL` and `bannerURL` fields in User model
- ✅ Image upload functions in `FirebaseService`
- ✅ Automatic image loading from URLs in `ProfileView`
- ✅ Image compression (70% for avatars, 80% for banners)
- ✅ Automatic Firestore update with download URLs
- ✅ **In-memory image caching** - Images load instantly after first download
- ✅ **CachedAsyncImage component** - No more loading spinners on repeated views

## 📦 Setup Firebase Storage

### 1. Enable Firebase Storage in Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click **Storage** in the left sidebar
4. Click **Get Started**
5. Choose **Production mode** or **Test mode** (we'll set proper rules next)
6. Click **Next** → **Done**

### 2. Add Security Rules

Go to **Storage** → **Rules** tab and paste these rules:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // User profile images
    match /users/{userId}/{imageType} {
      // imageType can be: avatar.jpg or banner.jpg
      
      // Allow users to read their own images
      allow read: if request.auth != null;
      
      // Allow users to write only to their own folder
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      // Only allow image files
                      request.resource.contentType.matches('image/.*') &&
                      // Limit file size to 5MB
                      request.resource.size < 5 * 1024 * 1024;
      
      // Allow users to delete their own images
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // Loop media (posts)
    match /loops/{userId}/{mediaId} {
      // Allow anyone to read loop media (public posts)
      allow read: if request.auth != null;
      
      // Allow users to upload only to their own folder
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      // Only allow image files
                      request.resource.contentType.matches('image/.*') &&
                      // Limit file size to 10MB for posts
                      request.resource.size < 10 * 1024 * 1024;
      
      // Allow users to delete their own loop media
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Click **Publish**

## 🎯 How It Works

### Image Upload Flow

```
1. User selects image from PhotosPicker
   ↓
2. Image is compressed (JPEG quality 0.7-0.8)
   ↓
3. Uploaded to Firebase Storage: users/{userId}/avatar.jpg
   ↓
4. Firebase returns download URL
   ↓
5. URL saved to Firestore: users/{userId} document
   ↓
6. ProfileView loads image from URL using AsyncImage
```

### File Structure in Storage

```
firebase-storage/
└── users/
    ├── {userId1}/
    │   ├── avatar.jpg
    │   └── banner.jpg
    ├── {userId2}/
    │   ├── avatar.jpg
    │   └── banner.jpg
    └── ...
```

## 🔧 API Reference

### Upload Functions

```swift
// Upload avatar image
let avatarURL = try await FirebaseService.shared.uploadAvatarImage(image)

// Upload banner image
let bannerURL = try await FirebaseService.shared.uploadBannerImage(image)
```

Both functions:
- ✅ Compress images to JPEG
- ✅ Upload to Firebase Storage
- ✅ Update Firestore with download URL
- ✅ Return the download URL string

### User Model Fields

```swift
struct User {
    let avatarURL: String?  // Firebase Storage download URL
    let bannerURL: String?  // Firebase Storage download URL
    // ... other fields
}
```

## 🔒 Security Rules Explained

### What These Rules Do:

1. **Read Access**
   - ✅ Any authenticated user can read profile images
   - Needed for viewing other users' profiles in chats

2. **Write Access**
   - ✅ Users can only upload to their own folder
   - ✅ Only image files allowed (`image/*`)
   - ✅ Maximum 5MB file size
   - ❌ Users cannot upload to other users' folders

3. **Delete Access**
   - ✅ Users can only delete their own images
   - ❌ Users cannot delete others' images

## 🎨 How Images Are Displayed

### Avatar Priority (in order):
1. **Cached Image** - Instant load from memory (if previously loaded)
2. **Selected Image** - Local UIImage (while uploading)
3. **Firebase URL** - CachedAsyncImage loads from Storage
4. **Default Initials** - Glass effect with user initials

### Banner Priority (in order):
1. **Cached Image** - Instant load from memory (if previously loaded)
2. **Selected Image** - Local UIImage (while uploading)
3. **Firebase URL** - CachedAsyncImage loads from Storage
4. **Default Gradient** - Blue to purple gradient

## 🚀 Image Caching

### How Caching Works

The app uses a custom `CachedAsyncImage` component with an in-memory cache:

```swift
// First load: Downloads from Firebase Storage
Open Profile → Downloads image → Stores in ImageCache → Shows image

// Subsequent loads: Instant from cache
Open Profile → Checks ImageCache → Shows cached image (instant!)
```

### Benefits
- ✅ **No loading spinners** after first load
- ✅ **Reduced Firebase calls** - saves bandwidth and costs
- ✅ **Instant display** - images show immediately
- ✅ **Thread-safe** - uses concurrent dispatch queue
- ✅ **Memory efficient** - only caches what you view

### Cache Lifecycle
- **Stored**: When image is first downloaded
- **Retrieved**: On every subsequent view
- **Cleared**: When app is closed/terminated
- **Automatic**: No manual management needed

## 📱 Image Compression Details

| Image Type | Quality | Purpose |
|------------|---------|---------|
| Avatar | 70% | Good balance for profile photos |
| Banner | 80% | Higher quality for larger display |

JPEG compression reduces file size while maintaining visual quality.

## ⚠️ Important Notes

### Caching
- `CachedAsyncImage` stores images in memory
- Images load **instantly** on subsequent views (no loading spinner!)
- Cache persists during app session, cleared when app closes
- Significantly reduces Firebase Storage bandwidth usage

### Updates
- When user uploads new avatar/banner, old file is overwritten
- Same filename (`avatar.jpg`, `banner.jpg`) = automatic replacement
- No orphaned files in Storage

### Error Handling
- Upload errors are caught and printed to console
- User can retry upload by selecting image again
- Original local image remains visible until successful upload

## 🚀 Optional Enhancements

### 1. Add Progress Indicators
```swift
// Show upload progress while uploading
.overlay {
    if isUploading {
        ProgressView()
    }
}
```

### 2. Image Resizing Before Upload
```swift
// Resize images to standard sizes before upload
func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
    // Implementation...
}
```

### 3. Allow Image Deletion
```swift
func deleteAvatarImage() async throws {
    // Delete from Storage and clear URL in Firestore
}
```

### 4. Support Multiple Image Formats
```swift
// Add PNG support with alpha channel
let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.8)
```

## 🔍 Debugging

### Check if images are uploading:
1. Go to Firebase Console → Storage
2. Navigate to `users/{yourUserId}/`
3. You should see `avatar.jpg` and/or `banner.jpg`

### Check if URLs are saving:
1. Go to Firebase Console → Firestore
2. Open `users/{yourUserId}` document
3. Check for `avatarURL` and `bannerURL` fields

### Common Issues:

**Images not loading?**
- Check internet connection
- Verify Storage rules are published
- Check console for error messages

**Upload failing?**
- Verify user is authenticated
- Check file size (< 5MB limit)
- Ensure image is valid format

**Old images not updating?**
- Images are cached in memory for performance
- Upload new image - it will replace cached version
- Cache clears automatically when app restarts

## 📊 Storage Costs

Firebase Storage Free Tier:
- **Storage**: 5 GB
- **Downloads**: 1 GB/day
- **Uploads**: 20K/day

For typical usage:
- Average avatar: ~100 KB
- Average banner: ~200 KB
- 5 GB = ~25,000 avatars + banners
- Very cost-effective for most apps!

## ✅ Next Steps

Your image storage is now fully functional! Users can:
1. ✅ Upload avatar and banner images
2. ✅ Images are automatically compressed and optimized
3. ✅ Images are stored securely in Firebase Storage
4. ✅ Images load automatically from URLs
5. ✅ Old images are replaced when updating

No additional code needed - it just works! 🎉

