# Cloud Functions Deployment Guide

## Prerequisites

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize Firebase in your project** (if not already done)
   ```bash
   cd /Users/victorgalindo/Documents/Proyectos/Bruce/tennis_connect
   firebase init
   ```
   - Select "Functions" when prompted
   - Choose your existing Firebase project
   - Select JavaScript as the language
   - Choose to use existing functions directory

## Installation

1. **Navigate to functions directory**
   ```bash
   cd /Users/victorgalindo/Documents/Proyectos/Bruce/tennis_connect/functions
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

## Deployment

### Deploy All Functions
```bash
firebase deploy --only functions
```

### Deploy Specific Functions
```bash
# Deploy only notification functions
firebase deploy --only functions:sendPushNotification,functions:onMatchUpdate

# Deploy only scheduled functions
firebase deploy --only functions:sendMatchReminders,functions:cleanupOldNotifications
```

## Testing

### Local Testing with Emulator
1. **Start the emulator**
   ```bash
   firebase emulators:start --only functions,firestore
   ```

2. **Test functions locally**
   - The emulator will run on `http://localhost:5001`
   - Firestore emulator on `http://localhost:8080`

### View Logs
```bash
# View all function logs
firebase functions:log

# View logs for specific function
firebase functions:log --only sendPushNotification

# Stream logs in real-time
firebase functions:log --follow
```

## Function Descriptions

### Notification Functions

1. **sendPushNotification**
   - Trigger: Document created in `notifications` collection
   - Purpose: Sends push notifications via FCM

2. **onMatchUpdate**
   - Trigger: Document updated in `matches` collection
   - Purpose: Notifies players of match changes (cancellation, reschedule, etc.)

3. **sendMatchReminders**
   - Trigger: Runs every 60 minutes
   - Purpose: Sends reminders 24 hours and 2 hours before matches

### User Functions

4. **onUserCreate**
   - Trigger: Document created in `users` collection
   - Purpose: Sends welcome notification to new users

### Cleanup Functions

5. **cleanupOldNotifications**
   - Trigger: Runs daily
   - Purpose: Deletes notifications older than 30 days

6. **updatePastMatchStatus**
   - Trigger: Runs every 60 minutes
   - Purpose: Updates status of completed matches

### Callable Functions

7. **sendCustomNotification**
   - Trigger: Called from the app
   - Purpose: Allows sending custom notifications from the app

## Configuration

### Environment Variables (Optional)
Create a `.env` file for local development:
```bash
# Example environment variables
ADMIN_EMAIL=admin@tennisconnect.com
NOTIFICATION_BATCH_SIZE=500
```

Set production config:
```bash
firebase functions:config:set admin.email="admin@tennisconnect.com"
```

## Monitoring

1. **Firebase Console**
   - Go to Firebase Console → Functions
   - View execution counts, errors, and performance

2. **Error Alerts**
   - Set up error alerts in Firebase Console → Functions → Logs

## Cost Optimization

1. **Function Configuration**
   - Adjust memory allocation if needed:
   ```javascript
   exports.myFunction = functions
     .runWith({ memory: '256MB', timeoutSeconds: 60 })
     .firestore.document('...')
   ```

2. **Batching**
   - The functions already batch operations where possible
   - Adjust batch sizes based on your needs

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you have the correct Firebase project selected
   - Check IAM permissions in Google Cloud Console

2. **Deployment Fails**
   - Check Node.js version (should be 18 or 20)
   - Clear npm cache: `npm cache clean --force`
   - Delete node_modules and reinstall: `rm -rf node_modules && npm install`

3. **Functions Not Triggering**
   - Check Firebase Console logs
   - Verify Firestore security rules allow function access
   - Ensure correct document paths in triggers

### Debug Mode
Enable detailed logging:
```javascript
functions.logger.log('Debug info', { data: someData });
```

## Security Notes

1. **API Keys**
   - Never commit API keys to the repository
   - Use Firebase Config for sensitive data

2. **Authentication**
   - The callable function checks for authentication
   - Add additional permission checks as needed

3. **Rate Limiting**
   - Consider implementing rate limiting for callable functions
   - Use Firebase App Check for additional security

## Next Steps

After deployment:
1. Test push notifications with a real device
2. Monitor function execution in Firebase Console
3. Set up error alerting
4. Configure budget alerts in Google Cloud Console