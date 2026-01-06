
It is very important that any person/AI coding on this project truly understands the set-up and nature of subscriptions.


How the free trial period works:

Once the user installs the app for the first time, they have three full days of trial period. 
During the three days, they have 10 captures per day 
Limit resets at midnight (local time)
Whether the user already had the app once is tracked using a UID in Keychain and in Firebase (check the codebase to understand this)
If the user is outside of the trial period or has already used the 10 captures that day, taking another image should not be possible. Instead it should open the "PlanView.swift" as a sheet. Of course unless the user has already subscribed to a paid plan (Premium or Unlimited)

There are two available subscriptions (both only have monthly plans):

1) Premium
Premium has the product ID "PremiumStandardSub"
Premium comes with 10 analysis per day (including both meal analysis, recipe analysis using image and recipe analysis using link)
How many analysis were used is displayed in "PlanView.swift" in the box with the bar
Once the 10 analysis per day are used up, the user can no longer capture any images. Clicking on the capture meal or capture recipe button will show an alert saying "You have reached your daily limit" and below "Upgrade to unlimited to continue"
This should be enforced
Once the user reaches the limit, the "Below limit" text on "ContentView.swift" should be replaced with "Limit reached" (same appearence, color etc.)
Limit resets at midnight (local time)

2) Unlimited
It has the product ID "unlimited"
Unlimited is shown as having unlimited scans
However there is a fair usage limit of 50 per day (limit resets at midnight local time)
This limit however is not displayed in the bar like for the premium plan. Instead, there is just a text saying "You have no usage limit"
When in the unlimited plan, it should say in "ContentView.swift", beneath the image of the logo "No limit" instead of "Below limit" (same appearence, color etc.)

THERE IS NO FREE PLAN


General Information for subscriptions:
Use the apple store kit system to regulare downgrades/upgrades. Basically we only use the "current plan" apple gives us. We do not try and mess with that
Keep the approach as simple as possible to make it robust
Always think about codingInstructions.md - also when creating subscriptions
