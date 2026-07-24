# /calendarize-this - Create the calendar event the argument asks for

ARGUMENTS: $ARGUMENTS — free text. Examples: a Slack thread URL where a meeting time was agreed, "focus 2h mañana en la mañana", "ooo viernes", "cita 30m con jason martes 10am EST".

## Purpose

Turn whatever the argument describes into a saved Google Calendar event on Bernard's work calendar (`bernard.uriza@visalaw.ai`), driving Google Calendar through the chrome-devtools MCP. Three modes, auto-detected from the argument:

| Mode | Trigger in argument | Event shape |
|------|--------------------|-------------|
| **Meeting / cita** | Slack URL, a person's name, "cita/call/1:1" | Guests + Google Meet + description with relevant links |
| **Focus** | "focus", "deep work", "bloque" | Solo event, "Focus time" type if the UI offers it, Show as Busy |
| **OOO** | "ooo", "out of office", "vacaciones" | "Out of office" native type (auto-declines), all-day unless hours given |

## Instructions

### Phase 1: Interpret the argument (no browser yet)

1. If it contains a Slack URL → read the thread with `slack_read_thread` (live slack-mcp, never cache). Extract ONLY what was explicitly agreed: participants, date, time, timezone. If no explicit agreement exists in the thread, STOP and ask — never invent a time nobody accepted.
2. Resolve relative dates against today ("lunes" = next Monday). Resolve the timezone:
   - Team/meeting times → Eastern (`ctz=America/New_York`). The team labels it "EST" year-round; the calendar handles the real offset.
   - Personal focus/OOO with no tz stated → `America/Mexico_City`.
3. Defaults when unstated: meeting = 30 min · focus = 2 h · ooo = all-day. Ambiguous date/time → `AskUserQuestion`, never guess.

### Phase 2: Open the prefilled event

Build the template URL (this exact shape — the `/calendar/u/<email>/r/eventedit` form 404s):

```
https://calendar.google.com/calendar/render?action=TEMPLATE
  &text=<title>
  &dates=YYYYMMDDTHHMMSS/YYYYMMDDTHHMMSS   (local to ctz, no Z)
  &ctz=<timezone>
  &add=<guest1@...>,<guest2@...>            (meetings only)
  &details=<url-encoded description>
  &authuser=bernard.uriza%40visalaw.ai
```

Open with `new_page`, then `take_snapshot` and verify ALL of: account chip = `bernard.uriza@visalaw.ai`, title, date, start/end time, timezone string, guest list exact (1:1 means exactly 2 people), Meet link present (meetings). For focus/OOO, click the matching event-type tab ("Focus time" / "Out of office") if the edit page offers it.

- Title in the AUDIENCE's language: English if any guest is a teammate; Spanish OK for solo personal blocks.
- Description carries the artifact links (launcher, Notion guide, ticket) — bare URLs.

### Phase 3: Save — the gate

- **Solo events (focus / OOO): save directly.** No gate.
- **Events with guests: fill everything, then `AskUserQuestion` with the summary (title · date/time tz · guests · Meet) BEFORE clicking Send** on the "send invitation emails" dialog. Send fires outward email — that click is the gated action. Bernard's go in the same session's argument (e.g. he already said "crea la cita") counts as the go: skip the ask and send.

### Phase 4: Verify saved

Navigate to the event's week, `take_snapshot`, confirm the event exists at the right slot. "Event saved" toast alone is acceptable evidence only if the week view also shows it.

### Report (silent efficient)

One block, nothing else:
```
✅ <title> — <date> <start>–<end> <tz> · guests: <list|solo> · Meet: <yes/no> · verified in week view
```
Plus the reference URL(s) the event came from (Slack thread, etc.).

## Rules

1. **Never invent an agreement.** A meeting is created only from an explicitly accepted time (thread evidence or Bernard's argument). No "probably works".
2. **Guest events never Send without the gate** (or Bernard's explicit order in the invocation).
3. **1:1 means exactly two guests** — Bernard + the named person. Never add extras "for visibility".
4. **No PII in titles.** Customer/case details go nowhere; links go in the description.
5. **Verify the account chip before saving** — wrong Google account = invite from the wrong identity.
6. **Timezone is explicit, always** — set `ctz`, verify the tz string in the snapshot, and report the tz in the summary. Team communications label it EST per convention.
7. If chrome-devtools MCP is down → 🛑 full-stop banner per `20-honesty.md`, no workaround.

## Anchors

- 2026-07-24: cita Scarlett (View-As walkthrough) creada exactamente con este flujo — template URL + authuser funcionó; `/calendar/u/<email>/r/eventedit` dio 404; el gate de Send aplicó porque el "crea la cita" de Bernard era la orden.
