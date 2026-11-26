# Bouba — iOS prototype

SwiftUI, iOS 26 (Liquid Glass), no backend. All data is in memory and resets when the app relaunches.

## Run
1. Install Xcode 26 from the App Store.
2. Open `Bouba.xcodeproj`, pick an iPhone simulator, press ⌘R.
   (To run on a real device, set your Team under Signing & Capabilities.)

## What's in it
- **Onboarding**: sign up with a phone number and a texted 6-digit code (in the prototype any 6 digits work), then "I have a pet" (a 5-step profile setup that's mostly taps: species, name and photo, age and size, starter routine, vet and emergency permission) or "I'm caring for a pet" (enter an invite code, then swipe through "Meet Felix").
  Demo code: `FX7K2Q`. "Try a sample pet" skips straight to the app.
- **Activity**: pet switcher, ⚠️ emergency info, notifications, a week strip, a day summary (progress, what's up next, who's on duty or check in/out), **Must do** priority tasks in the owner's ranked order, then the **Routine** sorted by time.
  One tap completes a task. A toast then lets you attach a photo, a note, or a quick answer like "Ate it all" or "💧 Pee".
- **History**: a timeline of completions, photo updates and visits, with filters. You can also post an update with photos and a mood.
- **Pet profile**: about, must-not-eat, home access (codes hidden until tapped), vet. Owners can edit all of it and manage the care team.
- **Invite caretaker**: role (co-owner, pet sitter or regular sitter), access dates with early access, update preferences (completion alerts, photo frequency, check-ins) and permissions, then a share link.
- **Me**: a prototype toggle to view the app as Owner (Brian) or Caretaker (Andrew).

## Structure
```
Bouba/App         App entry, tabs, Allo font + colors
Bouba/Models      Data model + in-memory AppStore with sample data
Bouba/Activity    Activity screen, task cards, task detail/editor/rank sheets
Bouba/History     Timeline + post update
Bouba/Pet         Pet profile, edit, invite caretaker
Bouba/Me          Settings / role switcher
Bouba/Onboarding  Welcome, create pet, join + meet the pet
Bouba/Shared      Reusable components, emergency + notifications sheets
Bouba/Fonts       AlloVariable.ttf (registered at launch)
```
