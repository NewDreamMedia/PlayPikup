const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================
// NOTIFICATION FUNCTIONS
// ============================================

/**
 * Send push notification when a notification document is created
 * Triggered by: Creating a document in the 'notifications' collection
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    try {
      // Check if it's a single or multiple recipient notification
      if (notification.token) {
        // Single recipient
        const message = {
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data || {},
          token: notification.token,
        };
        
        const response = await messaging.send(message);
        console.log('Successfully sent message:', response);
        
        // Update notification status
        await snap.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else if (notification.tokens && notification.tokens.length > 0) {
        // Multiple recipients
        const message = {
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data || {},
          tokens: notification.tokens,
        };
        
        const response = await messaging.sendMulticast(message);
        console.log(`${response.successCount} messages were sent successfully`);
        
        // Update notification status
        await snap.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          successCount: response.successCount,
          failureCount: response.failureCount,
        });
      }
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Update notification status to failed
      await snap.ref.update({
        status: 'failed',
        error: error.message,
      });
    }
  });

// ============================================
// MATCH NOTIFICATION FUNCTIONS
// ============================================

/**
 * Send notifications when a match is updated
 * Triggered by: Updates to documents in the 'matches' collection
 */
exports.onMatchUpdate = functions.firestore
  .document('matches/{matchId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const matchId = context.params.matchId;
    
    // Check for match cancellation
    if (before.status !== 'cancelled' && after.status === 'cancelled') {
      await notifyMatchCancellation(matchId, after);
    }
    
    // Check for substitute needed
    if (!before.subNeeded && after.subNeeded) {
      await notifySubstituteNeeded(matchId, after);
    }
    
    // Check for new player joined
    if (before.playerIds.length < after.playerIds.length) {
      const newPlayerId = after.playerIds.find(id => !before.playerIds.includes(id));
      if (newPlayerId) {
        await notifyPlayerJoined(matchId, after, newPlayerId);
      }
    }
    
    // Check for player left
    if (before.playerIds.length > after.playerIds.length) {
      const leftPlayerId = before.playerIds.find(id => !after.playerIds.includes(id));
      if (leftPlayerId) {
        await notifyPlayerLeft(matchId, after, leftPlayerId);
      }
    }
    
    // Check for match time/date changes
    if (before.matchDate !== after.matchDate || before.matchTime !== after.matchTime) {
      await notifyMatchRescheduled(matchId, after);
    }
  });

/**
 * Send reminder notifications for upcoming matches
 * Triggered by: Scheduled function running every hour
 */
exports.sendMatchReminders = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    
    // Query matches happening in the next 24 hours
    const matchesSnapshot = await db.collection('matches')
      .where('status', 'in', ['open', 'full', 'confirmed'])
      .where('matchDate', '>=', now)
      .where('matchDate', '<=', tomorrow)
      .get();
    
    const reminderPromises = [];
    
    matchesSnapshot.forEach(doc => {
      const match = doc.data();
      const matchTime = match.matchDate.toDate();
      const hoursUntilMatch = (matchTime - now) / (1000 * 60 * 60);
      
      // Send reminder 24 hours before
      if (hoursUntilMatch >= 23 && hoursUntilMatch <= 25 && !match.reminder24Sent) {
        reminderPromises.push(
          sendMatchReminder(doc.id, match, '24 hours')
        );
      }
      
      // Send reminder 2 hours before
      if (hoursUntilMatch >= 1.5 && hoursUntilMatch <= 2.5 && !match.reminder2Sent) {
        reminderPromises.push(
          sendMatchReminder(doc.id, match, '2 hours')
        );
      }
    });
    
    await Promise.all(reminderPromises);
    console.log(`Processed ${reminderPromises.length} match reminders`);
  });

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Notify all participants when a match is cancelled
 */
async function notifyMatchCancellation(matchId, match) {
  const tokens = await getPlayerTokens(match.playerIds);
  
  if (tokens.length === 0) return;
  
  const message = {
    notification: {
      title: 'Match Cancelled',
      body: `Match at ${match.courtName} has been cancelled${match.cancelReason ? ': ' + match.cancelReason : ''}`,
    },
    data: {
      type: 'match_cancelled',
      matchId: matchId,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent cancellation notification to ${response.successCount} players`);
  } catch (error) {
    console.error('Error sending cancellation notification:', error);
  }
}

/**
 * Notify users when a substitute is needed
 */
async function notifySubstituteNeeded(matchId, match) {
  // Get all users who have marked themselves as available for substitutes
  const usersSnapshot = await db.collection('users')
    .where('subAvailability', '==', true)
    .get();
  
  const tokens = [];
  for (const doc of usersSnapshot.docs) {
    const user = doc.data();
    // Check if user matches skill level and location requirements
    if (user.fcmToken && 
        user.ntrpRating >= match.minNtrpRating && 
        user.ntrpRating <= match.maxNtrpRating) {
      tokens.push(user.fcmToken);
    }
  }
  
  if (tokens.length === 0) return;
  
  const message = {
    notification: {
      title: 'Substitute Needed!',
      body: `A ${match.matchType} match at ${match.courtName} needs a substitute player`,
    },
    data: {
      type: 'substitute_needed',
      matchId: matchId,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent substitute notification to ${response.successCount} available players`);
  } catch (error) {
    console.error('Error sending substitute notification:', error);
  }
}

/**
 * Notify participants when a new player joins
 */
async function notifyPlayerJoined(matchId, match, newPlayerId) {
  // Get tokens for all players except the new one
  const existingPlayerIds = match.playerIds.filter(id => id !== newPlayerId);
  const tokens = await getPlayerTokens(existingPlayerIds);
  
  if (tokens.length === 0) return;
  
  // Get new player's name
  const newPlayerDoc = await db.collection('users').doc(newPlayerId).get();
  const newPlayerName = newPlayerDoc.exists ? newPlayerDoc.data().displayName : 'A player';
  
  const message = {
    notification: {
      title: 'New Player Joined',
      body: `${newPlayerName} has joined your match at ${match.courtName}`,
    },
    data: {
      type: 'player_joined',
      matchId: matchId,
      playerId: newPlayerId,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent join notification to ${response.successCount} players`);
  } catch (error) {
    console.error('Error sending join notification:', error);
  }
}

/**
 * Notify participants when a player leaves
 */
async function notifyPlayerLeft(matchId, match, leftPlayerId) {
  const tokens = await getPlayerTokens(match.playerIds);
  
  if (tokens.length === 0) return;
  
  // Get player's name who left
  const leftPlayerDoc = await db.collection('users').doc(leftPlayerId).get();
  const leftPlayerName = leftPlayerDoc.exists ? leftPlayerDoc.data().displayName : 'A player';
  
  const message = {
    notification: {
      title: 'Player Left Match',
      body: `${leftPlayerName} has left the match. ${match.spotsAvailable} spot(s) now available.`,
    },
    data: {
      type: 'player_left',
      matchId: matchId,
      playerId: leftPlayerId,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent leave notification to ${response.successCount} players`);
  } catch (error) {
    console.error('Error sending leave notification:', error);
  }
}

/**
 * Notify participants when match is rescheduled
 */
async function notifyMatchRescheduled(matchId, match) {
  const tokens = await getPlayerTokens(match.playerIds);
  
  if (tokens.length === 0) return;
  
  const message = {
    notification: {
      title: 'Match Rescheduled',
      body: `Match at ${match.courtName} has been rescheduled to ${formatMatchDateTime(match)}`,
    },
    data: {
      type: 'match_rescheduled',
      matchId: matchId,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent reschedule notification to ${response.successCount} players`);
  } catch (error) {
    console.error('Error sending reschedule notification:', error);
  }
}

/**
 * Send match reminder
 */
async function sendMatchReminder(matchId, match, timeframe) {
  const tokens = await getPlayerTokens(match.playerIds);
  
  if (tokens.length === 0) return;
  
  const message = {
    notification: {
      title: 'Match Reminder',
      body: `Your match at ${match.courtName} is in ${timeframe}`,
    },
    data: {
      type: 'match_reminder',
      matchId: matchId,
      timeframe: timeframe,
    },
    tokens: tokens,
  };
  
  try {
    const response = await messaging.sendMulticast(message);
    console.log(`Sent reminder to ${response.successCount} players for match ${matchId}`);
    
    // Mark reminder as sent
    const updateField = timeframe === '24 hours' ? 'reminder24Sent' : 'reminder2Sent';
    await db.collection('matches').doc(matchId).update({
      [updateField]: true,
    });
  } catch (error) {
    console.error('Error sending reminder:', error);
  }
}

/**
 * Get FCM tokens for a list of user IDs
 */
async function getPlayerTokens(playerIds) {
  const tokens = [];
  
  for (const playerId of playerIds) {
    const userDoc = await db.collection('users').doc(playerId).get();
    if (userDoc.exists && userDoc.data().fcmToken) {
      tokens.push(userDoc.data().fcmToken);
    }
  }
  
  return tokens;
}

/**
 * Format match date and time for notifications
 */
function formatMatchDateTime(match) {
  const date = match.matchDate.toDate();
  const options = { 
    weekday: 'short', 
    month: 'short', 
    day: 'numeric', 
    hour: 'numeric', 
    minute: '2-digit' 
  };
  return date.toLocaleDateString('en-US', options);
}

// ============================================
// USER NOTIFICATION FUNCTIONS
// ============================================

/**
 * Send welcome notification when a new user signs up
 */
exports.onUserCreate = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    const userId = context.params.userId;
    
    if (!user.fcmToken) return;
    
    const message = {
      notification: {
        title: 'Welcome to Tennis Connect! 🎾',
        body: 'Start by finding matches near you or creating your own match.',
      },
      data: {
        type: 'welcome',
        userId: userId,
      },
      token: user.fcmToken,
    };
    
    try {
      await messaging.send(message);
      console.log('Sent welcome notification to new user:', userId);
    } catch (error) {
      console.error('Error sending welcome notification:', error);
    }
  });

// ============================================
// CLEANUP FUNCTIONS
// ============================================

/**
 * Clean up old notifications (older than 30 days)
 * Triggered by: Scheduled function running daily
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldNotifications = await db.collection('notifications')
      .where('createdAt', '<', thirtyDaysAgo)
      .get();
    
    const batch = db.batch();
    let count = 0;
    
    oldNotifications.forEach(doc => {
      batch.delete(doc.ref);
      count++;
    });
    
    if (count > 0) {
      await batch.commit();
      console.log(`Deleted ${count} old notifications`);
    }
  });

/**
 * Update match status for past matches
 * Triggered by: Scheduled function running every hour
 */
exports.updatePastMatchStatus = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    const now = new Date();
    
    // Find matches that should be marked as completed
    const pastMatches = await db.collection('matches')
      .where('status', 'in', ['open', 'full', 'confirmed', 'inProgress'])
      .where('matchDate', '<', now)
      .get();
    
    const batch = db.batch();
    let count = 0;
    
    pastMatches.forEach(doc => {
      const match = doc.data();
      const matchEndTime = new Date(match.matchDate.toDate());
      matchEndTime.setMinutes(matchEndTime.getMinutes() + (match.duration || 60));
      
      if (now > matchEndTime) {
        batch.update(doc.ref, {
          status: 'completed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        count++;
      }
    });
    
    if (count > 0) {
      await batch.commit();
      console.log(`Updated ${count} matches to completed status`);
    }
  });

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Send custom notification (callable from app)
 */
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send notifications'
    );
  }
  
  const { recipientIds, title, body, data: notificationData } = data;
  
  if (!recipientIds || !title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: recipientIds, title, body'
    );
  }
  
  try {
    const tokens = await getPlayerTokens(recipientIds);
    
    if (tokens.length === 0) {
      return { success: false, message: 'No valid tokens found' };
    }
    
    const message = {
      notification: { title, body },
      data: notificationData || {},
      tokens: tokens,
    };
    
    const response = await messaging.sendMulticast(message);
    
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error sending custom notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notification'
    );
  }
});

// Export all functions
module.exports = exports;