# Android On-Device Smoke

The Android build's acceptance test (ANDR-D4): a documented checklist plus
the user's own confirmation on their own phone, not automation. The house
merge rule already provides the pause — the user runs this before saying
merge.

## Getting the APK onto a phone

CI is the build path of record. The local editor on this machine has no
Android export templates or SDK installed (`ANDROID_HOME` unset, no
`~/Library/Android/sdk`), and installing them is out of scope for this build —
if that ever needs to change, it is its own decision, not a side effect of
getting an artifact once. Every push to `main` and every manual
`workflow_dispatch` run of **Build Android debug APK**
(`.github/workflows/android-apk.yml`) uploads `android-debug-apk` as a run
artifact. Download it from the run's **Summary** tab, or:

```bash
gh run download <run-id> -n android-debug-apk
```

Install on a connected device or emulator with `adb install -r 907hustle-debug.apk`,
or transfer the file to the phone directly (it is debug-signed, so the device
needs "install from unknown sources" allowed for the source used).

## The checklist

Run these in order, on the actual phone, with a thumb — not a mouse.

- [ ] **Install** the APK downloaded above.
- [ ] **Cold boot** to name entry. First launch after install shows the
      Title screen; starting a new run reaches name entry with no crash and
      no stuck loading state.
- [ ] **Start a run.** Enter a name, confirm the run begins on Home at Day 1.
- [ ] **Scroll Market, Jobs, and Phone with a thumb starting ON a card** —
      not on bare background between cards. This is PR 1's fix
      (`fix/touch-scroll-transparency`, D-11): before it, only a drag
      starting on empty space scrolled, and a drag starting on a card,
      button, or label died at the card. Confirm all three screens scroll
      from a thumb placed directly on a card's own body.
- [ ] **Buy one item, then sell one item** on the Street Market. Confirm both
      the tap-to-open quantity sheet and the CONFIRM button respond correctly
      to a real touch, not just a mouse click in the editor.
- [ ] **Save and reload.** Back out to the Title screen (or force-quit and
      relaunch) and confirm CONTINUE RUN restores the same day, cash, and
      inventory.
- [ ] **Kill and relaunch resumes.** Swipe the app away from the OS's recent-
      apps view entirely, relaunch, and confirm CONTINUE RUN still restores
      the run from the last autosave.

Report anything that fails as its own finding — this checklist is the test,
not a formality ahead of one.
