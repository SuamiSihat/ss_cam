# Studio display (web portal) - QA record

Page: sidebar **Manage > Studio display** (`#studio-display`, in-app, touch-first). Public TV kiosk stays at `#signage`.
Roles: admin / manager / ceo (all write routes enforce this on the server).

| Area | Check | Status | Evidence |
|---|---|---|---|
| Navigation | Admin page no longer has a Studio Display tab, KPI card or ribbon item | PASS | Browser check on sandbox server |
| Navigation | Sidebar item opens `#studio-display` in the same tab; `#signage` still opens the kiosk | PASS | Browser check |
| Queue | Keypad + room chip -> Call now shows on page and on kiosk | PASS | Browser check (A-1031) |
| Queue | Add to waiting, Call next advances the queue | PASS | Browser check (A-1032) |
| Queue | Recall re-announces the same ticket (calledAt-based chime) | PARTIAL | Service test covers recall keeping the waiting list; audible chime not verified |
| Playlist | Toggle, reorder, add notice | PASS | Browser check (toggle, add notice); reorder not clicked in browser |
| Playlist | Upload MP4, stream with Range (206), delete removes file from disk | PASS | `security-tests.js` round trip with a minimal MP4 header |
| Playlist | Video plays on the kiosk and advances on end | PASS | Real ffmpeg MP4 uploaded via API; kiosk showed it playing, then returned to the next slide and cycled (browser check, silent playback). Sound ducking and unmuted autoplay on the real TV not checked |
| Branch info | Edit phone, save, persists after reload, shows on kiosk | PASS | Browser check |
| Branch info | Bad link (e.g. `javascript:`) refused; other branches unchanged; code cannot change | PASS | `security-tests.js` |
| Security | Designer/signed-out get 401/403 on every write route | PASS | `security-tests.js` |
| Security | Fake video sources and non-video uploads rejected | PASS | `security-tests.js` |
| Touch | Targets at least 44-48px, keypad, chips instead of dropdowns | PARTIAL | Visual check on desktop width; not tried on a real touch device |

Known limits: videos are upload-only (the site policy blocks external video links); a reverse proxy may cap upload size below the 300 MB app limit; the check-in QR on the TV is still a decorative placeholder.