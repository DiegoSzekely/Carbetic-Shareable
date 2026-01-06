# Push Notifications Implementation - Testing Guide

## ✅ What We Implemented

You now have **local push notifications** that alert users when their meal/recipe analysis completes while the app is in the background!

### **Files Created:**
1. **AnalysisNotificationManager.swift** - Manages notification state and delivery

### **Files Modified:**
1. **CarbFinderApp.swift** - Added notification permissions and delegate
2. **GeminiClient.swift** - Extended timeout to 120s for better backgrounding
3. **CaptureFlow.swift** (Capture3View) - Meal analysis notifications
4. **RecipeScanFlow.swift** (RecipeCaptureView) - Recipe scan notifications
5. **RecipeLinkView.swift** - Recipe link notifications
6. **ContentView.swift** - Clear badge on app open

---

## 🧪 How to Test

### **Test 1: Basic Notification (Meal Scan)**

1. **Start a meal capture flow**
   - Open CarbFinder
   - Tap "Capture Meal"
   - Take 3 photos of a meal

2. **Background the app immediately**
   - As soon as you see the loading screen (pulsing circle)
   - Press the home button or swipe up
   - **Don't force quit** - just go to home screen

3. **Wait 10-30 seconds**
   - The AI will complete in the background
   - You should see a notification appear!

4. **Check the notification:**
   ```
   Analysis Complete! 🎉
   Your meal has ~45g net carbs · Chicken Rice Bowl
   ```

5. **Tap the notification**
   - Should open the app
   - You'll be on the results screen

---

### **Test 2: Recipe Scan Notification**

1. **Start a recipe scan**
   - Tap the fork/knife button → "Scan recipe"
   - Take a photo of a recipe card or cookbook

2. **Background immediately**
   - Press home as soon as loading starts

3. **Wait for notification**
   - Should arrive within 15-30 seconds

---

### **Test 3: Recipe Link Notification**

1. **Enter a recipe URL**
   - Tap fork/knife → "Enter recipe link"
   - Paste a recipe URL (e.g., from AllRecipes)

2. **Submit and background**
   - Tap "Analyze Recipe"
   - Immediately press home button

3. **Wait for notification**

---

### **Test 4: Foreground Behavior (No Notification)**

1. **Start any analysis**
2. **Keep app in foreground** (don't press home)
3. **Result:** No notification! (Correct behavior)
   - Notification only appears if app is backgrounded

---

### **Test 5: Extended Backgrounding**

1. **Start analysis**
2. **Background for 60+ seconds**
3. **Result:** Should still complete (120s timeout)

---

## 📱 **First Time Setup Required**

### **Step 1: Enable Capabilities in Xcode**

You need to do this ONCE before testing:

1. Open your project in Xcode
2. Click on your project name in the navigator
3. Select your app target
4. Go to **"Signing & Capabilities"** tab
5. Click **"+ Capability"** button
6. Add **"Push Notifications"**
7. Add **"Background Modes"** and check:
   - ✅ Remote notifications
   - ✅ Background fetch

### **Step 2: Run on Real Device**

⚠️ **IMPORTANT:** Notifications don't work in Simulator!

1. Connect your iPhone/iPad
2. Select your device in Xcode
3. Build and run (Cmd+R)

### **Step 3: Grant Notification Permission**

First time you run the app, you'll see:

```
"CarbFinder" Would Like to Send You Notifications
```

**Tap "Allow"!**

---

## 🔍 Troubleshooting

### **Problem: No notification permission dialog**

**Solution:** Reset permissions
1. Go to Settings → CarbFinder
2. Toggle notifications off, then on
3. Or delete and reinstall the app

---

### **Problem: Notification says "Analysis Complete" but no details**

**Check logs:**
```
[AnalysisNotifications] 📤 Sending notification: 45g carbs - Chicken Bowl
```

If you see this log but no notification, check:
- Notification permissions in Settings
- Do Not Disturb is off
- Focus modes allow notifications

---

### **Problem: App killed/terminated instead of backgrounded**

iOS may kill your app if:
- Memory pressure is high
- Too many apps open
- Phone is low on battery

**Solution:** Close other apps before testing

---

### **Problem: Notification appears but tap doesn't open app**

This is expected! We haven't implemented deep linking yet. The notification handler in AppDelegate will print:

```
[Notifications] 👆 User tapped notification: [...]
```

But it won't navigate to a specific screen. That's a future enhancement.

---

## 📊 What Each Log Means

### **When Analysis Starts:**
```
[AnalysisNotifications] isAnalyzing set to true
```

### **When App Goes to Background:**
```
[AnalysisNotifications] 🌙 App entered background
```

### **When Analysis Completes in Background:**
```
[AnalysisNotifications] 📤 Sending notification: 45g carbs - Chicken Bowl
[AnalysisNotifications] ✅ Notification sent successfully
```

### **When User Returns to App:**
```
[AnalysisNotifications] ☀️ App entered foreground
[AnalysisNotifications] 🗑️ Cancelled pending notifications
```

---

## 🎯 Expected Behavior Summary

| Scenario | Expected Result |
|----------|----------------|
| Analysis completes while app in **foreground** | ❌ No notification (user sees result on screen) |
| Analysis completes while app in **background** | ✅ Notification appears |
| User taps notification | ✅ App opens (but doesn't navigate to results yet) |
| User returns to app naturally | ✅ Badge clears automatically |
| User force-quits app during analysis | ❌ Analysis fails (can't background-process when terminated) |

---

## 🚀 Next Steps (Optional Enhancements)

### **1. Deep Linking (Navigate to Results)**
When user taps notification, navigate directly to the result screen.

**Implementation:** Store `requestId` in notification userInfo, then navigate in the delegate.

### **2. Rich Notifications**
Show thumbnail of the meal in the notification.

**Implementation:** Use `UNNotificationAttachment` with meal image.

### **3. Remote Notifications (Firebase Cloud Messaging)**
For true server-side processing that survives app termination.

**Implementation:** Follow the guide in `BACKGROUND_ANALYSIS_GUIDE.md`

---

## 📝 Permission Prompt Customization

Add to your **Info.plist**:

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>Get notified when your meal analysis is complete, even when the app is closed.</string>
```

This text appears in the permission dialog.

---

## ✅ Checklist Before Submitting to App Store

- [ ] Add `NSUserNotificationsUsageDescription` to Info.plist
- [ ] Test on real device (not Simulator)
- [ ] Verify capabilities are enabled in Xcode
- [ ] Test both foreground and background scenarios
- [ ] Verify notifications appear on Lock Screen
- [ ] Verify badge clears when app opens
- [ ] Test with Do Not Disturb enabled (notifications should still show in Notification Center)

---

## 🎉 You're Done!

Run the app on your device and try backgrounding during analysis. You should see notifications appear!

If you have any issues, check the console logs for the `[AnalysisNotifications]` and `[Notifications]` tags.
