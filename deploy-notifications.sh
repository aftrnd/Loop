#!/bin/bash

# Deploy Firebase Cloud Functions for Push Notifications
# Run this script to enable push notifications in your Loop app

echo "🚀 Deploying Loop Push Notifications..."
echo ""

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged into Firebase"
    echo "Please run: firebase login"
    echo "Then run this script again"
    exit 1
fi

echo "✅ Firebase CLI authenticated"
echo ""

# Install dependencies
echo "📦 Installing Cloud Function dependencies..."
cd functions
npm install
if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo "✅ Dependencies installed"
echo ""

# Deploy functions
echo "🚀 Deploying Cloud Functions..."
cd ..
firebase deploy --only functions
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy functions"
    exit 1
fi

echo ""
echo "✅ Push notification function deployed successfully!"
echo ""
echo "📱 Next steps:"
echo "1. Configure APNs in Firebase Console:"
echo "   → https://console.firebase.google.com"
echo "   → Project Settings → Cloud Messaging"
echo "   → Upload your APNs Authentication Key (.p8 file)"
echo ""
echo "2. Test on a physical device (not simulator)"
echo "3. Check Xcode console for:"
echo "   '✅ Push notification sent to [userId]'"
echo ""
echo "Done! 🎉"

