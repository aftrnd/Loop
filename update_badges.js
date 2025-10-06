/**
 * Firebase Badge Update Script
 * 
 * This script helps you bulk update user badges in Firestore.
 * 
 * Setup:
 * 1. npm install firebase-admin
 * 2. Download your service account key from Firebase Console
 * 3. Update the serviceAccountPath below
 * 4. Run: node update_badges.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json'); // Update this path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

/**
 * Grant verified badge to specific users
 */
async function grantVerifiedBadges(userIds) {
  const batch = db.batch();
  
  for (const userId of userIds) {
    const userRef = db.collection('users').doc(userId);
    batch.update(userRef, { badgeType: 'verified' });
  }
  
  await batch.commit();
  console.log(`✅ Granted verified badges to ${userIds.length} users`);
}

/**
 * Grant premium badge to specific users
 */
async function grantPremiumBadges(userIds) {
  const batch = db.batch();
  
  for (const userId of userIds) {
    const userRef = db.collection('users').doc(userId);
    batch.update(userRef, { badgeType: 'premium' });
  }
  
  await batch.commit();
  console.log(`✅ Granted premium badges to ${userIds.length} users`);
}

/**
 * Remove badges from specific users
 */
async function removeBadges(userIds) {
  const batch = db.batch();
  
  for (const userId of userIds) {
    const userRef = db.collection('users').doc(userId);
    batch.update(userRef, { badgeType: null });
  }
  
  await batch.commit();
  console.log(`✅ Removed badges from ${userIds.length} users`);
}

/**
 * Initialize badgeType field for ALL users (set to null if not exists)
 */
async function initializeBadgeFieldForAllUsers() {
  const usersSnapshot = await db.collection('users').get();
  const batch = db.batch();
  let count = 0;
  
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    
    // Only update if badgeType field doesn't exist
    if (!data.hasOwnProperty('badgeType')) {
      batch.update(doc.ref, { badgeType: null });
      count++;
    }
  }
  
  if (count > 0) {
    await batch.commit();
    console.log(`✅ Initialized badgeType field for ${count} users`);
  } else {
    console.log('✅ All users already have badgeType field');
  }
}

/**
 * List all users with their current badge status
 */
async function listAllUserBadges() {
  const usersSnapshot = await db.collection('users').get();
  
  console.log('\n📋 Current Badge Status:');
  console.log('═══════════════════════════════════════════════════\n');
  
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const badge = data.badgeType || 'none';
    const displayName = data.displayName || 'Unknown';
    const username = data.username || 'no-username';
    
    const badgeIcon = badge === 'verified' ? '🔵' : badge === 'premium' ? '🟡' : '⚪️';
    
    console.log(`${badgeIcon} ${displayName} (@${username})`);
    console.log(`   ID: ${doc.id}`);
    console.log(`   Badge: ${badge}`);
    console.log('');
  }
}

// ═══════════════════════════════════════════════════
// EXAMPLES - Uncomment the function you want to run
// ═══════════════════════════════════════════════════

async function main() {
  try {
    // Option 1: List all users and their badges
    await listAllUserBadges();
    
    // Option 2: Initialize badgeType field for all users (safe to run)
    // await initializeBadgeFieldForAllUsers();
    
    // Option 3: Grant verified badges to specific users
    // await grantVerifiedBadges([
    //   'userId1',
    //   'userId2',
    //   'userId3'
    // ]);
    
    // Option 4: Grant premium badges to specific users
    // await grantPremiumBadges([
    //   'userId4',
    //   'userId5'
    // ]);
    
    // Option 5: Remove badges from specific users
    // await removeBadges([
    //   'userId6'
    // ]);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();

