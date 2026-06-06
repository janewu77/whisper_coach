# Frontend Acceptance Criteria

Whisper Coach app — acceptance scenarios from the perspective of a football coach using the app. Each scenario describes a real situation, what the coach does, and what they must experience for the feature to be considered complete. No technical implementation details.

---

## 1. App Launch

**AC-01: App opens to the home screen**
Given: the coach opens the Whisper Coach app for the first time
When: the app finishes loading
Then: the home screen is displayed with options to upload a team photo and fill in match details; no error messages appear

---

## 2. Roster Upload

**AC-02: Coach photographs the team sheet and sees the extracted players**
Given: the coach is on the home screen
When: the coach taps the upload button, selects or takes a photo of the team sheet, and confirms
Then: within a few seconds, a list of extracted player names (and numbers where legible) appears on screen for the coach to review

**AC-03: Coach can proceed without uploading a photo**
Given: the coach does not have a team photo available
When: the coach skips the photo step and proceeds to fill in match details manually
Then: the app allows the coach to continue without forcing a photo upload

---

## 3. Match Creation

**AC-04: Coach fills in match details and creates the match**
Given: players have been loaded (via photo or manually)
When: the coach enters the opponent name, location, and date, then taps Create Match
Then: the match is confirmed and the coach sees a Generate Lineup button

**AC-05: Form prevents submission with missing required fields**
Given: the coach has not filled in the opponent name
When: the coach taps Create Match
Then: the form highlights the missing field and does not proceed; no network call is made

---

## 4. Lineup View

**AC-06: Coach sees the AI-generated lineup on a pitch**
Given: a match has been created with a squad of players
When: the coach taps Generate Lineup
Then: a 2D pitch diagram appears showing all players positioned according to the AI's chosen formation; the formation name (e.g. 4-3-3) and a plain-language explanation of the tactical reasoning are displayed

**AC-07: Coach can tap a player to see details or add a note**
Given: the lineup is displayed on the pitch
When: the coach taps on any player icon
Then: a panel or sheet opens focused on that player, ready for the coach to add a note

**AC-08: Coach can regenerate the lineup**
Given: the lineup is displayed but the coach is not satisfied with it
When: the coach taps Regenerate
Then: a new lineup is fetched from the AI and the pitch updates to reflect the new formation and positions

---

## 5. Live Notes — Text

**AC-09: Coach types a note and receives a tactical suggestion**
Given: a match is in progress and the lineup is displayed
When: the coach types an observation (e.g. "our left side is being exposed") and taps Send
Then: within a few seconds, a suggestion card appears showing recommended substitutions or position changes and the AI's reasoning in plain language

**AC-10: Multiple notes can be sent during the match**
Given: the coach has already sent one note and received a suggestion
When: the coach sends another note about a different situation
Then: a new suggestion card appears for the new note; previous suggestions remain visible or accessible

---

## 6. Live Notes — Voice

**AC-11: Coach uses voice to dictate a note**
Given: the coach is on the live notes screen during a match
When: the coach taps the microphone button and speaks an observation aloud
Then: the spoken words are transcribed and appear in the note text field; the coach can review and edit before sending

**AC-12: Voice input flows into the same suggestion process**
Given: the coach has dictated a note via voice and tapped Send
Then: the app processes it and returns a suggestion card in exactly the same way as a typed note

---

## 7. Post-Match Summary

**AC-13: Coach ends the match and receives a full summary**
Given: the match has concluded and the coach has submitted notes throughout
When: the coach taps End Match
Then: a summary screen appears showing an overall match assessment, a rating and brief comment for each player, and a list of tactical points the team should work on before the next match

**AC-14: Summary is available even without notes**
Given: the coach ends a match without having submitted any in-match notes
When: the coach taps End Match
Then: a summary screen still appears with whatever analysis the AI can provide; the screen does not crash or show an error

---

## 8. Error States

**AC-15: Network error is surfaced gracefully**
Given: the device has lost connectivity or the backend is unreachable
When: the coach performs any action that requires a server call
Then: a clear message explains that the request could not be completed and the app remains usable; no crash occurs

**AC-16: AI processing delay is communicated**
Given: the AI is taking longer than usual to respond
When: the coach is waiting for a lineup, suggestion, or summary
Then: a loading indicator is visible so the coach knows the app is working; the coach is not left staring at a blank or frozen screen
