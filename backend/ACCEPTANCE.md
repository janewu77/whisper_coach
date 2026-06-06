# Backend Acceptance Criteria

Whisper Coach API — acceptance scenarios from the perspective of an API consumer (the Flutter app or a manual tester). Each scenario describes a real usage situation, what is sent to the API, and what observable outcome is required. These criteria define "done" for the backend.

Base URL: `http://localhost:8000`

---

## 1. System Readiness

**AC-01: Service is available**
Given: the backend is running
When: a caller checks the health endpoint
Then: the service responds immediately with a confirmation that it is operational

**AC-02: API documentation is accessible**
Given: the backend is running
When: a developer navigates to the API docs URL
Then: an interactive API reference is displayed listing all available endpoints

---

## 2. Roster Extraction

**AC-03: Coach uploads a team photo and receives a player list**
Given: a coach has a photo of the team sheet or squad list
When: the photo is submitted to the roster extraction endpoint
Then: the service returns a structured list of players with their names, jersey numbers (where visible), and preferred positions (where visible); a team record is created in the system

**AC-04: Optional team name is stored**
Given: a coach provides both a photo and a team name
When: the photo and name are submitted together
Then: the returned team record carries exactly the name the coach provided

**AC-05: Created team can be retrieved**
Given: a team was successfully created via roster extraction
When: the caller requests that team by its ID
Then: the full team record is returned including all extracted players

**AC-06: Non-image file is rejected**
Given: a caller accidentally submits a document or text file instead of a photo
When: the file is sent to the roster extraction endpoint
Then: the service rejects the request with a clear validation error before any processing occurs

---

## 3. Match Setup

**AC-07: Coach creates a match record**
Given: a team exists in the system
When: a coach submits match details — opponent name, location, date, and optionally notes and opponent strength
Then: a match record is created and the system returns a confirmation with the new match identifier

**AC-08: Match details are retrievable**
Given: a match has been created
When: the caller fetches the match by its ID
Then: all match details are returned, along with the current lineup (if generated) and any notes submitted so far

**AC-09: Missing opponent name is rejected**
Given: a caller submits a new match request
When: the opponent name field is omitted
Then: the service rejects the request with a validation error before creating anything

---

## 4. Lineup Generation

**AC-10: AI generates a tactical lineup for the match**
Given: a match exists with a roster of players
When: the coach requests a lineup for that match
Then: the AI returns a formation (e.g. 4-3-3), a list of player-position assignments covering the squad, and a plain-language explanation of the tactical reasoning

**AC-11: Lineup is saved and associated with the match**
Given: a lineup has just been generated
When: the caller fetches the match
Then: the lineup appears as part of the match record

**AC-12: Lineup can be regenerated**
Given: a lineup already exists for a match
When: the coach requests a new lineup for the same match
Then: a fresh lineup is returned; the previous lineup is preserved in history and not overwritten

**AC-13: Opponent strength can influence the lineup**
Given: a match exists
When: the coach requests a lineup and specifies that the opponent is strong
Then: the AI's tactical reasoning acknowledges the opponent's strength in its explanation

---

## 5. In-Match Adjustments

**AC-14: Coach sends a note and receives a tactical suggestion**
Given: a match is in progress with an active lineup
When: the coach submits a note describing an observation (e.g. "left winger is exhausted")
Then: the AI returns a concrete tactical suggestion — substitutions and/or position changes with a reason — and the note is stored against the match

**AC-15: Voice-transcribed notes are handled identically to text notes**
Given: a match is in progress with an active lineup
When: the coach submits a note flagged as voice-originated (text already transcribed client-side)
Then: the AI processes and responds to it the same way as a typed note

**AC-16: Notes require an existing lineup**
Given: a match exists but no lineup has been generated yet
When: the coach attempts to submit a note
Then: the service refuses the request and indicates that a lineup must be generated first

---

## 6. Post-Match Summary

**AC-17: AI produces a post-match analysis**
Given: a match has concluded with notes recorded during play
When: the coach requests a post-match summary
Then: the AI returns an overall match summary, a rating and comment for each player who appeared, and a list of tactical improvements for future matches

**AC-18: Summary is available even with no notes**
Given: a match was created and a lineup generated, but no notes were submitted
When: the coach requests a summary
Then: the AI still returns a valid response structure, even if the content is limited due to lack of in-match observations

---

## 7. Error Handling

**AC-19: Unknown resource returns a clear not-found response**
Given: a caller references a match, team, or lineup ID that does not exist
When: any endpoint is called with that ID
Then: the service responds with a not-found error and does not return partial data

**AC-20: AI service failure is surfaced clearly**
Given: the underlying AI service is unavailable or returns an error
When: any AI-powered endpoint is called
Then: the service returns an error response indicating the AI call failed, rather than returning empty or incorrect data silently
