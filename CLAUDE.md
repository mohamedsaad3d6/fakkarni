# Fakkarni (فكرني) — Project Guide

Arabic-first (RTL) medication reminder app for elderly patients in Egypt.
Its differentiator: when a **critical** dose is missed, the app runs an
**escalation ladder** that ends at the caregiver (the patient's adult child) —
the patient is never left alone with a notification he already missed.

Two users, different needs:
- **The patient** — ~72 years old, reading glasses, uses the app under pressure.
- **The caregiver** — working adult, checks briefly, and is covered by
  the **one family subscription** on the patient (see «Pricing»,
  24 Sep 2026). *Two earlier readings of this line are superseded: «the
  son pays for the father's account» (until 22 Sep) and «every follower
  pays for his own» (22–24 Sep). Today: one subscription per patient
  covers him and up to five people following him, and any of them may
  pay it.*

---

## Non-negotiable rules

These are product decisions, already settled. Do not "improve" them without asking.

1. **A dose is an anchor + an offset by default. A fixed clock time is the
   documented exception, never the first thing offered.**
   Timing is the sealed `DoseTiming`: `AnchorTiming(anchor, offsetMinutes)`
   — `{anchor: breakfast, offsetMinutes: -30}` — is the default and the
   primary control everywhere. `FixedTiming(minuteOfDay)` exists for the
   prescription that genuinely says "8:00 sharp". **Since 24 Sep 2026 (owner
   decision) the editor shows both modes side by side at the top** —
   «مع الأكل / الروتين» first and selected, «ساعة محددة» beside it; the
   small link that used to sit under «احفظ الجرعة» is gone. The anchor is
   still the default and the first thing offered; what changed is that the
   clock is a visible choice instead of a hidden one. The editor must still
   say plainly «ساعة ثابتة — مش هتتحرك مع روتين يومك» in that mode.
   The rule was not abandoned: anchors are still why Ramadan, travel and late
   wake-ups work by editing one field. Fixed doses simply stay where the
   patient put them when the routine changes. Never make fixed the default,
   never persist a resolved time for an anchor dose, and keep the fixed minute
   in `fixed_timings` — not as a column on every schedule.

2. **`lib/domain/` stays pure Dart.** No Flutter, no database, no IO, no
   plugins. Pure functions are why the engine is unit-tested in under a second.
   If a feature needs a dependency, it does not belong in `domain/`.

3. **Never auto-stop a medication.** `durationDays == null` means open-ended and
   the reminder runs forever until a human stops it. Never infer a duration.

4. **AI proposes, a human confirms.** No OCR/Gemini output ever becomes a
   scheduled dose without an explicit tap on a confirmation screen. On that
   screen, "أعدّل" carries the same visual weight as "تمام" — never nudge
   someone into confirming a medication schedule they have not read.
   Unknowns split into **blocking** and **non-blocking**: an unclear *name
   or timing* blocks «تمام» (nothing to schedule); an unknown *amount* does
   not — it stays gold with its note, «تمام» proceeds with a quiet
   «هتتحفظ من غير الجرعة — تقدر تضيفها بعدين», and the row is saved with
   `amountLabel = null, amountUnknown = true`, which «يومك» surfaces as
   «اسأل الصيدلي عن جرعة …». Never invent a value to unblock a button; never
   forget an unknown silently either. A «١×٣» line with no meal named is
   always flagged, whatever confidence the model reports, because spreading
   it over three meals is our convention, not the paper's.
   «صوّر تاني» is always offered — a bad read is fixed by a better photo,
   not by editing five fields by hand.

5. **A confirmation cancels every rung that has not yet fired — on the
   device and on the server — immediately, at any stage.** No exceptions
   and no "unless", including after the caregiver has already been
   alerted: the next rung dies the moment he confirms. A few seconds of
   lag here means needlessly worrying the son, which is worse than a late
   alert.
   The one thing this rule does **not** claim is the impossible. An alert
   already delivered to the son's phone is not recalled — there is no
   unsend, and both ways of faking one are worse than the alert itself.
   A second "never mind" push spends the channel that has to stay
   meaningful, and silently deleting a notification he may already have
   read turns a worrying message into a vanishing one. The repair is a
   correct view, not a deletion: his next refresh shows the dose as taken.
   Never build a recall path; if you think you need one, re-read this.

6. **No medical advice, ever.** Default offsets (30 min before food, 15 min
   before bed — one function, `defaultOffsetBefore(anchor)` in `domain/`,
   used by both the editor and the Gemini reader) are editable operational
   conventions, not clinical guidance. If a
   prescription line is unclear the answer is "مش متأكد — اسأل الصيدلي",
   never a confident guess. The app never suggests, changes or stops a drug.

---

## UI rules

- **Body text ≥ 20px. Never below 17px anywhere.** Tap targets ≥ 56px, primary
  buttons 64px. Maximum two primary actions per screen. No icon-only buttons —
  every control carries a word.
- The mockups render small and their type and targets read below these minimums.
  **Take every size from `class F`, never from measuring the image.** Where a
  mockup is tighter than the minimums, the minimums win — and say so.
- **Red belongs to emergency and to nothing else** — «معلومات الطوارئ»
  (`F.redDeep` ground), «بطاقة الطوارئ», the son's `EmergencyFactsCard`,
  and the top bar's filled `EmergencyPill` (mockup 04), all living in
  `lib/features/emergency/`, with `F.red` on the ambulance button. The pill
  is the only red outside those screens, and it holds its meaning **because
  nothing else takes it**: the mockup's red card buttons are gold here.
  **Two exceptions, each decided by the owner and each bounded the same
  way — one file, and never a fill.** The second is the son's escalation
  alert card (`caregiver_screen.dart`): border, start bar and a ⚠ icon in
  `F.careAlertInk`, with the text in ink and the ground untouched. Same
  values as `F.outOfRangeInk` (5.23:1 light / 5.09:1 dark on the worst
  ground), and **the guard was widened deliberately, not bypassed**:
  `careAlertInk` is *added* to the forbidden pattern in
  `red_only_in_emergency_test` and allowed in that one file, so writing
  it anywhere else still fails — mutation-checked. The filled red pill is
  still emergency's alone, which is the whole reason it means anything.
  **The first exception, decided in round 21 and bounded twice over:** a lab
  value outside the range printed on its own report takes red as *text and
  an outlined badge* — never a fill. The filled red pill stays unique to
  emergency, which is the whole reason it still means something; this is a
  comparison of two printed numbers, not a call for help. It lives in
  `lib/features/health/lab_flag.dart` and nowhere else, `F.outOfRangeInk`
  is a **getter** (plain `F.red` is 2.71:1 on a dark card — the night mode
  takes a lighter red), and the guard test allows that one file while a
  widget test asserts the badge's decoration carries a border and **no**
  `color`. Near-boundary uses the existing gold, with ink text (gold text
  is ~2:1, debt 5). Other
  screens *use* those widgets; they never paint red themselves. The
  mockups also spend red on the `طوارئ` shortcut in the top bar; ours is
  ink-outlined, because red on any other screen is wrong — including the
  door to the emergency screens. Never use red for an error, a warning, a
  validation message, or a missed dose. A missed dose uses gold and neutral
  wording — he forgot, he did not fail. `test/app/red_only_in_emergency_test.dart`
  reads `lib/` and fails on any red token or hex outside that folder.
- **Gold (`F.gold`) means one thing: "this needs your attention now."** A
  dose that needs taking now, the state you are currently on, and a field the
  AI is unsure about (the review row's gold edge, «مش متأكد من دي — راجعها»)
  — all three are that one meaning. Do not
  add a fourth use that isn't; a list of exceptions grows until the colour
  means nothing, a principle does not. The mockups show a coral FAB in the
  bottom bar — build that FAB in green, not coral. Gold must be the only
  colour that pops.
- **No time picker as the primary control.** The dose editor leads with anchor
  chips (`[قبل الفطار] [بعد العشا] …`) plus an offset wheel. A fixed clock
  time exists only as a small secondary link.
- **No preset time chips anywhere, and the clock wheel steps by one
  minute** (product change, 24 Sep 2026). The «٦:٠٠ / ٦:٣٠ / ٧:٠٠» rows
  above the routine questions, in «عدّل يومك», in the ask-meal sheet, and
  the «غيّر»/«ساعة تانية» chip-then-wheel toggles on Ramadan and «عدّل
  يومك» are gone: the `FTimeWheel` is always visible and rests where the
  middle chip used to be (`RoutineQuestion.fallback`). Required values
  show the rest and «تمام»/«احفظ» confirm it as before; optional or unset
  ones still write nothing until the wheel moves. `RoutineQuestion.presets`
  and `PresetRow` no longer exist. Nothing in scheduling assumed 5-minute
  alignment — `test/data/odd_minutes_test.dart` runs a 6:07/7:13 routine
  through the engine, the id bands, the ladder, the repeats and the horizon.
  `FNumberWheel` steps are unchanged (offset 0–180 by 5, days by 1).
- **Every number and every clock time is set on a wheel — one family,
  `lib/core/widgets/f_wheels.dart`** (product decision, 24 Sep 2026). No
  `+/−` stepper, no slider, no typed number for a value the app owns.
  `FNumberWheel` (min / max / step / unit, Arabic numerals) and
  `FTimeWheel` (hour + **one-minute** wheels with ص/م, the same `MinuteOfDay` in
  and out that `TimeWheel` used to carry) share one Cupertino column: 26px
  ink numerals, a green-tinted selection row, a haptic tick on every step
  (iOS ticks natively, Android through `HapticFeedback`), and they work
  on Android. `FNumberWheel.value` may be null: the wheel rests on `rest`
  and **writes nothing until it is moved** — how an optional question
  («سنّك كام؟») and a number we must never invent («المعمل قال صيام كام
  ساعة؟», rule 6) stay empty until a human answers. Where it lives now:
  the five routine questions, «عدّل يومك», Ramadan, the dose editor's
  fixed clock and its «بكام؟» offset (0–180 by 5, same range as the old
  stepper), «ضيف دوا»'s duration (1–90 days) and its «أكتر» count (5–12),
  the fasting sheet's draw time and hours (1–72, rests on 10), and the
  age. **Kept on the keypad, on purpose**: the glucose reading (a
  three-digit number read off a meter — spinning 20–600 to it is worse
  than typing three digits), lab values (decimals in the paper's own
  unit), the 6-digit invite code and phone numbers (not values), and the
  free-text amount («نص قرص»). Dates stay on chips plus the calendar.
  `MinuteStepper` and `features/onboarding/time_wheel.dart` are gone;
  `test/app/wheels_se_test.dart` pumps every screen that gained a wheel at
  375×667 with the real fonts and asserts the primary button is on screen.
- **Copy is warm Egyptian colloquial**, the way a family speaks:
  "بتفطر الساعة كام؟" — not "يرجى تحديد موعد وجبة الإفطار".
- **The app has a night mode, and every colour flips from one place.**
  The semantic surfaces and the text colours are **getters** on `F`, not
  constants: `F.pageGround` gives the current mode's value and the root
  rebuilds when `F.darkMode` changes. The preference lives in
  `shared_preferences` (`ui.dark`) like the water counter — **not** in the
  schema; it is a display choice on this phone. Two traps, both paid for
  once: a `const` widget subtree (`const SettingsScreen()`) does **not**
  rebuild when a global flips, so `main` keys the whole app on the mode;
  and the splash would replay on every toggle, so it now runs once per
  launch. `dark_mode_test` computes the contrast of the real tokens and
  fails if a colour drops under AA in either mode.
  **The son has the same switch, and it is the same switch** — one
  `DarkModeToggle`, one `ui.dark` key, no caregiver flag: it is a setting
  for *this phone*, whichever role runs on it. It sits in **two** places
  on his side and that is not a second door: the patient's toggle lives in
  the shell's top bar, which every tab is under, while `CaregiverShell`
  has no shell bar at all — each tab carries its own `AppBar` and
  «الإعدادات» has none. So «متابعة»'s bar covers the tab he lands on, and
  the settings row is the only one reachable from any tab. The row is the
  same widget with a word beside it («الوضع الليلي» — «شغّال»/«مقفول»),
  not a `Switch`: a switch there would trip `caregiver_shell_test`, which
  proves the son's side writes nothing.
  **A constant colour is a dark-mode bug waiting to happen, and `F.gold`
  is the only one that earns its constancy.** `F.greenDeep` was the text
  colour of «اتاخد» on «متابعة» and «اتسأل ✓» in his health file: 9.38:1
  on a light card, **1.51:1 on a dark one** — the confirmed dose and the
  asked question simply vanished at night. Both now use `F.green`, which
  flips (5.15 light / 7.24 dark). `caregiver_dark_mode_test` walks every
  rendered `Text` on **each** tab in dark mode and fails under 4.5:1.
  That check was written wrong first and caught by mutation: one pass at
  the end of the walk only sees the *current* tab, because
  `find.byType(Text)` skips offstage — restoring `F.greenDeep` stayed
  green. It now runs after every tab and asserts it inspected something.
- **A screen never names a surface colour; it names the surface's job.**
  `F.pageGround` (white), `F.cardGround` (`#EFEFEF`, the mockups' card
  grey), `F.railGround` (`#F6F6F6`, a quiet panel inside a card, a chip, a
  disabled row), `F.fieldGround`, `F.dialogGround`, and `F.onDark` /
  `F.onDarkMuted` for text on green or on a photo. The raw palette
  (`white`, `ivory*`, `cardGrey`, `quietGrey`) lives in `tokens.dart` and
  is not written anywhere else — `test/app/no_raw_surface_test.dart` fails
  if it is. This is what made the ground flip two lines instead of 133:
  before it, 69 `F.ivory` and 64 `Colors.white` each chose for themselves.
  **The app's ground is the mockups' white since that round**; ivory stays
  in the palette because `onDarkMuted` and a few tints are derived from it.
- **Never use «·» in a string the user reads.** The Arabic-Indic zero «٠»
  *is* a dot, so beside Arabic digits a middle dot and a zero are the same
  glyph: «الحاج عاشور · ٦٢ سنة» reads as «٦٢٠ سنة», and «كمان ١٠ ساعات ·
  ٧:٣٠ م» as «٧:٣٠٠ م». The separator is « — » (or a second line where that
  reads better); comments and docstrings may keep «·».
  `test/app/no_middle_dot_test.dart` reads every string literal under
  `lib/` and fails if one comes back.
- **الكيبورد بيتقفل من الجذر — مش من كل شاشة.** على آيفون حقيقي:
  «بيانات الطوارئ» بتحفظ وبتعمل `pop` وهي سايبة التركيز على حقل نص.
  الحقل بيروح مع الشاشة والكيبورد بيفضل مفتوح على «يومك» **من غير أي
  حقل يقفله بيه**. وأوحش: الكيبورد المرفوع بيزقّ الدوك لفوق، فـ«ضيف»
  و«القريب مني» بيقعدوا **فوق «تأكيد الجرعة»** — وراجل عنده ٧٢ سنة مادّ
  إيده للتأكيد بيدوس «ضيف». قبل الجولة دي كان فيه `unfocus` **واحدة** في
  التطبيق كله (`glucose_screen`)، يعني كل فورم تاني كان ممكن يسرّب
  كيبورد — فالعلاج في `lib/core/widgets/keyboard_dismiss.dart`، مش في
  الشاشة:
  - `FakkarniNavigatorObserver` بيسلّم التركيز عند كل `push` و`pop`
    و`didReplace`. `push` كمان مش `pop` بس: شاشة بتفتح شاشة وهي كاتبة
    بتسيب الكيبورد فوق الجديدة بنفس الطريقة.
  - `KeyboardDismiss` في الجذر: دوسة برّه أي حقل بتقفله. `translucent`
    فالدوسة بتعدّي، والزرار اللي تحت الصبع هو اللي بيكسب في ساحة
    الإيماءات — اختبار بيثبت إنها ما بتاكلش دوسة على زرار شغّال.
  - **وكل حقل في `lib/` له `textInputAction`**، فالكيبورد نفسه دايماً
    فيه باب خروج. `test/app/keyboard_test.dart` بيمشي على الأقواس
    المتوازنة لكل `TextField(` ويوقع لو واحد اتضاف من غيره — عدّ الكلمات
    كان هيعدّي على حقل ناقص في وسط ملف. حقل متعدد السطور بياخد `newline`
    مش `done`، وإلا زرار السطر الجديد بيتحوّل لـ«تم».
  - **`keyboardIsUp` بتتقرا من مصدرين، ودي مش حزام وحمّالة.**
    `MediaQuery.viewInsetsOf` هي اللي بتعمل إعادة البناء أصلاً — بس
    `Scaffold` وهو `resizeToAvoidBottomInset` **بيصفّر الـinset لجسمه**،
    فأي شاشة جوّه الشِل بتشوف صفر وهي مغطّاة بالكيبورد (ده اللي خلّى
    «القريب مني» يفضل ظاهر). الرقم الخام من `View` هو الحقيقة هناك،
    وإعادة البناء بتيجي من الشِل اللي فوقها.
  - الدوك و«ضيف» و«القريب مني» بيختفوا وهو مرفوع — في الشِل العادي ونمط
    كبار السن **وشِل الابن** («الملف الصحي» عنده فيه بحث).
  - **وفي الاختبار**: `Scaffold` بيطلّع الزرار العايم بحركة تصغير، فنبضة
    واحدة بعد تغيير الـinset بتلاقيه **لسه موجود**. لازم نبض محدود
    (`settle`) مش `pump` واحدة.
- **A sheet with a text field moves with the keyboard — and that lives in
  `FSheet`, not in the caller.** `showModalBottomSheet` is already
  `isScrollControlled`, but a sheet built at its natural height is simply
  covered when the keyboard rises: the field and the save button end up
  under it, so a 72-year-old types blind and cannot reach «احفظ» at all.
  `FSheet` now pads its bottom by `MediaQuery.viewInsetsOf(context).bottom`
  and puts its body (not the grip and title) in a `Flexible`
  `SingleChildScrollView`, so a short screen scrolls instead of clipping.
  Fixed in the one widget because the same sheet is opened from four
  places; `test/core/f_sheet_keyboard_test.dart` pins it on a 400×600
  screen with a 336px keyboard and asserts both the field and the button
  are **above** it and actually tappable — mutation-checked: dropping the
  padding puts the field at y=500 against a keyboard starting at 264.
- **Any monospace font needs an Arabic fallback in the stack.** IBM Plex Mono
  has no Arabic glyphs; without a fallback Arabic letters render disconnected.

---

## Architecture

```
lib/
  domain/scheduling/          PURE DART — no Flutter imports
    day_routine.dart          DayAnchor, MinuteOfDay, DayRoutine
    dose_schedule.dart        DoseSchedule, DoseRepeat, DoseTiming
                              (AnchorTiming | FixedTiming)
    schedule_engine.dart      resolveTime / resolveFixed / remindersForDay
  domain/escalation/          PURE DART — escalation_ladder.dart: rungs
                              +15/+30, graceWindow 45, serverGraceWindow 60,
                              syncSlack 15, ladderFor, isPastGrace
  ai/                         Phase 2 — gemini_config (key from --dart-define),
                              prescription_reading (pure model + responseSchema),
                              prescription_reader (Gemini REST, http.Client injectable)
  core/theme/tokens.dart      brand colours + elderly-first sizing (class F)
  core/images/                shrink_for_ai — PURE DART, no Flutter: the
                              one place an image is resized before Gemini
  core/notifications/         NotificationService — local scheduling; tap → lastPayload
  data/db/                    drift (SQLite) v29 (v25 vitals, v26 medication_stock, v27 medications.photo_path, v28 medications.not_bought_at, v29 dose_schedules day patterns): patients (sex, age — local),
                              day_routines, routine_backups (v7, local),
                              device_preferences (v9, local: elder mode +
                              the +15/+30 rung switches), emergency_profile
                              (v10; pushed since D5.1 without contacts),
                              records (v11, soft delete), readings +
                              lab_results (v12; the paper's printed range
                              ref_low/ref_high/ref_text, v18),
                              visit_questions (v14) —
                              the health file, pushed since D5.1,
                              dose_schedules.active_from (v15, local),
                              records checkup dates (v17),
                              medications (amount_unknown, active_ingredient
                              — local، من العلبة بس), dose_schedules
                              (timing_kind), fixed_timings, dose_events — every
                              synced table carries a device-minted `uuid`
                              (SyncIdentity mixin)
  data/repositories/          routine / medication / dose_event
  data/services/              reminder_plan (pure: IDs, window, payload,
                              planEscalations), reminder_scheduler (engine →
                              sink; materialise → sweepMissed → plan), reminder_sink
                              notification_actions (lock-screen «أخدته»/«فكّرني بعدين»)
  app/                        AppScope (services), AppRoot (onboarding | today,
                              opens ReminderScreen on tap), bootstrap.dart
                              (buildServices + background action entry point)
  features/onboarding/        5 routine questions (mockup 22): one per
                              screen, the wheel always visible (no presets),
                              «مش متأكد» → DayRoutine.fallback, 5 dots
  features/medication/        dose_editor (mockup 23 — the ONE timing editor:
                              8 anchor chips, offset wheel, gold preview, fixed
                              link last); add_medication (mockup 20 fields →
                              one DoseEditor per timing, saved only after the
                              last); EditMedicationScreen — amount, per-dose
                              «عدّل» → DoseEditor (updateTiming), stop (two-step)
  features/today/             home (greeting, «الآن», 48h, water) + day rail;
                              dose_actions (confirm/snooze shared with elder،
                              + nowLines وكلام العدّاد), widgets/now_block
                              (كتلة «الآن» الواحدة بعدّادها)
  features/elder/             ElderHomeScreen — one dose card, «تم ✅» 80
  features/routine/           EditRoutineScreen — change any anchor after onboarding
  features/settings/          SettingsScreen + NotificationsScreen (rung switches)
  features/link/              SignInScreen — the one door to identity («اربط ابني»)
  features/entry/             EntryScreen «مين ماسك التليفون؟» (D4) — routes only
  features/care/              CaregiverShell «متابعة» · «الأدوية» ·
                              «الملف الصحي» · «الإعدادات» — the son's
                              read-only app, one CaregiverSnapshotHolder
                              (fetch + gated poll) read by all three data
                              tabs, straight from Supabase; its own density
                              tier — caregiver_status (pure: the answer to
                              «هو كويس؟» + 7-day adherence) and caregiver_ui
                              (CareCard/CareHead/CarePanel/CareStateMark)
  domain/wording/             rule_wording — «الفطار − ٣٠ د» text shared by
                              the scheduler and the son's side (no scheduling
                              import there)
  data/auth/                  AuthService interface + GoogleAuthService +
                              supabase_init (initSupabaseAuth for the app,
                              initSupabaseForIsolate for the background wake-up)
  data/push/                  PushTokens / DeviceTokenSource / PushTokenRemote
                              (interfaces) + PushTokenService (pure decision
                              logic, tested with fakes) + firebase_token_source
                              (the ONLY firebase import in the app) +
                              supabase_push_tokens (claim_device_token)
  features/scan/              ScanPrescriptionScreen (advice → «صوّر الروشتة» /
                              «اختار من الصور», one image_picker path for both)
                              + ReviewPrescriptionScreen «الذكاء يقترح، وأنت تؤكّد»
  features/reminder/          ReminderScreen (mockup 10) — تم التناول ✅ / تأجيل ١٥ د ⏰ /
                              تخطّي, four-rung ladder from domain constants
test/                         1475 passing
```

**The routine is optional, and the app never times a medication from a
routine value the user did not set** (product decision, 24 Sep 2026).
`DayRoutine` keeps its five non-null minutes — so the engine math, Ramadan
and the wording are byte-for-byte what they were — and gains `unset`, the
anchors the user never chose. An unset anchor still holds a number, but it
is a **rest position for the wheel, not an answer**: `remindersForDay`
skips every `AnchorTiming` on an unset anchor (`routine_unset_test`), so
nothing can ring from it. An unset `wake` still bounds the routine day —
that decides which day a 1 AM fixed dose is counted under, never *when*
it rings, and the test pins that the instant is identical.
- **Storage**: `day_routines.unset_anchors` and `routine_backups.unset_anchors`
  (drift **v21**, `TEXT NOT NULL DEFAULT ''`, comma-joined anchor names).
  The default is the migration: every row from before v21 reads as fully
  set, because nobody reached the app without answering all five —
  `migration_test` asserts it on the v2 file. **No cloud migration**: the
  flag is not pushed. `_pushDayRoutines` sends the five minutes as before,
  nothing in the cloud reads a routine (the son never resolves anchors),
  and pushing a column that does not exist on the live project would fail
  the whole `day_routines` batch silently. If the cloud ever needs to know
  which minutes are placeholders, that is `0022` **run before** the build
  that pushes it — not a quiet edit to the payload.
- **Onboarding**: each question has «مش دلوقتي» («مش متأكد» is gone —
  it stored the fallback *as if chosen*). Skipping removes the answer and
  `routineFromAnswers` marks the anchor unset. Skipping all five saves
  `DayRoutine.none`: a row exists, the app proceeds, nothing is invented.
- **Add / edit a dose** (`DoseEditor`): when the chosen anchor is unset the
  editor opens in **fixed-clock mode** with the wheel at its rest — no
  number from a default routine. The anchor chips stay, each unset one
  labelled with «؟»; tapping it opens `askAnchorTime` (`lib/features/
  routine/ask_anchor_time.dart`: the same question and wheel as
  onboarding, «تمام» locked until the wheel moves) **once**,
  `RoutineRepository.setAnchor` writes it as set, and the chip is then an
  ordinary anchor. Closing the sheet writes nothing. `AddMedicationScreen`
  and `EditMedicationScreen` hold a live `_routine` so later editors in
  the same walk see the meal as set; a form with unset anchors says so in
  words instead of promising «مراسي يومك».
- **Prescription review**: an AI line on an unset anchor shows «ميعاد
  الفطار مش متحدد» in place of a time, a gold note, and «حدّد ميعاد
  الفطار» — and it **blocks «تمام»** like an unclear timing until the
  person answers. Never auto-filled (rule 4 and rule 6 in one place).
- **Settings «عدّل يومك»**: an unset anchor reads «مش متحدد» over a wheel
  resting at the fallback; only a wheel move sets it (null-until-moved).
  Once set, every dose on that anchor follows it as always; fixed doses
  stay where they are.
- **Appointment notices** still read `routine.wake` / `routine.dinner`
  for their clock; on an unset anchor that is the rest value (6:30 / 20:00),
  the same operational choice as the checkup's 9:00 — and it is a notice
  about a visit, not a medication time.

**«النهارده» بعد نص الليل = يوم الروتين اللي لسه ماشي** (٢٦ سبتمبر ٢٠٢٦، من
الجهاز: دوا اتضاف ١٢:٥٠ بالليل بساعة ثابتة ١٢:٥٢ وبداية «النهارده» اتعرض
«بكرة ١٢:٥٢ ص» وما رنّش). `start_date` بيتقارن بيوم الروتين في `isActiveOn`،
والفورم بيدّي تاريخ التقويم؛ قبل الصحيان الاتنين مختلفين وجرعة الليلة دي كانت
بتتشال. `startDayFor` في `domain/scheduling/routine_day.dart` (نقية؛
`currentRoutineDay` في `reminder_plan` بقت بتنده `routineDayOf` منها) بترجّع
يوم الروتين لما المختار = تاريخ النهارده ويوم الروتين قبله، وأي تاريخ تاني
زي ما هو. بتتطبّق في **مكان واحد**: `MedicationRepository._insertSchedule`
(كل إضافة: الفورم، المراجعة، التعديل، الممرض) و`updateTiming`. الماضي مقفول
زي ما هو من `active_from` والخطة «الأقرب من دلوقتي» — `start_after_midnight_test`
بيثبت ١٢:٥٠/١٢:٥٢ و١١:٥٠/١٢:١٠ و١٠ الصبح والتعديل بالليل، والخطط الذهبية
والمجدول خضر بالحرف. «بكرة» تاريخ تقويم والفورم بيكتبه («هيبدأ بكرة — التاريخ»).

**The day starts at wake, not midnight.** `minutesFromDayStart` is
`(anchor - wake + 1440) % 1440`, so a 1 AM bedtime lands 18 hours *after*
waking rather than 6 hours before it. A fixed time follows the same rule:
`resolveFixed` puts a 1 AM fixed dose at the *end* of the routine day (next
calendar date), and otherwise never moves it. Both kinds resolve to the same
minute-keyed map, so a fixed 2:00 PM and «قبل الغدا − ٣٠» at 2:00 PM merge
into one `Reminder` like any other pair.

**The Gemini key is compiled into the app again — a deliberate step back
taken on 18 Sep 2026.** C2 had moved it to an Edge Function secret and made
the app call `ai-read` with the user's session (`ca41dd3`); the owner
reverted that the same day and the app talks to
`generativelanguage.googleapis.com` directly once more. So the key ships
inside every APK and IPA and is ten minutes' work to extract.
**Shipping to any store in this state is forbidden**, exactly like
anonymous auth (debt 2) — and for a harder reason: the key is on the
internet the moment the binary is, your quota is spent by strangers, and
you find out from the bill.
Going back is one command: the C2 work is still in the tree and in the
history — `supabase/functions/ai-read/index.ts`, `0013_ai_reads.sql` (still
applied to the live project) and `ai_read_function_test` were kept, so
`git revert` of the revert restores it. `test/app/no_gemini_key_test.dart`
was **inverted rather than deleted**: it now pins the key to one file and
the Google endpoint to one file, and flips back with the same command.

**The key goes in `x-goog-api-key`, never in `Authorization`, never in the
URL.** Google answers `Authorization: Bearer <api key>` with a 401
`ACCESS_TOKEN_TYPE_UNSUPPORTED` — that header is for an OAuth token, not an
API key. This is a **revert hazard**, not a typo: under C2 the request went
to our own function with `Authorization: Bearer <session>` plus `apikey`,
so any half-finished move back to the direct call leaves that shape
pointing at Google. `test/ai/gemini_key_header_test.dart` pins the header
name, asserts no `Authorization` and no `apikey` header, and asserts the
key never appears in the URI — on the prescription reader, the lab reader
(same transport) and the fallback attempt. Mutation-checked both ways.

**The key comes from `--dart-define` only.** `GeminiConfig` reads
`String.fromEnvironment('GEMINI_API_KEY')`; `tryFromEnvironment()` returns
null when missing and the scan screen says so in words, `fromEnvironment()`
throws, and `GeminiPrescriptionReader`'s constructor throws on an empty key —
so no request can ever leave with an empty key. `secrets.json` and `*.env`
are gitignored for `--dart-define-from-file`. Run with
`flutter run --dart-define=GEMINI_API_KEY=…`. Gemini is called over REST
(`responseSchema` JSON) — the `google_generative_ai` package is deprecated,
and a REST call is testable with `MockClient`.

**The model name is Google's to retire, not ours to assume.**
`GeminiConfig.defaultModel` is the single place it lives (currently
`gemini-3.6-flash`; `gemini-2.5-flash` was closed to new users on
2026-09-01 with the only notice being the 404 body: "no longer available to
new users… use models/gemini-3.6-flash"). Override without a code change via
`--dart-define=GEMINI_MODEL=…`. When a scan fails, the logged
`Gemini: HTTP <status>: <body>` line is the source of truth — read it before
touching the request shape; our memory of which model exists is not.

**Pinned, with a loud fallback.** A medication reader must not change its
extraction behaviour silently, so the model stays pinned. But a 404 mid-demo
is worse than a behaviour shift: on `404` + `NOT_FOUND` the reader retries
**once** against `GeminiConfig.defaultFallbackModel` (`gemini-flash-latest`,
override `--dart-define=GEMINI_FALLBACK_MODEL=…`), logs
`Gemini: WARNING pinned model … retired`, and tags the reading with
`modelWarning`, which the review screen shows in debug builds. That warning
is the signal to re-pin deliberately. A `400` never triggers the fallback —
masking a schema rejection is exactly the silent shift being guarded against.

**Image quality beats prompt tuning.** Handwriting dies first under
downscaling. `pickWithSystemCamera` uses `maxWidth/maxHeight 2560,
imageQuality 92`; settle those numbers on a real handwritten prescription,
not on a screen. The system camera is used deliberately (familiar to a
72-year-old, handles focus/exposure/retake); build a custom viewfinder only
if real testing shows framing is what breaks the read.

**Gemini bills an image by its dimensions, so it is shrunk once, in the
transport** (C1). `shrinkForAi` in `lib/core/images/` — pure Dart, no
Flutter import — takes the longest side to `aiMaxSide` (1600) at JPEG
quality 80, **never upscales**, and returns the *same instance* when it
would not help, so an already-small file keeps its own bytes and its own
EXIF tag. It lives in `GeminiPrescriptionReader.generate`, the single
`base64Encode`, which both the prescription and the lab reader go through —
so no call site, present or future, can forget. The mime type on the wire
switches to `image/jpeg` whenever the bytes were re-encoded; sending
`image/png` with JPEG bytes is a 400.
Three things there are load-bearing:
- **EXIF orientation is baked before the resize.** Our output JPEG does not
  carry the tag, so a landscape prescription whose tag says «rotate» would
  arrive on its side and read badly. Tested on **pixels** — a marker in one
  corner must move — not on the tag, because the tag can be right while the
  image is wrong.
- **It never throws.** This is the path between a patient and his medicine:
  corrupt bytes, an unknown format, any exception — the original goes out
  and the read continues. The worst case is a bill, not a missed dose.
- **The size line is printed by `generate`, never by the shrinker.**
  `Gemini: shrinkForAi: 2560×1920 → 1600×1200 — 584KB → 418KB (72%)`,
  once per call, through `debugPrint` like every other Gemini line. The
  first version logged with `developer.log` from inside the `compute`
  isolate, and nothing printed there reaches the `flutter run` terminal —
  the one number this round existed to show was invisible. So the isolate
  returns a `ShrinkReport` (bytes-or-null, a description, both sizes) and
  the main isolate prints it; `shrink_for_ai.dart` prints nothing and
  stays Flutter-free. Anything that runs under `compute` follows the same
  shape: return the facts, log them on the main isolate.
- **The resize runs in `compute()`, and the question "is it even big?" is
  answered on the UI isolate from the real file header.** Decoding a
  2560×1920 photo costs seconds, so `generate` calls
  `compute(shrinkForAiOrNull, image)` — never the main isolate. The gate in
  front of it, `mayNeedShrinkForAi`, walks JPEG markers to SOF (or reads
  PNG's IHDR) and nothing else: **4 µs**. The first version used the
  `image` package's `startDecode` and was documented as "microseconds"
  without being measured — it was **169 ms**, ten dropped frames on every
  scan. Measure before writing a number down. An unknown format answers
  "maybe" and lets the isolate try. The isolate returns **null for
  "unchanged"**, because bytes that cross an isolate are copied and
  `identical` is always false on the far side — without the null, an
  untouched PNG went out labelled `image/jpeg`
  (`test/ai/shrink_on_the_wire_test.dart`, mutation-checked). So the
  «بيقرا الروشتة…» screen never freezes. Measured on this machine (Dart VM,
  synthetic images): 4032×3024 → 1600×1200 is 24 Gemini tiles → 6 in ~11 s
  of CPU; 2560×1920 (what `pickWithSystemCamera` actually hands us) → 12
  tiles → 6 in ~5 s. **The real saving is therefore 2×, not the 4–8× in
  PHASE_C.md** — that document assumed a raw 12MP file and the picker
  already caps at 2560. Dropping that cap to 1600 would make the platform
  do the resize in native code and turn this into a cheap safety net, but
  it is exactly the number the paragraph above says to settle on a real
  handwritten prescription, so it stays until someone does that.

**The uuid is identity for sync; the int id is plumbing for SQLite.**
Every synced-someday table mixes in `SyncIdentity`: `uuid TEXT NOT NULL
UNIQUE`, minted on the device by a `clientDefault` — never by a server, and
never by a call site (anything a call site must remember will be
forgotten). Auto-increment ids are per-device sequences — two phones both
mint 1, 2, 3 — so the uuid is what sync matches on, while all foreign keys
stay on the local int id. Never expose an int id outside the device.
Schema versions now live under `drift_schemas/` (`drift_dev schema dump`
before and after every schema change) and migrations are proven by
`SchemaVerifier` in `test/data/uuid_migration_test.dart` — written red
before the migration existed, because migrations run on a phone holding
real data.

**Schema changes migrate in place — never wipe.** This database holds real
patients' schedules. `onUpgrade` turns foreign keys off outside the
transaction (the PRAGMA is a no-op inside one), runs every step inside one
transaction, and turns them back on; `beforeOpen` re-asserts them.
`test/data/migration_test.dart` opens a hand-written v2 database with anchor
rows and asserts every schedule and event survived — add a case there for
every future version. **Old migration steps use frozen historical SQL, never
today's drift table definitions**: a step that references the current
definition silently changes shape every time the schema grows (the v2→v3
step broke exactly this way when v5 added `uuid`). Each step must produce
its own version's schema, byte for byte, forever.

**Times are built with `DateTime(y, m, d, 0, totalMinutes)`, never
`.add(Duration)`.** Egypt observes daylight saving; the constructor works in
wall-clock terms and the addition does not.

**Notification IDs are derived, and every feature owns a reserved band.**

An ID is computed from the reminder's slot alone — never allocated, never
stored:

```dart
// lib/data/services/reminder_plan.dart
slot = (epochDay % 32) * 1440 + hour * 60 + minute   // 0 … 46,079
id   = <band base> + patientIndex * 46_080 + slot
```

Same patient, same slot → same ID, forever. Rescheduling therefore re-emits
the identical set of IDs, so a duplicate is impossible by construction rather
than prevented by bookkeeping. The engine already merges same-minute doses
into one `Reminder`, which is what makes a slot unique per patient.

**The patient dimension is not optional.** Two people in one household both
taking something at 8:00 AM would otherwise land on the same ID, and one
reminder would silently overwrite the other. `patientIndex` is a small stable
slot (`patients.notification_slot`), **not** the row id — `id` only counts
upward and would leave the band after 128 rows. Freed slots are reused. An
index at or beyond `maxPatients` throws rather than wrapping, because wrapping
is exactly the collision being prevented.

**IDs repeat every 32 days per patient, and that is deliberate.** We never
schedule more than `reminderWindowDays` (7) ahead, so a repeated ID is never
pending twice; `planWindow` asserts the window stays under the cycle. The
4096-day cycle this replaced was 11 years of space for something that lives
for days — that waste is now the patient dimension.

| Band | Range | Owner |
|---|---|---|
| Dose reminders | `1_000_000` – `6_898_239` | **Phase 1**, live. `doseIdBase` / `doseIdLimit` / `isDoseId()` in `reminder_plan.dart`. 128 patients × 46,080 |
| Escalation rung 1 (+15) | `10_000_000` – `15_898_239` | **Phase 4.1**, live. `escalationFirstIdBase` / `escalationIdFor(at, rung)` / `isEscalationId()`. Derived from the **original** dose slot like snooze |
| Snooze | `20_000_000` – `25_898_239` | live. `snoozeIdBase` / `snoozeIdFor()` / `isSnoozeId()`. Derived from the **original** dose slot, not the snooze time — so a snooze can never overwrite a real dose that happens to fall on the same minute, and «أخدته» cancels it without storing anything |
| Escalation rung 2 (+30) | `30_000_000` – `35_898_239` | **Phase 4.1**, live. `escalationSecondIdBase`. One band per rung because a band holds exactly one ID per (patient, slot) — a second rung needs a second band |
| Fasting reminder | `40_000_000` – `45_898_239` | **D3.7**, live. `fastingIdBase` / `fastingIdFor(recordId)` / `isFastingId()`. Derived from the `records` row id (not a slot — one reminder per checkup cycle), throws past the band. **Not** in `isRescheduledId`: rebuilding doses never cancels it, and a dose confirmation never touches it. `test/data/checkup_fasting_test.dart` proves it overlaps no dose band — mutation-checked: moving the base into the dose band fails three tests |
| Lab follow-up dates | `50_000_000` – `55_898_239` | **round 20**; **now legacy — nothing schedules into it.** `checkupIdBase` / `checkupIdFor(recordId, stageSlot)` / `isCheckupId()`. Every `AppointmentScheduler.refresh` cancels **every pending id in this band** — that is the upgrade fix for phones whose dates were set before the appointments round |
| Appointment notices | `60_000_000` – `65_898_239` | **مواصفة المواعيد**, live. `appointmentIdBase` / `appointmentIdFor(day, notice)` / `isAppointmentId()`. **`base + epochDay * 2 + notice`** — إشعارين لكل **يوم** فيه مواعيد (هادي امبارحه، وواحد بيرن في يومه)، مش لكل ميعاد. `epochDayOf` بيتحسب بالـUTC. **Not** in `isRescheduledId` |
| Caregiver appointments | `70_000_000` – `75_898_239` | **مواصفة المواعيد**, live. `caregiverAppointmentIdBase` / `caregiverAppointmentIdFor(day, notice)` — **نفس اشتقاق الأب من نطاق تاني**؛ `caregiverAppointmentCap` (٤) بقى عدّ **أيام** مش عدّ مواعيد |
| Repeat alerts | `80_000_000` – `175_898_239` (ten bands, 80M … 170M) | **«التذكير مش بيرن»** + alert modes, live. `repeatIdBase` / `repeatIdFor(at, index)` / `isRepeatId()` / `repeatIndexOf()`. One band per repeat index — «مستمر» reaches ten — for the same reason the ladder has one per rung; derived from the **original** dose slot; in `isRescheduledId` like the ladder, so a dose confirmed anywhere drops its pending repeats on the next rebuild; `cancelReminderAt` cancels all ten whatever the mode was |
| Nurse reminders | `180_000_000` – `185_898_239` | **حساب الممرض** (24 Sep 2026). `nurseIdBase` / `nurseIdFor(at, patientIndex)` / `isNurseId()`. On the **nurse's** phone only, about a patient's doses, derived from the slot like a dose with `patientIndex` = the patient's position among the nurse's patients sorted by uuid. **Not** in `isRescheduledId`: the patient's reschedule never touches it and the nurse scheduler cancels only inside it — `nurse_reminders_test`, mutation-checked. Capped at `maxPendingNurseReminders` (40) |
| Refill alerts | `190_000_000` – `195_898_239` | **المخزون** (25 Sep 2026). `refillIdBase` / `refillIdFor(medicationId)` / `isRefillId()`. One id per medication, **shown** with `NotificationService.showRefill` (channel `fakkarni_refill`, system sound, no buttons) on a wake-up — never scheduled, so it takes **no** iOS pending slot and costs the dose window nothing. **Not** in `isRescheduledId` |
| — | everything else | unclaimed; take the next free band at a `10_000_000` boundary (`200_000_000` is next) and add an `isXxxId()` guard beside `isDoseId()` |

Band width is unchanged at 5,898,240 — `128 × 46,080` is exactly the old
`4096 × 1440`. The gap between bands is deliberate slack, and every band stays
far below the 32-bit ceiling Android imposes on notification IDs
(`2_147_483_647`).

**iOS keeps only 64 pending local notifications per app and silently drops
the rest** — no error, no warning. So the window is capped, not fixed:
`maxPendingReminders` is 24 (48 until D3.7, 46 until the follow-up dates,
44 until the repeat alerts, 32 until the «مستمر» mode); the remaining 40
are `maxPendingEscalations` (14 = the nearest 7 reminders × 2 rungs),
`maxPendingRepeats` (20 — one budget for every mode: «مستمر» covers the
nearest two reminders with ten each, «يتكرر» the nearest six with three),
`snoozePendingSlack` (2),
`fastingPendingSlack` (2 — at most two fasting reminders exist at once, and
the button says so) and `checkupPendingSlack` (2, same reasoning), so dose +
ladder + repeats + a snooze + fasting + follow-up dates never reach 65.
**When the budget is short, main alerts outrank repeats** (schedule
patterns round 1, 25 Sep 2026). `splitPendingBudget` in `reminder_plan.dart`:
while the 7-day window holds ≤ 24 main alerts the plan is byte-identical to
before (24 + 20 repeats — `pending_budget_test` replays the old algorithm and
compares); above that, the repeats of the **next 2 dose times** are kept first
(`protectedRepeatCount` — a grouped notification is one dose time, and a dose
still inside its 45-minute grace counts), then main alerts nearest-first up to
`mainAndRepeatBudget` (44 = 64 − 14 ladder − 6 slack), then any repeats left.
The ladder's 14 never move. Measured from 06:00: 3 medicines every 4 h
(unaligned) 32 h → 54 h of coverage; 2 every 2 h + 3 daily 23 h → 38 h. `lastPlanTruncated` /
`lastCoverage` on the scheduler feed health code `lowCoverage` (broken, admin
only, when the plan was cut **and** `horizon_until` is < 48 h away); the
coverage itself is the existing `device_health.horizon_until`, so no
migration.
**Every new band pays for itself out of the dose window, never out of the
ladder.** `planWindow` sorts and keeps the **nearest** 24, so the horizon
shortens by itself as medications accumulate — a patient on one drug gets the
full 7 days, one on six drugs three times daily gets about two and a half.
Every app launch calls `rescheduleAll()`, which re-extends the window from the
new "now". The cap applies on Android too: one behaviour on both platforms
beats "works on my Android".

**Two isolates write this SQLite file, so the connection sets WAL and a
busy timeout — in one place, for every opener.** The app runs
`rescheduleAll` as it starts; a lock-screen «أخدته» wakes a separate
isolate that opens the *same file* and writes. That is the normal case,
not a rare one — the same tap can do both. With SQLite's defaults the
loser of the race fails instantly with
`SqliteException(5): database is locked` on `BEGIN IMMEDIATE`. WAL stops a
reader blocking a writer; **`busy_timeout` is the line that actually fixes
it**, because WAL does nothing for two *writers* — the default is to give
up at once rather than wait. `busy_timeout` is per-connection and is not
stored in the file, so it must be set by every isolate: that is why it
lives in `prepareDatabase` inside `connection.dart`, which everything goes
through. `openDatabaseFile` is exposed so tests open the file exactly the
way the device does. `test/data/db/concurrent_write_test.dart` reproduces
the original exception when the pragmas are removed.

**In the lock-screen handler, the promise is the dose row and the cancel;
everything after is a courtesy.** Recording the confirmation now uses
`DoseEventRepository.confirmDose` — one row seeded if missing and its state
written, a two-statement transaction — and it runs *first*. It used to be
`materializeDay` (the whole day, one large transaction) and only then
`markTaken`, so a lock conflict on a write that is **not** the promise
destroyed the confirmation itself. `rescheduleAll` still runs from the
isolate, because nothing else renews coverage for a patient who never opens
the app — but it is demoted to a courtesy: wrapped, logged loudly, and
never able to undo a confirmation already written. The cloud push was
already last and stays there.

**A confirmation that fails must never look like one that succeeded.** iOS
removes the notification the moment the button is tapped, whether our write
worked or not — so a swallowed error leaves the patient certain he
confirmed while nothing was recorded. The handler therefore **throws** when
the promise fails and only swallows courtesies.
`test/data/notification_actions_test.dart` pins both directions, and the
throwing case was mutation-checked: wrap the promise in a `try`/`catch` and
it goes red.

**iOS runs notification actions in a SECOND Flutter engine, and that
engine gets no plugins unless `AppDelegate` says so.** A tap on «أخدته»
with the app terminated does not reuse the main engine — the plugin spawns
a separate one (`FlutterEngineManager.m`: `NSAssert(registerPlugins != nil)`
then `registerPlugins(backgroundEngine)`). Without
`FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` in
`didInitializeImplicitFlutterEngine`, that engine has zero plugin
registrations, so `onBackgroundNotificationAction` dies **before its first
line**: no drift, no path_provider, not even a `debugPrint`. The symptom
is exactly nothing from Dart while Console.app shows SpringBoard handling
the action normally — which reads like a Dart bug and is not one.
Registering the main engine (`GeneratedPluginRegistrant.register(with:
engineBridge.pluginRegistry)`) is a **separate** line and both are needed;
this app is on the UIScene lifecycle, so both live in
`didInitializeImplicitFlutterEngine`, not `didFinishLaunchingWithOptions`.
Android needs no equivalent. The two diagnostic `debugPrint`s that found
this — at the isolate entry point and in `_onTap` — are kept on purpose:
they are the only visibility into a path no test can reach.

**السبب الجذري، بدليل من الجهاز (٢٠ سبتمبر ٢٠٢٦): على iOS مفيش callback
بتتنده أصلاً — الرد بيستنى في `getNotificationAppLaunchDetails()`، و
`init()` كانت بتاخد منه الـ`payload` وترمي الـ`actionId`.** يعني زرار
«أخدته» كان بيتحوّل لدوسة عادية في صمت: التطبيق بيفتح على الجرعة والصف
عمره ما اتكتب. من `fkdiag.log` لحظة الدوسة (نسخة profile، آيفون، التطبيق
مقفول):

```
20:30:05.961  didFinishLaunching — launchOptions=nil state=background
20:30:06.042  didInitializeImplicitFlutterEngine
20:30:06.096  didReceive — action=taken category=fakkarni_dose
```

مفيش سطر `registerPlugins`، مفيش `Isolate:`، مفيش `_onTap`. النظام شغّل
العملية وسلّم الرد، والإضافة ما ندهتش حاجة. وكمان `didFinishLaunching`
تانية بعدها بـ٧ ثواني — العملية اللي النظام شغّلها ما عاشتش.

الإصلاح كله في الطريق العادي، مش في الـisolate:
- **`NotificationService.init()` بترجّع رد الإطلاق كامل** لما يكون زرار،
  و`applyLaunchResponse` هي المكان الوحيد اللي بيتاخد فيه القرار: زرار
  بيترجّع للمعالجة، ودوسة عادية بتنزل `lastPayload` زي ما كانت.
  **زرار عمره ما ينزل في `lastPayload`** — ده كان العيب نفسه.
- **`main` بتعالجه قبل أي حاجة بتستنى الشبكة.** الخدمات بتتبني محلية
  بالكامل، الجرعة بتتكتب والسلّم بيتلغي، وبعدين بس بتيجي
  `initSupabaseAuth()` و`FirebaseTokenSource.initialise()` — الاتنين
  awaited وكانوا قبلها، على إطلاق خلفية عمره ثواني. الخدمات بتتبني تاني
  ومعاها السحابة، والمزامنة بتاخد دفعة فورية عشان الصف المتوسّخ يلحق
  السيرفر قبل مهلته. اختبار بيقارن مواضع السطور في `main.dart` نفسها.
- **مرة واحدة بس لكل (جرعة، زرار).** `claimResponse` بتمسك المفتاح
  `actionId|id|payload`، والبابين بيعدّوا عليها — رد الإطلاق و`_onTap` —
  فلو النظام بعت الاتنين، الجرعة بتتعالج مرة.
- **والـisolate بيفضل مكانه**: اللوج ده عن iOS بس؛ على أندرويد الصحوة دي
  هي الطريق الحقيقي. الدليل متسجّل في `bootstrap.dart` بتاريخه.

**«أخدته» من شاشة القفل — الطابور الأصلي في سويفت (٢٦ سبتمبر ٢٠٢٦، آيفون
حقيقي، نسخة profile).** من `fkdiag.log` وقاعدة الجهاز: خمس دوسات في يوم،
**أربعة ضاعوا**. النمط: لما النظام يشغّل التطبيق عشان الدوسة (`didFinishLaunching
23:36:05.9` ← `didReceive 23:36:06.1` ← ولا سطر ← `didFinishLaunching 23:36:14.2`)
الإضافة بترجّع `completionHandler` فوراً والعملية بتتقتل بعد ~٨ ثواني قبل ما
المحرّك الخلفي يسجّل إضافاته؛ ولما تفشل مرة، `startEngineIfNeeded` بترجع من أول
سطر لباقي عمر العملية (`if (backgroundEngine) return`) فكل دوسة بعدها تتبلع
(١٩:٣٦، ١٩:٣٩، ١٩:٤٥)؛ والإضافة **ما بتحفظش** رد الإطلاق لزرار مش `foreground`،
فسكّة `main` («الوعد الأول» تحت) ما بتشوفه أبداً — كانت بتنفع للدوسة العادية بس.
الإصلاح: `PendingActionQueue` في `AppDelegate.swift` بيكتب كل دوسة ملف
`Documents/pending_actions/<uuid>.json` **قبل** ما يسلّم الرد للإضافة، وبياخد
`beginBackgroundTask` ٢٥ ثانية؛ ودارت بتطبّق الطابور (`drainPendingActions`،
`data/services/pending_actions.dart`، نفس باب `handleNotificationAction`) عند
الفتح في `main` قبل السحابة، وعند الرجوع للمقدمة قبل إعادة الجدولة، وفي
الـisolate لو اشتغل (وبيشيل ملفه). التأجيل الأقدم من ٤٥ دقيقة بيتشال من غير
تطبيق؛ التأكيد بيتطبّق مهما كان عمره. **ولا سطر دارت وصل `fkdiag.log` على
الجهاز ولا مرة** (الـisolate كتب صف ١٩:٤٩:٣٠ ومفيش `Isolate:` قبله) — فسويفت
بقت بتحط مجلد المستندات في البيئة (`FAKKARNI_DOCS`) و`diag` والطابور بيقروه
من غير قناة. `pending_actions_test` بيثبت الباب الحقيقي (الصف taken والخانة
كلها اتلغت) والمرايا والترتيب.

**صحوة شاشة القفل على iOS: مقروءة من مصدر الإضافة، ومش متشافة على جهاز
ولا مرة.** A confirmation from a locked iPhone was reported on
20 Sep 2026 to leave the +15/+30 rungs ringing — which would mean the
**local** write and the cancels did not happen either, not just the push.

**That observation is not evidence, and it took a day to notice why: it
was made in a debug build.** From iOS 14 the system refuses to launch a
debug (JIT) Flutter app outside the tooling, so the moment `flutter run`
detaches there is no process to wake — the background isolate *cannot*
run, by construction, whatever the code says. A rung ringing afterwards
is the expected outcome of that, not a defect in the handler.
**This path can only be tested in a profile build**, which is AOT and
launches on its own. Never read a lock-screen result from a debug build
again; the answer it gives is about the build mode, not about the app.
(Both fixes below still stand on their own — the plugin's own source is
what they were derived from, and that reading is independent of any
build. What is open is whether they were ever needed.)

What the installed sources (`flutter_local_notifications` 22.3.0)
actually say about that path, so nobody has to guess again:
- An action **without** `.foreground` (ours) is routed by
  `FlutterLocalNotificationsPlugin.m` to a second headless
  `FlutterEngine`, via `FOREGROUND_ACTION_IDENTIFIERS` in
  `NSUserDefaults` — so the routing is right and the category is right.
- **The plugin calls `completionHandler()` immediately**, before any Dart
  runs, and takes **no `beginBackgroundTask` assertion anywhere**. That
  completion handler is the only thing telling iOS we are still working.
  Once it returns, the process may be suspended at any moment; nothing in
  the plugin, and nothing in our code, holds the app awake while the
  isolate writes.
- The engine starts inside `dispatch_async(main queue)` — one runloop turn
  *after* that — then runs the plugin's `callbackDispatcher`, which makes a
  `getCallbackHandle` method-channel round trip and only then attaches the
  event stream that replays our tap. Three hops before our first line.
- So the budget is small, unbounded from our side, and **everything we do
  before the promise is spent out of it**.
**Both halves are fixed; neither is verified on a phone yet.**
- **`BackgroundTask.begin()` is the first line of the wake-up**, and
  `end()` is in the `finally`. It is a `MethodChannel('fakkarni/background_task')`
  onto `UIApplication.beginBackgroundTask`
  (`ios/Runner/BackgroundTaskChannel.swift`), registered on **both**
  engines from `AppDelegate` — the background one inside
  `setPluginRegistrantCallback`, beside `GeneratedPluginRegistrant`.
  **The `end` is not optional: iOS kills an app that holds an expired
  assertion**, so the Swift side also ends it from its own
  `expirationHandler` and the Dart side keeps it in a `finally`. Android
  has no equivalent (its wake-up is a `BroadcastReceiver` holding a wake
  lock) and `flutter test` has no channel: both get `null` back and `end`
  is a no-op. Every call is bounded by 500 ms — a hang in the call that
  buys time would spend the time it was buying.
- **And the order was wrong for exactly the same reason.**
  `NotificationService.init()` (timezone channel + plugin initialize) and
  `initSupabaseForIsolate()` (up to `isolateCloudInitTimeout`, 2 s) both
  ran **before** `confirmDose` and `cancelReminderAt`. Rule 5 says a
  confirmation cancels every unfired rung *immediately*; a cloud init in
  front of the local write is that rule broken in the ordering, not in the
  wording. The order is now: assertion → database → **the dose row** →
  notifications init → the cancels → `rescheduleAll` → cloud init → push.
**The ordering lives in the handler, not in `bootstrap`, so a test can
hold it.** `NotificationActionHandler` no longer takes a built
`SyncService`; it takes `cloud`, a **function** it calls in its last
statement, plus `prepareNotifications`, which it calls after the dose row
and before the first cancel. `test/data/notification_actions_test.dart`
asserts `confirmDose` is the first thing that happens and that the cloud
factory runs after the last cancel — mutation-checked both ways (moving
the channel init in front of the write fails one test; calling `cloud` at
the top of `handle` fails four).
**Never put anything between the tap and the dose row that is not needed
to write it.** The cloud, the timezone database and the notification
plugin are all needed *after* — the cancels, `rescheduleAll` and
`pushOnce` — never before.

**A diagnostic that only prints is gated `!kReleaseMode`; one that shows
on screen is gated `kDebugMode`.** Two facts forced the split, and both
are easy to get backwards:
- **`debugPrint` has no gate at all.** Its own documentation says it
  "logs to console even in release mode", so every `Handle:` / `Isolate:`
  / `Sync:` line was shipping inside each IPA and APK — table names, dose
  states, raw error text. `diag()` in `lib/core/diagnostics.dart` is the
  one place that gate lives now.
- **`kDebugMode` silences exactly the build that can answer this
  question.** A profile build is the only one that can run the
  lock-screen isolate on iOS at all (see above), so a diagnostic hidden
  behind `kDebugMode` goes quiet precisely when it is needed.
On-screen debug affordances keep `kDebugMode` on purpose — a raw
`Gemini:` cause panel or a `modelWarning` line in front of a patient in a
profile build is a different thing from a line in Console.app. Those are
`scan_lab_screen`, `scan_prescription_screen` and
`review_prescription_screen`.
**Still on `kDebugMode` and print-only, so they go quiet in profile:**
`SupabaseCaregiverRemote._guard` and `CaregiverSnapshotHolder` (the
`Care:` lines — the ones that named the `0014` gap in one line) and
`GeminiLabReader`'s per-line range log. Left as they are deliberately:
they are not on the wake-up path, and flipping them is one line each when
a round needs them. `test/app/diagnostics_gated_test.dart` fails on a
bare `debugPrint` anywhere on the wake-up path and on `diag` being gated
the wrong way — mutation-checked.

**والأثر التشخيصي بيعيش من غير مصحّح — `FKDIAG`.** The question this
round could not answer is "how far does the tap actually get?", and every
stage of it is in a different language, in a process nobody is attached
to. So there is now one trail with **one filter and one file**:
- **Native** (`FKDiag` in `AppDelegate.swift`): `os_log` at
  `didFinishLaunching` (with `launchOptions` nil-or-keys and
  `applicationState` — a background launch reads `background`),
  `didInitializeImplicitFlutterEngine`, inside the
  `setPluginRegistrantCallback` closure **when it actually runs** (that
  line firing is the proof the second engine came up), and an override of
  `userNotificationCenter(_:didReceive:)` that logs the action and
  category identifiers **and then calls `super`** — it observes, it never
  handles.
- **Dart**: `diag()` writes the same prefix and appends to the same file.
- **The same file**: `Documents/fkdiag.log`, which is exactly what
  `getApplicationDocumentsDirectory()` returns on iOS. Dart reaches it
  through `$HOME/Documents` with **no plugin call**, because `diag` is
  called from the wake-up isolate and that is not the moment for a channel
  that can hang; `path_provider` is only a fallback, from the UI.
  **Resolution is gated on `Platform.isIOS`** — on this Mac
  `$HOME/Documents` exists, so without the gate every `flutter test` run
  would write into the developer's own Documents folder.
- **Read it in the app**: «الإعدادات» → «للمطوّر» → «سجل التشخيص»,
  newest first, with «حدّث» / «انسخ» / «امسح». The row is behind
  `!kReleaseMode`, so it does not exist in a store build.
`diagPrefix`, `diagFileName` and `diagMaxLines` are mirrored by hand in
Swift; a test pins the three values, because a prefix that drifts splits
the trail in two and the filter shows half of it.

**The window must renew without the app ever being opened.** The patient
has no reason to open it — the app exists to remind *him*. At 48 pending and
12 doses a day that is four days of coverage; on day five reminders would
silently stop for exactly the person who needs them most. So every
confirmation re-extends the window (`ReminderScheduler.afterConfirmation`:
cancel the slot first — rule 5 — then `rescheduleAll()`), and the
notification itself carries «أخدته» / «فكّرني بعدين» buttons. Those actions
show no UI: the OS wakes the app in a background isolate and
`onBackgroundNotificationAction` (`lib/app/bootstrap.dart`,
`@pragma('vm:entry-point')`) opens the database, records the dose and
re-emits the window. `NotificationActionHandler` is the testable core;
`test/data/notification_actions_test.dart` drives a week of lock-screen
confirmations with no widget pumped and asserts coverage keeps moving.

**A dose that falls before its rule existed was never a dose.**
`dose_schedules.active_from` is the instant a rule took effect — written by
`MedicationRepository` (injectable `clock`) when the rule is created **and**
when `updateTiming` changes it; null on rows from before v15 (active since
forever — no invented time). It is **not** a dose time (the ban on a time
column on `dose_schedules` is about resolved dose times; the column test
allows this one name) and it is **not** `updatedAtMs`, which belongs to sync.
`materializeDay` — the one place every caller goes through — makes no row
for a dose whose instant is before `active_from`, and `rescheduleAll` adds
those doses to `done` so no escalation rung rings for them. A medicine added
at 11:17 therefore shows no «نسيتها؟» for its 7:00 dose, and tomorrow's 7:00
is materialised as usual. **A timing edited to an earlier time never deletes
the existing `pending` row**: that row may already be in the cloud, sync has
no deletes (debt 1), and a ghost `pending` there would alert the son. The
device writes `DoseState.superseded` («القاعدة اتغيّرت») instead; it is
pushed like any state, `due_escalations` ignores it (only `pending` is
chosen), `watchDay`/`watchBetween` and the caregiver query hide it, and an
edit back to a time still ahead revives it to `pending`. Cloud:
`0010_dose_superseded.sql` widens the state check — **it must run before a
v15 build reaches a linked phone**, or the old check rejects the row and the
whole `dose_events` batch fails silently. Tests: `test/data/active_from_test.dart`
(new medicine, new dose on an old medicine, earlier edit, the ladder, the
reverse case, pre-v15 null) — mutation-checked three ways. Test fixtures
seed medicines with `seededLongAgo` (`test/support/seeded_clock.dart`);
tests about `active_from` inject their own clock.

**A dose confirmed early must not be re-scheduled.** 2:00 PM taken at 1:50 is
still "in the future" by the clock. `planWindow` takes the set of done
`(scheduleId, routineDay)` keys (`doneKey`, read from `dose_events`) and drops
them; a grouped reminder keeps its remaining doses. The handler also
materialises the day's events before marking, because «يومك» — which
normally does that — may not have run that day.

**Rescheduling only ever cancels inside its own bands.** `ReminderScheduler`
diffs the planned IDs against `pending()` and cancels the stale ones filtered
through `isRescheduledId` (dose + escalation; snooze is deliberately outside —
it is cancelled by a confirmation, never by a rebuild). `cancelReminderAt(at)`
is the one exception by design: it cancels the dose ID, the snooze ID *and*
both escalation rung IDs of that single slot, because a
confirmation must silence everything that slot could still ring. A missed
critical dose escalates to the caregiver, and `cancelAll()` would silently take
that escalation down while merely rebuilding a routine — so it is never used. Any new feature that schedules notifications
must claim a band and filter cancellations by it the same way.

---

## Phase 3 — identity (optional, NEVER a gate)

The app is complete with no account: onboarding → scan → reminders all work
offline forever. Identity exists only because escalation needs the son's
phone. It has two doors, both behind a tap: «اربط ابني» on the patient's
«العائلة» tab, and «ابني أو والدي بعتلي كود» on the D4 entry screen — which
is a **question, not a sign-in** (no session, no call until that card is
tapped, and then only through SignInScreen's button). If a sign-in screen
ever appears at startup, that is a bug by definition —
`test/app/root_test.dart` has loudly-named guard tests for it.

- **An SDK import lives in a `supabase_*` / `firebase_*` file behind an
  interface, and nowhere else.** `lib/data/auth/` was once the only place
  allowed to import `supabase_flutter`; that stopped being true in 3.3 and
  this line stayed wrong until round 4.2b part 2. What actually holds is
  the shape: the app sees `AuthService`, `SyncRemote`, `CaregiverRemote`,
  `CareCircleService`, `PushTokenRemote`, `DeviceTokenSource`, and the SDK
  sits in one named file implementing it. `firebase_messaging` appears in
  exactly one file (`lib/data/push/firebase_token_source.dart`), and
  `main.dart` imports neither SDK. Everything else sees the `AuthService` interface
  (`authState`, `currentUser`, `signInToLink`, `signOut`) and
  `FakkarniUser` (with `isAnonymous` from the JWT `is_anonymous` claim —
  unused yet, upgrade rounds will need it). The live implementation is
  `AnonymousAuthService` (see «دين تقني»); `GoogleAuthService` is already
  written as a dormant sibling, and **Apple arrives the same way** — a new
  file on the same interface, never a refactor. Email OTP was removed from
  the product entirely; do not rebuild it.
- `signInToLink()` (currently `signInAnonymously`) is called from exactly
  one line: the SignInScreen button handler. Never from `main()`, startup,
  a splash, or an eager provider — a fresh install reaches «يومك» with NO
  Supabase session. The guard test in `root_test.dart` runs with auth
  *configured* and asserts zero sign-in calls and no session at launch, so
  it cannot become trivially true.
- Config via `--dart-define` only, like `GEMINI_API_KEY`: `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `GOOGLE_SERVER_CLIENT_ID` (the Web client ID —
  Supabase's audience), `GOOGLE_IOS_CLIENT_ID`. Missing → app runs fully,
  the sign-in screen names what's missing. `initSupabaseAuth()` never
  throws and never blocks startup; failures log and return null.
- Errors reach the screen only as the four agreed Arabic states; user
  cancellation is silent; an expired refresh token lands on signed-out
  silently. Raw SDK strings never render.
- `google_sign_in` is v7: `initialize()` once then `authenticate()`, which
  throws `GoogleSignInException` with a code (`canceled` → silent). The API
  was read from the installed source — keep doing that here.
- Sign-out is local-scope on purpose (must work offline); server-side
  revocation comes with the sessions round.
- Out of scope so far: tables, RLS, sync, invite codes, care
  relationships, anonymous auth.

**The one gate through the wall is `redeem_invite`** (round 3.3).
`care_relationships` and `invite_codes` have NO insert/update policies —
that absence is the security model: any INSERT policy would let a key
holder who learned one patient_uuid grant himself an 'accepted' link.
Creation and redemption happen only inside two SECURITY DEFINER functions
(`create_invite` / `redeem_invite`, `search_path=''`, authenticated-only) —
the redeemer under RLS can neither read the code row, insert the link, nor
burn the code, and the function does all three atomically. Error tokens
(`invalid_code` / `own_code` / `already_linked`) are mapped to Arabic in
`lib/data/care/` — server text never renders. Roles emerge from data: a
redeemer is a caregiver for that patient, a device with a local patient row
is a patient; there is no role column. The only sync write so far is the
patient row upsert (uuid, owner_id, name) right before showing a code.
Known accepted risk: a 6-digit code space is brute-forceable in principle;
mitigations today are the 15-minute expiry and one live code per patient —
rate limiting is future work.

**The background isolate pushes too, and cloud always comes last**
(round 4.2a). A lock-screen «أخدته» is the most common confirmation path
for a 72-year-old, and since 4.1 the same wake-up also materialises days
and writes «اتنست». None of it reached the cloud until the next
foreground, which the patient has no reason to trigger — so 4.2b's
server-side scan would alert the son about a dose already taken.
`NotificationActionHandler` now ends with `sync?.pushOnce()`, **after**
the local write and after `rescheduleAll` has cancelled the slot's
notifications. That order is rule 5: a network call placed before the
cancels would leave the +30 rung armed on a bad connection and nag a man
who already took his pill. The local write and the cancels are the
promise; the push is a courtesy that is allowed to fail. `pushOnce` is
one attempt with a `backgroundPushTimeout` (5s) and never throws — a
timeout frees us, not the request, which is enough because everything
that matters already happened. Unpushed rows stay dirty by construction
(`synced_at_ms` is marked only after a successful upsert).

**Supabase can be initialised inside the background isolate** — verified
against the installed sources, not assumed (`supabase_flutter` 2.17.2,
`gotrue` 2.27.2). `Supabase.initialize` awaits `SupabaseAuth.initialize`,
which reads SharedPreferences and calls `setInitialSession`, so
`currentUser` is ready after the await with no network; the unawaited
`recoverSession()` is only a proactive refresh. Every PostgREST call takes
its token from `getSession()`, which refreshes an expired one first and
throws rather than sending it. Two settings are load-bearing in
`initSupabaseForIsolate`: `detectSessionInUri: false` (no app_links
observer in a background wake-up), and `autoRefreshToken` left at its
default `true`, stopped by hand on shutdown. **Passing `false` is the
trap**: with auto-refresh off, an expired session sends `recoverSession`
into a local `_signOut`, so the isolate would sign the patient out of the
whole app while recording a dose. The shutdown is skipped when
`_initialisedByApp` is set, so if the background path ever runs inside the
app's own isolate it cannot stop a live client's token refresh. The init
keeps `isolateCloudInitTimeout` (2s), but its reason changed: **it no
longer runs before the local write.** It used to, and the timeout was the
mitigation; the whole cloud step is now a function the handler calls in
its last statement, after the dose row and after the cancels (see «صحوة
شاشة القفل على iOS»). The timeout stays because the wake-up is short and
a hung channel would still spend what is left of it — but nothing the
patient was promised sits behind it any more.

**The push token is cleared BEFORE sign-out, never after.** Deleting the
`device_tokens` row needs the session that owns it; call `signOut()` first
and the row survives in the cloud, so a phone that has left the account
keeps receiving alerts about a patient who is now a stranger to it.
`PushTokens` is injected into `SignInScreen` like `AuthService` —
deliberately *not* pulled from `AppScope` — because sign-out must work
whether or not a scope sits above it. Registration is the mirror image: on
every sign-in through the auth stream, *and* eagerly right after linking,
because the son may close the app at once and his father's first missed
dose can be an hour later. Failures are silent and logged like sync; the
retry is the next sign-in, token rotation or launch. The one thing never
done is deleting the Firebase token itself — it belongs to the install,
not the account, and reattaching it to a new owner is what
`claim_device_token` is for.

**Sync is one-way, silent, and derived.** Local drift is the source of
truth; the cloud is a copy; only the owner's device writes; nothing pulls
into drift (3.5 reads Supabase directly) — so there is no merge code, on
purpose. Dirtiness is derived (`synced_at_ms IS NULL OR < updated_at_ms`,
epoch **milliseconds** so a same-second edit during a push stays dirty),
and `updated_at_ms` is maintained by SQLite triggers created idempotently
in `beforeOpen` (self-healing after any table rebuild) — never by call
sites. The trigger fires only `WHEN NEW.synced_at_ms IS OLD.synced_at_ms`
so the push's own marking never re-dirties rows. `SyncService.push()` is
parent-first, marks `synced_at_ms` with the pushed `updated_at_ms` (never
now()), and is a silent no-op unless signed in AND linked
(`confirmLinked()` fires once from the link screen). Triggers: foreground,
3s-debounced local writes via `db.tableUpdates()`, connectivity restored.
Never a timer, never an error surfaced to the user. Wire times are UTC ISO.
**Migration steps normalize tables (alterTable) only in the LAST step of
the chain** — an intermediate normalization builds tomorrow's shape from
yesterday's columns and breaks old upgrade paths (bitten **three** times
now). In code that means: the `if (from < 6)` normalization block sits at
the very **end** of `onUpgrade`, after every later step's columns exist.
v8 found it the hard way — the block used to live inside the v6 step,
rebuilt `patients` on a definition that already had `sex`, and failed
every upgrade from v5 or older until it moved. **Any new column goes in
its own `from < N` step ABOVE that block, added with an existence check.**

## Phase 4 — the escalation ladder

**Every dose escalates; there is no "critical" flag** (decided 2026-09-02).
Choosing which drug is critical is a clinical judgment rule 6 forbids, and
mockup 26 already says the miss alert «لا يمكن إيقافه». Where this file
says "critical dose" read "any dose". If a per-medication toggle is ever
wanted it is worded operationally («لو نسيها، نبّه ابنك»), default on, and
it only *filters* `planEscalations` — the ladder itself does not change.

**The ladder is pure and pre-scheduled** (`lib/domain/escalation/`). Rungs
are +15 (`EscalationRung.first`) and +30 (`second`) from the *original* dose
minute, never from the previous rung; `graceWindow` is 45. Every rung is a
local notification scheduled ahead of time, because neither OS runs our
code when a notification merely fires — only when the user touches it. A
rung carries the dose's own payload and the same «أخدته»/«فكّرني بعدين»
buttons, so acting on a rung is acting on the dose. Android rungs go out on
the `fakkarni_escalation` channel (vibration pattern, own volume slider);
iOS stays `timeSensitive` until the Critical Alerts entitlement exists.

**The ladder window is built from now − 45, not from now.** A dose that
rang at 8:00 is gone from `planWindow(from: 8:10)`; if the ladder were
derived from that plan, opening the app at 8:10 would cancel the 8:15 and
8:30 rungs as "stale" — the app would silence the ladder of exactly the
dose in progress. So `rescheduleAll` plans escalations from a second
`planWindow` whose `from` is shifted back by `graceWindow`, then drops
rungs already in the past. Only the nearest 7 reminders get a ladder; the
window renews on every confirmation and launch like the dose window.

**The reminder rings for 24 seconds and comes back every five minutes
until someone acts** (24 Sep 2026 — the tester's «مش بيرن»). On iOS the
default sound is one short ding and nothing repeats; a 72-year-old across
the room never hears it. Two things fixed that, neither of them touching
the ladder:
- **One chime, two files, our own.** `tool/make_dose_chime.py` generates a
  three-note bell (G5–B5–D6, all fundamentals under 1.2 kHz because
  age-related hearing loss takes the high end first) repeating for
  **24 s** at −1 dBFS; `afconvert` turns it into `ios/Runner/dose_chime.caf`
  (IMA4, in Copy Bundle Resources) and `android/app/src/main/res/raw/
  dose_chime.m4a`. No third-party sample, no licence to track. **iOS
  silently falls back to the default sound for any file over 30 s** — so
  `test/app/dose_alert_test.dart` parses the CAF header and fails above
  30. It is `sound:` on every `scheduleDose` (dose, repeat, snooze and
  both rungs — the rungs are dose notifications with dose buttons, and a
  louder rung with a quieter sound would be a contradiction) and on
  nothing else: appointments, fasting and the health alert keep the
  system sound, pinned by the same test. **Android channel sound is fixed
  at creation**, so the dose and escalation channels were re-created under
  new ids (`fakkarni_doses_chime`, `fakkarni_escalation_chime`) and the
  old ids are deleted on every `init` (`retiredChannelIds`). Dose
  notifications also carry `Notification.FLAG_INSISTENT`
  (`androidFlagInsistent`) so the sound loops until the shade is opened —
  no `fullScreenIntent`, no `USE_EXACT_ALARM`, no
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- **Repeats: +5, +10, +15 from the original minute** —
  `domain/escalation/repeat_alerts.dart` (pure; `repeatEvery`,
  `maxRepeats`, `repeatsFor`) and `planRepeats` in `reminder_plan.dart`,
  built from the same `now − 45` window as the ladder so opening the app
  at +7 keeps the +10. Same title, same payload, same buttons; the body
  says «فات ٥ دقايق». **A repeat never rings in the same minute as an
  enabled rung**: with both rungs on, the +15 repeat is dropped and the
  rung rings alone; switch the +15 rung off in «التنبيهات» and the third
  repeat fills that minute. **Rule 5 covers them**: `cancelReminderAt`
  cancels all three, «فكّرني بعدين» cancels all three (the snooze *is* the
  next reminder), and a dose confirmed by any path is out of the plan on
  the next `rescheduleAll`, so its pending repeats are cancelled as stale
  through `isRescheduledId`. The ladder is untouched — `reminder_repeat_test`
  compares every scheduled rung against `ladderFor` and pins 15/30/45/60.
  Budget: 12 slots paid from the dose window (44 → 32), the ladder still
  14 — on the app's own convention that is still more than the 7-day
  window; a hand-edited 9-minutes-a-day patient drops from ~5 to ~3.5 days.
- **iOS Time Sensitive needs an entitlement, and the entitlement needs
  the portal — and it is wired on Release only.** `ios/Runner/
  Runner.entitlements` carries
  `com.apple.developer.usernotifications.time-sensitive` and is
  `CODE_SIGN_ENTITLEMENTS` on the **Release** config of the Runner target
  alone. A personal Xcode team cannot sign that entitlement, so having it
  on Debug and Profile broke every on-device dev build; `dose_alert_test`
  pins Release-only. **Consequence, stated so nobody reads a dev build as
  proof**: Debug and Profile builds deliver dose reminders as ordinary
  notifications (Focus can hold them), and only a Release / TestFlight
  build signed with the company team shows Time Sensitive behaviour.
  **That team's App ID must have the capability enabled** (Certificates,
  Identifiers & Profiles → the App ID → Capabilities → Time Sensitive
  Notifications) and the provisioning profile regenerated, or
  `timeSensitive` is delivered as an ordinary notification with no error
  anywhere. `docs/ALARMKIT_NOTE.md` is the
  research note on iOS 26 AlarmKit — not built, deliberately.

**Alert modes: how often the reminder comes back, per medicine** (24 Sep
2026). `AlertMode` in `domain/escalation/alert_mode.dart`: `once` (the
chime only, no repeats), `repeating` (+5/+10/+15 — the default and the
behaviour above), `continuous` (every 3 minutes, capped at ten, so +3 …
+30). **The ladder, the 60-minute server grace and the son's alert are
identical in all three** — a mode only changes the local repeats, and
`reminder_repeat_test` pins the 14 rungs under each. A repeat still never
rings in the minute of an enabled rung, so «مستمر» with both rungs on is
eight repeats plus the two rungs. The device default lives in
`device_preferences.alert_mode` (drift **v22**, default `repeating`; in
drift and not `shared_preferences` because the lock-screen isolate
reschedules too) and is set from «التنبيهات» → «نوع التنبيه». The
per-medicine override is `medications.alert_mode` (v22, nullable,
null = follow the device), shown as `AlertModeChips` — one row of four
equal-width chips at 17px — on «ضيف دوا» and on the edit screen, and
carried through `MedicationDraft` so a prescription line keeps what the
person chose on «عدّل». A merged reminder takes the strongest mode among
its doses (`alertModeOf`). **Not pushed to the cloud**: the medications
payload names its columns and `alert_mode` is not among them, like
`active_ingredient`; repeats happen on the patient's phone only, so no
`0022` was needed. Budget: `maxPendingRepeats` is one pool of 20 slots
handed out nearest-first (`planRepeats` takes each reminder's steps from
what is left), paid from the dose window (32 → 24) — never from the ladder.
`repeatEvery` / `maxRepeats` remain the `repeating` numbers;
`maxRepeatsAny` (10) sizes the id bands.

**«اتنست» is a grace decision, written by the device, reversible.**
`rescheduleAll` first materialises yesterday's and today's routine days
(so a day the app never opened still has rows — and yesterday's bedtime
dose is counted the next morning), then `sweepMissed(now)` writes
`DoseState.missed` on every pending row whose `scheduled_at + 45 ≤ now`.
`actedAt` stays null: nobody acted, and the row says so. «أخدته» after that
overwrites it — he forgot, then remembered. `rescheduleAll` runs on launch,
foreground resume, every confirmation and every lock-screen action, so the
decision is taken at every wake-up the OS gives us; there is no timer.
«جدول النهاردة» shows «نسيتها؟» on the pinned card and «لسه ما اتأكدتش»
on the rail card — the same line for an overdue dose and a swept `missed`
one, with the same gold edge as a dose still to come (gold = «دي لسه
عايزاك»; never grey, never red). «أخدته» on the pinned card is the only
primary; tapping a rail card opens its `ReminderScreen`. A taken dose
collapses to a ✓ line and never leaves the rail. The son's screen renders `missed` verbatim as
«اتنست — لسه ما اتأكدتش» in gold — reporting the father's device's
decision, still not judging.

**`pending` and `missed` both mean «ما اتأخدتش».** The difference is who
marked the row — nobody yet, or the device after its 45-minute grace — not
a different medical state, and never a reason to stay silent. So the
server escalates on both (`0011_escalate_missed.sql`). Until 0011 it chose
`pending` only, on the theory that «اتنست» was "a decision already taken";
but the device writes it at +45 on any wake-up (opening the app, tapping
another dose's notification) and sync lifts it within seconds, so at +60
the scan found nothing and the son was never told — in the **common** case,
because the phone is in its owner's hand. `taken` (rule 5), `skipped` (a
human's decision, not forgetting) and `superseded` (0010) never escalate.
A row flipping `pending` → `missed` keeps its uuid (sync upserts on it), so
the `escalations` unique and the claim's stale-`claimed`-only condition
already prevent a second alert — `escalation_test.sql` §٢ب proves it.

**Snooze is not a confirmation, so it does not clear the ladder — but it
removes the rungs it overtakes.** «فكّرني بعدين» at 8:10 means "leave me
until 8:25"; a rung at 8:15 would nag against that request, so rungs at or
before the snooze time are cancelled and rungs after it stay. Rule 5 is
untouched: «أخدته» / «مش هاخده» cancel everything for the slot at once.

**The server's grace is longer than the device's, and the gap is the sync
budget** (round 4.2b). `graceWindow` is 45 on the device;
`serverGraceWindow` is 60; `syncSlack` is the 15 between them, and the
invariant `serverGraceWindow == graceWindow + syncSlack` is locked by a
test. It is an **identity, not an inequality** — `syncSlack` is defined as
the gap, so 45 + 15 = 60 exactly; this file said `>` until round 4.2b part
2, and the test that "locked" it subtracted a minute to make `>` pass on an
`=`, which let any one of the three move alone. Both constants live in `domain/escalation/` so the SQL and the
device read the same numbers. **Why they must differ:** the father
confirms at +44, the push debounce is 3s, the cron ticks at +45 — the row
is still `pending` in the cloud and the son is alarmed about a pill taken
thirty seconds ago. That is not an edge case, it is the last minute of
every grace window, and it is the same false alarm 4.2a exists to
prevent. The device's own decision stays at 45, so «يومك» still says
«نسيتها؟» on time; the extra fifteen minutes buys the wire, not the
patient.

**The cloud must know a dose before its time** (round 4.2b, part 1).
The server escalates from rows that already exist, and it never resolves
anchors (3.5) — it reads the instants the father's device computed. A
father who ignores every notification wakes nothing, so `rescheduleAll`
materialises **yesterday, today and tomorrow**: yesterday because a
bedtime dose lands after midnight, today because a day the app never
opened still needs rows, and tomorrow so an ignored dose already has its
row in the cloud when its time comes. Materialising stays idempotent —
the key is (schedule, routine day) and `materializeDay` only adds what is
missing — so re-opening never duplicates a row. `test/data/sync/` proves
the chain: one morning open, no further touch, every dose of that day and
the next present in the cloud as `pending` before it is due. Build this
before any alerting code, and never after: with the rows missing the scan
finds nothing, yet every hand-run test still passes, because touching the
app is itself what creates the row.

**Not yet (4.2 / 4.3):** a real device token — `lib/data/push/` is built
and unit-tested but has never run on hardware, so every alert still
resolves to `no_token`; the son's alert screen (mockup 27), so a tap on
the alert opens «يومك»; Critical Alerts entitlement; the +90
«الدائرة كلها» rung. The cloud half is done and running: `0006`–`0009`
are applied to the live project and the scan ticks every five minutes.

**The server's decision is visible on the son's screen** (round 4.2c).
`CaregiverRemote.snapshot()` also reads `escalations` of the last 48
hours (`alertWindow`), and each one is a card at the top of
`CaregiverScreen`: «⚠ والدك ما أكّدش جرعة {med} الساعة {time}» plus one
line per `delivery_status`. Three decisions live there:
- **`no_token` is not a failure and is not worded as one.** The server
  decided and recorded, and the card the son is reading *is* the alert;
  only the device channel is not activated yet. So it says «تنبيه داخل
  التطبيق — إشعار الجهاز محتاج تفعيل», `sent` says «السيرفر بلّغك {sent_at}»
  and only `failed` says «الإشعار ما وصلش» — that one really did fail. A
  row still `claimed` is hidden: the send is in flight, and `0009` will
  settle or retry it within five minutes.
- **A closed dose gets no card at all — reversed in round 26.**
  4.2c kept the card after the father confirmed and added «أكّدها بعدين ✓»
  («the alert happened; the outcome is the update, not a deletion»). That
  was wrong in the only place it mattered: the card's headline stays
  «⚠ والدك ما أكّدش جرعة …» in bold gold *above* the ✓, and the headline is
  what gets read. **It told a son his father missed medicine he had
  taken** — and a son who learns the alerts are wrong stops reading them,
  which costs far more than a missing card.
  **Rule 5 is untouched.** Its ban is on *recalling a delivered push*, and
  nothing here unsends anything; the push stands, and «the repair is a
  correct view» is exactly what this is — a dose that is closed has nothing
  open to show.
  **Open is `pending` and `missed`, and nothing else**, defined once in
  `caregiver_remote.dart` as an **exhaustive switch over `DoseState`** with
  the wire list derived from it, so a sixth state is a compile error rather
  than a silent alert:
  `pending` nobody acted; `missed` the device passed its grace and wrote it
  — the same «ما اتاخدتش», differing only in who marked it (these two are
  what `private.due_escalations` selects, so client and server agree);
  `taken` he took it; `skipped` a human decision, not forgetting;
  `superseded` the rule changed so the dose never existed (`0010`).
  **The filter is in the query, not the widget** — the son never downloads
  a row he will not show — with `alert.open` as a second line for a stale
  row, and an unrecognised state counting as *not* open.
- **Sections, each with the app's heading style** (round 28 order):
  «تنبيهات» ← «آخر أسبوع» ← «جرعات النهارده» ← «الجديد».
  Alerts stay first because an open one means a dose is being missed *now*;
  what stopped them filling the screen is that closed ones no longer exist,
  not demoting them. The alerts heading counts the **open** alerts, or a
  filtered row would leave a heading over nothing.
  **Medicines are no longer here at all** (round 29): that list is
  *reference*, not *state*, and it became its own dock tab — see «The son
  is not a patient» below.
  «جرعات النهارده», not «النهارده» — the week panel's today row says
  «النهارده» too, and one word for two things on one screen confuses.
- **The week strip is gone** (round 30, owner's call). Round 28 had
  rewritten it from seven columns of «٤/١٦» and «—» into seven labelled
  rows, because the fraction told nobody anything and the dash conflated
  *no doses* with *no news from his phone*. The owner then removed the
  panel outright: a seven-day count is a summary of something the day list
  below already answers, and «متابعة» is about **now**. The widget and its
  tests went with it — the empty-week sentence belonged to the strip, and
  the day list keeps its own «مفيش جرعات متسجّلة النهارده» so an empty
  screen still explains itself.
- **Each part of a report is named** (round 30). The card headed every
  record with one run-on line — «١٢ سبتمبر — د. طارق — معمل البرج» — which
  leaves the reader to work out which is which. Now each part is its own
  labelled field, **and the label follows the kind**, because the same
  column means different things: `place` is «المعمل» on a lab, «العيادة»
  on a prescription, «المركز» on imaging; `happened_at` is «تاريخ التقرير»
  / «تاريخ الورقة» / «تاريخ الأشعة». An empty field renders nothing — no
  labels standing over blanks. The body gets a heading with its count,
  «النتايج (٦)» or «الأدوية (٣)», so the reader knows the size before
  starting.
- **A prescription's medicines are one per line** (round 30) — they were a
  single paragraph, «Concor 5mg — Telfast 180mg — Augmentin 1g», the exact
  wall removed from the lab card in round 28 and left standing here. The
  split is on **our own** separator (`names.join(' — ')`, written by the
  review screen), and it applies to prescriptions **only**: a visit or
  imaging note is free text a person typed, and splitting that would cut
  their sentence in half.
- **One lab result, one representation** (round 28). The card wrote
  `notes` as a paragraph («… APTT 23.4 sec — Haemoglobin 11.6 g/dL — …»)
  and then repeated the same results as rows underneath. `notes` now
  renders **only when the record has no lab lines** — for a visit or an
  X-ray it is the whole content; for a lab it was the same data written
  worse. **Flagged rows are never collapsed**, wherever they sit in the
  report: clean rows show three and the rest wait behind «كل النتايج (N)»,
  because an out-of-range value must be visible without opening anything.
  The test puts a flagged line *fifth* to prove a late one still escapes
  the collapse.
- **`FSectionHead` is the one heading definition** (`core/widgets/
  primitives.dart`). There were three — 23px display on متابعة, 19px
  non-display on the son's الملف الصحي, and a third inside «الجديد». That
  spread is exactly why the screen read as sections written at different
  times.
- **Filtered to `caregiver_id = me` for wording, not access.** RLS lets a
  brother read alerts sent to his siblings (decided in 4.2b part 2), and
  «بلّغك» must not point at the wrong person. RLS is still the only
  scoping of what the circle may see.
No empty-state card, no sound, no animation; refresh is the existing
open/foreground/pull path (plus the visible-tab poll). `alertFromRow` is pure so the nested embed
(`dose_events → dose_schedules → medications`) is unit-tested without
Supabase — but the `!inner` embed filter on `patient_uuid` has **never
run against the live project**; if a card fails to appear on a device it
is the first suspect, and dropping that `.eq` is safe for a son with one
linked father.

**الابن مش أبوه — نفس الهوية، كثافة تانية** (جولة إعادة تصميم شاشة
الابن). شاشات الابن كانت ورثت مقاسات اتكتبت لراجل عنده ٧٢ سنة بنضارة
قراية: متن ٢٠، هدف لمس ٥٦، حشو ١٦. ده صح للأب وغلط لواحد شغّال بيفتح
التطبيق تلات ثواني بين اجتماعين.
- **تدرّج جنب التدرّج، مش بداله.** `F.care…` في `tokens.dart` (متن ١٦،
  ثانوي ١٤، دقيق ١٢٫٥، هدف لمس ٤٦، حشو ١٢) — والقيم مأخوذة من سلّم الخط
  اللي في الـREADME (`body2`, `rowLabel2`, `secondary2`) مش مخترعة. **ولا
  قيمة واحدة من مقاسات الأب اتغيّرت** — الفرق في `tokens.dart` إضافة
  صافية، صفر سطر متشال. نفس اللوحة، نفس الخطوط العربية، نفس الـRTL.
- **والتدرّج محبوس.** `test/app/caregiver_density_test.dart` بيقرا `lib/`
  ويوقع لو `F.care…` أو أي ودجت من `caregiver_ui.dart` ظهرت برّه
  `lib/features/care/`، **ولو** شاشة ابن استعملت `F.minTextSize` /
  `F.minBodySize` / `F.minTapTarget` / `F.elder…`، **ولو** قيمة مشتركة
  اتغيّرت (الأرقام مكتوبة بالحرف هناك — قرايتها من `F` كانت هتخلّي
  الاختبار يقارن الحاجة بنفسها). مُتحقَّق بالطفرة في الاتجاهين.
- **A health notification is sent only for what the patient can fix on the
phone, and it opens the check screen** (24 Sep 2026, tester feedback 5).
`HealthFinding.notifies` is true only for codes in `notifiableCodes`
(notification permission, exact alarms, battery, dropped reminders, the
horizon, timezone, the pending band); `HealthWatcher` filters on it. A
sync problem — `staleSync`, and the new `accountMissing` — stays in the
in-app bar and screen and never pushes: the tap used to open nothing, and
the patient cannot repair the server. Every health notification now
carries `HealthWatcher.tapPayload`, which `AppRoot` routes to
`HealthCheckScreen`, cold start included (`applyLaunchResponse` stores a
plain tap in `lastPayload`). The stale copy is in plain words and names
the follower: «التأكيدات لسه ما وصلتش لـمحمد» / «أول ما النت يرجع هتتبعت
لوحدها. لو مستعجل، دوس «ابعتها دلوقتي».» — and that button now returns a
sentence (`SyncService.pushNow`): «اتبعتت ✓», «مفيش نت دلوقتي — أول ما
يرجع هتتبعت لوحدها.», «الحساب ده مش موجود على السيرفر — لازم تربط تاني.»,
or «حصلت مشكلة وإحنا بنبعت — هنحاول تاني لوحدنا بعد شوية.»
**A rejected account stops the queue.** `SupabaseSyncRemote` translates
`PostgrestException` into `SyncRejected(code)` and network faults into
`SyncOffline`, so the service classifies without importing the SDK; codes
`42501` (row-level security) and `23503` (foreign key) mean the patient
row the phone is bound to is not the server's any more — the anonymous
user changed (debt 2) or the row was deleted. `push()` then writes
`sync.blocked` to `shared_preferences`, returns `PushOutcome.blocked` with
**no network call** on every later trigger, `checkAccountMissing` shows
the one sentence with «اربط حد يتابعك» as its button, and `confirmLinked`
clears the block. **`stats()` counts only rows the push would send**:
child rows whose parent is gone (a dose event whose schedule was deleted
by an old build with foreign keys off, a medication whose patient row is
absent) and the unpushable «أنا» patient are excluded, so an orphan can no
longer hold «لسه ما وصلتش» open forever while the push skips it. The
tester's stuck queue reads as exactly that pair: a server rejection
retried on every trigger, counted by a stats query that never joined.

**الحد الأدنى للنص بقى حدّين**: `expectNoRedAndMinSize` أخد بارامتر،
  و`expectCaregiverDensity` هو اللي شاشات الابن بتتنده بيه. حد الأب ١٧
  زي ما هو على شاشاته.
- **الإجابة الأول.** أول كارت على «متابعة» بيرد على السؤال اللي الابن
  فاتح الشاشة عشانه: «كل حاجة تمام» / «فيه N محتاجة انتباهك»، وتحتها
  آخر جرعة **مؤكَّدة** وإمتى — الجملة لوحدها ممكن تبقى شاشة واقفة،
  والوقت جنبها هو اللي بيخلّيها مصدّقة. الحساب نقي في
  `caregiver_status.dart` ومتختبر بالأرقام من غير ما نرسم شاشة.
- **الأسبوع سطر واحد**: «٦ من ٧ أيام كل الجرعات فيها اتقفلت». جولة ٣٠
  شالت شبكة السبع خانات لأن الكسور مكانتش بتقول حاجة، والرجوع بقى رقم
  بجملته **من غير أي رسم**: سبع نقط مش بيانات تستاهل رسمة، والجملة أسرع
  في القراية. **والنهارده مش محسوب** — اليوم لسه ماشي، وعدّه ناقص بيخلّي
  كل يوم يبان مش كامل لحد آخره.
- **الحالة أيقونة وكلمة، واللون على العلامة مش على النص.** كل صف جرعة
  فيه `CareStateMark`: أيقونة + كلمة + لون. ده بيتقري لحد مش بيفرّق
  الألوان وبيتقري في الوضعين. **ودي صلّحت دين قديم**: العنوان
  «⚠ والدك ما أكّدش جرعة …» و«اتنست — لسه ما اتأكدتش» كانوا `F.gold`
  **نص** — ٢٫٠٦:١ على كارت نهاري، يعني أهم سطرين على الشاشة كانوا أصعب
  سطرين يتقروا. دلوقتي الكلمة بلون المتن والذهبي على الأيقونة وعلى حد
  الكارت الجانبي (نفس فكرة `GoldNote`). تلات تأكيدات في الاختبارات
  القديمة كانت مثبّتة على `style?.color == F.gold` واتغيّرت لتثبّت
  العقد الجديد (النص ink + أيقونة ذهبية) — ده التغيير الوحيد في اختبار
  قديم، ومقصود.
- **أفعال عملية، من غير قدرة جديدة**: «حدّث» جنب سطر آخر تحديث،
  و«حاول تاني» على لوحة الخطأ. الاتنين بيندهوا نفس `holder.refresh` اللي
  السحب لتحت بينده عليه — قراية وخلاص، وحارس `caregiver_shell_test` لسه
  بيثبت إن مفيش ولا زرار بيكتب في بيانات الأب.
- **فجوة داتا، متسجّلة مش متعمولة: «اتصل بوالدك» مش ممكن.** أرقام
  التليفونات في `emergency_profile.contacts_json`، و**ده مش بيتدفع
  للسحابة أصلاً** (قرار D5.1، و`health_file_sync_guard_test` بيوقع لو
  اتدفع)؛ `CaregiverEmergency` مالهاش عمود تليفون. زرار اتصال محتاج
  يا إما عمود جديد في السحابة يا إما قرار خصوصية جديد — والاتنين
  مش شغل جولة عرض.
- **ألوان الأقسام، النسخة اللي المالك طلبها**: «تنبيهات» أحمر،
  «ما اتأكدتش» دهبي، «جاية» أخضر غامق، «اتاخدت» أخضر، «متخطّية» رمادي،
  «زيارات» بنفسجي، «تحاليل» برونزي.
  - **الأخضر الغامق لازم يفتح في الليل**: `greenDeep` بيقيس **١٫٥١:١**
    على كارت الليل، يعني القسم كان هيختفي — نفس الفخ بالظبط اللي خد
    «اتاخد» قبل كده. الليل بياخد `#2E9E85`.
  - **والأخضرين ولاد عم، والرقم مكتوب**: «جاية» و«اتاخدت» بينهم **١٤٫٠
    ΔE نهاري و١٠٫٢ ليلي** — تحت أرضية الـ١٥، وباقي الأزواج كلها فوقها.
    ده ناتج مباشر للطلب (لونين من نفس العيلة جنب بعض)، وبيتفرقوا
    بالإضاءة وبالعنوان المكتوب فوق كل قسم. لو الفصل مطلوب أوضح،
    «اتاخدت» بتتنقل للون تاني — كلمة واحدة في `tokens.dart`.
  - **والأحمر لما دخل، «زيارات» و«تحاليل» اضطروا يتنقلوا.** الأحمر
    الجديد كان **١٢٫٢ ΔE** من بنفسجي الليل القديم، والأخضر الغامق كان
    **١٠٫٧** من برونزي النهار القديم. بدل ما نفضل ننحت استثناءات لحد ما
    الحارس يفضى، اتعاد البحث: بعد الأحمر والأزرق والدهبي والأخضرين، اللي
    فاضل **عايلتين بس** بيشتغلوا في الوضعين — بنفسجي (٢٧٦°) وبرونزي
    (٣٨–٤٠°)، وهما اللي اتاخدوا. **الحساب هو اللي طلّعهم، مش الذوق.**
- **و«الأدوية» و«الملف الصحي» كروتهم ملوّنة كمان** — بس بمنطقين
  مختلفين، لأن الشاشتين مش نفس الحاجة:
  - **«الأدوية»: تبويب واحد، لون واحد** (أخضر «اتاخدت»). القايمة دي
    **مرجع** مش حالة، فمفيش أقسام تتفرّق بينها. ولون لكل دوا كان هيبقى
    تلوين **بالدور**: اللون بيتغيّر لما دوا يتضاف أو يتوقف، فبيدّي معنى
    مش موجود — وده بالظبط اللي قاعدة اللون الفئوي بتمنعه.
  - **«الملف الصحي»: لون لكل نوع سجل** (`careRecordAccent` في
    `caregiver_ui.dart`) — `RecordKind` مجموعة مقفولة بخمس قيم، وده
    اللي اللون الفئوي موجود له. تحليل برونزي وزيارة بنفسجي **بنفس لونهم
    في «متابعة»**: نفس الحاجة في المكانين. واللون بيمشي مع الورقة —
    الكارت جوّه القايمة بياخد لون نوعه زي المدخل اللي فتحها.
  - **وسبعة مداخل أكتر من الألوان المتاحة.** غير الدلالية (الدهبي
    «محتاجاك» والأحمر للتنبيهات) فاضل خمسة، والبحث في الجولة اللي فاتت
    طلّع إن مفيش عايلة تالتة بتعدّي في الوضعين. فالسجلات بتاخد الهوية،
    و**اللي مش سجل** — قياسات السكر والأسئلة والحجوزات — بياخدوا الرمادي
    المحايد. ده تقسيم بمعنى مش نقص لون متغطّى، واختبار بيثبت إن ولا نوع
    بياخد الدهبي ولا الأحمر.
  - **وروشتات/أشعة ولاد عم زي الأخضرين**: أخضر وأخضر غامق، بيتفرقوا
    بالإضاءة وبالكلمة المكتوبة على المدخل.
- **«بكرة» مابقاش ليها قسم** (طلب المالك): «متابعة» بقت عن النهارده وبس.
  اللي فاضل من بكرة هو الجملة اللي بتظهر لما النهارده يبقى فاضي («أول
  جرعة بكرة الساعة …») — دي بتقول «ليه الشاشة فاضية»، مش بتعرض جدول.
  الصفوف لسه في الصورة (جهاز الأب بينزّل بكرة مقدماً)، بس ما بتترسمش —
  واختبار بيثبت إن جرعة بكرة ما بتظهرش.
- **بنية «متابعة» بترتيب المالك** (ملحق نفس الجولة): سطر الحالة ←
  **ما اتأكدتش** ← **جاية** ← **اتاخدت** ← **متخطّية** ← **زيارات** ←
  **تحاليل** ← الأسبوع ← الجديد ← سطر التحديث. كل قسم بعدّاده، والفاضي
  **بيختفي** — سطر الحالة فوق قال خلاص. الحساب كله في
  `careDoseSections` / `careFollowUps` (نقي، متختبر بالأرقام).
  - **«جاية» الأقرب الأول**، و«اتاخدت» **الأحدث الأول بوقت التأكيد** —
    السؤال هو «خد آخر واحدة؟». و«ما اتأكدتش» **الأقدم الأول**: اللي عدّى
    عليها ساعتين أهم من اللي عدّى عليها عشر دقايق. التلاتة
    مُتحقَّقين بالطفرة.
  - **بكرة تحت عنوان يومها** («بكرة — ١ سبتمبر»)، فالصف بيكتفي بساعته
    بدل ما يكرّر الكلمة في كل سطر.
  - **صف «جاية» بيقول قد إيه فاضل** («كمان ٤٠ دقيقة») بدل ما يكرّر اسم
    قسمه. `timeAhead` / `timeSince` في `caregiver_words` بيكتبوا الصيغة
    العربية بتلاتتها (دقيقة / دقيقتين / ٥ دقايق) — قاعدة عامة واحدة كانت
    هتغلط في التنتين.
  - **وصف «اتاخدت» بيقول وقت التأكيد الحقيقي** («اتأكّدت ٨:٠٥ ص»)،
    والساعة المجدولة في عمود الوقت على أوله.
- **«متخطّية» قسم زيادة عن قايمة المالك، ومقصود.** «مش هاخده» قرار إنسان
  مش نسيان: هي لا فايتة ولا اتاخدت، وحطّها تحت «اتاخدت» كان هيخلّي
  العنوان يكدب، وإخفاؤها كان هيضيّع معلومة كانت بتتعرض. قسم صغير لوحدها
  لحد ما المالك يقرر.
- **والعنوان الأول «ما اتأكدتش» مش «فاتت» — الحتة الوحيدة اللي خرجت عن
  نص الملحق.** القاعدة المكتوبة هنا من زمان: «جرعة عدّى وقتها من غير
  تأكيد بتتقال «لسه ما اتأكدتش» — عمرها ما تبقى «فاتت» ولا حمرا: إحنا
  بنبلّغ مش بنحكم»، وفيه اختبار باسمه بيقرا الشاشة ويوقع على الكلمة دي
  بالسبب مكتوب جواه. وعنوان «فاتت» فوق صف بيقول «لسه ما اتأكدتش» بيناقض
  نفسه على شاشة واحدة. **لو المالك عايز «فاتت» فعلاً، دي كلمة واحدة في
  `_doseSections` وسطر في `caregiver_screen_test`** — والقرار قراره.
- **لون لكل قسم — هوية محسوبة، واللون تالت دايماً.** كل قسم في «متابعة»
  بياخد لونه على **حد الكارت (١٫٥ بكسل، نصف قطر ١٢) وشريطه الجانبي
  وعلامة صغيرة جنب العنوان** — **مش على النص ومش على الأرضية**. العنوان
  العربي مكتوب فوق كل قسم، فالهوية عمرها ما بتتحمل على اللون لوحده.
  | القسم | نهاري | ليلي |
  |---|---|---|
  | تنبيهات / ما اتأكدتش | `F.gold` | نفسه |
  | جاية | `#4A2A86` | `#9B6BC0` |
  | اتاخدت | `F.green` | نفسه |
  | متخطّية / الجديد | `#5B6B7A` | `#93A3B0` |
  | زيارات | `#9C5C8F` | `#DB9ACE` |
  | تحاليل | `#573611` | `#C76728` |
  - **المحجوز فضل محجوز**: الأحمر للطوارئ، الأزرق للمية، الكهرماني
    والبرتقالي لدرجات السلّم — ولا واحد منهم اتلمس، و`red_only_in_emergency`
    عدّى من غير تعديل.
  - **واتنين اترفضوا بالقياس مش بالذوق**: وردي `#B33A6D` طلع **٩٫٨ ΔE**
    بس من أحمر الطوارئ `#A81E26`، وطيني `#9A5326` طلع **١٣٫٤** — الاتنين
    تحت أرضية الـ١٥، يعني صعب تفرّقهم عن الأحمر حتى برؤية كاملة. لون
    بيلخبط مع الأحمر بيضيّع أغلى معنى في التطبيق. التحاليل نزلت لبرونزي
    غامق (١٦٫٩ ΔE). **الاختبار هو اللي لقى الاتنين، مش العين.**
  - **والمساحة ضيقة عن قصد**: بعد ما نشيل الأحمر والأزرق والدهبي والأخضر
    وكل حاجة قريبة منهم، الباقي عايلتين بس — بنفسجي وبرونزي. عشان كده
    «جاية» و«زيارات» ولاد عم، والفرق بينهم متقاس (١٧٫٧ نهاري).
  - **اللي عدّى واللي ما عدّاش، بالأرقام** (`validate_palette` بتاع مهارة
    عرض البيانات): فصل الرؤية العادية **عدّى في الوضعين** (١٩٫٨ نهاري /
    ١٦٫٥ ليلي) وكذلك التباين (الكل فوق ٣:١). **اللي ما عدّاش**: فصل عمى
    الألوان على زوج واحد — الأخضر (اتاخدت) والبنفسجي-الوردي (زيارات) —
    ٦٫٢ نهاري و**٥٫٢ ليلي**، وده تحت الأرضية. المحور ده (أخضر↔أرجواني)
    هو أشهر التباس عند deutan، والمساحة اللي فاضلة بعد المحجوزات مش
    سايعة حل تاني. **الشرط اللي بيخلّيه مقبول موجود**: كل قسم فوقه
    **كلمته مكتوبة**، وكل صف فيه أيقونة وكلمة — يعني اللون مش حامل
    المعنى أصلاً. والقسمين دول مش جنب بعض على الشاشة («متخطّية» بينهم).
  - `caregiver_accents_test` بيحسب ده كله من `tokens.dart` مباشرة، فأي
    تعديل لون بيقع هنا بدل ما يعدّي في مراجعة.
- **«زيارات» و«تحاليل» قراية بس، ومن غير هجرة ولا سياسة جديدة.**
  أعمدة المتابعة (`checkup_stage`, `follow_kind`, `checkup_stage_since`,
  `lab_booking_at`, `result_ready_at`, `doctor_visit_at`) موجودة على
  `public.records` من `0012`/`0015`/`0017`، والصف نفسه هو اللي
  `records_select` بيسمح للابن بيه من `0012` عن طريق
  `private.can_access_patient`. **RLS في بوستجرس على مستوى الصف مش
  العمود**، و`0015`/`0017` زوّدوا أعمدة على نفس الجدول من غير ما يلمسوا
  ولا سياسة — فاللي كان ناقص هو الـ`select` بس، واتزوّد. والمرحلة
  بتتقري بنفس دوال الأب (`FollowKind.stageFromNumber`،
  `followIsStalled`)، ونفس اختيار عمود الميعاد اللي في
  `CheckupService.stageDateOf` — مفيش حساب تاني يقدر يختلف مع الأول.
- **وشورت-كت لـ«الملف الصحي» من «متابعة» ما اتعملش عن قصد**: هو تبويب
  في الدوك، وباب تاني لنفس الأوضة بيخلّي الواحد يسأل هما أوضتين ولا
  واحدة — نفس القاعدة اللي شالت القايمة من «متابعة» في جولة ٢٩.

**«مقدرناش نكمّل» is what the son reads; the log is what you read.**
The caregiver fetch swallowed every failure into that one sentence — a
missing column, an RLS refusal and a dead socket all looked identical from
the outside, so a real bug could not be told from a flaky network.
`SupabaseCaregiverRemote._guard` now logs the cause under `kDebugMode`
with the `Care:` prefix, and for a `PostgrestException` it prints
**`code`, `message`, `details`, `hint`** — those are the fields that name
the column, the table or the relationship — plus the stack;
`CaregiverSnapshotHolder`'s bare `catch (_)` does the same. **The sentence
on screen is unchanged and no raw error ever reaches it.** When a caregiver
screen misbehaves, that log line is the first thing to read; guessing from
the sentence is guessing.

**No session means «not linked», never «something went wrong»** (round 25).
The query built its filter as `currentUser?.id ?? ''`, so a device with no
session sent `caregiver_id=eq.` — and Postgres rejects `''` as a uuid
(22P02). That threw inside `linkedPatient()`, which `snapshot()` calls
first, so **every later query never ran**: the son saw «مقدرناش نكمّل»
*and* an empty health file, from one empty string. A wiped install or an
expired token is an ordinary state, and the answer to it is the entry
screen. `no_session_not_linked_test` points at an unreachable host, so
"returns null" can only mean no request was attempted.

**And a guard must not re-classify what an inner guard already
classified.** `snapshot()` and `linkedPatient()` are both wrapped, and the
outer one was catching the inner one's `CareCircleException` and relabelling
it `other` — so an ordinary **offline** failure inside `linkedPatient`
reached the son as «مقدرناش نكمّل» instead of the offline sentence. Since
`linkedPatient` runs first, that was the common path, not an edge. `_guard`
now rethrows an already-classified exception untouched.

**The son's side never resolves anchors** (round 3.5). Resolving needs
the father's routine plus the engine — a second scheduler that can silently
disagree with the real one. The father's device is the only scheduler; the
caregiver view (`lib/features/care/`, data via `CaregiverRemote` in
`lib/data/care/`) renders only what his device wrote onto `dose_events`
(`scheduled_at` instants), or shows nothing. Enforced by
`test/features/care/no_scheduling_imports_test.dart`. The screen reports,
it does not judge: a past-due unconfirmed dose is «لسه ما اتأكدتش» in gold —
never «فاتت», never red ("missed" is Phase 4's grace-window decision). The
footer is «آخر تحديث من موبايل والدك» from the max server `updated_at` —
deliberately not "last seen"; data changing proves nothing about the phone
being alive. The linked patient is identified via the caregiver's own
`care_relationships` rows, never by filtering `owner_id` client-side —
RLS is the only scoping. When a son follows more than one parent,
`linkedPatient` orders by `created_at desc` and takes one — without a
deterministic order Postgres may return the title from one parent and the
medicines from another, and the screen looks empty with no error.
**Refresh: open, foreground, pull, plus a 10-second poll (`refreshEvery`)
that runs only while the «متابعة» tab is visible and the app is in the
foreground.** The rule used to be «no realtime, no timers», and it left the
son looking at a frozen screen: the father confirmed, his phone had already
pushed, and the son's view stayed stale until he killed and reopened the
app. `CaregiverShell` keeps both tabs alive in an `IndexedStack`, so the
poll is gated by `CaregiverScreen.active` (`_tab == 0`) and cancelled on
`paused`/`inactive`; it restarts — with an immediate refresh — on resume or
on returning to the tab. `caregiver_poll_test` proves it stays silent on
«الإعدادات» and in the background, and fires on the tab (mutation-checked
both ways). No realtime yet: a Supabase Realtime subscription is the
intended **replacement** for the poll, not an addition to it. Offline keeps
the last snapshot visible under the agreed sentence.

**The cloud schema's only wall is RLS** (`supabase/` — SQL only, run by
hand in the SQL editor, order: 0001 → 0005 → tests). The publishable key
ships in the binary, so every table has RLS enabled as its first statement
and `anon` is stripped of table privileges entirely. Access checks for
*other* tables route through SECURITY DEFINER functions in `private` —
patients' visibility depends on care_relationships and vice versa, and
direct policies would recurse ("infinite recursion detected in policy").
Always `(select auth.uid())`, never bare. Cloud PKs are the device-minted
uuids; local int ids have no cloud column. Caregivers are read-only until
escalation adds one narrow UPDATE policy. After ANY schema change run
`tests/rls_test.sql` and the zero-rows `rowsecurity=false` check in
`supabase/README.md`.

**A table's policy must NEVER call a function that queries that same
table.** The row's own columns are already in scope inside the policy —
compare against them directly (`owner_id = (select auth.uid())`). The
definer-function indirection exists for one job only: reaching *other*
tables without recursion. Breaking this does not fail loudly at
`create policy` time; it fails on `INSERT ... RETURNING`, because
Postgres applies the SELECT policy to the new row inside the same
statement, where a subquery cannot yet see it. `patients_select` called
`can_access_patient(uuid)`, which queries `public.patients` — so every
new patient insert failed with 42501, always, for everyone. Fixed in
`0005_fix_patients_select.sql`, and `tests/rls_test.sql` now inserts a
patient, a medication and a dose_event **with RETURNING**, the way the
app does.

**Escalation rows are readable by the whole care circle, not just their
recipient** (round 4.2b part 2). `escalations_select` goes through
`private.can_access_patient`, so an accepted caregiver sees every alert
sent about that patient — including ones sent to his *siblings*, not only
to himself. For a family sharing one father that is the intended reading,
and it is why the policy is not `caregiver_id = (select auth.uid())`.
The same choice has a second consequence: a **revoked** caregiver loses
sight of alerts he previously received, because access is re-derived from
the relationship every time rather than stored on the row. Both of these
are visible behaviour, decided, not accidents.

`device_tokens` is the deliberate exception to the whole pattern: no
`can_access_patient` appears anywhere in it, in either direction. A linked
son sees his father's doses; he never sees his father's phone token, and
his father never sees his. Every policy on it compares `user_id` against
`(select auth.uid())` — a column already in the row, the cheapest possible
form of the rule above. Writes go through `public.claim_device_token`,
whose threat model is written out in `0006_push.sql` and tied to debt 2.

**`private` is not exposed to PostgREST, so the Edge Function reaches the
scan through one narrow `public` wrapper.** `public.due_escalations_for_service`
(`0007_escalate_rpc.sql`) has no body of its own — it calls
`private.due_escalations` and nothing else — and its EXECUTE is granted to
`service_role` alone, revoked from `anon` and `authenticated`. The two
rejected alternatives are worth naming: exposing the `private` schema in
API settings would publish every definer access function at once, and a
TypeScript copy of the scan inside the function is the "two definitions of
selection" this whole round exists to prevent. `escalation_test.sql`
asserts the wrapper and the inner function return the same rows, because
the wrapper is the one the Edge Function actually calls.

**An interrupted send retries after 5 minutes, and the duplicate that can
cause is chosen deliberately** (`0009_escalation_retry.sql`). The function
claims a row, then sends, then writes the result; if it dies in between —
timeout, recycle, redeploy — the row sits at `'claimed'` forever and
`due_escalations` used to exclude it, so that dose would never alert
again, silently. Now a row still `'claimed'` after
`private.escalation_retry_after()` (5 minutes) becomes due again, and the
claim is a single atomic statement
(`public.claim_escalation_for_service`) that inserts or takes over a dead
claim — **not** an INSERT whose 409 the function reads as "already
alerted", which is what made the plain SQL fix a no-op until the Edge
Function changed with it.

**The threshold must exceed the function's maximum lifetime.** Shorter,
and a slow-but-still-running send gets a second claim from the next tick,
manufacturing in the normal case the duplicate that should only ever
happen during a failure. Never trim it for a faster retry; the number is
about being sure the holder is dead, not about speed.

**And the judgment, because it is the whole basis of the fix:** if the
function died after FCM accepted the message but before writing `'sent'`,
the retry sends the alert twice. A son annoyed by a duplicate has a second
of confusion and then checks on his father. A son **never told** his
father missed a dose is the failure this entire product exists to prevent,
and with phone calls cancelled this push is the last rung. We choose the
duplicate. (This is unrelated to rule 5's ban on a recall: there we would
spend a channel that must stay meaningful to unsay something; here we say
the same true thing twice.) `'sent'`, `'no_token'` and `'failed'` are
written decisions and stay excluded forever.

**The cron reads the service role key at run time, not at schedule time**
(`0008_escalation_cron.sql`). Interpolating it into the scheduled command
would store it verbatim in `cron.job.command`, readable by anyone who can
read that table. So the job is literally `select
private.run_escalation_scan()`, and that function looks both the URL and
the key up in Vault on every tick. Missing secrets raise a loud exception
every five minutes into `cron.job_run_details` — correct noise: it means
the last rung of the ladder is down. `pg_net` does not wait for the
response; it queues the request and a background worker runs it, so the
reply lands in `net._http_response`, which is the first place to look when
an alert does not arrive. Two overlapping runs are harmless — the unique
on `escalations` is what prevents a double alert, never the cron's timing.

**The caregiver channel id is a second cross-language mirror.**
`fakkarni_caregiver` is written in Dart
(`NotificationService.caregiverChannelId`) and in TypeScript
(`CAREGIVER_CHANNEL` in the Edge Function). If they drift, Android drops
the alert onto the default channel — **no error anywhere** — so the last
rung arrives at ordinary priority, or not at all if the son muted that
channel. `test/data/push/push_channel_test.dart` reads the function file
and fails if either side moves, exactly like the grace-window mirror.

**The selection query has exactly one definition, in SQL.**
`private.due_escalations` is called by the cron, by the Edge Function and
by `tests/escalation_test.sql`. A copy of the scan written in TypeScript
would let the test prove a statement the function never runs — which is
precisely how `rls_test.sql` passed over the `0005` bug. Anything that
picks rows for alerting lives in that function or it does not exist.
`private.server_grace_window()` is the only place `60` appears in the SQL,
and `due_escalations` is forced through it — the number is a **mirror** of
`serverGraceWindow` in `domain/escalation/`, and the mirror is held by
`test/data/sync/server_grace_sql_test.dart`, which fails if either side
moves alone. Postgres cannot read Dart; drift between the two shows up as
a false alarm on a son's phone, never as a failing build, so the test is
the only thing standing there.

**If a migration file changes after you have run it, say so — out loud, in
the next message, with "re-run it".** "I ran `0006`" and "the file now on
disk has run" are different facts, and the gap between them is invisible
from both sides: the file looks right to whoever reads it, and the database
looks right to whoever ran it. A function that was never actually created
costs half an hour of debugging something that is not broken. This applies
to a comment-only edit too — the cost of saying so is one sentence, and
nobody can tell from the outside which kind of edit it was.

**SQL migrations are run against the real project in the same round that
writes them, before that round is committed.** Both of the above shipped
green because the SQL had never been executed — `0004` collided on a
`day_routines.updated_at` that `0001` already created, and the policy bug
above was invisible to a test that inserted without RETURNING. Code
nobody has executed is not code, however carefully reviewed. Every
migration must be idempotent (`if not exists`, `create or replace`,
`drop ... if exists` before `create`) so re-running the whole chain is
always safe. That promise was **false** until round 4.2b part 2: `0001`
died on its first `create table` and `0002`/`0003` on their first
`create policy` against any live project, while the README said the chain
replayed. A README that lies costs a morning. The known price of
`if not exists` is that a replay never reshapes an existing table — which
is correct: migrations are history, and a shape change gets its own
numbered file, never an edit to an old one.
And when a test passes over a bug, fix the test's *shape* — ours exercised
a different statement than the app, which is not thoroughness but a blind
spot.

**A migration file in the repo is not a migration in the database, and an
audit that confuses the two is worse than no audit.** Round 25 spent a
debugging session on a caregiver screen that would not load. Asked to check
every column the son's query selects, I diffed the selects against the
**migration files** and reported a clean table — a tick beside
`medications.removed_at` and `dose_schedules.stopped_at`, both of them
"added by `0014`". `0014` had never been run on the live project. The
columns existed in git and not in Postgres, the tick was true of the wrong
thing, and it sent the search away from the actual cause.

So: **any answer to "does this column exist" must say which of the two it
checked** — the file, or the database. They are different questions with
different answers, and only one of them is what the app talks to. Checking
the file is still useful (it catches a select that no migration ever
wrote); it is simply not an answer about the cloud. To answer about the
cloud, query `information_schema.columns` on the project, or run the
migration's own self-check, which is written to be re-runnable for exactly
this.

**What actually named it was the debug log added the same round** — one
line, `Care: ... PostgrestException code=... message=...`, naming the
column Postgres could not find. A log beat a careful audit because the log
was reading the database and the audit was reading the repo.

### Migrations confirmed run on the live project

**آخر تشغيلة: ٢٤ سبتمبر ٢٠٢٦ — `supabase/verify_migrations.sql` رجّع
٢٢ صف، كلهم `ok = true`.** (التشغيلة اللي قبلها، ٢٣ سبتمبر، كانت ٢١/٢١؛ و٢٠ سبتمبر ١٧/١٧
بـ١٦١ فحص.)

**This list is evidence from the database, not from the repo.** That
distinction is the whole point of it: the previous version of this list was
reasoned from migration files and said `0014` was applied when it was not.
These rows come from `pg_class`, `pg_proc`, `pg_policies`, `pg_indexes`,
`pg_trigger`, `pg_constraint`, `information_schema.columns` and `cron.job`
on the live project.

| Confirmed | Files |
|---|---|
| 20 Sep 2026 | `0001`-`0018`, all of them |
| **22 Sep 2026** | **`0019_battery_state`** و**`0020_caregiver_preferences`** — اتشغّلوا واتأكّدوا في نفس اليوم: **١٥/١٥ على ٠٠٢٠، و٢٠ صف كلهم `ok = true`** |
| **23 Sep 2026** | **`0021_admin`** — اتشغّلت واتأكّدت في نفس اليوم؛ `verify` رجّع **٢١ صف كلهم `ok = true`** |
| **24 Sep 2026** | **`0022_admin_devices`** — اتشغّلت واتأكّدت في نفس اليوم (المالك): `verify` رجّع **٢٢ صف كلهم `ok = true`** |
| **not yet run** | **`0023_nurse_role`** و**`0024_medication_changes`** و**`0025_family_subscription`** و**`0026_nurse_account`** و**`0027_vitals`** و**`0028_medication_stock`** و**`0029_med_photos`** و**`0030_patient_papers_limits`** و**`0031_not_bought`** و**`0032_schedule_patterns`** و**`0033_delete_account`** — اتكتبوا ٢٤–٢٥ سبتمبر ٢٠٢٦ ولسه ما اتشغّلوش (طلب المالك: الملف بس). من غير 0023/0024: تأكيد الممرض بيقع، والدعوة بدور بترجع خطأ على `p_role`. من غير 0025: التطبيق بيقرا «مفيش صف» = مسموح، فمفيش تجربة بتنتهي ومفيش سقف ٥. من غير 0026: باب الممرض بيرجع خطأ على `p_expect_role`، وكود الممرض ما بيشيلش «يعدّل الأدوية»، والصور ما بتترفعش. الترتيب: 0023 ثم 0024 ثم 0025 (بتعيد تعريف `due_escalations` بعد 0023) ثم 0026 ثم 0027 ثم 0028 ثم 0029 ثم 0030 ثم 0031 ثم 0032 ثم 0033، وبعدها `verify_migrations.sql` لازم يرجّع ٣٣ صف كلهم `ok = true`. **0033 ملف بس** (مسح الحساب) — ومعاها دالة الحافة `delete-account` لازم تترفع؛ من غيرهم «امسح حسابي» بترجع «مقدرناش نكمّل المسح — حسابك لسه موجود» ومفيش حاجة بتتمسح. **0032 ملف بس** (أنماط الأيام) — من غيرها الجدول بنمط بيفضل على الموبايل ويطلع `patternSync` للأدمن. المالك بيطبّق 0028 و0029 بنفسه (٢٥ سبتمبر)؛ 0030 و0031 المالك بيطبّقهم كمان (٢٥ سبتمبر). من غير 0028 المخزون بيفضل على موبايل المريض (صفه مستني، باقي الدفع ماشي)، والعيلة ما بتشوفش سطره، و«علبة جديدة» من الممرض بترجع خطأ على قيد النوع. **و`3f74e5c` غيّر ملف 0026** (الفحص الذاتي من غير `private.` تحت `set role`) — لو كان اتشغّل، يتشغّل تاني. من غير 0027 القياسات بتفضل على موبايل المريض (الدفع بيسيبها مستنية من غير ما يوقّف جدول تاني) وعيلته وممرضه ما بيشوفوهاش. **و`bf460e0` غيّر ملف 0023 بعد ما اتكتب** — لو كان اتشغّل، يتشغّل تاني. |

**والصف اللي كان بيقول `0019` «not yet run» كان بايت** — تشغيلة ٢٢ سبتمبر
رجّعت **٢٠ صف كلهم true**، و٢٠ صف يعني `0001`–`0020`، يعني `0019` فيهم.
الجدول اتكتب من الذاكرة بدل ما يتكتب من مخرج السكريبت، وده بالظبط اللي
القاعدة اللي فوقه بتحذّر منه. الدرس مش جديد، بس ده تاني مرة.

`0018_device_health` was run and verified the same day it was written —
**18/18 rows true, and 13/13 on `0018` itself**. That is the rule working
as intended: SQL is run against the real project in the round that writes
it, and the row above is evidence from the database, not from the repo.

**`0020` اتشغّلت — وغلطة واحدة فيها تستاهل تتكتب.**

الملف كان بيقول `execute function extensions.moddatetime (updated_at)`،
والمشروع الحقيقي ردّ **`function extensions.moddatetime() does not exist`**.
الامتداد متركّب في سكيما تانية عنده، وكل الملفات اللي قبله (`0004`،
`0006`، `0012`، `0018`) بتكتبها **من غير سكيما**: `execute procedure
moddatetime (updated_at)`. الملف بقى زيهم، واختبار بيقفل على ده
(`no_qualified_moddatetime`) — الغلطة دي ما بتظهرش غير على مشروع حقيقي،
وهي بالظبط الصنف اللي القاعدة «ملف في المستودع مش هجرة في القاعدة»
موجودة عشانه.

**وشكل «تمام» لما تتشغّل تاني** (الملف idempotent، فإعادته آمنة):

١. في SQL editor، الزق **كل** `supabase/migrations/0020_caregiver_preferences.sql`.
   **«تمام» = `Success. No rows returned`.** الاستثناء `rollback_0020`
   **مش بيطلع كـ`ERROR`**: هو متمسوك جوّه `exception when others` في نفس
   البلوك، وشغلته الوحيدة إنه يرجّع بيانات الفحص المؤقتة. وسطر
   `NOTICE: 0020 OK — …` بيظهر في لوحة الرسايل لو المحرّر بيعرضها، بس
   **مش هو العلامة** — العلامة هي النجاح، وبعده الخطوة ٢.
   **أي `ERROR: FAIL 0020:` معناها الهجرة ما اتطبّقتش**، واللي بعد
   النقطتين بيقول إيه بالظبط.

٢. بعدها الزق `supabase/verify_migrations.sql` كله. **«تمام» = الصف
   `0020_caregiver_preferences` بـ`ok = true` و`expected = found = 15`
   و`missing` فاضي**، وباقي الصفوف زي ما هي. لو `missing` فيه حاجة، هي
   بالحرف اللي ناقص.

**Re-run the script rather than trusting the date.** A row here goes stale
the moment anyone touches the project; the script is one paste and it
answers about today.

**What the script does not cover, so the row above is not read as more
than it is:**
- **Whether RLS actually protects anything.** It checks that each policy
  exists by name and that `relrowsecurity` is on. `0005` exists precisely
  because `patients_select` existed *and was wrong* — every insert failed
  42501. Behaviour is `tests/rls_test.sql`'s job, and that one writes
  (inside a rollback), which is why it is a separate file.
- **Triggers firing.** `set_updated_at` and its column are verified to
  exist; proving `moddatetime` stamps a row needs an UPDATE.
- **Grants and revokes.** `anon` being stripped, and EXECUTE granted to
  `service_role` alone, are not checked — the aclitem shapes vary enough
  between projects that a false red was the likelier outcome.
- **Anything outside the database**: the `escalate` and `ai-read` Edge
  Functions, their `verify_jwt` setting, and the Vault secrets `0008`'s
  cron reads at run time. The script confirms the job is *scheduled*;
  whether it *succeeds* lives in `cron.job_run_details` and
  `net._http_response`.
- **Column types and nullability.** A column of the wrong type still
  passes — the check is existence.

**Three checks are deliberately not existence checks**, because existence
would have lied: `private.due_escalations` is created by `0006` and
rewritten by `0009`, `0011` and `0014`, so those three are verified by what
their bodies contain (`escalation_retry_after`, `missed`, `removed_at`);
`0005` is verified by `patients_select` mentioning `is_accepted_caregiver`,
since it replaces `0002`'s policy under the same name; and `0010` / `0017`
only alter CHECK constraints, so the definition is searched for
`superseded` / `visit`. **The `funcsrc` check on `removed_at` is the one
that would have caught the `0014` gap.**

**A self-check that inserts into `public.patients` must create the owner in
`auth.users` first.** `patients.owner_id` is a foreign key onto
`auth.users`, and a `gen_random_uuid()` is not a real user — so the first
`insert into public.patients` fails the key, the exception escapes the
sub-transaction, and **the whole script rolls back**: the migration you
thought you ran was never applied. The failure does not read that way from
either side. The error names the foreign key, not the columns you were
adding, and a script that ends without `NOTICE ... OK` is easy to scroll
past. One line, before the patient, as `0011`–`0015` all have it:

```sql
insert into auth.users (id, email) values (v_owner, 'owner-' || v_owner || '@00NN.check');
```

`0016` shipped without it and rolled back on the live project;
`test/data/sync/migration_selfcheck_owner_test.dart` reads every file under
`supabase/migrations/` and `supabase/tests/` and fails if one inserts a
patient without creating an owner, or creates the owner **after** the
patient. Mutation-checked both ways. Postgres does not run in `flutter
test`, so this class of mistake is otherwise found only by the real project
— after the time is spent.

---

**فحص السلامة — «اطمن إن التذكير هيشتغل»** (`domain/health/health_check.dart`,
`data/health/`, `features/selfcheck/`).

كل عيب اتصلّح الأسبوع ده كان **ساكت**: التطبيق شكله سليم والوعد مكسور،
وآخر واحد كلّف ماك وConsole.app وتلات ساعات. راجل عنده ٧٢ سنة عمره ما
هيعمل ده، ومع ألف مستخدم كنا هنعرف من جرعة فايتة.

- **المنطق نقي**: `HealthSnapshot` بيانات ساذجة، وكل فحص دالة نقية
  بترجّع `HealthFinding?`. الاختبار بيبني لقطة حرفية ويقرا النتيجة —
  مفيش قاعدة ولا pumping. **ولكل فحص لقطة بتعدّيه ولقطة بتوقّعه**؛ فحص
  عمره ما اتحقّق شرطه مش حارس.
- **درجتين وبس** (`broken` / `note`). تالتة معناها فرز، والفرز مش شغل
  المريض.
- **المدى بيتقرا من `pending()` مش من `planWindow`** —
  `horizonFromPendingDoseIds`. الخطة هي اللي احنا فاكرينه؛ الـpending هو
  اللي iOS وافق يمسكه، والفرق بينهم هو صنف العيب اللي بيسكت لحد ما جرعة
  تفوت. وفيه فحص لنفس الفرق: `remindersDropped` بيقارن
  `ReminderScheduler.lastPlannedDoseCount` (اللي **الخطة الحقيقية**
  سجّلته، مش نسخة منها) باللي الجهاز ماسكه.
- **كل مكسور معاه زرار بيحلّه** أو جملة بتقول اللي بيحصل. صف أحمر
  المستخدم ما يقدرش يعمل فيه حاجة هو ضوضا، واختبار بيقفل على ده.
- **السطر الأخضر جزء من الميزة**: شاشة عمرها ما بتقول «كله تمام» معناها
  الوحيد «فيه بايظ». وعشان السطر ده ما يكدبش، `noMedications` ملاحظة —
  موبايل مفيهوش دوا كان بيعدّي كل الفحوص ويقول كله تمام عن وعد مش موجود.

**تلات حواجز، وكلها اتعملها mutation:**
1. **الفحص بعد الوعد، مش قبله.** `test/app/health_is_last_test.dart`
   بيقرا `main.dart` ويقارن المواضع: الفحص بعد معالجة رد الإطلاق وبعد
   `rescheduleAll`، ومن غير `await` قبل `runApp` — وبيقرا
   `bootstrap.dart` ويوقع لو اسم الفحص ظهر فيه أصلاً. **كسرنا الترتيب ده
   مرتين في يوم واحد**، فهو اختبار مش تعليق.
2. **تنبيه السلامة معروض، مش متجدول.** `NotificationService.showNow`
   بتستعمل `show` — إشعار متجدول كان هياخد خانة من الأربعة وستين، يعني
   التنبيه اللي بيقول «التذكير ممكن ما يشتغلش» هو نفسه اللي بيعطّله.
   رقمه `60_000_001`، برّه كل النطاقات المحجوزة.
3. **النبضة متخنوقة**: صف بيترفع لما مجموعة الأكواد المكسورة **تتغيّر**،
   أو كل `heartbeatEvery` (٦ ساعات). ست ساعات = ربع نافذة الـ٢٤ ساعة
   اللي «مكسور» بيتحدّد بيها، وأربع صفوف في اليوم للجهاز الواحد.

**السحابة: `0018_device_health`** — صف لكل (مريض، تنزيلة)، **أكواد سلامة
وبس**: مفيش اسم دوا ولا محتوى جرعة ولا أي حاجة طبية. الـRLS بيمشي على
قاعدة ٠٠٠٥: السياسة بتقرا `patient_uuid` بتاع الصف نفسه وبتنده دوال
بتوصل لجداول **تانية** بس. `private.broken_devices()` بترد على «أنهي
حسابات مكسورة دلوقتي وعلى إيه» — وبتحسب الجهاز **الساكت** كمان، لأن
الغياب أخطر من أي كود: الجهاز مش بيقدر يقوله عن نفسه.

**`batteryOptimisation` رجع ومعاه القناة اللي بتقراه.** أول نسخة اتشالت
لأنها كانت بتحط `true` ثابتة — حارس شرطه عمره ما بيتحقّق. بس **الحل إننا
نقرا الشرط، مش إننا نشيل الحارس**: قاتل البطارية بتاع الشركة المصنّعة هو
أشهر سبب إن تذكير دوا ما يرنش على أندرويد، وأندرويد هو المنصة اللي مش
بنقدر نجربها هنا — يعني ده بالظبط الفحص اللي الميزة موجودة عشانه.
`MethodChannel('fakkarni/battery')` في `MainActivity.kt` بيقرا
`PowerManager.isIgnoringBatteryOptimizations` (**مش محتاج أي إذن**).

**والزرار بيفتح قايمة الإعدادات، مش الحوار المباشر — ده قرار سياسة مش
ذوق.** `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (الحوار «اسمح؟»)
بيشترط إذن `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`، وهو إذن **مقيّد** على
Google Play بقايمة استخدامات مقبولة وبمراجعة. `ACTION_IGNORE_BATTERY_
OPTIMIZATION_SETTINGS` بيوصل لنفس النتيجة بدوسة زيادة، **من غير أي إذن
ومن غير أي تعرّض للمراجعة** — فمفيش سبب نراهن بالنشر على تصنيف.
`test/app/battery_policy_test.dart` بيقفل على ده: القراية موجودة،
والـintent المقيّد مش موجود، والإذن مش في الـmanifest (زي قاعدة
`USE_EXACT_ALARM` القديمة بالظبط).

**وحاجة الفحص ده ما بيشوفهاش**: قوايم «التشغيل التلقائي» بتاعة شاومي
وأوپو وهواوي قفل تاني **برّه** العلم ده خالص، فجهاز ممكن يعدّي الفحص
ويفضل بيتقفل. الفحص بيقول الحقيقة اللي يعرفها، مش كل الحقيقة.

**و`pushToken` بقى ملاحظة، مش مكسور، طول ما APNs لسه ما اتظبطش** (الدين
٣). مش تهوين: صف أحمر دايم مالوش زرار بيموّت معنى الأحمر نفسه — الابن
بيشوفه كل يوم، بيتعلّم يعدّي عليه، وبعدين بيعدّي على واحد حقيقي. الجملة
بتقول الحقيقة كاملة (الموبايل مش هيرن، والتنبيه مستنيه في «متابعة»)،
و**بيرجع `broken` أول ما APNs تشتغل**: ساعتها غياب التوكن يبقى عطل في
جهاز بعينه مش حالة معروفة في المنتج كله.

**المريض ما يشوفش مشكلة تقنية أبداً — قرار المالك (٢٤ سبتمبر ٢٠٢٦).**
يا التطبيق بيصلّحها لوحده في صمت، يا بتتبلّغ للوحة الأدمن. مفيش كلام
تقني على أي شاشة مريض. الفحص نفسه لسه بيشتغل بالكامل (كل الأكواد،
والنبضة زي ما هي)؛ اللي اتغيّر مين بيشوف نتيجته.
- **اتشال من واجهة المريض**: شريط `HealthBar` على «يومك» (الملف اتمسح)،
  إشعار السلامة (`showNow` + `tapPayload` + سكّة الجذر اللي كانت بتفتح
  عليه)، وصف «اطمن إن التذكير هيشتغل» من الإعدادات العادية. الشاشة
  نفسها لسه موجودة **تحت «للمطوّر» وجوّه `!kReleaseMode`** — للتشخيص،
  مش للمريض. `health_is_last_test` بيقرا `lib/features/today/` و`elder/`
  و`root.dart` ويوقع لو اسم الشاشة أو الشريط رجع فيهم، وبيقارن موضع
  الصف في الإعدادات بموضع البوابة.
- **الاستثناء الوحيد: إذن التنبيهات مقفول** — مش تقني وفي إيده هو بس.
  `NotificationsOffLine` (`features/today/`) سطر واحد على «يومك»:
  «التنبيهات مقفولة — افتحها عشان نفكّرك» وزرار «افتح الإعدادات» بيطلب
  الإذن، ولو مرفوض بيفتح إعدادات النظام. بيقرا كود واحد بس
  (`patientVisibleCodes = {notificationPermission}` في الدومين)، وبيعيد
  قراية الإذن الحقيقي عند الرجوع للمقدمة فبيختفي من غير إعادة تشغيل.
  «مش معروف» ما بيغيّرش حاجة — الشك مش سبب لسطر.
- **الإصلاح الآلي في `HealthAutoFix`** (`health_watcher.dart`، دوال
  متحقونة فالاختبار بيعدّ الندوات): `reminderHorizon` / `remindersDropped`
  → `rescheduleAll`؛ `timezoneChanged` → `rescheduleAll` + حفظ المنطقة؛
  `pushToken` → `push.registerNow()`؛ `staleSync` → `sync.push()`.
  `autoFixableCodes` في الدومين، و`autoFixes` بيشمل **الملاحظات كمان**
  (توكن ناقص ملاحظة لحد ما APNs تشتغل، وإعادة تسجيله ما بتضرش). **مرة كل
  ست ساعات لكل كود** (`health.autoFixed.<code>` في shared_preferences)،
  وبعد أي إصلاح الفحص **بيتعاد** فالنبضة بتبلّغ الحالة بعد الإصلاح مش
  قبله. كل إصلاح سطر `diag('Health: إصلاح آلي — …')`. الحساب المرفوض
  (`accountMissing`) **مش** منهم — الربط هو الحل، والإعادة للأبد كانت
  العيب اللي اتصلّح الجولة اللي فاتت.
- **المزامنة بتعيد المحاولة لوحدها بتراجع أُسّي** (`SyncService`):
  ٣٠ ثانية، دقيقة، دقيقتين… لحد نص ساعة (`retryDelayFor`)، **بعد
  `start()` بس** — صحوة الخلفية محاولة واحدة ومفيش عملية يعيش فيها
  مؤقّت — وبتقف مع أول نجاح. الحساب المرفوض ما بيتعادش (قرار `_block`
  زي ما هو). ده لسه «مفيش مؤقّت دوري»: المؤقّت بيتجدول بعد فشل بس.
- **اللوحة بتشوف أكواد كل جهاز**: `0022_admin_devices.sql` —
  `public.admin_devices()` قراية بس بحارس `private.is_admin()` وبنفس حدود
  0021 (ولا بيان طبي)، بترجّع كل صف `device_health` بأكواده وأعمدة
  النبضة. في `admin/`: `AdminDevice`، و`device_codes.dart` (الكود → كلام
  الأدمن، وحد السكوت ٢٤ ساعة)، و`DeviceProblemsList` **قايمة واحدة** على
  «نظرة عامة» («أجهزة فيها مشكلة — N» + أول خمسة) و«صحة الأجهزة» (كاملة)
  وجوّه لوحة الحساب («مشاكل الجهاز»). «فيه مشكلة» = كود موجود **أو** نبضة
  أقدم من ٢٤ ساعة («ماوصلش منه حاجة من {مدة}») — الغياب هو الكود.
  `device_codes_test` **مرآة** لقايمة `HealthCode` في التطبيق (بيقرا
  الملف، مش بيستورده): كود جديد هناك من غير كلمة هنا بيوقّع.
- **ما اتلمسش**: التذكيرات، السلّم، تصعيد السيرفر — اختبار الخطة الذهبية
  و`reminder_plan_test` و`reminder_repeat_test` خضر من غير تعديل.

### اللي لسه مش متأكَّد منه على أندرويد

**شاشة CI الخضرا معناها «الطريق اشتغل مرة على محاكي مخزني»، ومعناهاش
«أندرويد شغّال».** الفرق ده مكتوب هنا عشان محدش يقراها غلط بعد شهر.

`.github/workflows/android-lockscreen.yml` بيشغّل محاكي x86_64 حقيقي على
جهاز GitHub (فيه KVM؛ المحاكي بيقع على مستوى QEMU على الماك بتاع
التطوير) وبيعيد بالحرف اللي اتعمل بالإيد على الآيفون: يزرع جرعة، يقتل
**العملية**، يستنى الإشعار، يفتح الستارة، يدوس «أخدته»، ويتأكد إن الصف
اتكتب وإن التطبيق بيعرضها مؤكَّدة بعد ما يتفتح تاني.

**`am kill` مش `am force-stop`** — و ده مش تفصيلة: force-stop بيحط الحزمة
في حالة «موقوفة» وبيلغي منبّهاتها في AlarmManager، فالإشعار عمره ما كان
هيرن والاختبار كان هينجح أو يقع لسبب تاني خالص. و`am kill` بيقتل
العمليات **اللي في الخلفية بس**، عشان كده الاختبار بيضغط Home الأول،
وبيتأكد بعدها من `dumpsys package` إن الحزمة مش موقوفة.

**اللي الاختبار ده بيثبته فعلاً:** إن دوسة على زرار في ستارة الإشعارات،
والعملية متقتولة، بتوصل دارت وبتكتب صف الجرعة وبيتقري بعدها من التطبيق.
ده الشيء الوحيد اللي مكانش متأكَّد منه خالص.

**واللي ما بيثبتوش، وكله بيحصل على أجهزة حقيقية وبس:**
- **قتلة البطارية بتوع الشركات المصنّعة.** محاكي مخزني مافيهوش ولا واحد
  منهم. قوايم «التشغيل التلقائي» بتاعة شاومي وأوپو وهواوي بتوقّف
  التطبيق **برّه** علم `isIgnoringBatteryOptimizations` تماماً — يعني
  جهاز ممكن يعدّي فحص السلامة ويفضل بيتقفل.
- **Doze على جهاز حقيقي.** المحاكي بيشتغل موصّل بالكهربا والشاشة نايمة
  لثواني معدودة؛ Doze الحقيقي بيدخل بعد فترة سكون طويلة وبيجمّع
  المنبّهات في نوافذ. التأخير اللي بيسببه مش بيبان هنا.
- **حدود الإشعارات بتاعة المصنّعين.** فيه واجهات بتقصّ عدد الإشعارات
  المعلّقة أو بتأخّر القنوات — ومحدش بينشر الأرقام دي.
- **نُسخ أندرويد غير اللي في المصفوفة** (دلوقتي API 34 بس) وواجهات
  MIUI/ColorOS/One UI — شكل الستارة نفسه بيختلف، وده اللي الاختبار
  بيدوس فيه.
- **إن الإشعار بيرن أصلاً وسط استعمال عادي** — الاختبار بيدّي الإذن
  بـ`pm grant` وبيسمح بالمنبّه الدقيق بـ`appops`. مستخدم حقيقي ممكن
  يرفض الاتنين، وده اللي فحص السلامة موجود عشانه.
- **التصعيد للابن** — الاختبار بيتأكد إن الجرعة اتسجّلت، مش إن السحابة
  عرفت. ده لسه محتاج جهاز مربوط.

**أول تشغيلة (٢١ سبتمبر ٢٠٢٦) وصلت لآخر تأكيد ووقعت عنده.** الباب
اتفتح: المنبّه عاش بعد `am kill`، الإشعار رن والعملية ميتة، الستارة
اتفتحت، زرار «أخدته» كان موجود، والدوسة وصلت. وبعدين
`expected:<1> but was:<0>` على عدّ صفوف الجرعة.

**ومكانش فيه في التشغيلة دي حاجة تفرّق بين تلات تفسيرات**، وده العيب
اللي اتصلّح في الاختبار نفسه مش في `lib/`:
- **(أ) WAL**: القاعدة على `journal_mode = WAL`، والاختبار كان بيفتح
  الملف `OPEN_READONLY`. اتصال للقراية بس ما بيقدرش يعمل استرجاع
  للـWAL، فبيرجّع اللقطة القديمة — **صفر من غير أي خطأ**. الصف ممكن
  يكون موجود والاختبار أعمى عنه.
- **(ب) الوقت**: ثمان ثواني ثابتة لـisolate بيشغّل محرّك تاني ويسجّل
  إضافات ويفتح قاعدة، على محاكي CI.
- **(ج) الـisolate فعلاً بايظ** — اللي بنختبر عشانه.

اللي اتعمل ساعتها: الاختبار بقى يفتح الملف قراية وكتابة بدل
`OPEN_READONLY`، وبقى **يستنّى لحد ما الصف يظهر ويقول خد قد إيه** بدل
ثابت مخمّن، وبقى **يطبع الدليل قبل ما يقع**.
**والسطر اللي كان مكتوب هنا — «بيفتح الملف زي ما التطبيق بيفتحه» —
غلط، واتشال في ٢٢ سبتمبر.** شوف «الإطار مش قارئ التطبيق» تحت: الجملة
دي هي اللي خلّت أداة القياس تفضل فوق الشبهة لفة كاملة.

**واللوج هو أثر أندرويد** — `diag()` بتكتب في `fkdiag.log` على iOS بس،
وعلى أندرويد السطر بيخرج من `debugPrint` للوج. عشان كده الـworkflow بقى
بيسجّل `adb logcat` طول الخطوة ويرفعه. **الفجوة دي مقصود إنها تتقال**:
مستخدم أندرويد في الشارع ما يقدرش يوريك الأثر — «سجل التشخيص» جوّه
التطبيق بيقرا ملف مش موجود عنده أصلاً. الحل المقترح (**مش متعمول**)
إن `path_provider` يحل مجلد المستندات مرة عند الإقلاع ويتخزّن المسار في
`shared_preferences`، فالـisolate يكتب في الملف من غير أي نداء قناة.

**والتأكيد بتاع `am kill` كان بيعدّي وهو فاضي.**
`UiDevice.executeShellCommand` بيعدّي على `Runtime.exec(String)`، اللي
بيقطّع على المسافات من غير صدفة — يعني `dumpsys package … | grep stopped`
كان بيبعت `|` و`grep` كوسائط لـdumpsys ومش بيفلتر حاجة، والنص الراجع
مكانش فيه `stopped=true` لأنه مكانش فيه حاجة. دلوقتي المخرج بيتجاب كامل
وبيتفلتر في كوتلن، والتأكيد بيرمي لو ما لقاش علم `stopped=` أصلاً.
**فأي `executeShellCommand` جديد: مفيش أنابيب ولا `$(...)` ولا علامات
تنصيص — هات المخرج وفلتره في كوتلن.**

**التشغيلة التانية سمّت السبب، وهو مش (أ) ولا (ب) ولا (ج): مستقبِل ناقص
في الـmanifest.** الدليل من `logcat-full.txt`:

```
20:36:06.315  UiObject2: Clicking on (217, 904)   ← الدوسة على «أخدته»
(وبعدها ولا سطر واحد من الحزمة بتاعتنا — لا Isolate: ولا Notif: ولا استثناء)
FKTEST: fakkarni.sqlite-wal — مش موجود
FKTEST: taken بالقراية-والكتابة = 0، بالقراية-بس = 0
```

(أ) اتشالت: مفيش `-wal` أصلاً. (ب) اتشالت: ستين ثانية ومفيش حاجة.
و(ج) غلط في صياغتها — الـisolate **ما وقعش**، محدش ناداه.

**الـmanifest المدموج — اللي بيشحن — كان بيعلن
`ScheduledNotificationReceiver` و`ScheduledNotificationBootReceiver` وبس،
ومن غير `com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver`.**
الإضافة ما بتعلنش ولا مستقبِل في الـmanifest بتاعها (فيه إذنين وبس) —
التطبيق هو اللي لازم يعلنهم، والـREADME بتاعها بيقول كده بالنص:
«To use notification actions, specify `<receiver … ActionBroadcastReceiver />`
between the `<application>` tags». فالإشعار بيرن عادي، والدوسة على أي زرار
بتتبعت لمكوّن **مش موجود**، وأندرويد بيرمي الـbroadcast من غير أي خطأ في
أي مكان. يعني على **كل** جهاز أندرويد، مقفول أو مفتوح، في المقدمة أو في
الخلفية: «أخدته» و«فكّرني بعدين» عمرهم ما اشتغلوا. الإشعار بيختفي — لأن
النظام بيشيله — والمريض فاكر إنه أكّد.
`test/app/notification_receivers_test.dart` بيقفل على التلاتة: عيب بيقع
في صمت لازم يقع بصوت وقت الاختبار. مُتحقَّق بالطفرة مرتين — شيل المستقبِل
يبقى أحمر، وحطّ اسمه في تعليق بس يفضل أحمر.

**واتنين عن الاختبار نفسه، مسجّلين هنا عشان يتصلّحوا في اللفة الجاية
(مش مع إصلاح الـmanifest — حاجتين مع بعض ما بتثبتش حاجة):**
- **العملية عمرها ما اتقتلت.** `am kill` اتنفّذ الساعة 20:35:12، والعملية
  5795 عاشت لحد `Killing 5795 … (adj 0): due to finished inst` الساعة
  20:37:07. الاختبار المُجهَّز (instrumented) بيجري **جوّه** عملية التطبيق،
  والـinstrumentation بيثبّتها على `adj 0` — فـ`am kill`، اللي بيقتل
  عمليات الخلفية بس، بيبقى بلا أثر. يعني سيناريو «التطبيق مقتول» ما
  اتجرّبش في أي تشغيلة من الاتنين.
- **وتأكيد `dumpsys` عدّى وهو بيقيس حاجة تانية.** `stopped=false` بيقرا
  **علم الحزمة**، مش إن العملية ماتت — حارس تاني شكله بيقيس حاجة وبيقيس
  غيرها، زي `executeShellCommand` بالظبط.
- **وتاريخ `.sqlite` مش دليل على كتابة.** 20:36:06.395، تسعتاشر ملّي بعد
  الدوسة، هو **فتح الملف من الاستطلاع بتاع الاختبار نفسه** (قراية وكتابة)،
  مش كتابة من التطبيق. أداة القياس لوّثت الدليل اللي بتقيسه.

**التشغيلة التالتة أثبتت الـmanifest، ووقفت عند قفل.** التغيير الوحيد
كان المستقبِل، ولأول مرة في التاريخ دوسة أندرويد وصلت دارت:

```
07:49:05.739  الدوسة على «أخدته»
07:49:06.773  FKDIAG Isolate: دخلنا المعالج — action=taken payload={...}
07:49:06.972  SqliteException(5): database is locked
              Causing statement: pragma journal_mode = WAL;
              at prepareDatabase (connection.dart:28)
              ← RoutineRepository.ensurePatient ← buildServices
```

وقعت عند **الفتح**، قبل أي كتابة جرعة.

**الإطار مش قارئ التطبيق — وعمرنا ما نفتح القاعدة الحية من الاختبار
والتطبيق ممكن يكون بيكتب.** `android.database.sqlite.SQLiteDatabase`
اتصال **تاني خالص**: مكتبة تانية، بإعداد journal بتاعها وأقفالها بتاعها،
مش sqlite3 بتاع drift بالـpragmas بتاعتنا. النسخة القديمة من الاختبار
كانت بتفتحه `OPEN_READWRITE` من ٣٠ ملّي بعد الدوسة وكل نص ثانية — يعني
أداة القياس كانت قاعدة على الملف وهو بيتكتب، وكان مكتوب فوقها إنها
«بتفتح زي ما التطبيق بيفتحه». الجملة دي هي اللي حمتها من الشك.

النسخة الجديدة ما بتفتحش الملف الحي خالص:
- **بتستنّى على اللوج**، مش على القاعدة: سطر نهاية المعالج. مكانش فيه
  سطر نجاح لا لبس فيه (الموجود كان سطر الفشل بس، فالسكوت كان بيعني
  «نجح» أو «لسه شغّال» أو «العملية ماتت» — تلاتة من غير فرق)، فاتضاف
  **سطر واحد** في آخر `try` بتاع `onBackgroundNotificationAction`:
  `Isolate: خلص المعالج — handled=ok action=…`. تسجيل وبس، مفيش أي سلوك
  وراه. العلامة `handled=ok` **لاتينية** عن قصد — المقارنة بتحصل على
  مخرج `logcat` عبر `executeShellCommand`، ومش وقت المراهنة على ترميز.
- **وبعد السطر ده بس**، بتاخد **نسخة** من `.sqlite` و`-wal` و`-shm`
  وتقرا **النسخة** `OPEN_READONLY`، وتسجّل `pragma journal_mode` منها.
  أي حاجة الإطار يعملها بتحصل على النسخة.
- **ولقطة الملفات (موجود/حجم/تاريخ) بتتاخد قبل أي قراية بتاعتنا**، مرتين:
  قبل الدوسة وبعد سطر النهاية. ده stat بس، مفيش فتح.

**واللي التشغيلة الجاية هتقدر تسمّيه بالظبط:** لو القفل فضل موجود
والاختبار بقى برّه الصورة، يبقى **التطبيق** هو الماسك للاتصال التاني —
والـisolate الجديد بيزاحم الـmain isolate اللي لسه حي في نفس العملية.
ولو اختفى، يبقى **الاختبار** كان هو، وكانت أداة القياس هي العطل.
الاتنين إجابة؛ اللي مكانش موجود هو الفرق بينهم.

**متسجّل ومش متصلّح — عن قصد، عشان تغييرين مع بعض ما بيثبتوش حاجة:**
- **ترتيب البراغما في `prepareDatabase` مقلوب.**
  `pragma journal_mode = WAL` (سطر ٢٨) بيجري **قبل**
  `pragma busy_timeout = 5000` (سطر ٤٠). وتحويل الـjournal هو الجملة
  الوحيدة اللي بتحتاج قفل حصري — فهي بالظبط اللي بتجري من غير أي معالج
  انتظار، وبتقع في ~٢٠٠ ملّي بدل ما تستنّى ٥ ثواني. الترتيب ده غلط
  بغضّ النظر عن مين ماسك الاتصال التاني، بس إصلاحه بيستنّى تشغيلة
  الاختبار لوحده.
- **`BackgroundTask.begin()` بينده قناة iOS على أندرويد.**
  `MissingPluginException … fakkarni/background_task` — متمسوك ومكتوب في
  التوثيق إنه لا-عملية هناك، بس هو نداء قناة مرمي على أول سطر في سكّة
  الصحوة، وهو الوقت اللي الملف ده كله بيقول ما يتصرفش فيه.
- **ولسه مفتوح من قبل: العملية عمرها ما اتقتلت** (`adj 0` تحت
  الـinstrumentation)، فسيناريو «التطبيق مقتول» ما اتجرّبش.

**التشغيلة الرابعة: السكّة اتثبتت، والقفل اتحسم — الاختبار هو اللي كان
ماسكه.**

```
08:15:16      الدوسة على «أخدته»
08:15:18.886  Isolate: دخلنا المعالج — action=taken
08:15:25.708  Isolate: خلص المعالج — handled=ok action=taken
FKTEST: journal_mode في النسخة = wal، taken = 1
```

**والدليل على مين كان ماسك القفل هو `-wal` نفسه.** قبل التغيير ما كانش
فيه `-wal` ولا `-shm` في أي لقطة، مع إن الـmain isolate حي والقاعدة
مفتوحة — يعني الملف مكانش في WAL أصلاً. بعد التغيير الاتنين موجودين
**قبل** الدوسة (`-wal` ٤٢٨ كيلو). قراية `SQLiteDatabase` بتاعة إطار
أندرويد كانت بتقلب الملف برّه WAL: **أداة القياس كانت بتكسّر اللي
بتقيسه**، وتغيير واحد أثبت ده.

**فالقاعدة، مكتوبة عشان متتنسيش: `android.database.sqlite.SQLiteDatabase`
مش قارئ التطبيق، وعمرنا ما نفتح القاعدة الحية من الاختبار والتطبيق ممكن
يكون بيكتب فيها.** ده اتصال تاني بمكتبة تانية بإعداد journal بتاعها
وأقفالها بتاعها، مش sqlite3 بتاع drift بالـpragmas بتاعتنا. الاختبار
بياخد **نسخة** ويقراها `OPEN_READONLY`.

**ووقعت عند الخطوة الأخيرة — والتأكيد نفسه كان فاضي.** كان بيدوّر على
«TestDose» في أي مكان، والاسم ده موجود في الحالتين: السطر الهادي
(`_quietLine`) والكارت الذهبي (`_card`) — يعني كان هيعدّي على شاشة بتقول
«لسه ما اتأكدتش». **فخ الحارس الفاضي تاني**، وده تالت مرة.

**إزاي «يومك» بتعرض جرعة اتأكّدت** (من `day_rail.dart` و`now_card.dart`):
- **مأخوذة** → `_quietLine`: أيقونة ✓ (من غير نص)، اسم الدوا بخط mono،
  و`say.takenAt(time)` = «أخدته ٧:٣٠ ص». **ما بتتشالش من السكة أبداً.**
- **مش مأخوذة** → `_card` بحافة ذهبية + «لسه ما اتأكدتش»، و«الآن» بيقول
  «لسه ما اتأكدتش — كان معادها …». الجملة دي هي علامة «مش مؤكّدة» في
  الاتنين.
فالتأكيد بقى على «أخدته <حاجة>» بنمط (`Pattern`) — زرار الستارة نصه
«أخدته» بالظبط من غير أي حاجة بعده، فالنمط بيطلب كلمة تانية ومفيش خلط.
والصفحة بتتلف بالتمرير لأن «جدول النهاردة» تحت «خلال ٤٨ ساعة» وكارت
المية، وUiAutomator بيشوف المعروض بس.

**والخطوة دي بقت تفرّق بين «بايتة» و«مستخبية»** — وده اللي مكانش موجود:
«لسه ما اتأكدتش» على الشاشة = **بايتة** وبتقع بالكلمة دي؛ ولا هي ولا
«أخدته …» بعد لفّ الصفحة = **مستخبية** أو الشاشة مش «يومك» أصلاً.
قراية استعلام الـmain isolate من الاختبار مش ممكنة من غير باب في `lib/`،
فالبديل المكتوب في الوعد هو ده: الشاشة **لازم** ما تعرضهاش غير مؤكّدة.

**والخطر الحقيقي اللي الخطوة دي موجودة عشانه — فرضية، مش نتيجة:**
استعلامات drift المتدفّقة بتعيد الإرسال على الكتابات اللي عدّت من **نفس
نسخة القاعدة**. الـisolate بيكتب من نسخته. والعملية حية (الحالة العادية
على موبايل حقيقي)، فـ«يومك» بتاعة الـmain isolate ممكن عمرها ما تعرف
بالكتابة: المريض يفتح التطبيق، يلاقي «لسه ما اتأكدتش»، ويأكّد تاني.
الخطوة دي هي اللي هتقول إن ده بيحصل ولا لأ — وبتقوله بالاسم.

**والشاشة بقت بتتصوّر لما تقع**: `dumpWindowHierarchy` (بتتطبع في التقرير
كمان، عشان لو السحب من الجهاز فشل) و`takeScreenshot`، في الكاش الخارجي
بتاع التطبيق، والـworkflow بيسحبهم في `artifacts/screen/`. **تتقرا، مش
تتوصف من الكود.**

**و٩.٦ ثانية من الدوسة لسطر النهاية.** آمنة في السكّة دي لأن العملية حية
ومثبّتة على `adj 0`. لما السكّة المقتولة تتجرّب فعلاً، الـ
`BroadcastReceiver` بيرجع والعملية بتنزل لأولوية «مخزّنة» — والشغل ده
ممكن يتقطع في نصه. الرقم متسجّل جنب اختبار السكّة المقتولة، مش كإنه
«تمام».

**التشغيلة الخامسة: التطبيق عدّى كل خطوة. الاختبار هو اللي مقدرش يشوفه.**
شجرة النوافذ (اللي بتتطبع، والسبب الوحيد إن التشغيلة دي اتقرت أصلاً)
بتقول إن الشاشة «يومك» والجرعة **مؤكَّدة**:

```
content-desc="الصحيان — ٦:٣٠ ص\nالفطار — ٧:٣٠ ص\nTestDose\nأخدته ٨:٣٩ ص\nالغدا — ٢:٠٠ م…"
```

**فلاتر بيطلّع نصه لـUiAutomator في `content-desc`، مش في `text`** —
ومدموج لكل عقدة دلالات، يعني السكة كلها عقدة واحدة وصفها سطور بأسطر
جديدة. الخطوة الخامسة كانت بتقارن بـ`By.text`، فعمرها ما كانت هتلاقي أي
حاجة رسمتها فلاتر. الخطوة التالتة نجحت لأن ستارة الإشعارات `TextView`
أصلي. و«TestDose مش موجودة» في تشغيلة ٢٢ كانت **نفس السبب** — مكانتش
بايتة ولا مستخبية.

**فالقاعدة: أي مقارنة على واجهة فلاتر بتبقى على `content-desc`
(`By.desc` / `descContains` / نمط على الوصف)، وعمرها ما تبقى `By.text`.**
والوصف بلوك متعدد السطور، فالنمط لازم يلفّه بـ`.*` وعلم `DOTALL` — وده
بالظبط اللي `By.descContains` بتعمله جوّه (`Patterns.contains` =
`^.*<quoted>.*$` بعلم `DOTALL`، مقروء من bytecode المكتبة مش من الذاكرة).
**والاسم بيوصل ملفوف بعلامات عزل اتجاه** (U+202A…U+202C) لأن فلاتر بيلفّ
النص اللاتيني — فمفيش مقارنة على اسم الدوا نفسه خالص؛ المقارنة على
«أخدته <وقت>».

**ودي رابع مرة تبقى أداة القياس هي العطل** — وده مش صدفة، ده نمط:
١. تأكيد `dumpsys` اللي كان بيعدّي وهو فاضي (أنبوب في `executeShellCommand`).
٢. قراية إطار أندرويد اللي كانت بتقلب الملف برّه WAL.
٣. تأكيد بيدوّر على اسم موجود في الحالتين — ما كانش يقدر يقع لسببه.
٤. ومقارنة على الخاصية الغلط، فعمرها ما شافت حاجة رسمتها فلاتر.
**قبل ما تتهم `lib/`، اسأل الأول: هل الأداة بتقيس اللي بتقول إنها
بتقيسه؟** في أربع تشغيلات، الإجابة كانت «لأ» أربع مرات.

**واللقطة رجعت `ok=false` وصفر بايت، والسبب لسه مش متأكَّد — بس اتحصر في
اتنين، بدليل من bytecode المكتبة.** في
`UiDevice.takeScreenshot(File, float, int)` (uiautomator 2.3.0) فيه
طريقين بس بيرجّعوا false: `UiAutomation.takeScreenshot()` ترجّع `null`
(بتسجّل `Failed to take screenshot.` و**ما بتعملش الملف**)، أو الكتابة
تقع (بتسجّل `Failed to save screenshot.` والملف بيبقى موجود وفاضي).
السطر اللي كنا بنطبعه كان `length()` بس — **وهي صفر في الحالتين**، لأن
ملف مش موجود بيرجّع صفر برضه. فالتسجيل نفسه مكانش يقدر يفرّق. دلوقتي
بيطبع `exists()`، وبيجيب سطور المكتبة من اللوج عشان المكتبة تقول بلسانها
هي راحت فين.
**وفيه سبب تاني منفصل خلّى الملفات ما توصلش الأرتيفاكتس:** الكاش الخارجي
تحت `/sdcard/Android/data/<pkg>/`، وده المسار اللي التخزين المحدود
بيصعّب سحبه بـ`adb` — عشان كده الشجرة وصلت **بالطباعة** مش بالسحب. فبقى
فيه لقطة تانية بآلية مختلفة خالص، `screencap` من الشل في
`/data/local/tmp`، واللي `adb pull` بيوصله دايماً. لو الاتنين رجعوا
فاضي يبقى مفيش حاجة تتصوّر؛ ولو الشل نجح والمكتبة لأ، يبقى العطل في
طريق `UiAutomation`.

**والزمن بيتحرّك: ٣.٩ ثانية من الدوسة لـ`handled=ok` في التشغيلة دي، بعد
٩.٦ في اللي قبلها.** الرقمين على محاكي CI والعملية حية ومثبّتة — يعني
مفيش رقم منهم قياس للسكّة المقتولة.

**التشغيلة السادسة: الاختبار نجح. الشغلانة حمرا لسبب في سكربت الـCI.**

```
09:16:09.886  Isolate: دخلنا المعالج — action=taken
09:16:11.913  Isolate: خلص المعالج — handled=ok action=taken
FKTEST: journal_mode في النسخة = wal، taken = 1
09:16:53.539  I/TestRunner: run finished: 1 tests, 0 failed, 0 ignored
```

**فالسلسلة اتثبتت على أندرويد والعملية حية**: إشعار ← «أخدته» ← دارت ←
صف الجرعة ← «يومك» بتعرضها مؤكَّدة. ~٦ ثواني من الدوسة لـ`handled=ok`.

**وده خامس عطل في أداة القياس — والمرة دي الأداة هي الـCI نفسه.**
`reactivecircus/android-emulator-runner` بينفّذ **كل سطر** من `script:`
في صدفة لوحده. ده متأكَّد من لوج الشغلانة نفسها، مش من التوثيق:

```
[command]/usr/bin/sh -c adb shell settings put global window_animation_scale 0
[command]/usr/bin/sh -c adb install -r -g … || true
[command]/usr/bin/sh -c cd android && ./gradlew :app:connectedDebugAndroidTest --info
```

أربع نتايج، كلها كانت شغّالة في صمت:
- `set +e` / `set -e` ما بيعدّوش للسطر اللي بعده.
- `STATUS=$?` بيضيع، فـ`exit $STATUS` **عمره ما نقل نتيجة الاختبار**.
- `cd android` ما بيفضلش.
- وسطر متقسّم بـ`\` بيتنفّذ **نصّين**: النص التاني — اللي فيه
  `|| true` — بيروح، فالنص الأول بيقع لوحده.
وأي سطر بيقع بينهي الخطوة فوراً، فاللي بعده عمره ما بيجري: عشان كده
`logcat-ours.txt` ما اتعملش ولا مرة، مع إن سطره منتهي بـ`|| true` ومش
ممكن يقع. والسبب المباشر للأحمر كان `adb pull` على مجلد لقطات **مش
موجود في تشغيلة ناجحة** → بيرجّع ١.

**فالقاعدة: شغلانة حمرا مش معناها اختبار أحمر.** أول حاجة تتقري هي سطر
`TestRunner: run finished` — هو اللي بيقول نجح ولا لأ. السكربت بقى
بيطبعه في `artifacts/verdict.txt` وفي مخرج الشغلانة، فوق كل حاجة.

اللي اتعمل: المنطق كله اتنقل لـ`.github/scripts/android-lockscreen.sh`
(**مش `tools/`** — دي في `.gitignore` دلوقتي)، `set -uo pipefail` من غير
`-e`، حالة جرادل بتتمسك في متغيّر، جمع الأدلة كله `|| true` وما يقدرش
يحمّر الشغلانة، والخروج بحالة جرادل وبس. والـ`script:` في الـworkflow
بقى **سطر واحد** بينده الملف. متأكَّد بمنصّة تجربة بـ`adb` بيقع دايماً
و`gradlew` بحالة خروج مختارة: الحالة بتوصل كما هي (٠ و١ و٧)، والأدلة
بتتجمع في الحالتين.

**وتقرير الاختبار عمره ما اترفع، لسبب تاني منفصل: مجلد البناء منقول.**
`android/build.gradle.kts` بيحط `rootProject.layout.buildDirectory` على
`../../build`، فتقارير وحدة app في `build/app/reports/androidTests/` و
`build/app/outputs/androidTest-results/` — والـworkflow كان بيرفع
`android/app/build/…`، وهو مسار مش موجود ولا مرة. مجلد مش موجود في
`upload-artifact` بيعدّي بتحذير، مش بخطأ — فالنقص كان ساكت زي الباقي.

**التشغيلة السابعة: إصلاح السكربت اشتغل.** لأول مرة الأرتيفاكت فيه
تقرير جرادل، والـXML، و`verdict.txt`، و`logcat-ours.txt` — الأربعة اللي
عمرهم ما وصلوا في ست تشغيلات.

**ووقعت أبدري، في خطوة عدّت تلات مرات ورا بعض** — وده **سادس** عطل في
أداة القياس، وأول واحد **متقطّع**:

```
09:48:04.253  UiObject2: Long-clicking on (535, 702)
              W/UiObject2: Long-clicking on non-long-clickable object
09:48:05.010  FKDIAG Notif: _onTap action=null payload={"v":1,…}
              وبعدها ١٠ ثواني «Node not found» على «أخدته»
```

الضغطة المطوّلة اللي كانت بتفرد الإشعار نزلت **دوسة عادية** على محاكي
مشغول. **والتطبيق عمل الصح بالظبط**: دوسة على جسم الإشعار المفروض
تفتحه. النظام شال الإشعار، وراح معاه زرار الأكشن — فالرسالة قرت «الزرار
ما ظهرش»، وهي كدب عن التطبيق.

**فالقاعدة: أي إيماءة على واجهة النظام معلّقة على التوقيت. استهدف
عنصر بعينه بمعرّفه، مش منطقة بإيماءة.** ضغطة مطوّلة ممكن تنزل دوسة،
وسحبة ممكن تنزل ضغطة، ومفيش أي منهم بيقول لك إنه اتحوّل — بيديك نتيجة
مختلفة وخلاص.

اللي اتعمل: الضغطة المطوّلة **اتشالت خالص** (مفيش أي لمسة على جسم
الإشعار)، والاختبار بيدوّر على «أخدته» **الأول** (أحدث إشعار في الستارة
بيبقى مفرود غالباً)، ولو مش موجود بيفرد من **زرار الفرد نفسه**.

**وزرار الفرد على صورة API 34 دي — مقروء من موارد المنصة المثبّتة
(`platforms/android-34/data/res`)، مش من الذاكرة:**
`layout/notification_expand_button.xml` بيعلن
`android:id="@+id/expand_button"` على
`com.android.internal.widget.NotificationExpandButton`،
و`notification_template_header.xml` بيضمّه — فالمعرّف اللي UiAutomator
بيشوفه هو **`android:id/expand_button`**، ووصف محتواه
`@string/expand_button_content_description_collapsed` = **«Expand»**
(ومفرود «Collapse»). **الصورة بتعرض الاتنين**، والمعرّف هو الأساس
والوصف بديل — الوصف نص متُرجم بيتغيّر مع لغة الجهاز والمعرّف لأ.
(`expand_button` مش في `public-final.xml`، وده ما يفرقش:
`getViewIdResourceName()` بيرجّع المعرّفات الداخلية برضه.)

**وفيه حارس دلوقتي بيمنع العطل ده يتنكّر تاني:** لو سطر
`Notif: _onTap action=null` ظهر في اللوج بين فتح الستارة ودوسة الزرار،
الاختبار بيقع فوراً برسالة بتقول إن **الاختبار** لمس الجسم — مش إن
الزرار ما اترسمش.

## تفضيلات المتابع (٢٢ سبتمبر ٢٠٢٦)

أربع أسئلة بعد ما الابن يستبدل الكود، كل واحد على شاشته، وكلهم بيتخطّوا —
و**الأربعة بيتغيّروا بعدين من إعداداته**. الإعدادات دي بتغيّر **اللي بيوصل
الابن وبس**: تذكير الأب، وتوقيت السلّم، وأي حاجة على جهاز الأب ما
بتتلمسش (اختبار الخطة الذهبية أخضر).

**وتلات قرارات صحّحت المواصفة نفسها، كلها بتاريخ النهارده:**

- **مفيش «الأدوية المهمة بس».** المواصفة كانت بتفترض علامة «دوا مهم»؛
  البحث في `lib/` و`supabase/` طلّع إن **العلامة دي مش موجودة خالص** —
  اتشالت عن قصد في ٢ سبتمبر ٢٠٢٦ لأن اختيار إن دوا مهم وتاني لأ حكم طبي
  (القاعدة ٦). فالاختيار التاني مكانش هيلاقي حاجة يفلتر عليها، ومعناه
  الحقيقي «مفيش تنبيهات خالص» — إعداد بيسكت في صمت، وده اللي المواصفة
  نفسها بتمنعه. **المالك شال الاختيار**: سؤال ٢ بقى اختيار واحد («أي
  جرعة تفوت») بسببه مكتوب قدّام الابن. `AlertScope` فيها قيمة واحدة،
  والعمود والقيد في السحابة موجودين — فاليوم اللي تبقى فيه العلامة
  موجودة، فتح التاني سطر واحد مش هجرة.
- **ساعات الهدوء للمواعيد والملخصات بس.** التعريف القديم («اهدى إلا لو
  الدوا مهم») كان بيعتمد على نفس العلامة المش موجودة — فهو يا فاضي يا
  **خطر**: جرعة فايتة تتحجز لحد الصبح هي بالظبط الحاجة اللي السلّم موجود
  عشان يمنعها. التعريف الجديد: الهدوء بيمسك **إشعارات المواعيد والملخصات
  على موبايل الابن وبس**، وتنبيه الجرعة الفايتة بيعدّي في أي وقت.
  والسطر ده مكتوب على الشاشة نفسها من مصدر واحد (`quietHoursPromise`):
  «أي جرعة تفوت هتوصلك في أي وقت — الهدوء للمواعيد والملخصات بس.»
  **واللي بيتأجّل بيتأجّل لآخر النافذة، ما بيتلغيش** (`heldUntil`).
- **الدعوة: الابن بيبعت طلب، والأب بيوافق.** المواصفة كانت بتقول الابن
  يعمل كود زي الأب؛ بس `create_invite` بيرفض أي حد غير المالك
  (`private.owns_patient`)، وده «الباب الوحيد في الحيطة». فتحه للمتابعين
  كان معناه إن ابن يقدر يدخّل ناس على بيانات أبوه الصحية من غير ما
  الأب يعرف. **قرار المالك**: الابن بيشارك، والأب بيوافق على موبايله،
  والمنع على السيرفر مش مخبّي في الواجهة. دي **جولة لوحدها بعد دي**؛
  النهارده سؤال ٤ بيقول «هنبعت طلب لوالدك يوافق عليه» ويقف — **مفيش كود
  بيتعمل، وبوابة `create_invite` زي ما هي**. والسقف (٥ متابعين) مكتوب
  على الشاشة بما يحصل عنده.

**والشاشة اتوصّلت بالتطبيق — الجولة اللي بنتها ما وصّلتهاش.**
`9a0a5a0` بنت الشاشة وبنت `SupabaseCaregiverPreferences`، وولا واحدة
اتنده عليها من `lib/`: الشاشة كان بيشوفها ملف اختبارها **وبس**، والخدمة
عمرها ما اتبنت. الهجرة اتطبّقت واتأكّدت و`caregiver_preferences` فضل صفر
صف — لأن الابن عمره ما شاف السؤال. **اختبار الشاشة لوحدها كان أخضر طول
الوقت وهي مش موصّلة بحاجة**، وده الفرق بين «الشاشة شغّالة» و«الشاشة
موجودة في التطبيق».
- الخدمة بتتبني جنب باقي خدمات السحابة (`initSupabaseAuth`) وبتتمرّر
  `main` → `buildServices` → `AppScope`. مفيش global.
- **مدخل واحد بيغطّي (أ) و(ب)**: بوابة في `CaregiverShell` — بترسم
  الأسئلة **بدل** التبويبات، فاللي خارج من استبدال الكود بيشوفها قبل
  البيت، واللي مربوط من زمان بيشوفها أول فتحة. مدخلين منفصلين كانوا
  هيبقوا مكانين لنفس القرار، حر إن واحد يتنسي.
- **والشِل بقى بيسمع للصورة**: التبويبات بتسمع كل واحد لوحده، والشِل
  نفسه ماكانش — فكان بيتبني مرة والصورة `null`، والبوابة عمرها ما تشوف
  uuid المريض. التوصيل كان «موجود» وهو مش شغّال، والاختبار هو اللي مسكه.
- **فشل القراية مش إجابة**: أوفلاين → ما بنسألش **وما بنسجّلش تخطّي**
  (`OnboardingDecision.unknown`)، وإلا عطل شبكة لحظي بيسكّت السؤال
  للأبد. والتخطّي بيتسجّل محلياً لكل مريض (`shared_preferences`).
- **وفشل الحفظ بيتقال**: الشاشة بتفضل على نفس السؤال برسالة وزرار «حاول
  تاني»، وعمرها ما بتقول «تمام» والصف ما اتكتبش.
- **(ج) في إعدادات الابن**: «بياناتك وتنبيهاتك» بتفتح نفس الشاشة متعبّية
  من `load()` — شاشة فاضية بتخلّيه يفتكر إن اللي كتبه راح.
- **وكارت حسابه بيرحّب باسمه**: «أهلاً يا محمد — ابن الحاج أحمد»
  (`welcomeLine`). الصلة بتتضاف للابن والبنت بس — «حد تاني» نصّه حر
  وتركيبه في جملة عن المريض بيطلّع عربي غلط. من غير اسم: «أهلاً بيك»،
  مفيش اسم مخترع.
- **وسطر الأب بقى بيقرا فعلاً**: `CareCircleRow` كان بياخد قايمة فاضية
  دايماً؛ دلوقتي «يومك» بتنده `followers()` مرة عند الفتح، وبتفشل في
  صمت زي المزامنة.

**التخزين في السحابة، مش في drift** (`0020_caregiver_preferences`): جهاز
الابن مالوش نسخة محلية من أي حاجة (قاعدة ٣.٥)، والتفضيلات لازم تعيش بعد
إعادة التنصيب و**الأب لازم يقرا منها الاسم والصلة**.
- RLS على قاعدة ٠٠٠٥: كل سياسة بتقارن `caregiver_id` بتاع الصف نفسه —
  مفيش دالة بتستعلم نفس الجدول. والإدخال كمان بيشترط
  `private.is_accepted_caregiver`، وإلا صاحب مفتاح عرف uuid مريض يقدر
  يرمي صفوف على الجدول من برّه الدائرة.
- **والأب بيعدّي على دالة، مش على سياسة**: `public.followers_of_patient`
  بترجّع **الاسم والصلة وبس**. سياسات بوستجرس على مستوى **الصف** مش
  العمود، فلو اتسمح له بالصف كان هيقرا ساعات هدوء ابنه ونطاق تنبيهه
  كمان. الفحص الذاتي بيثبت الاتنين: الأب `count(*) = 0` على الجدول،
  و`count(*) = 1` من الدالة.
- **و`due_escalations` ما بتقراش ساعات الهدوء خالص** — اختبار بيقرا جسم
  الدالة ويوقع لو اسم أي عمود هدوء ظهر فيها. ده الفرق بين «الهدوء
  للمواعيد» و«الهدوء بيحجز جرعة فايتة».

**الصيغة بتمشي مع الصلة، مش مع الاسم** (`domain/care/follower_profile`):
«محمد ابنك بيتابعك» / «سارة بنتك بتتابعك» / «أحمد (أخوه) بيتابعك». الاسم
ما بيقولش ولد ولا بنت، والتخمين منه بيغلط في ناس حقيقيين — فالابن هو اللي
بيقول صلته. من غير صلة: الاسم لوحده، من غير أي افتراض.

**سكّة الاشتراك — `private.follower_subscription_active`.** ده **المكان
الوحيد** اللي فحص الاشتراك هيتحط فيه، وبيرجّع `true` دايماً النهارده
لأن مفيش كود دفع (مستني حساب Apple Developer، الدين ٣). بيتنده من
`due_escalations` — تعريف «مين يستاهل تنبيه» الواحد — وموثّق عنده إنه
كمان المكان اللي بيعرف إمتى الخبرين بتوع سؤال السلامة ٢ في «Pricing»
يتبعتوا. `verify_migrations.sql` بيتأكد من وجوده **بالاسم** ومن إن
`due_escalations` بتنده عليه (`funcsrc`) — وجود الدالة لوحده بيكدب،
لأنها بتتكتب من جديد في خمس هجرات.

## الممرض / المرافق — علاقة بدور وصلاحيات (٢٤ سبتمبر ٢٠٢٦، تعليق المختبِر ٧)

**الممرض علاقة رعاية ليها دور وصلاحيات، مش دخول مشترك** (قرار المالك).
الأدوار `follower` («متابع»: بيشوف وبيتنبّه) و`nurse` («ممرض / مرافق»:
مرآة). الصلاحيات على العلاقة: `can_confirm` (للممرض افتراضياً، للمتابع لأ)
و`can_edit_meds` (مقفولة للاتنين لحد ما المريض يفتحها). **موبايل الأب
مصدر الحقيقة للتذكير**، والسلّم ومهلة الـ٦٠ وتنبيه الابن ما اتلمسوش —
اختبار الخطة الذهبية والمجدول أخضر من غير تعديل.

- **`0023_nurse_role.sql`** (ملف بس — ما اتطبّقش): الأعمدة التلاتة على
  `care_relationships` بافتراضيات بتسيب كل متابع موجود زي ما هو؛ `role`
  على `invite_codes`؛ `create_invite(uuid, text default 'follower')` (التوقيع
  القديم اتشال عشان نداء PostgREST ما يبقاش غامضاً) و`redeem_invite` بتنقل
  الدور وصلاحيته للعلاقة؛ **`proxy_confirmations`**: صف واحد لكل حدث،
  إدخال للممرض المسموح له على حدث **مستحق** لمريضه وباسمه هو
  (`private.can_confirm_for` + `private.dose_confirmable`)، ولا update ولا
  delete لحد؛ `private.due_escalations` بتستبعد أي حدث عليه تأكيد نيابةً
  (**السيرفر بيعتبرها مؤكَّدة من لحظة الصف**، قبل ما موبايل الأب يسحب)؛
  `followers_with_permissions` / `set_follower_permissions` /
  `remove_follower` للمالك بس (الشيل = `revoked`، مش مسح). الفحص الذاتي
  بيثبت الستة: ممرض بيأكّد، ومن غير صلاحية / المتابع / مريض تاني / جرعة
  جاية / باسم حد تاني مرفوضين، والتصعيد بيسكت.
- **التأكيد نيابةً مش كتابة على `dose_events`** — الصف ملك موبايل الأب.
  موبايله بيسحب (`ProxyConfirmationPuller`، `lib/data/sync/proxy_pull.dart`
  — **السحبة الوحيدة من السحابة لـdrift**، وللتأكيدات وبس) عند الفتح
  (`AppRoot.initState`) والرجوع للمقدمة وبعد كل رفعة ناجحة
  (`SyncService.afterPush`). تأكيد اتسحب = «أخدته» بالظبط (القاعدة ٥):
  `DoseEventRepository.confirmByProxy` بيكتب `taken` باسمه في
  `dose_events.acted_by` (**drift v24**، محلي، مش بيترفع) **لو لسه مش
  مؤكَّد** — قرار المريض بنفسه ما بيتكتبش فوقه — وبعدها
  `scheduler.afterConfirmation` بتلغي الجرعة والتأجيل والدرجتين والإعادات
  العشرة وتعيد الجدولة. `proxy_pull_test` بيثبت الإلغاء بالأرقام.
  «يومك» بتقول «أكّدها {اسم} ٧:٣٠ ص» (`proxyConfirmedLine`، من غير اسم
  «أكّدها حد بيتابعك» — مفيش اسم مخترع).
- **الدعوة بدور**: شاشة الكود فيها شريحتين كبار («متابع» افتراضياً /
  «ممرض / مرافق»)؛ تغيير الشريحة بيعمل كود جديد بدوره
  (`CareCircleAdmin.createRoleInvite`). الأكواد والعلاقات القديمة كلها
  «متابع».
- **الممرض: تبويب «مرآة» مكان «متابعة»** (`CaregiverMirrorScreen`): «الآن»
  وجدول النهارده من الصورة المرفوعة — **ما بنحلّش مراسي** — و«أكّد إنه
  أخدها» على المستحق/الفايت لو `can_confirm`، وإلا لوحة بتقول إنه بيشوف
  بس. بعد الدوسة الصف بيقول «أكّدتها ✓ — مستنية موبايله يوصله» من
  `CaregiverSnapshot.proxied` لحد ما يسحبها. الشِل بيقرا الدور من
  `CaregiverPatient.permissions` (من صف العلاقة نفسه).
- **الإعدادات → «اللي بيتابعوك»** (`FollowersScreen`): كل واحد بدوره،
  تغيير الدور (لممرض بيفتح التأكيد معاه، لمتابع بيقفله)، «يعدّل الأدوية»
  مفتاح بكلمته، و«شيله» بتأكيد بالاسم.
- **المرحلة ب — تعديل الأدوية من المرآة** (`0024_medication_changes.sql`،
  ملف بس): الممرض اللي معاه `can_edit_meds` بيبعت **تغيير معلّق** — إضافة
  (المسوّدة كاملة: الاسم والمراسي/الساعة والجرعة والمدة والغرض
  والتعليمات ونوع التنبيه والبداية)، أو إيقاف، أو تعديل جرعة — صف في
  `medication_changes` (إدخال بـ`private.can_edit_meds_for`، التعليم
  بالنتيجة للمالك بس). موبايل الأب بيسحب (`MedicationChangePuller`) ويطبّق
  **بسكّته هو**: `addMedicationWithDoses` (المراسي بتتحلّ بروتين الأب —
  فورم الممرض بيعرض `DayRoutine.fallback` للمعاينة بس، من
  `features/medication/nurse_draft.dart` عشان حارس «الابن ما يستوردش
  الجدولة» يفضل صادق)، `stopMedication`، أو الجرعة — وبعدها `rescheduleAll`.
  **تعديل الأب المحلي بيكسب**: `updated_at_ms` بتاع الدوا أحدث من
  `created_at` بتاع التغيير → `conflict` على الصف وسطر `diag`، ومفيش
  كتابة. «يومك» بتقول «{اسم} ضاف دوا X» (`CircleNotices`، محفوظة في
  `shared_preferences` لحد «تمام»). عند الممرض الصف بيقول «اتبعت لموبايله —
  هيتطبّق أول ما يفتح التطبيق».
- **قرارات اتاخدت من غير سؤال**: «تعديل» الدوا عند الممرض = الجرعة بس
  (المواعيد بتتغيّر بإيقاف وإضافة)؛ الممرض بيشوف «مرآة» **بدل** «متابعة»
  (تنبيهات السيرفر لسه بتوصله لأنه علاقة مقبولة)؛ الاسم اللي بيتكتب على
  التأكيد هو اسمه في «بياناتك وتنبيهاتك»، ومن غيره null.

## حساب الممرض — نوع حساب لوحده، مرآة لتطبيق المريض (٢٤ سبتمبر ٢٠٢٦، قرار المالك)

**بيحل محل «مرآة» اللي كانت تبويب جوّه شاشة الابن.** الممرض/المرافق
داخل من باب لوحده، وبيشوف تطبيق المريض نفسه بداتا المريض، ومربوط بحساب
المريض كواحد من الخمس مقاعد بتوع اشتراك العيلة (سقف `redeem_invite` زي
ما هو).

- **شاشة البداية تلات أبواب**: «التليفون ده ليا» / «معايا كود متابعة» —
  «ابن، بنت أو قريب» / «أنا ممرض / مرافق» — «هتابع مريض وأساعده في
  أدويته». **الباب بيمشي لحد السيرفر**: `SignInScreen(door)` ←
  `RedeemCodeScreen(door)` ← `RoleRedeem.redeemInviteAt` ←
  `redeem_invite(p_code, p_expect_role)`. كود متابع في باب الممرض: «الكود
  ده لمتابع — اطلب من المريض كود ممرض»، والعكس بيقوله يرجع لباب الممرض —
  **والكود ما بيتحرقش** (الفحص قبل أي كتابة؛ الفحص الذاتي بيثبت إن نفس
  الكود بيشتغل بعدها في الباب الصح). `circle_full` بقى ليه جملة.
- **المريض لما يعمل كود ممرض بيتسأل مرة** «يقدر يعدّل الأدوية
  والمواعيد؟» — والإجابة على الكود (`invite_codes.can_edit_meds`) وبعدين
  على العلاقة. قفل الورقة من غير إجابة = الدور ما اتغيّرش. بتتغيّر بعدين
  من «اللي بيتابعوك».
- **التطبيق** (`lib/features/nurse/`، بمقاسات المريض مش كثافة الابن):
  `NurseHeader` ثابتة فوق كل شاشة «بتتابع: {اسم}» + «غيّر» لو أكتر من
  مريض (`MultiPatientRemote` + `CaregiverSnapshotHolder.selectPatient`) +
  «طوارئ» (كارت المريض، من غير أرقام). التبويبات: «يومك» (الآن، جدول
  النهارده، «أكّد إنه أخدها» على الفايت والمستحق بس — نفس شرط
  `private.dose_confirmable` — و«معلومة تهمك» بنفس معلومة المريض
  النهارده) / «أدويته» (الجرعة والميعاد بكلامه والغرض والتعليمات ونوع
  التنبيه) / «السجل» (مواعيدك الجاية / أوراقك / للدكتور، والورقة بتفتح
  بحقولها، و«للدكتور» فيها «اطبع أو ابعت الملف» بنفس `buildExportPdf`) /
  «الإعدادات». عناوين الشاشات المفتوحة في جسمها مش في الترويسة (كانت
  بتفيض بالخط الكبير).
- **المسموح**: التأكيد نيابةً، ولو `can_edit_meds`: ضيف/عدّل الجرعة/وقّف
  دوا، و«ميعاد جديد» و«ورقة جديدة» — **كلها طلبات معلّقة** (جدول ٠٠٢٤
  اتوسّع بـ`record` و`appointment`) بتتطبّق على موبايل المريض بسكّته:
  الميعاد من `CheckupService.bookAppointment` — **الدالة اللي زرار المريض
  نفسه بقى بيعدّي منها** — بإشعاراته، والورقة من `RecordsRepository.add`
  من غير صورة. «يومك» عند المريض بتسمّي الحاجة (`changeSubject`: «سارة
  حط ميعاد زيارة د. حسام»، عمرها ما تقول «دوا» عن ميعاد).
  **الممنوع بالتصميم**: روتين المريض وإعداداته واللي بيتابعوه واشتراكه —
  مفيش واجهة سحابة ليهم للممرض أصلاً.
- **الاشتراك**: الكتابة (تأكيد وطلبات) مع التجربة/النشط بس — في SQL
  (`private.circle_writes_allowed` في سياسات الإدخال) وفي الواجهة
  (`NurseController.writesAllowed`). القراية شغّالة دايماً عشان كارت
  «التنبيهات واقفة» و«جدّد» يتقروا.
- **«فكّرني بمواعيده»** (مفتوح افتراضياً، `nurse.remind`): تذكيرات محلية
  على موبايل الممرض من **أوقات موبايل المريض بالحرف** — الممرض ما بيحلّش
  مراسي (`no_scheduling_imports_test` بقى بيقرا `lib/features/nurse`).
  نطاق 180M (الجدول فوق)، نغمة الجرعة على قناة `fakkarni_nurse_doses`،
  وزرار واحد «أكّد إنه أخدها» بيفتح التطبيق = تأكيد نيابةً. **الزرار ليه
  باب لوحده** (`NotificationService.onNurseAction`)؛ `isAction` ما بيشملوش
  فعمره ما يوصل معالج «أخدته» بتاع المريض، والإطلاق منه بيتعالج بعد ما
  السحابة تتبني. القفل أو خلوص الاشتراك بيلغي تذكيرات الممرض كلها.
- **صور الورق**: بتفضل على موبايل المريض إلا لو فتح «شارك صور الورق مع
  الممرض» (مقفول افتراضياً، في إعداداته). ساعتها `PaperShareService`
  (`lib/data/files/` — مش `lib/data/care/`، عشان حارس «مسار الصورة ما
  يطلعش» يفضل صادق: **المسار عمره ما بيطلع، البايتس بس بإذنه**) بيرفع من
  المقدمة لباكت خاص `patient-papers/{patient}/{record}.jpg`؛ القراية
  للمالك وممرضينه بس، المتابع لأ (RLS بدوال `private.can_read_paper`).
  القفل بيمسح كل اللي اترفع، وسجل ممسوح بتتمسح صورته. من غير المشاركة
  الممرض بيشوف الورقة وسطر «الصورة على موبايل المريض» (للروشتة والتحليل
  والأشعة بس — ورقة مكتوبة بالإيد غالباً مالهاش صورة). سطر «دائرة
  الرعاية» عند المريض اتصلّح: كان بيقول إن محدش بيقدر يغيّر حاجة، وده بطل
  صح من جولة الممرض الأولى.
- **جرد الداتا** (ما في السحابة ← ما كان ناقص):
  | الحاجة | قبل ٠٠٢٦ | اللي اتعمل |
  |---|---|---|
  | الأدوية | الاسم والجرعة والإيقاف | + الغرض والتعليمات ونوع التنبيه (عمود + دفع + قراية) |
  | الجداول والمواعيد الثابتة | موجودة | — |
  | أحداث الجرعات | موجودة (امبارح→بكرة) | — |
  | السجلات والمتابعات والمواعيد | موجودة | — |
  | الطوارئ | من غير أرقام | — (الأرقام بتفضل برّه عن قصد) |
  | مدخلات المعلومة اليومية | الأحداث والمدد | + الغرض والتعليمات |
  | الصور | مش موجودة | باكت خاص بإذن المريض |
  **شبكة أمان للدفع**: لو نسخة وصلت قبل 0026، PostgREST بيرفض الأعمدة
  الجديدة (PGRST204/42703) — `_upsertAndMark` بيعيد الدفعة من غيرهم عشان
  الجرعات اللي بعدها ما تقفش (`optional_columns_test`)، والقراية عند
  المتابع بترجع لاستعلام من غيرهم. ده مش بديل للترتيب.
- **وإصلاح توصيل كان مكسور من ٣ جولات**: `main` ما كانش بيمرّر `careAdmin`
  ولا `proxy` ولا `medChanges` ولا الاشتراك لـ`buildServices` — على الجهاز
  كانوا null واختبارات الشاشات (اللي بتبني خدماتها بنفسها) خضرا.
  `main_wiring_test` بيقرا `CloudServices` ويوقع لو حقل مش متمرّر.
- **اتشالت** `CaregiverMirrorScreen` واختبارها؛ السلوك اتنقل
  لـ`nurse_app_test` (+ آيفون SE بخط ×١٫٣).
- **ما اتجرّبش على جهاز**: الإشعار وزراره على iOS وأندرويد، الرفع للباكت،
  والتنزيل منه. والهجرة نفسها ما اتشغّلتش.

## الكود في ست خانات، والكلام بيسمّي العيلة والممرض (٢٥ سبتمبر ٢٠٢٦)

- **`CodeBoxes`** (`lib/core/widgets/code_boxes.dart`) — الكتابة والعرض بنفس
  الشكل: ست خانات، **حقل واحد مخفي وراهم** (مش ست حقول) فالكيبورد والرجوع
  واللصق و«الكود من الرسايل» (`AutofillHints.oneTimeCode`) شغّالين زي
  النظام. من الشمال لليمين حتى في العربي، عربي أو غربي (بيطلع غربي
  للسيرفر، وبيتعرض عربي)، والسادس بيربط لوحده (الزرار فاضل لو حاجة
  وقفته). الكود اللي المريض بيعمله في نفس الخانات للقراية بس. `F.primary`
  مش موجود — الحد المركّز `F.green` (لون التطبيق الأساسي). الخانة
  بتصغر مع الشاشة والرقم جوّه `FittedBox` — SE بخط ×١٫٣ من غير فيض.
- **نوعين ناس حوالين المريض، بالاسم**: «متابع» (من العيلة) و«ممرض /
  مرافق». «اللي بيتابعوك» ← «عيلتك أو ممرضك»؛ «محدش بيتابعك لسه» ←
  «مفيش حد من عيلتك أو ممرضك لسه — ضيفه من هنا»؛ شرايح الكود «متابع — من
  العيلة» / «ممرض أو مرافق» (`FollowerRole.inviteLabel`)، وجمل النسخ
  والمشاركة بتسمّي اللي هيكتب الكود والباب (`holder` / `door`).
  **وسطر الدعوة لما محدش مربوط اتنقل تحت الجدول**: الجملة الجديدة أطول
  وبتلفّ سطرين على SE، وهامش «تأكيد الجرعة» تحت «ضيف» العايم بكسل ونص.
  السطر بالأسامي (لما فيه حد) فاضل فوق.

## «الرفيق الصوتي» — المرحلة ١: بيتكلم بس (٢٥ سبتمبر ٢٠٢٦)

**مفيش مايك، مفيش شبكة، مفيش ذكاء، مفيش هجرة.** صوت راجل مصري بيقول جمل
مكتوبة مسبقاً، وملخص اليوم بصوت الموبايل. **الكتالوج = `docs/voice/script_ar.md`**
(٤٦ رقم وجملة) — `lib/domain/voice/voice_catalog.dart` **مولّد منه بالحرف**
و`voice_catalog_test` بيقرا الماركداون ويقارن كل جملة، وبيتأكد إن لكل رقم
`assets/voices/<id>.mp3` ومفيش ملف يتيم (٥٫٢ ميجا، بتاعتنا، في الريبو).
عايز جملة جديدة؟ **في السكريبت الأول**، وبعدين تسجيلها، وبعدين الكود.
- **الطبقات**: `data/voice/voice_service.dart` — `VoiceService`
  (`ChangeNotifier`: شغّال/مقفول، سرعة، صوت، `caption` للترجمة المكتوبة،
  `speakLine(id)` تسجيل ← لو ناقص أو وقع → صوت الموبايل بنفس النص،
  `speakText` للملخص بصوت الموبايل **بس**، `stop()`). ثلاث واجهات
  بتنفيذ في ملف واحد لكل SDK: `audio_voice_player.dart` (`audioplayers`)،
  `device_tts.dart` (`flutter_tts`، عربي و`ar-EG` لو موجود)،
  `audio_focus.dart` (`audio_session`: بيوطّي اللي شغّال وإحنا بنتكلم
  وبيسلّم الجلسة بعدها — نغمة الجرعة إشعار نظام، مش بتتأثر). الإعدادات في
  `shared_preferences` (`voice.*`)، عرض على الموبايل ده.
- **تنبيه الجرعة بيكسب، من تلات أبواب**: `attachAlertSignal(NotificationService.lastPayload)`
  في `main` (دوسة الإشعار)، `onAction` بينده `stop()` قبل المعالج (زرار
  الإشعار)، و`ReminderScreen` بتنده `stop()` أول ما تتبني (أي باب).
  **الجدولة والإشعارات ما اتلمسوش**: `voice_alert_stop_test` بيوقع لو ملف
  صوت استورد الجدولة أو ملف جدولة ذكر الصوت؛ الخطة الذهبية والمجدول خضر.
  **الحد المكتوب**: إشعار بيرن والتطبيق مفتوح وبيتكلم — النظام ما بيندهناش
  عند الرنّة نفسها، فالكلام بيقف عند الدوسة مش عند الرنّة.
- **المقدمة أول شاشة في تنزيلة جديدة** (٢٦ سبتمبر ٢٠٢٦): `AppRoot` بيعرض
  `VoiceIntroScreen` **قبل** «مين ماسك التليفون ده؟» مرة واحدة (`voice.introDone`)،
  فلو قال «أيوه، اتكلّم» `onb_entry` بتتقال من أول شاشة. (كانت قبل «نتعرّف
  عليك» — الباب ده اتشال، `voice_placement_test` بيثبت إن المقدمة من الجذر.)
  `intro_01…05` ورا بعض ← «أيوه، اتكلم» / «لأ، من غير صوت» ← `intro_yes`/`intro_no`،
  و«تخطّي» ظاهر طول الوقت → أول سؤال. من غير خدمة صوت في `AppServices`
  (اختبار) مفيش مقدمة. إعادتها من الإعدادات ← «الرفيق الصوتي».
- **«🔊 ساعدني»** (`HelpButton(id)` / `HelpRow`) — **بيظهر بس لما الصوت شغّال**؛
  نمط كبار السن أكبر (٦٤ وخط ٢٤). الأماكن: «يومك» (العنوان، «الآن»، «مواعيدك
  الجاية»، «إنت ماشي إزاي» — `help_progress_missed` لما الأسبوع فيه فايتة —
  «معلومة تهمك»، «قرب يخلص»، «لسه ماتشترتش»)، نمط كبار السن (التحية وكارت
  الجرعة)، أسئلة الروتين، «ضيف دوا» (الاسم، الغرض، النمط، المواعيد، التنبيه،
  البداية)، التعديل (التعليمات، الصورة)، المراجعة (العنوان، «اشتريته؟»)،
  التصوير (روشتة/علبة)، «السجل» (الأربع أقسام — مش جنب عنوان الصفحة، اتشال ٢٦ سبتمبر)، «للدكتور»، القياسات
  (التاريخ والورقة)، كود الربط (+ `help_nurse` مع شريحة الممرض)، اشتراك
  العيلة، بطاقة الطوارئ، الإعدادات (نمط كبار السن، وشاشة الصوت).
  **جمل بتتقال لوحدها بعد الفعل** (مش زرار): `help_confirm_done` بعد
  التأكيد، `help_later` بعد التأجيل، `help_routine_skip` بعد «مش دلوقتي».
  **كل رقم ليه مكان دلوقتي** — الجدول في `voice_placement_test`.
- **خطوات البداية بتتكلم لوحدها** (٢٦ سبتمبر ٢٠٢٦): `onb_*` (١١ جملة، من
  `docs/voice/script_onboarding_ar.md` بالحرف) بتتقال **لوحدها** أول ما الصفحة
  تفتح لو قال «أيوه، اتكلّم» — `OnboardingVoice` (`features/onboarding/`)،
  مرة لكل صفحة، بتستنّى اللي بيتقال يخلص (`intro_yes`)، وبتسكت أول ما يكتب أو
  يختار أو يحرّك بكرة أو يسيب الصفحة. `onb_entry` على شاشة البداية (المقدمة قبلها، فبتتقال من أول فتحة)؛ «نتعرّف عليك» بقت
  **تلات صفحات** (الاسم ← الجنس ← السن، «رجوع» صفحة لورا، والحفظ بعد السن)؛
  `onb_routine_skip` مرة بعد `onb_wake` بس؛ «مش دلوقتي» بتقول
  `help_routine_skip` وبعدين سؤال الصفحة اللي بعدها؛ `onb_routine_done` بعد آخر
  سؤال وبيكمّل والشاشة بتتقفل. «ساعدني» فوق بيعيد جملة الصفحة، و`help_routine`
  اتنقل لـ«عدّل يومك». **وعطل اتصلّح في الطريق**: `speakLines` كانت بتقف بعد
  أول جملة دايماً (`_begin` بيزوّد الجيل مرتين)؛ `speakLine` بقت بترجّع
  «اتقالت لآخرها». واختبار الملفات بيسيب تسجيل رقمه مكتوب في سكريبت تاني تحت
  `docs/voice/` (مرحلة جاية) — أي ملف تاني بيوقّع.
- **كل جملة في مكانها — جدول ومقفول** (٢٦ سبتمبر ٢٠٢٦):
  `test/features/voice/voice_placement_test.dart` فيه خريطة رقم → الملفات اللي
  بتقوله، وبيوقّع لو رقم في الكتالوج ما بيتقالش من أي مكان، أو «ساعدني» /
  `speakLine` على رقم مش موجود، أو جملة اتنقلت، أو `onb_*` / `OnboardingVoice`
  ظهروا برّه البداية. المراجعة نقلت `help_add_med` لشيت «ضيف دوا» (بتوصف
  اختياراته)، و`help_family` لصف «دائرة الرعاية» (الباب اللي بيضيف منه — صف
  «عيلتك أو ممرضك» بيظهر بعد الربط بس)، ووصّلت التلاتة اللي ما كانوش
  بيتقالوا: `gen_try_hands` «ساعدني» جنب رسالة إن قراية الروشتة أو العلبة
  وقعت، `gen_no_medical` على سطر «اسأل دكتورك» في القياسات، و`gen_goodbye`
  بعد ما يقفل الصوت من «الرفيق الصوتي».
- **ملخص اليوم** (`domain/voice/briefing.dart` نقي + `features/voice/briefing_card.dart`):
  أول فتحة في يوم الروتين (`voice.briefingDay`)، لما الصوت شغّال، ولما فيه
  حاجة تتقال — من البيانات المحلية: لحظات التذكير النهارده، أول جرعة بكلام
  المرساة (`spokenTimingWording`)، مواعيد النهارده، وامبارح من `computeAdherence`
  نفسه (كامل ← «برافو، دي رابع يوم ورا بعض»؛ فايتة ← «النهارده يوم جديد،
  وأنا معاك»). الكارت بيكتب نفس الكلام و«اسمع تاني». **ما بيتقالش قبل ما كل
  مصادره توصل** (`ready`). الساعة من `spokenTime`: ٥ العصر بتتقال «٥:٠٠
  بالليل» — كلمة التطبيق الموجودة، مش الأمثلة في السكريبت.
- **الترجمة المكتوبة**: `VoiceCaptionOverlay` في جذر التطبيق — كل جملة
  بتتكتب تحت الشاشة مع «اسكت».
- **الخطوط الحمرا**: `voice_banned_words_test` بيمشي على الـ٤٦ جملة وعيّنات
  الملخص بكلمات القياسات (`adviceWords`) و«معلومة تهمك» (`offendersIn`)
  وكلمات تقنية. استثناءان مكتوبان بالاسم: «الحباية» في `help_photo` (الشيء
  المصوَّر) و«مرض» جوّه «ممرض».
- **ما اتجرّبش على جهاز**: التسجيل نفسه، صوت الموبايل بالعربي المصري،
  التوطية وتسليم الجلسة، وإن نغمة الجرعة بتعدّي فوق الكلام.

## «الرفيق الصوتي» — المرحلة ٢: بيسمع (إجابات مقفولة بس) (٢٦ سبتمبر ٢٠٢٦)

**مفيش ذكاء، مفيش سيرفر بتاعنا، مفيش هجرة، ومفيش تسجيل.** متعرّف كلام
الموبايل نفسه (`speech_to_text`) بيحوّل الصوت لكلام مكتوب، وقارئ نقي بالمصري
بيفهمه، والتطبيق بيقول اللي فهمه وبيستنّى «أيوه» قبل ما يطبّق.
- **الطبقات**: `domain/voice/answer_parser.dart` (نقي — `parseYesNo`,
  `parseTime(hint:)`, `parseNumber`/`parseAge`, `parseSex`, `parseDoseAnswer`,
  `parseName`؛ بيرجّع `SpokenTime` مش `MinuteOfDay` عشان ملفات الصوت ما
  تستوردش الجدولة)، `data/voice/speech_listener.dart` (الواجهة) +
  `speech_to_text_listener.dart` (**الملف الوحيد اللي بيستورد `speech_to_text`**)،
  `features/voice/listen_flow.dart` (الدورة، `ChangeNotifier`، متختبرة بمزيّف)
  و`listen_button.dart` («🎤 اتكلم» + ورقة السماع). `VoiceService` أخد
  `listener` و`micDenied` و`listenIntroDone` و`interrupts` و`speakQueued`.
- **الدورة**: دوسة → (لو مفيش إذن: `lis_mic_permission` **قبل** طلب النظام؛
  رفض → `lis_mic_denied` والزرار بيختفي في الجلسة) → `lis_listening` → سماع
  (٦ ثواني سكوت / ١٢ ثانية كلها) → فهم → «فهمت: …» بصوت الموبايل →
  `lis_confirm` → «أيوه» بالصوت أو بالإيد → **`onApply` هي نفس دالة الزرار**
  (الاسم = الحقل، الجنس = الشريحة، السن والساعة = البكرة، «اشتريته؟» =
  `setBought`، التذكير = `_taken` / `_snooze` بالحرف — `voice_dose_test` بيثبت
  نفس الصف ونفس الإلغاء ونفس `help_confirm_done`). «لأ» = اسمع تاني؛ مش مفهوم
  = `lis_not_understood`؛ **ولا تطبيق من غير تأكيد** (`listen_flow_test`).
  **الورقة بتتقفل الأول وبعدين التطبيق** (`autoApply: false` في الزرار) —
  وإلا شاشة التذكير كانت بتقفل الورقة بدل نفسها. وفيه سباق اتصلّح: إجابة
  جاهزة فوراً (المزيّف) بتخلّص الدورة قبل ما جسم الورقة يتبني، فبيتأكّد
  بعد أول فريم.
- **فين المايك** (`placement` في `voice_placement_test`): صفحات البداية التلاتة
  وأسئلة الروتين الخمسة (في الترويسة جنب «ساعدني»، بجزء اليوم من السؤال —
  `_hintFor`)، المقدمة («تحب أكلّمك؟» — `force`)، «اشتريته؟» في المراجعة،
  وشاشة التذكير فوق الزرارين. أول ظهور: `lis_intro` مرة (بعد جملة الصفحة —
  الطابور). **برّه دول مفيش مايك**: الإجابة لازم تكون مقفولة.
- **تنبيه الجرعة بيكسب**: `VoiceService.stop()` بيوقّف السماع كمان وبيزوّد
  `interrupts`؛ الدورة بتقارنه بعد كل خطوة وبتسكت في صمت (مش «مافهمتش»).
  **عمرنا ما نسمع في الخلفية**: الزرار `WidgetsBindingObserver` وبيلغي عند
  أي حالة غير `resumed`.
- **على الجهاز ولا السيرفر**: أول سماع بـ`onDevice: true`؛ آيفون بيرفض
  (`onDeviceError`) لو `supportsOnDeviceRecognition` مش متاح للعربي → إعادة
  مرة من غير الشرط + سطر `diag('Listen: التعرّف على الجهاز مش متاح…')` و
  `lastOnDevice = false`. أندرويد: `EXTRA_PREFER_OFFLINE` + متعرّف على الجهاز
  من أندرويد ١٢ لو موجود — «طلبنا» مش «اتأكدنا». سياسة الخصوصية بتقول ده
  (`docs/legal/privacy_*.md`، بعلامة [يتأكّد] للأجهزة).
- **الأذونات**: `NSMicrophoneUsageDescription` و`NSSpeechRecognitionUsageDescription`
  بالمصري، و`RECORD_AUDIO` + `<queries>` لـ`RecognitionService` على أندرويد.
- **الاختبار في testWidgets**: `watchDay(...).first` جوّه الجسم بيعلّق —
  `voice_dose_test` بيقراه من `tester.runAsync` (نفس فخ IO الحقيقي).
- **ما اتجرّبش على جهاز**: التعرّف نفسه بالعربي المصري، الإذن على الآيفون،
  الإعادة من غير `onDevice`، والورقة وهي بتسمع فعلاً.

## تجربة release على الآيفون (٢٦ سبتمبر ٢٠٢٦، com.fakrny.app) — ست حاجات

- **«أخدته» والتطبيق عايش ما كانتش بتتسجّل** (`149e1e5`). من مصدر
  `flutter_local_notifications` 22.3.0: أي زرار مش `foreground` بيروح لإنجن
  فلاتر **تاني** بتقوّمه الإضافة ساعتها (`startEngineIfNeeded`) وبترجّع
  `completionHandler()` فوراً — **حتى والتطبيق عايش**. التطبيق الشغّال ما
  بيعرفش، والكتابة والإلغاء معلّقين على إنجن جديد في ثواني الخلفية؛ على
  الجهاز ما لحقش، فإعادة +٥ رنّت و«يومك» قالت «نسيتها؟». ملف الطابور كان
  بيتكتب، بس بيتطبّق عند الفتح/الرجوع بس. الإصلاح: `LiveActionChannel` في
  سويفت و`LiveActions` في `pending_actions.dart` — لو دارت على الإنجن الرئيسي
  قالت `ready`، الدوسة (بعد الطابور) بتتطبّق هناك بـ`drain` و`completionHandler`
  بيستنى الرد، **ومن غير `super`** (مفيش إنجن تاني). الإطلاق الجديد في الخلفية
  زي ما هو. والأصلي وكل إعادة ودرجة شايلين نفس الـpayload — `live_actions_test`.
  **ما اتجرّبش على الجهاز لسه.**
- **«نسيتها؟» في دقيقة المعاد** (`d5c7501`): الشاشة كانت بتقارن بـ`isBefore`.
  `doseMomentOf` (دومين): «الجاية» ← «معادها دلوقتي» لحد مهلة الـ٤٥ ← «نسيتها؟».
  و`no_technical_words_test` بيمنع «مراسي/مرساة/توكن/مزامنة/…» في نص الواجهة.
- **التخطيط** (`760563b`): كلمات الدوك بهامش ٤ وسطر ١٫٣ (كانوا لازقين على ٣٧٥
  ونمط كبار السن بيفيض)؛ «ضيف» طلعته فوق الدوك بتتزوّد على `padding.bottom` لكل
  تبويب من الهيكل؛ «القريب مني» **سطر جوّه «يومك»** مش عايم؛ والشريط العلوي كان
  مصمت أصلاً (اتقاس) بس أبيض على أبيض من غير حافة — الثيم بقى فيه خط تحت وظل
  لما في محتوى تحته. `layout_iphone_test` على SE بالخطوط الحقيقية.
- **المايك تاني — والسبب من لوج الجهاز** (profile، صفحة الجنس):
  `Listen: جاهز — اللغة ar-SA (62 لغة)` ← `بدء السماع وقع (start: Instance of
  'ListenFailedException')` ← `error_listen_failed (دايم)`، وقبلها تحذير
  `audioplayers` (continuation leak). `error_listen_failed` بيتبعت من `catch`
  بتاع `listenForSpeech` في سويفت بس = تجهيز جلسة الصوت أو محرّكه رمى.
  وتلات عيوب عندنا خلّوا ده «مش قادر أساعد» على طول: الاستثناء اتكتب
  «Instance of …» (فرفض «على الجهاز» عمره ما اتعرف ولا اتعاد عبر السيرفر)؛
  أول وقعة كانت نهائية (مفيش إعادة)؛ و`cancelOnError: true` + أحداث مهام قديمة
  من غير رقم بتتحسب على السماع الجديد. الإصلاح: `ListenSession` (نقي،
  `lib/data/voice/listen_session.dart`) بيقرر لكل حدث — وقعة البداية = إعادة
  مرة بعد ٣٠٠ ملّي، والـ`error_listen_failed` اللي بعد الاستثناء نفس الوقعة؛
  بقايا قبل «listening» بتتساب؛ عطل بعد ما بدأ = تعثّرة. **آيفون من غير شرط
  «على الجهاز»** (الإضافة بترجّع خطأ وبتكمّل مهمة بالشرط — سياسة الخصوصية
  اتعدّلت: الصوت بيروح لأبل)، `ar-SA`. قبل المايك: الجملة لآخرها ← المشغّل
  `release` والـTTS يقف ← الجلسة تتسلّم ← ٢٥٠ ملّي. ١٠ ثواني كلها، ٦ لأول
  كلمة، ٣ سكوت بعدها (`ListenTimings`). السكوت «مافهمتش» والمايك فاضل،
  والتانية ورا بعض «كمّل بإيدك» والمايك برضه فاضل؛ الإخفا للي ما بدأش بس.
  كل خطوة سطر `Listen:` برقم المحاولة والملّي. **ما اتجرّبش على الجهاز لسه.**
- **النسخة** (هنا): `AppVersion` من الحزمة (`package_info_plus`، الملف الوحيد)،
  «2.0.0 (1)» في الإعدادات والنبضة؛ «dev» fallback في debug بس.
- **٢ و٣ (المايك وجمل البداية)** في `9cf77a0`، و**٦ب (باب المطوّر)** في `90e28ca`.

## «اتكلم» على الآيفون، وجمل البداية في مكانها (٢٦ سبتمبر ٢٠٢٦، نسخة release)

**تلات أعطال من الجهاز، وكل واحد سببه اتسمّى بدليل:**
- **«معلش، مافهمتش» فوراً والمايك عمره ما اتفتح.** من مصدر الإضافة
  (`speech_to_text` 7.4.0، `SpeechToTextPlugin.swift` → `listenForSpeech`): لو
  طلبنا «على الجهاز» والمتعرّف ما بيدعموش للعربي، الإضافة بترجّع `FlutterError
  (onDeviceError)` من `listen()` نفسها — **استثناء، مش نداء `onError`** — وبتكمّل
  تشغّل مهمة بشرط «على الجهاز» بتفشل بعدها وبتسيب الإضافة «مشغولة». إحنا كنا
  مستنيين الرفض في `onError` بس، فالاستثناء كان بيتقري «سكوت» ← «مافهمتش». دلوقتي
  `SpeechListener.listen()` بترجّع **تلات نتايج**: `ListenHeard` / `ListenSilence`
  / `ListenFailed`، والرفض ده بيتعاد مرة عبر سيرفر النظام بعد `cancel` على
  الناحية الأصلية (من غير شرط `isListening`). **السماع اللي ما بدأش عمره ما
  يتقال «مافهمتش»**: الإذن → `lis_mic_denied`؛ غير كده → `gen_try_hands` مرة،
  والزرار يختفي من الشاشة (`startFailed`)، والسبب سطر `Listen:` في السجل وكود
  `listenUnavailable` للأدمن (٢٤ ساعة، `lib/data/voice/listen_health.dart`، مفيش
  هجرة — `failing_codes` مالهاش قيد). ونفس القاعدة في «كلّمني». وقبل كل سماع
  `VoiceService.yieldToMic()` بيوقّف التسجيل والـTTS ويسلّم الجلسة.
  **السبب ده مقروء من المصدر ومطابق للعَرَض — مش متشاف على الجهاز**؛ أول
  تجربة: افتح باب المطوّر (٧ دوسات) وبعدين اضغط «اتكلم» واقرا سطور `Listen:`.
- **`onb_name` على شاشة التسجيل.** الجذر كان بيحط `_patientPath` **قبل** ما
  يفتح شاشة الدخول، فأسئلة البداية بتتبني تحتها وبتقول جملة الاسم، وصفحة الاسم
  نفسها بعدها ساكتة. دلوقتي `_patientSignIn` بيسيب شاشة البداية تحت (ونفس
  الـState، فمفيش `onb_entry` تاني) والأسئلة بتتبني بعد ما الدخول يتقفل.
- **جملة البداية بتتعاد لوحدها.** حفظ الجنس بيقلب `hasPatient`، والجذر كان
  بيبدّل الفرع ويبني الأسئلة **تاني** — State تانية بتقول جملة الصفحة والأولى
  لسه بتتقال (بتتقطع وتبدأ تاني). دلوقتي طول ما `_patientPath` الأسئلة State
  واحدة، و`onDone` بتقفل المسار. **المُعاد بالقياس كان `onb_wake` (أول سؤال
  بعد الحفظ)، مش `onb_breakfast`** — ومفيش مسار تاني بيبني الأسئلة من جديد
  (الوضع الليلي بس، وده مش في البداية)؛ الاختبار بيثبت إن الفطار وكل صفحة
  بعدها ما بتتعادش مع البكرة ولا إعادة بناء الشجرة ولا ٣٠ ثانية سكوت.
- **ولقيت في الطريق**: صفحات المواعيد الخمسة بتشارك State زرار «اتكلم» (نفس
  النوع في نفس المكان)، فالدوال كانت ماسكة سؤال الصحيان وهو على الفطار. الزرار
  بقى بيقرا `widget` وقت النداء.
- **الاسم حقل حر**: مفيش قارئ — اللي اتسمع بيتكتب في الحقل (`previewName`)
  و«اسمك …، صح كده؟» بصوت الموبايل جملة واحدة؛ «لأ» أو قفل الورقة بيرجّع اللي
  كان مكتوب. مفيش حقل حر تاني عليه مايك.
- **الجملة بتتكتب مرة**: ورقة «اتكلم» و«كلّمني» بتكتب اللي بيتقال، فـ
  `VoiceService.captionHolds` بيسكّت الترجمة اللي تحت طول ما الورقة مفتوحة
  (بتتاخد وتتساب في microtask — وسط البناء التنبيه ممنوع وكانت بتفضل ظاهرة).
- **ليه `voice_placement_test` ما مسكش جملة الاسم**: هو بيقرا المصدر («الرقم في
  أنهي ملف»)، والرقم كان في الملف الصح؛ العطل كان وقت التشغيل. واختبار البداية
  كان بيبني الشاشة لوحدها. دلوقتي فيه اختبار بيمشي `AppRoot` بالترتيب الحقيقي
  بمشغّل بياخد وقت (`TimedPlayer` — المزيّف العادي بيخلّص فوراً وده اللي خبّى
  القطع والإعادة). **أربع طفرات**: الأسئلة تحت الدخول، ترتيب الفرع، شيل حجز
  الترجمة، والفشل يتقري سكوت — كلها بتوقّع.
- **ما اتجرّبش على جهاز**: الإعادة عبر السيرفر بعد رفض «على الجهاز»، والتعرّف
  نفسه. **و`ios/Runner.xcodeproj/project.pbxproj` متعدّل على الماكينة**
  (CocoaPods شال `inputPaths`/`outputPaths` الفاضيين) — مش من الجولة دي وما
  اتكوميتش.

## المايك — ماكينة `MicOrb` (بورت من jarvis-ai-finance، ٢٦ سبتمبر ٢٠٢٦)

**بيلغي أي حاجة فوق أو تحت بتقول غير كده عن المايك.** المايك على **شاشة
التذكير و«كلّمني» بس** — اتشال من البداية والمقدمة و«اشتريته؟»
(`voice_placement_test` بيقفل الملفين).
- **الدايرة** (`features/voice/mic_orb.dart`): دوسة واحدة لكل حالة،
  و**الحالة كلمة مكتوبة تحتها** (`micStateLabel` في
  `domain/voice/mic_state.dart`): «دوس واتكلم» / «سامعك…» / «بفكّر…» /
  «برد عليك — دوس عشان تقاطعني» / «قول «أيوه» أو «لأ» — أو دوس» / «اكتب أو
  دوس بدل الصوت». idle ← listening ← thinking ← confirming/speaking ← idle.
- **دوسة = سماع واحد، ومفيش سماع لوحده أبداً.** السماع بيبدأ من الراحة بس
  (دوستين = سماع واحد — في الدورة وفي `MicListener`). والموبايل بيتكلم
  (الرد أو «صح كده؟») الدوسة **بتسكّته وبتفتح المايك في نفس الدوسة**
  (مقاطعة من غير إلغاء صدى). والمايك مفتوح الدوسة = «خلصت» واللي اتسمع هو
  الإجابة. **القفل (`_busy`) بيتفك أول ما المايك يتقفل** — قبلها الدوسة وقت
  «صح كده؟» كانت بتتبلع (اختبار باسمه، مُتحقَّق بالطفرة).
- **نهاية الكلام بتاعتنا**: ١٫٢ ثانية بعد آخر كلمة (`MicListener.endOfSpeech`)،
  مش سكوت المتعرّف؛ قبل أول كلمة المتعرّف بيستنى زي ما هو (٦ ثواني).
- **«مفيش كلام» مش عطل**: راحة، سطر مكتوب «ما سمعتش حاجة — دوس واتكلم.»،
  ولا جملة بتتقال. كلام مش مفهوم = «مافهمتش» (نسأل تاني). **القاطع**
  (`MicBreaker`): ٥ وقعات سماع في ١٠ ثواني ← المايك يتقفل على الشاشة دي؛
  وقعة واحدة ما بتقفلش (قبل كده كانت بتخفي الزرار من أول مرة). الإذن
  المرفوض والمتعرّف المش موجود لسه بيقفلوا على طول.
- **«أيوه» / «لأ» بالصوت**: `classifyReply` في `answer_parser.dart` = بورت
  `affirm.js` مدموج مع قايمتنا — **أول كلمة بتحكم، الرفض قبل القبول، ومش
  واضح = «صح كده؟» تاني** (عمره ما يأكّد لوحده). «مش» لوحدها بقت مش واضح
  («مش عارف»)؛ رفض في عبارات بس («مش دلوقتي»، «مش كده»…).
  `affirm_parity_test` فيه حالات `gate.test.js` بالحرف. **مفيش ذكاء في
  التأكيد أبداً.**
- **الوصلة**: `SttDriver` (`data/voice/stt_driver.dart`) — `device`
  (`speech_to_text_listener.dart`، الملف الوحيد اللي بيستوردها) و`cloud`
  (`cloud_stt.dart`: كعب **مقفول**، مفيش شبكة ولا مفاتيح — اختبار بيقفل).
  `--dart-define=STT_DRIVER=cloud` = مفيش مايك لحد ما الكعب يتبني.
  `main` بيدّي الشاشات `MicListener(driver)` مش المحرّك على طول.
- **ما اتجرّبش على جهاز**: الـ١٫٢ ثانية مع راجل عنده ٧٢ سنة بياخد نفَس في
  نص الجملة — لو بيتقطع، الرقم في مكان واحد.

## «الرفيق الصوتي» — المرحلة ٣: «كلّمني» — بيفهم طلبات مفتوحة (٢٦ سبتمبر ٢٠٢٦)

زرار «🎤 كلّمني» على «يومك» تحت التحية (٨٠ في نمط كبار السن). المريض بيقول
طلبه، التطبيق بيقول اللي فهمه (صوت الموبايل للجمل المتغيّرة) + `lis_confirm`،
**ولا حاجة بتحصل غير بعد «أيوه»** (بالصوت أو بالإيد).
- **الفهم محلي الأول** (`features/voice/command_parser.dart`، دارت نقية، ١٠٤
  حالة): أخدت الدوا / الدوا الجاي / أدويتي النهارده / ضيفلي دوا (الاسم
  والمواعيد **بكلماتها**) / سؤال طبي — **والطبي قبل أي فهم تاني** («أخدت
  جرعة زيادة أعمل إيه» طبي). مطابقة الدوا على القايمة المحلية بالاسم
  (`medKey`: ة/ه، ى/ي، أ/ا، شيل «ال» والتركيز، حرف ناقص) وبالغرض («الضغط»
  ↔ `MedicationPurpose.pressure`) **وبالصوت عبر الحروف** (`phoneticKey`):
  «كونكور» و«Concor» الاتنين `knkr` — هيكل ساكن لاتيني من غير حركات،
  والأصوات اللي المصري بينطقها واحد بتتوحّد (ك/ق/c/q → k، ب/p → b، ف/v → f،
  ج/g/j → g، س/ص/ز/ش/ث/th → s، ph → f، x → ks، c قبل e/i/y → s). قبول
  المطابقة: هيكل متطابق، أو حرف واحد فرق في هيكل من ٦ حروف وأكتر — «كوندور»
  (kndr) مش Concor. الـ«ال» بتتجرّب كجزء من الاسم كمان (التروكسين ↔
  Eltroxin). اتنين قريبين = «أنهي واحد؟» زي ما هو؛ ٣٥ زوج حقيقي وقريب-مش-هو
  في `command_parser_test`. السحابة ما اتغيّرتش (الكلام المكتوب وبس).
- **السحابة خطوة أخيرة** (`ai/command_reader.dart`): بس لو المحلي رجّع
  unknown، و`voiceCommandsCloud` (شغّال في debug/profile، **مقفول في release**
  — المفتاح الحالي مش لكلام مرضى حقيقيين)، والحد اليومي لسه. **الجسم فيه
  الكلام المكتوب وبس** — ولا صورة ولا اسم دوا من القاعدة ولا اسم مريض
  (`command_reader_test` بيمسك الطلب). JSON صارم `{intent, med_name_as_spoken,
  timing_words, pattern_words}`: زيادة/نقص/نوع غلط/نية غلط = مش مفهوم؛ مش
  JSON/HTTP/شبكة/مهلة ٨ ثواني = عطل (`gen_try_hands`)، ومفيش رمية. الكلمات
  اللي بترجع بتتفهم بنفس القارئ المحلي وبتتطابق على الموبايل.
- **التنفيذ بنفس سكّة الزرار** (`features/voice/command_flow.dart`): «أخدت»
  → المرشّحين من نافذة «أخدته» نفسها (`nowGroups`)، واحد = «فهمت: أخدت X بتاع
  الساعة …»، ٢–٣ = «أنهي واحد؟» بأزرار، ومحدش = جملة على الشاشة؛ «أيوه» →
  `confirmGroup` بالحرف (نفس الصف والإلغاء و`help_confirm_done` —
  `command_flow_test` بيثبت بالأرقام). «ضيفلي» → الفورم العادي **متعبّي**
  (الاسم أو الغرض، المراسي من الكلمات بعُرف الفورم، «مرة واحدة») والحفظ
  بزراره هو؛ `cmd_done` بعد ما يرجع «اتحفظ». «الجاي» / «النهارده» رد محلي
  بـ`voiceTime` (خمسة بحد أقصى ثم «وحاجات تانية على الشاشة»). طبي →
  `gen_no_medical`. مش مفهوم → `lis_not_understood`، والتانية ورا بعض
  `gen_try_hands`. «لأ» → `cmd_cancelled`. أول دوسة خالص → `cmd_hint` مرة
  (`voice.cmdHintDone`). الصوت مقفول = نفس الجمل مكتوبة في الورقة
  (`shown`) من غير ما تتقال — الزرار بيظهر برضه.
- **تنبيه الجرعة بيكسب** زي المرحلة ٢ (`interrupts`)، ومفيش سماع في الخلفية.
- الجمل `cmd_*` الخمسة في السكريبت والكتالوج بالحرف (٦٧ جملة)،
  و`voice_placement_test` بيثبّت مكان كل واحدة.
- **الحد اليومي والتشخيص**: `DailyCloudBudget` (`data/services/` — مش
  `data/voice/`، عشان حارس «ملفات الصوت ما بتستوردش الجدولة» يفضل صادق) ٢٠
  سؤال للسحابة لكل موبايل في **يوم الروتين** (`routineDayOf` — ١ بالليل لسه
  امبارح)، عدّاد في `shared_preferences` (`voice.cloudDay`/`voice.cloudCount`)،
  بيتحمّل في `buildServices` مع روتين المريض؛ لما يخلص `cmd_limit` والمحلي
  شغّال. كل طلب سطر `Cmd:` في سجل التشخيص (النية، المصدر local|cloud،
  الزمن، كود العطل، `used=N/20`) — **والكلام المكتوب نفسه عمره ما يتكتب**.

## القياسات الحيوية (٢٥ سبتمبر ٢٠٢٦)

الضغط (انقباضي/انبساطي + نبض اختياري)، النبض، الوزن، الأكسجين %،
والحرارة — جنب السكر اللي زي ما هو.
- **جدول لوحده (`vitals`، drift v25، سحابة `0027`) مش توسيع لـ`readings`**:
  السكر ليه سياقه وجدوله وشاشاته من ١٢ نسخة؛ توسيعه كان هيعمل هجرة على
  بيانات شغّالة عشان أعمدة مالهاش معنى له. `kind` بالاسم، `value` الانقباضي
  أو القيمة، `value2` الانبساطي، `pulse` مع الضغط.
- **الدومين** (`domain/health/vitals.dart`، دارت نقية): الأنواع ووحداتها،
  **حدود «الجهاز بيقرا كده» مش حدود طبية** («الرقم ده غريب — راجعه» ومفيش
  حفظ، زي السكر ٢٠–٦٠٠)، «المعتاد ليك» = متوسطه هو في آخر ٣٠ يوم ومحتاج
  **٣** قياسات (الوزن بيتقاس مرة في الأسبوع؛ ٥ زي السكر كانت هتخلّي
  المعتاد ما يظهرش أبداً)، والفرق رقم بإشارة («+١٫٥» / «زي المعتاد») —
  من غير «عالي» ولا «واطي» ولا لون.
- **«سجّل قياس»**: ورقة واحدة بشرايح الأنواع + شريحة «السكر» بتفتح شاشته
  زي ما هي؛ الرقم من الكيبورد (رقم جهاز بيتقرا ويتكتب — نفس قرار السكر)،
  والوقت «دلوقتي» وبيتغيّر (الأيام شرايح والساعة `FTimeWheel`). المداخل:
  «سجّل قياس» في «ضيف» **مكان «قيس السكر»** (السكر جوّه الورقة)، وقسم
  «قياساتك» في «السجل».
- **التاريخ لكل نوع** (`VitalHistoryView` — نفس الودجت عند المريض والعيلة
  والممرض): آخر رقم، المعتاد، الفرق، رسم ٧/٣٠/٩٠ يوم (الضغط خطين ومكتوب
  مين مين؛ **مفيش خط مرجعي ولا منطقة ملوّنة** — أي خط أفقي كان هيتقري
  «الحد»)، والقايمة باليوم.
- **الخطوط الحمرا**: «اسأل دكتورك» هي الكلمة الطبية الوحيدة
  (`vitalsAskDoctor`، عند المريض بس)، و`vitals_test` بيقرا كل نصوص ملفات
  القياسات ويوقع على أي كلمة من `adviceWords` غيرها — متحقَّق بالطفرة.
- **العيلة والممرض قراية بس**: مدخل «القياسات» في «الملف الصحي» عند
  الابن، و«قياساته» في «السجل» عند الممرض. صفحة الدكتور (الاتنين) والملف
  PDF (قسم `ExportSection.vitals`) فيهم آخر قياس لكل نوع. `_hints` في
  شاشة الملف بقت switch شامل — القسم الجديد كان بيوقّعها وقت التشغيل.
- **المزامنة**: `vitals` آخر جدول بيتدفع، ولو الجدول لسه مش على السيرفر
  (PGRST205/42P01) الصفوف بتستنى من غير ما توقّف أي جدول قبلها؛ والقراية
  عند العيلة بترجع فاضية بدل ما الشاشة تقع.
- **التذكير والجدولة ما اتلمسوش** — الخطة الذهبية والمجدول خضر.

## نسخة TestFlight على سجل التطبيق القديم (٢٦ سبتمبر ٢٠٢٦)

**`docs/release/testflight.md` هو الدليل** — أمر البناء بأسامي التعريفات
(ولا قيمة)، ثم Xcode Organizer. الهوية `com.fakrny.app` (`RunnerTests` =
`com.fakrny.app.RunnerTests`، مفيش extension؛ أندرويد فضل `com.fakkarni.fakkarni`
— الطلب كان iOS بس)، والنسخة `2.0.0+1` فوق `1.12.1` بتاعة التطبيق القديم.
**مفيش رفع اتعمل** — الملف بيقول إزاي، والمالك هو اللي بيرفع. والدينين ٢ و2b
لسه واقفين: TestFlight داخلي بقرار المالك، المتجر لأ.
- **باب المطوّر في release**: الإعدادات → سطر «فكرني — النسخة …» (آخر صف قبل
  «امسح حسابي») → **٧ دوسات** بتكتب ملف فاضي `Documents/fkdiag.on`
  (`diagOptInFileName`) جنب السجل، و٧ تاني بتشيله. `diag` في release بتقرا
  العلامة **بنفس `_resolveSink`** — ملف، مش `shared_preferences`، عشان
  الـisolate يشوفها من غير قناة — وبتكتب في **الملف بس**: `debugPrint` عمرها
  ما تطلع في release حتى والباب مفتوح (`diagnostics_gated_test` بيثبّت
  السطرين بالحرف). القسم نفسه ظاهر على `developerVisible =
  !kReleaseMode || _devDoor` (`health_is_last_test` بيقرا الاسم ده).
  `developer_door_test` بيثبت العلامة (بـ`PathProviderPlatform` وهمي على
  مجلد مؤقت — `path_provider_platform_interface` دخلت dev_dependencies
  عشان كده) والـ٧ دوسات — مُتحقَّق بالطفرة (٦ بتوقّع).
- **اللي بيختلف في release وما بيكسرش حاجة للمختبِر**: الدخول المجهول نفسه
  (الربط والمزامنة والمسح شغّالين — مفيش فرق كود بين الوضعين، بس
  «Allow new users to sign up» لازم تفضل ON)؛ `voiceCommandsCloud` مقفول
  فـ«كلّمني» محلي بس (`command_flow_test` «العلم مقفول»)؛ التشخيصات اللي على
  الشاشة (`kDebugMode`) مش موجودة.
- **Entitlements**: Time Sensitive بس، على Release بس (زي ما هو). مفيش
  `aps-environment` ولا `UIBackgroundModes` عن قصد — مفيش APNs (الدين ٣)
  ومفيش شغل خلفية غير إشعارات محلية؛ إضافة `aps-environment` من غير Push على
  الـApp ID بتوقّع التوقيع. لو الـApp ID القديم عليه Push، سيبه — مش بيضر.

## مسح الحساب والسياسات — B4 وB5 (٢٥ سبتمبر ٢٠٢٦)

**«امسح حسابي» (Apple 5.1.1(v))** — في إعدادات المريض (لما فيه حساب) وإعدادات
المتابع والممرض، وبيفتح `DeleteAccountScreen` (`lib/features/account/`، مقاسات
المريض للتلاتة): خطوتين («اللي هيتمسح» بالسطر ← «متأكد؟ ده نهائي»)، «لأ،
رجوع» هو الأساسي في الاتنين، وزرار المسح **حبر مش أحمر**، وسطر «الغي الاشتراك
من إعدادات آبل أو جوجل — إحنا مش بنقدر نلغيه». القايمة (`deletedLines`) هي
بالظبط اللي الـSQL بيمسحه.
- **السيرفر الأول، والموبايل بعد «اتمسح» بس.** `delete-account` (Edge
  Function، مفتاح الخدمة من أسرارها بس، المستخدم من جلسته) بتمشي: الصور من
  الباكت (Storage API — المسح المباشر من `storage.objects` ممنوع) ← الصفوف في
  معاملة واحدة (`delete_account_for_service`، 0033) ← المستخدم من Auth **آخر
  حاجة**. كل خطوة بتتعاد من غير ضرر، وطول ما المستخدم موجود التطبيق بيقول
  «جرّب تاني» وما بيلمسش الموبايل: أوفلاين = «مفيش نت — ولا حاجة اتمسحت».
  مفيش «نص حساب».
- **بعد النجاح `LocalWipe`** (`lib/data/account/`): الإشعارات المعلّقة **بالرقم**
  (مش `cancelAll`)، كل الجداول وصف مريض فاضي **بنفس الرقم** (الـpatientId في
  الذاكرة عند كل حاجة) وuuid جديد، فولدرات `attachments` و`med-photos` و
  `exports` و`med-photo-cache` بالاسم، `shared_preferences`، والخروج — والجذر
  بيرجع لشاشة البداية لوحده.
- **المالك** → صف المريض وكل اللي تحته بالـcascade. **المتابع/الممرض** →
  علاقاته وتفضيلاته وتنبيهاته وتوكنه بس؛ بيانات المريض بتاعته. وقبل ما العلاقة
  تتشال بيتكتب `circle_departures` («سارة خرجت من الدايرة» — الفعل بالصلة،
  ومن غير اسم مفيش اسم بيتخترع): عند المريض على «يومك» في كارت «سارة ضافت دوا»
  نفسه (`CircleDeparturePuller`)، وعند الباقيين في «الجديد». ٣٠ يوم وبيتمسح.
- **تلات مفاتيح أجنبية اتصلّحت في 0033**: `invite_codes.used_by` كانت من غير
  `on delete` (مسح أي حد استبدل كود كان هيقع)، و`proxy_confirmations.actor_id`
  و`medication_changes.actor_id` كانوا `cascade` — ممرض يمسح حسابه فتأكيده
  يتشال و`due_escalations` ينبّه الابن عن حباية اتاخدت. بقوا `set null`،
  والدالة بتشيل الاسم كمان. **`due_escalations` ما اتلمستش.**
- **الأدمن**: الممسوح بيختفي من كل قايمة (كله مشتق من `patients`)، واللي فاضل
  `private.account_deletions` (يوم ونوع — ولا معرّف) → عمودين زيادة في
  `admin_counts` وسطر على «نظرة عامة».
- **٢٦ سبتمبر ٢٠٢٦ — «مقدرناش نكمّل المسح» على الجهاز، والسبب من نداء مباشر
  على المشروع الحقيقي بجلسة مجهولة (ES256 — البوابة قبلتها): الدالة المنشورة
  ردّت `200 {"message":"Hello undefined!"}` — **قالب سوپابيز، مش `index.ts`
  بتاعنا**. العميل بقى يكتب حالة الرد وجسمه في `diag`، ويفرّق عطل الشبكة
  (الـSDK بيلفّه `FunctionException(status: 0)` → «مفيش نت») عن رفض السيرفر،
  وما بيبعتش من غير جلسة. `supabase_account_deletion_test` بيمسك الطلب نفسه
  (`POST /functions/v1/delete-account`، الجسم، و`Authorization: Bearer` الجلسة).
  **الإصلاح المتبقي على السيرفر**: نشر `supabase/functions/delete-account/index.ts`
  مكان القالب. ومستخدم مجهول واحد اتعمل في `auth.users` بالتجربة دي وما اتمسحش
  (القالب ما بيمسحش) — بيتمسح من لوحة Auth.
- **ما اتجرّبش**: الدالة (مفيش Deno هنا) والهجرة (ملف بس). وابن مريض مسح حسابه
  بيرجع لشاشة البداية من غير جملة بتقول ليه — المريض نفسه اتمسح، ومفيش صف
  يتعلّق عليه سطر.

**السياسات (مسودّات — محتاجة مراجعة قانونية)**: `docs/legal/privacy_{ar,en}.md`
و`terms_{ar,en}.md` و`store_forms.md` (بيحل محل `docs/STORE_LISTING_DATA.md`)،
مكتوبين من الكود. **ملاحظة صادقة فيهم**: صور التصوير بتروح لـGemini **من
الموبايل على طول** مش من السيرفر (C2 اترجعت) — لو C2 رجعت، السطر ده بيتغيّر.
الروابط من مكان واحد: `lib/core/legal/legal_links.dart`
(`--dart-define=PRIVACY_URL=… --dart-define=TERMS_URL=…`؛ علامة المكان ما
بتتفتحش)، و`LegalLinksRow` في شاشة البداية (قبل أي حساب) وفي الإعدادات عند
الاتنين. `legal_links_test` بيوقع لو الاسمين اتكتبوا في أي ملف تاني.

## Pricing — اشتراك العيلة

**Decided by the owner, 24 Sep 2026 (tester feedback #3). Built behind one
seam; not sellable until the company does the store work in HANDOVER B7.**

> **ONE family subscription per patient covers the patient and up to 5
> people following him (followers or nurses). Not «each person pays».
> Anyone in the circle may buy it.**

This replaces the 22 Sep model («every follower pays for his own»), which
replaced the original («the son pays for the father»). Both are history.

**Two safety rules, and they are structural, not policy:**
1. **The patient's own reminders never stop** because of payment, trial
   end or verification failure — the dose, the ladder, the repeats, the
   60-minute server grace and the son's alert **never read billing**.
   `test/data/billing/billing_mirror_test.dart` reads
   `lib/domain/scheduling`, `lib/domain/escalation`, `lib/data/services`,
   `lib/core/notifications`, `lib/data/sync` and `bootstrap.dart` and fails
   on any billing import or gate call. The golden-plan test and the
   scheduler tests are green without modification.
2. **Unreachable verification = last known state (grace), never a
   lockout.** `SubscriptionService.refresh` keeps `current` and
   `billing.lastKnownAllowed` on any failure; with no state at all
   everything is allowed; an `active` row keeps allowing for
   `graceDays` (3) past `expires_at`.

**Free forever vs family — one list, `AppFeature` in
`lib/domain/billing/family_plan.dart` (default, awaiting the owner's
confirmation):**

| مجاني للأبد | اشتراك العيلة |
|---|---|
| كل التذكيرات (الجرعة والسلّم والإعادات) | ربط متابعين وممرضين وتنبيهاتهم (`circle`) |
| إضافة الأدوية وتعديلها | مرآة الممرض والتأكيد بداله (`nurseMirror`) |
| «يومك» | قراية الروشتة والعلبة والتحليل بالكاميرا (`scans`) |
| الملف الصحي على الموبايل | تصدير الملف PDF بعد أول ٣ مرات (`exportBeyondFree`) |
| بطاقة الطوارئ | |

`featureAllowed(feature, …)` is the one decision: a free feature is `true`
whatever the state; a family feature follows the debug override (never in
release), then the subscription (`trial` until `trial_ends_at`, `active`
until `expires_at` + grace, `expired` never), then the last known state,
then `true`.

- **Trial**: `trialDays` 14 from patient creation (trigger on
  `patients` insert), `migrationTrialDays` 30 for patients existing when
  `0025` runs. Both live once in `SubscriptionConfig` and once as SQL
  functions in `0025`; the mirror test pins the four numbers (14/30/3/5)
  and the two product ids against the SQL and the Edge Function.
- **Cloud: `0025_family_subscription.sql`** (file only — **not yet run**):
  `family_subscriptions` keyed by `patient_uuid` (status trial/active/
  expired, `trial_ends_at`, `expires_at`, `store`, `product_id`,
  `purchaser_id`, `last_verified_at`), select for the circle through
  `can_access_patient`, **no client insert/update** (the Edge Function
  writes with the service role); `private.family_subscription_active`
  (missing row = allowed — an old patient before the backfill is not
  locked out); `private.follower_subscription_active(caregiver, patient)`
  is the seam `due_escalations` now calls, so an expired family stops
  the **son's alert** and nothing else; `redeem_invite` returns
  `circle_full` at `follower_cap()` (5) accepted links. Self-check: trial
  window, circle reads / cannot write, stranger sees nothing, escalation
  gated by trial/expired/active+grace, missing row still escalates.
- **Verification: `supabase/functions/verify-purchase`** — POST with the
  user's JWT `{patient_uuid, store, product_id, receipt}`; the caller must
  be the owner or an accepted caregiver; Apple = ES256 App Store Server
  API (`/inApps/v1/transactions/{id}`, production then sandbox), Google =
  service-account RS256 → `subscriptionsv2`; credentials **only** from
  Edge secrets; missing secrets → `{status: 'not_configured'}` and the
  phone stays in trial/grace. **Never run — there is no Deno here.**
  Product ids `fakkarni_family_monthly` / `fakkarni_family_yearly` are
  placeholders until the store products exist.
- **App**: `lib/data/billing/` — `SubscriptionRemote` (+ Supabase impl),
  `StorePurchases` (+ `iap_store_purchases.dart`, the only
  `in_app_purchase` import; **prices come from the store, never from
  code** — the mirror test fails on a price literal in the screen),
  `SubscriptionService` (`ChangeNotifier`; `patientUuid` set from the
  patient row on the father's phone and from the snapshot on the son's;
  `allowed(feature)`, `noteExport()` — first 3 exports free even when
  expired, `buy`/`restore` → verify → refresh; debug override under
  `!kReleaseMode` only). `lib/features/billing/family_plan_screen.dart`
  «اشتراك العيلة»: `remindersStayFreeLine` first, status line, who is
  covered by name, the two lists, one button per store product with its
  store price, «استرجاع المشتريات», developer simulate chips
  (`حقيقي / نشط / منتهي`). `feature_gate.dart` `ensureFamilyFeature`
  opens it and returns whether the feature is allowed after; no
  `AppScope` (a screen pumped alone) = allowed. Gates: the three scan
  entries in the «ضيف» sheet, invite creation on `LinkCodeScreen`, and
  «اطبع أو ابعت الملف» on «للدكتور» (counted on save in the preview).
  Settings rows «اشتراك العيلة» on both the patient's and the son's side.
- **The circle is told before the alerts stop, and after** (24 Sep 2026 —
  the safety gap: an expired family silenced the son's missed-dose alert
  and nobody knew). One pure rule, `familyNotice` in `family_plan.dart`:
  `endingSoon` from **7 days** before the stop instant (wording marks the
  7/3/1 milestones; the card stays visible every day in between rather
  than appearing only on those three days), `ended` once
  `allowsFamilyAt` is false or the last known state is «مقفول»; **unknown
  = no card** (we never tell anyone their alerts stopped without knowing).
  The stop instant is `familyEndsAt` — trial end, or `expires_at` + 3 days
  grace — the same boundary the server uses, so the date on the card is
  the day it actually stops.
  - **Follower / nurse** (`features/care/family_notice_card.dart`, top of
    «متابعة» and «مرآة», above the status answer — «كله تمام» under a
    silent server is a lie by omission): «تنبيهاتك عن {اسم} هتقف يوم …
    لو الاشتراك ما اتجددش», then a **persistent** card with no dismiss
    «التنبيهات واقفة — مش هتتبلّغ لو {اسم} فوّت جرعة». Gold edge and
    icon, ink text, never red.
  - **Patient** (`features/billing/family_notice_cards.dart`, on «يومك»
    **under the day rail** — above it would push «تأكيد الجرعة» under the
    floating button on SE): «تنبيهات محمد وسارة هتقف يوم …» and after the
    stop the one line «اللي بيتابعوك مش بيتبلّغوا دلوقتي». Hidden when the
    follower list was read and is empty; shown when it could not be read.
  - Both carry «جدّد» → «اشتراك العيلة». Reminders read none of it —
    `billing_mirror_test` green. Tests: `family_plan_test` (the rule, the
    wording) and `family_notice_test` (both sides, both states, placement);
    mutation-checked on the 7-day window and on the ended state.
- **Not built, said out loud**: store webhooks (renewal/cancellation
  reach us only on the next verification), and a nurse-mirror gate on
  the son's phone (the mirror needs an accepted relation, and the cap and
  the escalation gate already live on the server).

---

## لوحة الأدمن — `admin/`

**تطبيق ويب، قراية بس، لصاحب المنتج وحده** — حزمة مستقلة جوّه الريبو
(`admin/pubspec.yaml`)، بتتشغّل محلي وبس، ومفيش استضافة ولا CI ليها.
بتجاوب على سؤال واحد: **«المنتج شغّال ولا لأ»** — نبضة كل موبايل، حالة
البطارية، مدى التذكير، الجرعات اللي ما اتأكدتش في ٢٤ ساعة، والتنبيهات
اللي اتبعتت.

**ولا بيان طبي بيعدّي منها.** مفيش اسم دوا، ولا سجل، ولا نتيجة تحليل، ولا
قياس، ولا بيانات طوارئ، ولا رقم تليفون. **والحد مكتوب في SQL مش في
الشاشة**: كل دالة في `0021_admin.sql` ليها `returns table (…)` بقايمة
أعمدة مقفولة، فعمود جديد = قرار جديد في ملف ترحيل جديد، مش سطر في ويدجت.

**الهوية بالإيميل، وده أول `auth.jwt()` في المشروع.** `private.admins`
جدول إيميلات، و`private.is_admin()` بترجّع true لما الإيميل يبقى في
القايمة **و**الجلسة مش مجهولة. ليه مش `auth.uid()` زي كل حاجة تانية:
دي **قايمة ناس**، والدخول المجهول بيولّد مستخدم جديد كل مرة (الدين ٢)،
فمعرّف مخزّن كان هيبوظ في صمت. والشرط التاني متجرّب في الفحص الذاتي، مش
مكتوب وبس.

**اللوحة عميل عادي بمفتاح النشر.** الحاجز كله في السيرفر:
- الأربع دوال `public.admin_*` بتبدأ كلها بـ`if not private.is_admin() then
  raise exception 'not admin'`، وEXECUTE بتاعها **مسحوب من `anon`** —
  فمفيش جلسة بترجّع `42501` قبل ما الحارس يشتغل أصلاً، وحساب عادي بيرجّع
  `not admin`. الاتنين مختلفين، والفحص الذاتي بيمسك كل واحد بسببه.
- الأرقام كلها متعرّفة **مرة واحدة** في `private.admin_account_rows()`،
  واللي بينده عليها الأربعة. عشان كده الشريط والجدول ما يقدروش يختلفوا،
  و«جرعة ما اتأكدتش» بتتحسب بنفس شرط `private.due_escalations` بالظبط
  (`state in ('pending','missed')` وعدّت `private.server_grace_window()`)
  — لوحة بتقول رقم غير اللي الكرون بيشوفه أسوأ من مفيش لوحة.
- **`last_sync_at` من ختم السيرفر** (`updated_at` بتاعة `patients` /
  `medications` / `dose_events`)، مش من `device_health.last_sync_at` —
  دي دعوى الجهاز عن نفسه، والسؤال هنا هو «وصل إيه فعلاً».

**حزمة مستقلة، والاستقلال محروس.** ما بتستوردش `package:fakkarni/` أبداً
(`admin/test/no_mobile_import_test.dart`، وبيوقّع على `path:` في الـpubspec
كمان). اللي محتاجينه من التطبيق **متنسخ** وفوق كل نسخة سطر بيقول مصدرها:
`tokens.dart`، `arabic_time.dart`، `follower_profile.dart`، والخطوط؛
و`relative_time.dart` **مستخرَج** من `caregiver_words.dart` (الملف الأصلي
بيستورد طبقة البيانات فمينفعش يتنسخ كامل). تعديل في الأصل بيتنقل بالإيد.
**واللوحة برّه كل حرّاس التطبيق** — كلهم بيمشوا على `Directory('lib')`
بتاعة الحزمة التانية — فحرّاسها هي في `admin/test/`.

**ومفيش مفتاح خدمة فيها خالص.** `admin/test/no_privileged_key_test.dart`
بيمشي على الحزمة كلها (dart وhtml وjs وjson وyaml) ويوقع لو الاسم ظهر،
**حتى في تعليق** — وده حصل فعلاً وقت الكتابة: التعليق اللي بيقول «مفيش
مفتاح خدمة هنا» كان هو نفسه أول اللي الحارس مسكه. الكلمة الممنوعة
**متجمّعة وقت التشغيل** (`['service','role'].join('_')`) فمفيش استثناء
للملف نفسه ولا لاسمه. `signInAnonymously` ممنوعة بنفس الطريقة.

**`0021` اتطبّقت على المشروع الحقيقي في ٢٣ سبتمبر ٢٠٢٦**، و
`verify_migrations.sql` بعدها رجّع **٢١ صف كلهم `ok = true`**. الترتيب
تحت متسجّل عشان مشروع جديد أو إعادة بناء، مش كخطوات مستنية:

**ترتيب اللصق، بالظبط:**
1. `verify_migrations.sql` — صف `0019_battery_state` لازم يقرا `ok = true`
   (٠٠٢١ بتقرا `battery_state`).
2. `migrations/0021_admin.sql` — المتوقّع **`Success. No rows returned`**،
   و`0021 OK — …` في تبويب Messages.
3. `verify_migrations.sql` تاني — ٢١ صف، و`0021_admin | 14 | 14 | true`.
4. الإيميل في قايمة السماح (محرر SQL):
   ```sql
   insert into private.admins (email) values (lower('OWNER_EMAIL_HERE'))
   on conflict (email) do nothing;
   ```
5. **من لوحة Supabase، مش من SQL**: Authentication → Providers → Email
   مفعّل (افتراضياً مفعّل — أكّده)، وAuthentication → Users → Add user →
   Create new user بنفس الإيميل وباسورد، و**Auto Confirm User** متعلّمة
   (مفيش سكّة بريد متظبطة). نفس الإيميل بحروف صغيرة في الناحيتين.

**والخطوتين ٤ و٥ اتعملوا على المشروع الحقيقي في ٢٣ سبتمبر ٢٠٢٦**:
`private.admins` فيه إيميلين — بتاع المالك و`demand.dev.911@gmail.com` —
والمستخدم في Supabase Auth بتاع `demand.dev.911@gmail.com` موجود
بـAuto Confirm، فالحساب ده بيدخل دلوقتي. الخطوات فوق فاضلة **كمرجع
لمشروع جديد**؛ الهجرة ما بتزرعش أدمن عن قصد، لأن اسم في قايمة سماح جوّه
هجرة بيبقى قرار متخبّي في ملف.

**بس إيميل المالك متسجّل في القايمة ومفيش مستخدم Auth مكتوب ليه هنا.**
القايمة لوحدها ما بتدّيش دخول: من غير مستخدم مقابل في Auth مفيش حاجة
يتسجّل بيها الدخول أصلاً. يا إما المستخدم موجود والسطر ده قديم، يا إما
الخطوة ٥ لسه محتاجة تتعمل له. يتحسم قبل التسليم — العطل شكله مشكلة
صلاحيات وهو مش كده: إيميل في القايمة من غير مستخدم ما يقدرش يدخل،
ومستخدم مش في القايمة بياخد «الحساب ده مش أدمن».

**التشغيل**: `cd admin && flutter run -d chrome
--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` (أو
`--dart-define-from-file=../secrets.json`). من غير المفاتيح اللوحة بتفتح
وبتقول اللي ناقص بالنص وما بتحاولش تتصل.

**متسجّل ومش متعمول**: مفيش CI على اللوحة — `.github/workflows/` مش
بيشغّل `flutter test` لا للتطبيق ولا ليها، فحرّاسها بتجري بالإيد
(`cd admin && flutter test`).

### الرفع على Firebase Hosting

**موقع لوحده على نفس مشروع فايربيز بتاع الدفع** (`fakkarni-5704c`) —
`firebase.json` فيه هدف واحد اسمه `admin` على موقع `fakkarni-admin`، ولا
بيلمس أي إعداد تاني. الدفع (FCM) بيتظبط من الكونسول ومالوش علاقة بالملف.

**البناء بتعريفين وبس، وده مش تفصيلة.** حزمة الويب **عامة**: أي حد بيفتح
اللوحة بيقدر يقراها بايت بايت. عشان كده الرفع عمره ما يبني بـ
`--dart-define-from-file=../secrets.json` — الملف ده فيه `GEMINI_API_KEY`
كمان، وكان هيروح على الإنترنت مع أول رفعة. `admin/tool/deploy.sh` بيقرا
**`SUPABASE_URL` و`SUPABASE_ANON_KEY` بالاسم** بـ`jq` وبس، وعمره ما
بيطبع قيمة.

**و`leak_check.sh` هو اللي بيمنع ده يحصل بالغلط** — بيجري بعد البناء وقبل
الرفع، وبيوقف الرفع لو لقى:
- قيمة أي مفتاح في `secrets.json` **غير** الاتنين المسموحين،
- أو **اسم** أي مفتاح منهم (وجود الاسم معناه إن التعريف اتمرّر للبناء)،
- أو `AIza` أو اسم مفتاح الخدمة، مهما كان مصدرهم.
بيدوّر في الملفات الثنائية كمان (`grep -a`) — سر جوّه `.wasm` سر برضه.
**وبيطبع اسم المفتاح وبس، عمره ما يطبع قيمته**: تقرير بيسرّب السر وهو
بيبلّغ عنه أسوأ من مفيش تقرير. `admin/test/leak_check_test.dart` **بيشغّل
السكربت الحقيقي** على مجلد مزيّف بقيم مخترعة — تسعة حالات، منهم واحدة
بتثبت إن القيمة ما بتتطبعش. مُتحقَّق بالطفرة: `exit 1` → `exit 0` بيوقّع
خمس حالات.

**قايمة السماح مفتوحة للمراجعة عن قصد**: اختبار بيثبّت السطر
`ALLOWED=("SUPABASE_URL" "SUPABASE_ANON_KEY")` بالحرف، فأي زيادة عليها
بتبقى قرار نشر بيتقرا بالعين، مش سهو في سكربت.

**ورابط مشروع سوپابيز ما بيتكوميتش.** `firebase.json` المتتبَّع فيه علامة
`__SUPABASE_ORIGIN__` في الـCSP، و`deploy.sh` بيكتب `firebase.deploy.json`
مؤقت (متجاهَل في git، وبيتمسح في `trap`) وبيرفع بيه بـ`--config`. الرابط
عام بطبيعته (بيشحن في كل APK)، بس الريبو ماسكه برّه git من زمان والجولة
دي ما بتغيّرش القرار ده من ورا حد.

**الترويسات** (كلها في `firebase.json`، والتحقق تحت):
`X-Frame-Options: DENY`، `Referrer-Policy: no-referrer`،
`X-Content-Type-Options: nosniff`، و**CSP** بتسمح بـ`'self'` وبأصل
سوپابيز وبس: `script-src 'self' 'wasm-unsafe-eval'` (الـwasm لـCanvasKit)،
`style-src 'self' 'unsafe-inline'` (فلاتر بيحقن أنماط)،
`worker-src 'self' blob:`، و`frame-ancestors 'none'`.
**مفيش Google Fonts ولا أي CDN**: الخطوط متحزّمة، والبناء بـ
`--no-web-resources-cdn` بينزّل CanvasKit جوّه الحزمة (`useLocalCanvasKit`
= true) بدل `gstatic.com`، و`--csp` بيطلّع جافاسكريبت من غير `eval`.

**والكاش مكتوب على اللي فلاتر بيطلّعه فعلاً، مش على المثالي.** فلاتر
للويب **ما بيحطّش هاش في أسماء الملفات** — `main.dart.js` اسمه هو هو كل
رفعة — فمفيش حاجة تستاهل `immutable` بسنة. اللي اتعمل: `.html`/`.json`/
`.js` كلهم `no-cache` (يعني «تأكّد بالـETag»، مش «ما تخزّنش»)، و
`canvaskit/` و`assets/` و`icons/` يوم واحد — ده بيوفّر إعادة تنزيل ٦ ميجا
CanvasKit في نفس اليوم وبيحدّ أي بيات بعد ترقية فلاتر بيوم.

**التحقق اللي اتعمل فعلاً**: الحزمة اتبنت، و`leak_check` عدّى عليها،
واتسرفت محلياً **بنفس الترويسات** واتفتحت في Chrome بلا واجهة —
**صفر مخالفة CSP**، وفلاتر رسم (`<flutter-view>` بمقاسات حقيقية). **اللي
ما اتجرّبش**: نداء سوپابيز الحقيقي (اللوحة ما بتلمسش الشبكة قبل الدخول)،
فـ`connect-src` متحقَّق بالقراية مش بالتشغيل.

**والأوامر اللي المالك بيشغّلها** (أنا ما شغّلتش ولا واحد — مفيش
firebase CLI ولا جلسة على الماكينة دي):

```bash
npm i -g firebase-tools          # مرة واحدة
firebase login                   # مرة واحدة
firebase hosting:sites:create fakkarni-admin   # أول مرة بس
bash admin/tool/deploy.sh        # بناء + فحص + رفع
bash admin/tool/deploy.sh --no-deploy   # بناء + فحص من غير رفع
```

### الموبايل: الجدول بيبقى كروت

المدير ممكن يفتح اللوحة من موبايله، وجدول بعشرة أعمدة على ٣٩٠ بكسل بيبقى
تمرير أفقي مش بصة سريعة. تحت `phoneBreakpoint` (٧٠٠) الصفوف بتبقى كروت
(`AccountsCards`) — **نفس الأعمدة بالحرف، ولا واحد اتشال** — وشريط
العدّادات بيبقى اتنين في الصف. فوق ٧٠٠ الجدول زي ما هو.
`admin/test/phone_width_test.dart` بيقيس على ٣٩٠ و٣٧٥ ويثبت الكروت
ومفيش فيض، وعلى ١٤٠٠ يثبت الجدول. مُتحقَّق بالطفرة.
**والترتيب على الموبايل قايمة منسدلة** (`AccountsSortBar`) — بديل
ترويسات الجدول اللي مش موجودة لما الصفوف بتبقى كروت. من غيرها كان المكتب
يقدر يسأل تلات أسئلة والموبايل سؤال واحد، على نفس الداتا.
- **قايمة بالعمود، وزرار بالاتجاه**، الاتنين بكلامهم. تلات مداخل بس (نفس
  الأعمدة اللي بتترتّب في الجدول) مش ستة بالاتجاهين — ست سطور على شاشة
  بصة سريعة بقت قراية مش اختيار.
- **ووصف الاتجاه بيمشي مع نوع العمود**: «الأكتر الأول» على عمود أرقام،
  «الأقدم الأول» على عمود وقت. كلمة واحدة لكل الأعمدة («تصاعدي») كانت
  هتخلّي الواحد يترجم في دماغه.

**و«عمود جديد بيبدأ من طرفه الوحش» — ودي غيّرت المكتب كمان.**
`defaultAscendingFor` دالة نقية: «آخر مزامنة» بتبدأ تصاعدي (الساكت الأول،
لأن `lastSyncAt == null` بيسبق أي تاريخ)، والباقي تنازلي (الأكتر الأول).
قبلها كل عمود جديد كان بيبدأ **تنازلي** في الجدول، يعني أول دوسة على
«آخر مزامنة» كانت بتجيب **الأحدث** — أهدى صف في الأسطول أول القايمة،
وهو عكس السؤال اللي الواحد بيفتح العمود ده عشانه. الجدول والقايمة
بيندهوا نفس الدالة، فمفيش ناحيتين يقدروا يختلفوا.

### تسجيل حسابات جديدة — **ما تقفلهاش دلوقتي**

اللوحة **مفيهاش تسجيل حساب ولا استرجاع باسورد** عن قصد: الأدمن بيتعمل من
لوحة سوپابيز وبس.

**والطلب إن «Allow new users to sign up» تتقفل — دي بتكسّر تطبيق الموبايل،
فما اتعملتش.** الدليل من مصدر GoTrue نفسه
(`internal/api/anonymous.go`، أول الدالة):

```go
func (a *API) SignupAnonymously(w http.ResponseWriter, r *http.Request) error {
	...
	if config.DisableSignup {
		return apierrors.NewUnprocessableEntityError(
			apierrors.ErrorCodeSignupDisabled, "Signups not allowed for this instance")
	}
```

والدخول المجهول في دارت بيروح على **نفس النقطة**: `signInAnonymously()` في
`gotrue-2.27.2/lib/src/gotrue_client.dart:245` بتعمل `POST $_url/signup`.
والدخول المجهول هو **الدخول الشغّال الوحيد في التطبيق** (الدين ٢،
`AnonymousAuthService`) — فقفل التسجيل معناه إن «اربط ابني» يقع عند كل
مستخدم. **وتوثيق سوپابيز ساكت عن التداخل ده تماماً**، فالمصدر هو الدليل
الوحيد.

**ومكسبها الأمني هنا قريب من الصفر**: حساب جديد على المشروع ما بيقراش
حاجة — `private.is_admin()` بترد «not admin»، وRLS هو الحاجز على كل حاجة
تانية. يعني التنازل كان: نكسر دخول كل مريض عشان نقفل باب مقفول أصلاً.

**تتقفل إمتى**: يوم ما الدين ٢ يتدفع (جوجل/أبل بدل المجهول). ساعتها،
والمسار للمالك:

> `https://supabase.com/dashboard/project/<project-ref>/auth/providers`
> → قسم **User Signups** فوق → **Allow new users to sign up** → OFF.
> (نفس الصفحة اللي فيها **Anonymous sign-ins**.)

**وقبل ما تقفلها، اتأكد بنفسك** إن مفيش نسخة بتستعمل الدخول المجهول:
اقفلها، حاول «اربط ابني» على موبايل، ولو رجعت
`Signups not allowed for this instance` ارجّعها فوراً.

## دين تقني

Debts we took on knowingly. Each one blocks something specific — check this
list before any store submission.

### Decision: phone calls are cancelled (not deferred)

Automated voice calls to the caregiver are **out of the product**. Decided
deliberately, not forgotten — do not reintroduce them, and do not propose
them in a plan without the owner asking first.

Why: a paid telephony provider working in Egypt, per-call cost, Arabic TTS,
DTMF confirmation and call-state webhooks were the single largest source of
risk and delay in the plan, for a feature that could not ship free.

What replaces it: escalation ends at a **push notification to the caregiver**.

What this costs us, stated honestly so nobody is surprised later: push is the
same channel the patient already missed, so the ladder is weaker than a call.
That makes the mechanics of the caregiver alert load-bearing — see the
escalation rules below. It is not "just another notification"; it is the last
rung, and it must behave like one.

Consequences to handle:
- The executive plan given to management describes a **paid subscription for
  the calls feature**. That subscription now has no feature behind it. The
  plan document needs updating before it is shown again — **and the model it
  should describe is «Pricing» below** (24 Sep 2026): one family subscription
  per patient covers him and up to five followers.
- `escalations.channel` stays in the schema with value `push`. It is a
  generic audit column, not a placeholder for calls.
- iOS **Critical Alerts** entitlement (bypasses silent mode and Focus) is now
  the only remaining way to make the caregiver alert harder to miss. It needs
  Apple's approval and the paid developer account. Request it before launch.

0. **Cloud coverage is two days, and the son can see when it runs out.**
   Each app open uploads today and tomorrow, so escalation keeps working
   for about two days with no interaction at all; after that the cloud
   goes stale and the server has nothing current to judge. This is not
   filed as an invisible risk — the caregiver footer
   («آخر تحديث من موبايل والدك») turns **gold** once the last update is
   older than `staleAfter` (24h), before coverage runs out rather than
   after, and adds «اطمن عليه». Gold means "this needs your attention
   now", and a father whose phone has said nothing for a day is exactly
   that. Do not bury this under a retry or a background fetch; the
   silence is the signal.
0b. **A confirmation made offline can still alert the son.** He takes the
   pill, confirms, and the push cannot leave — the cloud row stays
   `pending` past +60 and the son is told. `syncSlack` covers a slow
   wire, not a dead one. Inherent to any server-side scan; his view
   corrects on the next refresh (rule 5).
0c. **THE WORST FAILURE MODE, AND IT IS OPEN: when the reminder horizon
   runs out the app goes quiet and says nothing.** The patient who
   forgets most is the one the app stops speaking to first.
   `planWindow` keeps the **nearest** `maxPendingReminders` (44) and
   drops the rest, so coverage is contiguous from now to a horizon and
   then simply ends — no gap, no last warning. Every renewal path needs
   a human: launch (`main.dart`), foreground resume (`root.dart`), a
   confirmation, or a lock-screen «أخدته»/«فكّرني بعدين» through the
   background isolate. A patient who answers his notifications therefore
   never reaches the horizon; **a patient who ignores every one of them
   reaches it in about five days** and the reminders stop. The
   pre-scheduled ladder stops with them, `materializeDay` stops running,
   the cloud goes stale two days later, and the server-side scan has
   nothing current to judge — so the last rung falls silent too. On his
   phone nothing is wrong: a normal app that has gone quiet.
   `coverageEnd()` in `reminder_plan.dart` computes the exact instant and
   **is rendered on no screen** — it exists only in tests. The son's only
   signal is debt 0's gold footer, which reports his father's phone being
   silent, not his father's reminders having run out; they are different
   facts and only one of them is shown.
   **Measured, so the shape is not guessed at** (20 Sep 2026,
   `DayRoutine.fallback`): what fills the queue is **distinct reminder
   minutes per day**, not medications — the engine merges same-minute
   doses, so 8 medications × 3 doses on the app's own convention (all
   «قبل الأكل») is **3 notifications a day** and gets the full 7-day
   window, exactly like 5 × 3 and 3 × 2. Only a patient whose offsets
   were hand-edited so nothing merges gets near the cap: 9 distinct
   minutes a day → ~5 days, 15 → ~3, 24 → ~2. The 46 → 44 drop for the
   checkup band cost **no case a calendar day** — the largest loss is
   about six hours, and the ladder paid nothing (`maxPendingEscalations`
   is still 14).
   **Not built, on purpose, and not a sizing problem.** Widening the cap
   cannot fix it — iOS holds 64 and the horizon always ends somewhere.
   The repair is to make the end **visible before it arrives** (the
   father's screen, the son's screen, or both) rather than to push it
   further away in silence, and the day the two slots are wanted back,
   `checkupPendingSlack` and `fastingPendingSlack` can be borrowed only
   while a follow-up is actually open — computed from `pendingIds()`
   through `isCheckupId`/`isFastingId`, with `CheckupService` calling
   `rescheduleAll` when it touches its band, and `maxPendingEscalations`
   left a constant so the ladder never shrinks. That is a saving of
   about six hours; it is not the fix for this item.
1. **Sync deletes exactly one table, and has no second owner device — yet.**
   `SyncRemote.deleteByUuid` exists for `records` only, because deleting a
   record is the first thing a person does that *must* reach the cloud (see
   «المسح بيمسح» below). Every other table is still upsert-only, and a
   second device for the same owner still ships as last-write-wins by
   `updated_at` — neither exists today, and nothing may pretend to handle
   them until they do. Do not read the records delete as permission to
   delete elsewhere: each table that needs one needs its own thinking about
   what the absent row means to the son.
   **The lock-screen note that used to sit here was false, and it sent the
   next reader — me — down the wrong path.** It said a dose confirmed from
   the lock screen stays dirty until the next app open «because the
   background isolate builds no SyncService». Round 4.2a made that untrue:
   `onBackgroundNotificationAction` builds one whenever
   `initSupabaseForIsolate()` returns non-null, and `pushOnce` runs as the
   handler's last statement. What is actually true is narrower and is not a
   sync debt at all: the isolate pushes **if it runs**, and on iOS whether
   it runs at all has never been observed on hardware (see «صحوة شاشة
   القفل على iOS» under Architecture). A note that contradicts the code
   costs more than no note.
2b. **The Gemini key is inside the binary (since the C2 revert,
   18 Sep 2026). Shipping to any store in this state is forbidden.**
   Same shelf as anonymous auth, same absolute rule. Paying it back is
   reverting the revert — the function, its migration and its guard test
   are all still in the tree for exactly that. Do not "improve" the
   direct-call path in ways that make C2 harder to re-apply.
2. **Anonymous sign-in is a development stand-in ONLY.** An anonymous user
   is bound to one device and is lost when app data is cleared. It must be
   upgraded via `linkIdentity` to Google before any store submission.
   **Shipping with anonymous auth is forbidden.**
   **It also costs us `public.claim_device_token`.** Anonymous sign-out
   mints a *new user on the same device*, so the unchanged FCM token
   collides with a dead user's row; the function reattaches it atomically
   and trusts possession of the token as proof. The accepted risk is named
   in `0006_push.sql`: whoever obtains another install's token can claim
   it, and that victim's phone then receives alerts naming a stranger's
   patient and medication. Low risk today — the token leaves neither the
   device nor our server. **When this debt is paid the collision disappears
   at its source** (a real Google/Apple id survives sign-out), so delete
   the function and go back to a plain upsert under RLS. Revisit it here,
   not somewhere it will be forgotten.
3. **Sign in with Apple is mandatory before any iOS App Store submission**
   once Google is offered (Guideline 4.8). Blocked until the paid Apple
   Developer account exists. It lands as a sibling `AuthService` file.
4. **Huawei / no-GMS devices cannot use Google Sign-In** — a real segment
   in Egypt. May require adding an email provider later; `AuthService`
   must stay open to it (which is why the interface is provider-neutral).
**Deferred by decision (not by oversight):**
- **Mockup 21's «الروشتة لو مش مكتوب فيها ميعاد؟» policy block is not
  built.** Its third option («افترض من غير ما تسأل») lets an AI reading
  become a scheduled dose without a tap — rule 4 forbids exactly that.
- **`accountType` is not stored.** «Roles emerge from data… there is no
  role column» (3.3). Mockup 2's cards are the D4 entry screen — it only
  routes; the choice lives in memory and is gone once setup ends (see D4).
- **Google and Apple sign-in are shown disabled on mockup 3, each with its
  own real reason** — Google «قريباً», Apple «محتاج حساب Apple Developer».
  They are not buttons (no InkWell, a lock, a muted fill), a test taps them
  and asserts zero sign-in calls. The only working control is «كمّل بحساب
  تجريبي», labelled as what it is (debt 2). Email is not offered (Email OTP
  was removed from the product).
- **«الملف الصحي» is not a settings row.** It is a dock tab; two doors to
  one room make a user wonder whether they are two different rooms.
  «قريب منك» stays in settings — it has no tab.
- **Mockup 33's rows with no backend are not built:** نمط كبار السن,
  التنبيهات, الاسم والسن, بطاقة الطوارئ, تصدير البيانات. A settings row that
  opens onto nothing is worse than a row that is not there. Each returns
  with the feature behind it. «اللغة: عربي» is shown disabled — no English
  in this version, and the row says so instead of pretending.
- **Mockup 09's voice-add button is not built** — no speech input exists.
  Adding goes through the shell's «ضيف».
- **Mockup 15's per-member permissions (checkboxes per caregiver) are not
  built.** There is no permissions table in the backend; a permissions UI
  that changes nothing is worse than none. Ships with the schema that
  makes it true, or not at all.
- **The invite *link* (`fakrny.app/join/…`) is not built.** The 6-digit
  code is live and verified on the cloud; a link needs a domain and a deep
  link that do not exist. The design's invite block is used with the code
  inside it; «ابعته» copies the ready message (no `share_plus` before the
  demo — the callback is injectable when it lands).
- **Mockup 22's «قواعد الافتراض» block (قبل/مع/بعد الأكل + gap stepper +
  live 1×/2×/3× table + default duration) is not built — and not because
  of time.** «مع الأكل» and «المدة» are now asked **per medication** in the
  «ضيف دوا» path, which is more precise than one global rule; a global
  rule would be a second place holding the same decision, free to
  disagree with the first. If it ever returns it must *feed* the per-dose
  defaults, never override them.
- **Mockup 10's voice line («قول تمام لتسجيل الجرعة») is dropped, not
  deferred.** The app has no TTS and no speech input. A line asking a
  72-year-old to speak to a phone that cannot hear him is worse than no
  line: he says «تمام», nothing happens, and the dose he just took looks
  unconfirmed. If voice confirmation is ever built, it lands as a real
  input path with its own test, and only then does the line come back.
- **Escalation rung 5 («+٩٠ — دائرة الرعاية كلها») is not built**, so the
  alert screen's ladder shows the four rungs that exist and its ramp stops
  at `F.orange`. Red never appears on it — the fifth rung would have been
  the only red, and drawing it would promise an alert nobody sends.
- **«لا أذكر» on the alert screen** — no state for it in `dose_events`;
  «تخطّي» with a human asking covers the same case.
- **Mockup 18's «📞 اتصل بمحمد» (and its «اتصل» tab) is not built.** Since
  D3.4 the patient can type emergency contacts (name, number, relation),
  stored **on this device only** and never synced — so the old reason ("we
  collect no phone numbers") no longer holds. The honest reason now: a call
  button on the elder home lands *on top of* those contacts (which one is
  «ابنك»?), not on its own, and the one-tap «طوارئ» card already carries
  their call buttons. The server still holds no phone number, and phone
  calls from the escalation ladder stay cancelled. Elder mode's
  second tab is «الإعدادات» instead: it is the only way back out of the
  mode. Its voice line («قول تمام وأنا هسجّلها») is dropped for the same
  reason as mockup 10's.
- **Mockup 32's emergency card on the real lock screen is not built.** That
  needs a WidgetKit extension in Swift plus an App Group for the data, and
  the Android equivalent. What exists is an **in-app full screen** with the
  same look and function, one tap from the top bar in every tab (and in
  elder mode). No user-facing text calls it a lock-screen card or says it
  works «من غير فك الموبايل»; a test asserts that.
- **Mockup 19's «ملاحظة للمسعف» field and mockup 32's «مشاركة سريعة» are
  not built** — not in the plan, and sharing needs `share_plus`.
- **Mockup 13's «استخراج الملف» waits for
  D3.8, and its «نشطة/منتهية» chips and 29's «إيقاف دوا» entries come from
  `medications`, not records, so they are not on these screens.
- **A manual «روشتة» or «حجز» record schedules nothing.** Both forms say so
  in words; medicines are added through «ضيف», and bookings have no
  notification band.
- **Mockup 14's voice entry is not built** — there is no speech input.
  Glucose is typed. Its «المستهدف» line and «أعلى من المستهدف» chip are
  not built either: that is a textbook target dressed as an interface.
- **Mockup 7's multi-page capture is not built** — one page per scan.
- **Mockup 8's reference range is built (round 21) — as the *paper's*
  range, never ours.** `lab_results` carries `ref_low` / `ref_high` /
  `ref_text` (v18, cloud `0016`), transcribed by the reader from that
  report and by nobody else: the prompt says a missing range is a correct
  answer and a remembered one is wrong «even when it is medically true»,
  and an unsure read is stored as no range at all. A line whose report
  printed none shows the plain number and says so
  («الورقة ما فيهاش نطاق للتحليل ده»). The comparison is two printed
  numbers and lives in `domain/health/lab_range.dart`; «قريب من الحد» is
  **our display aid, not medicine** — one named constant,
  `nearBoundaryFraction` (10% of the printed range's own width), needing
  both bounds, and worded as nothing more than those three words.
  `test/app/no_builtin_lab_ranges_test.dart` fails on any lab-test name
  sitting next to a number anywhere in `lib/`, and pins that the rule file
  holds no number but that fraction — there is **no table of normal
  values**, and there must never be one.
  The mockup's «أعلى» chips and red cards are still not built: the flag
  words are «فوق المعدل» / «تحت المعدل» / «قريب من الحد» and nothing else,
  and the red is text + an **outlined** badge — see the red rule above.
  **All three places that show a lab value show the same range and the
  same word**, from one wording file and one `LabFlagBadge`: the reading
  screen, the son's «الملف الصحي» (the range rides the cloud embed since
  `0016`; a row written before v18 simply has none), and «صفحة الطبيب».
  **The range is worded the way the paper says it** (round 27): «من ٤ إلى
  ١١» for two bounds, «أكتر من ٤٠» / «أقل من ٢٠٠» for one. Never «من ٤٠»
  alone — that reads as a sentence cut in half, and sometimes it *is* one:
  a two-sided range can reach the screen with one bound missing, and the
  clear wording is what makes that visible instead of plausible.
  **Three ways a bound goes missing, all on the extraction side** — found
  by reproducing them, after proving the formatter renders both bounds
  whenever both arrive: the model returned it below the confidence
  threshold, returned it as a string (`"1.2"`) where the schema said
  NUMBER, or **omitted the field entirely**, which the schema allowed
  because `required` listed only test/value/unit. All three are fixed:
  the three range fields are now required (nullable values, so absence is
  a written `null` rather than a missing key), `_number` reads a numeric
  string, and the prompt asks for both bounds of one printed range at one
  confidence. `GeminiLabReader` logs the parsed range per line in debug
  (`Gemini: نطاق TSH — low=…/… high=…/…`), because the three causes look
  identical on screen.
  **Still open**: a two-sided range with one bound below threshold keeps
  the confident bound and drops the other, which silently disables
  «قريب من الحد» on that line. The wording exposes it and «عدّل» fixes it;
  the honest repair is a review mark that does not block «تمام» (rule 4's
  shape for an unknown amount), and it is not built.
  A second wording here would be a second opinion — the father and the son
  are reading the same paper and must read the same sentence.
  `expectNoRedAndMinSize` allows red only inside that badge, scoped to the
  widget, so red text anywhere else on those screens still fails.
- **Mockup 11's rule box («قاعدة: لا يمكن للفحص أن يبقى…») and «المتوقع ٢٤
  ساعة» are not built** — an automatic judgment on delay and a number
  nobody gave us. The fasting duration is never ours either: the user picks
  the hours the lab gave.
- **The calendar shows doses only where `dose_events` rows exist** (up to
  tomorrow). It does not recompute future days with the engine, and says so.
- **The son adding visit questions from his own phone is not built** — it
  needs the cloud; questions are written on the patient's phone only.
- **Mockup 16's trend arrow («↑ عن الشهر السابق»), the red lab arrows and
  the medication stop reason are not built** — a judgment, a colour we do
  not spend, and a field nobody stores.
- **Mockup 30's second per-section control is not built:** a switch and «👁
  مرئي» meant the same thing; there is one 👁 «هيظهر» / 🙈 «مخفي» chip.
- **Mockup 17's star ratings are not built, and never will be from OSM.**
  OpenStreetMap has no ratings; a made-up star on a real pharmacy is a lie
  told to people, not a UI detail. «Concor 5mg متوفر», «توصيل ٤٥ د» and
  «بيقبل تأمينك» are not built either — no source holds them. Its «معامل»
  filter is left out (not in the brief).
- **Mockup 26's «ساعات الهدوء» is not built.** README's rule is that quiet
  hours silence everything **except** a missed dose and emergency — and
  those are the only alerts we have, so the switch would do nothing. A
  settings row that does nothing is worse than a row that is not there.
- **Mockup 26's other rows wait for their features:** «نداء الطوارئ 🔒»
  lands with D3.4 (a locked row would promise an alert nobody sends),
  «قراءة سكر غير معتادة» with D3.6, and «عضو أكّد جرعة» / «انضمام عضو
  بالرابط» / «رفع تقرير أو تحليل» when a notification exists behind them.

4b. **«قريب منك» runs on public OpenStreetMap services — fine for a demo,
   not for a store launch at scale.** Overpass's policy says an app for
   regular users on the public instance "requires your own instance"
   (~10k requests/day guideline); the tile policy allows small apps
   (distinct User-Agent, attribution, ≥7-day caching, no offline bulk) but
   access "may be withdrawn at any point". Before launch: our own Overpass
   instance or a paid provider, and a tile provider that allows commercial
   use. Doctors' coverage in Egypt on OSM is thin and is shown as-is.

4c. **Every install still gets an empty «أنا» patient row at boot** (D4
   took option A2). `buildServices` calls `ensurePatient()` and
   `AppServices.patientId` is a non-null int that the scheduler, every
   screen and the lock-screen isolate rely on — so "has a patient" is
   *derived*: a saved routine **or** a non-null `sex`
   (`RoutineRepository.watchHasPatient`). The son's phone therefore holds a
   row that is not a patient; `SyncService` never pushes a patient with no
   routine and no medications, so it cannot reach the cloud and make him
   one. **The correct long-term shape is A1:** create the row only when
   «نتعرّف عليك» saves, and build the patient-bound services after that.
   It is a refactor of everything that reads `patientId`, not a tweak.
6. **Two dark-mode faults found in the caregiver round, reported and NOT
   fixed — both are app-wide, not caregiver-specific.**
   - **`FSecondaryButton` and `FPrimaryButton` outline in `F.greenDeep`**
     (`primitives.dart:112` and `:144`), a constant. On the night page
     ground that is **1.71:1** — the outline is invisible, so a secondary
     button reads as bare text with no boundary. The label itself is
     `F.ink` (16:1) so nothing is unreadable; what is lost is the button's
     edge. Not text, so AA's 4.5 does not apply, but WCAG 1.4.11 wants 3:1
     for a control boundary. The fix is one token, and it repaints **every
     button in the app** — it belongs in its own round with a look at the
     patient screens, not in a round about the son's switch.
   - **Toggling the mode drops you back on the first tab.** `main` keys
     the whole app on the mode (`KeyedSubtree(key: ValueKey(dark))`)
     because a `const` subtree will not rebuild otherwise — and that key
     discards every `State`, including the shell's selected tab and the
     caregiver's snapshot holder. Mild for the patient, whose toggle is in
     a bar he is usually looking at from «اليوم»; visible for the son,
     who taps it **in Settings** and lands on «متابعة».
     `caregiver_dark_mode_test` pins this by name rather than hiding it.
     The repair is to stop keying on the mode (make the few `const`
     subtrees non-const, or lift the tab index above the key), which is a
     root change.
5. **PAID (with the white-ground round).** `F.muted` (`#6E7F76`) was the
   secondary text colour and measured 3.68:1 on ivory — under the 4.5:1 AA
   needs at this size. All 65 text uses moved to `F.mutedDark` (`#43544C`):
   8.04:1 on the page, 6.99:1 on a card. `F.muted` survives on three
   controls only — a switch's inactive thumb and two chevron icons — where
   AA's text rule does not apply. **It is still 3.68:1 on a card, so it must
   never come back as text.**

---

## Design reference

All 33 screen mockups live in `screenshots/` as numbered PNGs
(`01-splash.png` … `33-settings.png`). Look at the relevant file before
building a screen, and match its layout, hierarchy and spacing.

**They are a reference for appearance, not for structure.** Do not translate
the mockup's HTML/CSS into Flutter literally — build with native Flutter
widgets and take every colour and size from `class F` in
`lib/core/theme/tokens.dart`, never from a value eyeballed off the image.

**Where a mockup and the UI rules above disagree, the rules win** — especially
minimum text size and tap targets. Say so instead of silently following the
image.

---

## Commands

```bash
flutter test                       # everything
flutter test test/domain/          # engine only, ~1 second
flutter run                        # needs a REAL device for notification testing
flutter analyze
```

Flutter 3.47.1 / Dart 3.13.1 at `~/develop/flutter`. There is an older Flutter
elsewhere on this machine — always use the one on PATH after `.zshrc` setup.

---

## Testing conventions

**A green assertion that was never put to the question is not a guard.**
The pattern: a check whose *condition has never occurred in any fixture*.
It passes everywhere, is counted in the total, reads as coverage in review,
and is load-bearing in exactly nobody's hands — and the first real case
walks straight past it, or fails it for the wrong reason. A test is a guard
only once something has actually made it go red. **Twice in one week now**,
so it is written down:

- **`expectNoRedAndMinSize`** asserts no red text on a screen and is called
  from **23 test files**. It had never seen red. Every lab fixture in the
  suite had a value with no printed range, so the one thing that can
  legitimately be red — an out-of-range lab value (round 21) — had never
  been rendered under it. The helper was not protecting 23 screens from
  red; it was protecting them from a case that never arrived, and the first
  test to carry an out-of-range value would have failed on a badge the
  owner had just sanctioned.
- **A mutation check that reported zero failures over a corrupted file.**
  Removing the v18 migration step was supposed to turn the migration tests
  red. It reported all green — because the removal never happened: the
  script sliced on `if (from < 6) {`, which appears **twice** in
  `app_database.dart`, so it duplicated the migration chain instead of
  cutting the step out. The "check" was green over a file that still had
  the step *and* was now broken in four places. A mutation check proves
  nothing until you prove the mutation landed — assert the thing is gone
  before running the suite, and anchor on a string you have verified is
  unique.

**The fix is a fixture that triggers the condition — not an exemption.**
When a guard finally meets its case and the case is legitimate, the
temptation is to widen the guard and move on; that leaves it exactly as
unexercised as before, now with a hole in it. `expectNoRedAndMinSize` did
need one narrow exemption (red inside `LabFlagBadge` is a product
decision), but that is not what made it a guard again: what did is that
the son's screen and the doctor page now have fixtures carrying above,
below and near-boundary values, and that red **outside** the badge on
those same screens still fails — mutation-checked by colouring the range
line and watching it go red.

So: when you add a shared assertion, add the fixture that makes it fail on
the same day. When you meet one that has never fired, treat it as untested
code, because that is what it is.

**And the sibling failure: the instrument measuring something other than
what its name says.** On the Android lock-screen test this happened
**six times in seven runs** — an `executeShellCommand` assertion that
passed over empty output, a framework database read that flipped the file
out of WAL, an assertion on a name that appears in both states, a matcher
reading `text` on a Flutter screen that publishes through `content-desc`,
the CI harness itself (each `script:` line in its own shell, so the test's
exit status never reached the job), and a long-press on a notification
that landed as a plain tap on a busy emulator — dismissing the very button
it was reaching for. Each one accused the app; the app was innocent every
time. **A gesture on system UI is timing-dependent: target a control by
id, never a region by gesture.** **Before suspecting
`lib/`, ask whether the tool measures what it claims to** — and remember
a red job is not a red test: read `TestRunner: run finished` first. The
five cases and their evidence are under «اللي لسه مش متأكَّد منه على
أندرويد».

**The test harness has a required shape, and breaking it fails as a hang,
not as an error.** `testWidgets` runs the body inside a fake-async zone.
Step outside what that zone can drive and the test does not fail — it
stops, with no message, no stack, and **no reaction to `--timeout`**. It
looks exactly like a slow machine. Twice now:

- **Real file IO awaited outside `tester.runAsync`.** `await store.save(…)`
  in a test body never returns: the completion needs the real event loop,
  which the fake zone is not pumping. Every direct file operation in a
  widget test goes through a `runAsync` wrapper — see the `io()` helper in
  `test/features/records/attachment_test.dart` and the comment above it.
- **Plain `testWidgets` instead of the project's `screenTest`.** Any screen
  holding a drift stream leaves a `StreamQueryStore` timer pending at
  teardown; `screenTest` (in `test/features/scan/scan_test_support.dart`)
  pumps an empty tree and drains it. Without it the round-24 follow-up
  tests hung — all of them, silently. **Use `screenTest` for anything that
  pumps a screen**; reach for bare `testWidgets` only for a widget with no
  streams and no IO.

The tell is the same in both cases: **a test that hangs is usually a test
doing something the harness cannot drive, not a test that is slow.** Before
hunting for an infinite loop in the code under test, check what the body
awaits — and remember `pumpAndSettle` is a third way into this, which is
why no test on a patient screen calls it (the water drop animates forever).

---

## Current state

**Phase 1 is complete and verified on a physical iPhone** — reminders fire
with the app fully closed, offline, and across a reboot.

**Done (Phase 1)**
- Scheduling engine + tests (offsets, after-midnight bedtime, Ramadan,
  grouping, `once` repeat, open-ended duration, next-reminder, fixed times)
- Brand tokens (`class F`)
- `NotificationService` — timezone-aware scheduling, exact-alarm handling
- Android manifest permissions, receivers, core library desugaring
- drift database + repositories, schema v3 with in-place migrations
- Engine → notifications: derived IDs, 7-day / 48-pending window,
  band-filtered reconcile, `rescheduleAll()` on every launch
- Screens: routine onboarding, add medication (anchor default + fixed-time
  escape hatch), «يومك», reminder, edit routine («عدّل يومك»)
- Notification tap → `ReminderScreen` (also on cold launch, waits for the
  routine to load). Payload = routine day + schedule IDs, never a time.
- Snooze («فكّرني بعد ربع ساعة») in its own ID band
- Notification action buttons («أخدته» / «فكّرني بعدين») handled in a
  background isolate; every confirmation re-extends the window; early
  confirmations are excluded from re-scheduling

**Phase 2 — read a paper prescription (built, needs a real-photo pass)**
- `lib/ai/`: config, reading model with per-field confidence, Gemini REST
  reader. Threshold 0.8; below it the medicine's row gets a gold side edge
  and «مش متأكد من دي — راجعها», listing each unsure field with its note.
- Scan screen (D2.3, mockup 05): corner frame over the captured photo,
  «صوّر الروشتة» 64px with «اختار من الصور» / «أكتبها بإيدي» 56px under it.
  **The line-by-line reveal is honest by construction:** Gemini returns
  everything at once, so while waiting the frame shows only «بيقرا
  الروشتة…» with a pulsing dot and **no marked lines**; once the reply
  lands the reveal walks the lines that actually came back (their real
  count and names — dashed until read, filled ivory after), then goes to
  review. Boxes are stacked, not placed: the model returns no coordinates
  and drawing on an imagined spot would be the same lie. Pinned by a test
  that completes the reader mid-flight. Then the review screen (D2.2, mockup 06): one
  row per medicine — mono name, resolved time shown in Arabic digits (never
  stored), a chip with the rule not the time, «عدّل» with icon + word — a
  dashed «أضف دوا ما اتعرفش عليه» row, and «أعدّل» / «تمام، ظبّطهم» as two
  solid dark buttons of identical size and type (the test compares style,
  not just size), plus «صوّر تاني» — which returns
  to the scan screen so both sources are offered again, never auto-opening
  the camera.
  «تمام، ظبّطهم» writes each clear line (one schedule per timing) then `rescheduleAll`.
- Editor accepts prefilled values and now has an optional amount field;
  the offset wheel follows the chip (30 before meals, 15 before sleep).
  Since D2.5 the timing lives in one shared `DoseEditor`; «ضيف دوا» asks
  name / amount / «كام مرة» / «مع الأكل» / duration first and hands off to
  it once per timing («الجرعة ١ من ٣»), saving nothing until the last
  «احفظ الجرعة». «كام مرة» → meals is our operational convention (١×
  الفطار، ٢× + العشا، ٣× + الغدا), every page editable. The design's
  `{ anchor: … }` line is a designer's note, not UI — not built.
- Unknown amount is non-blocking: saved as `amountUnknown`, surfaced on
  «يومك» as «اسأل الصيدلي عن جرعة …», which opens `EditMedicationScreen`.
- «يومك» lists «أدويتك» (mockup 09 rows: name, amount · rule); each row
  opens `EditMedicationScreen`: set the amount (the only place that clears
  `amountUnknown`, by a value a human typed) or stop the medication —
  two-step confirm, ink not red, `stopMedication` + `rescheduleAll`.
- Model pinned to `gemini-3.6-flash` with a one-shot, loudly-logged fallback
  to `gemini-flash-latest` on `404 NOT_FOUND`.
- Not yet done on hardware: a real handwritten prescription through the
  live API — that is where the image-size numbers and the prompt get tuned.

**Round 4.1 — the local ladder on the father's phone (built, not yet
device-verified)**
- `domain/escalation/escalation_ladder.dart` (pure) + tests; bands 10M and
  30M; `planEscalations`, `isRescheduledId`, `snoozePendingSlack`;
  ladder planned from now − 45; rule-5 cancel covers both rungs; snooze
  clears overtaken rungs only; `sweepMissed` + yesterday/today
  materialisation inside `rescheduleAll`; resume hook reschedules;
  `fakkarni_escalation` Android channel; «نسيتها؟» / «اتنست» on «يومك»,
  `missed` verbatim on the caregiver screen. No schema change.
- Device check pending: dose two minutes out, phone locked → rings +0,
  +15 (vibrates), +30; repeat and tap «أخدته» at +16 → +30 never rings;
  untouched past +45 → «يومك» shows «نسيتها؟».

**D3.1 — the front door (built)**
- Schema v8: `patients.sex` (`Sex.m`/`Sex.f`) and `patients.age`, both
  nullable and **local** (sync still sends uuid/name/slot only). Written
  red first: the SchemaVerifier failed with «no such column: sex», then the
  step went in — and moving the normalization to the end of the chain was
  what made v2→v8 and v5→v8 pass.
- «نتعرّف عليك» (mockup 21) before «ظبّط يومك» when `sex` is null: name,
  راجل/ست, optional age. **The age is a wheel, 18 to 110** (`AgeWheel`
  in `profile_page.dart`, a `CupertinoPicker` with our Arabic numerals and
  our type size, on Android too). It used to be four range chips that all
  started at 60, which told a 40-year-old on blood-pressure pills that the
  app was not for him. The wheel rests on 60 **and writes nothing until
  it is moved** — a rest position is not an answer; the hint under it
  says «حرّك البكرة لحد سنّك», and «مش عايز أقول» / «مش عايزة أقول»
  (via `say.pick`) clears it back to null and returns the wheel to rest.
  Every reader of `patient.age` (the home header, the emergency card, the
  export) only prints «N سنة» when non-null; nothing assumes 60+. The
  block was sized on an iPhone SE with the real fonts loaded: name, sex,
  wheel, its row and «كمّل» all visible without scrolling, pinned by a
  test in `routine_onboarding_test`. Existing installs are not re-asked.
- **Sex-keyed copy layer:** `domain/patient/sex.dart` → `Say`, provided by
  `PatientVoice` / `PatientVoiceScope` above the Navigator. Applied to the
  sentences that address the patient in onboarding («بتفطر/بتفطري»,
  «مش متأكد/ة»), the alert («خدته/خدتيه خلاص», «ارجع/ي ليومك», «أخدته/ي
  {time}») and the rail («نسيتها/نسيتيها؟», the ✓ line, «خلصت/خلّصتي»).
  Unknown sex (pre-v8) = masculine, exactly the text it had. **Buttons in
  the patient's own voice stay as they are** — «أخدته» on the pinned card is
  the patient saying "I took it", identical for both. Everything else moves
  over screen by screen.
- Mockup 3 restyled on `SignInScreen` (see deferred list for the honest
  Google/Apple rows); mockup 2's cards for the post-sign-in path choice.

**D3.2 — the home (built; matched to mockup 04 later)**
- The home (mockup 04) sits **at the top of the «اليوم» tab** and replaces
  the pinned next-dose card; «جدول النهاردة» stays below it. Tabs unchanged.
  Why: a separate home tab would show the same next dose twice, with two
  places to confirm it.
- Order: «يومك» + «صباح/مساء الخير يا {name}» + «{name} · {age} سنة» (only
  when an age exists) + `say.whatNow` («تعمل/تعملي إيه دلوقتي؟» — the
  mockup's «ماذا أفعل الآن؟» is MSA). Then «الآن», «خلال ٤٨ ساعة»
  (tomorrow's doses), water, the rail.
- «الآن» (`NowCard`): unconfirmed past doses (oldest first), then the next
  one. **All gold, neutral wording** («لسه ما اتأكدتش · كان معادها …») —
  the mockup's red cards are not ours. Only the first card has the primary
  «تأكيد الجرعة/الجرعات»; the rest have «افتح» (ReminderScreen).
  «لاحقًا» is the real 15-minute `scheduler.snooze`, and the card says so.
  «مش هاخده» now lives only on ReminderScreen.
- **«معلومة تهمك» replaced the water card on «يومك»** (24 Sep 2026, tester
  feedback; renamed from «معلومة ليك» the same day). Same slot, same
  weight, below «الآن» and «جدول النهاردة» so the fold rule for
  «تأكيد الجرعة» is untouched.
  **Its look is the old water card's** (owner, 24 Sep 2026): `F.radiusLarge`,
  `F.gap` padding, the icon in its own rounded tile on the start side, on
  `F.tipSurface` — a very light blue defined once in `tokens.dart` with a
  dark value, text in `F.ink` (both modes measured in `dark_mode_test`).
  So **blue is no longer water's alone**: the water widget keeps its own
  tokens, and the tip card has its own two (`tipSurface`, `tipGlow`). The
  title is «معلومة تهمك» at `F.subtitleSize` w800, clearly larger and
  bolder than the tip text (`F.minBodySize`). The icon is a lightbulb
  (`GlowingBulb`) whose glow and brightness fade up and down on a 1.6 s
  eased cycle — **no scale, no shake** (a test asserts no `Transform`
  under it); under «تقليل الحركة» it is a static lit bulb; it stops when
  the app is paused (`WidgetsBindingObserver`) and when the tab is
  offstage (`TickerMode`). The card sits one `F.gap` below whatever
  precedes it — the rail now ends with that gap, so the card is never
  flush against it. One tip per day, stable
  for the day and rotating daily, chosen by `pickTip` in
  `features/today/tips/tip_picker.dart` (pure) in this order: (a) his own
  adherence from local data — a medication whose duration ends within 3
  days, a streak of days fully taken, evening doses missed or taken more
  than 45 minutes late twice in the week; (b) a tip for the «الدوا ده لإيه؟»
  of an active medication, naming it; (c) a general safe tip. A
  medication's own «تعليمات» rides along as a gold reminder line. **Every
  sentence lives in `features/today/tips/tips_ar.dart`**, hand-written, no
  AI, no network, no runtime generation — a reviewer edits that file and
  nothing else. `test/features/today/tips_banned_words_test.dart` reads the
  file and every template with sample values and fails on doses, dose
  changes, interactions, symptoms or diagnoses, «الأفضل لحالتك», or any
  «وقّف الدوا»; anything medical ends at «اسأل دكتورك», which is why the
  today test's glucose advice scan skips the tip card's text. Tapping the
  card opens the medication it is about, or nothing. **The water widget
  file and its `water.*` `shared_preferences` keys are untouched**; only
  the card left the screen, and the data on existing phones stays where it
  was.
- Water (`WaterWidget`, no longer on «يومك»): cups 0–8, interval 1/2/3 h, countdown ring. Three
  `shared_preferences` keys (`water.*`), local, not synced, reset on a new
  calendar day. No notification, no advice — 8 is the counter's limit, not
  a recommendation. The one periodic timer runs only after the first cup
  and is cancelled in `dispose` (mutation-checked: removing the cancel
  fails the test).
- **No sugar or lab cards until D3.6** — they get added to «الآن» then.
- **Mockup-04 pass (later round):** the big title is gone — neither
  «ماذا أفعل الآن؟» (MSA) nor «تعمل إيه دلوقتي؟»; the greeting runs
  straight into the sections. «الآن» takes a **gold** dot (the mockup's red
  one would say "danger" about a man who simply forgot) and «خلال ٤٨ ساعة»
  a quiet green one. Every card carries its type icon (`CardTypeIcon`), the
  water card sits **below both sections** (a nudge, not a task), and
  «القريب مني» floats bottom-start as a secondary pill. Under the greeting,
  `CareCircleRow` says who is watching — an invitation when nobody is
  linked; the transparency the father was owed, on his first screen.
  Every line addresses the account owner: the mockup's «ملف والدك» is the
  son's screen, and that is a separate round.
- **The dock is «اليوم · الأدوية · السجل · الإعدادات»** (the third tab was «الملف» until the «السجل» round), floating,
  fully rounded and translucent glass (blur 30, the ground at 55%, a light
  rim on top) — and **every** tab sits on its own 40px rounded-square tile
  the way macOS dock icons do, the current one filled green with a white
  icon. «العائلة» left the bar: linking now lives in Settings
  («دائرة الرعاية») and in the home screen's «مين بيتابعك» row, so the door
  is still there twice. The top bar is the app mark, the night-mode toggle,
  and «طوارئ».
  **Transparency needs `extendBody: true`, not a lower alpha.** A
  `bottomNavigationBar` sits *beside* the body, not over it, so the body is
  inset above it and nothing ever passes underneath — the blur then has
  only the page ground to blur and the bar reads solid however low the
  opacity goes. All three shells (patient, elder, caregiver) set
  `extendBody: true`, the glass is at 35%, and every tab's list adds
  `MediaQuery.of(context).padding.bottom` to its bottom padding: inside an
  extended body Flutter puts the bar's own height there, which is exactly
  the clearance the last card needs. Add that padding to any new tab list,
  or its last row hides under the dock forever.
  Two more things that must not be hardcoded again: the bar's
  **height is computed** from the tile plus `MediaQuery.textScalerOf(…)`
  applied to the label — the two fixed numbers (78/96) overflowed by 6px at
  ×1.3 the moment the tile grew; and the quiet tile's fill is
  `railGround`→`cardGround`, semantic surfaces, because a fixed light colour
  becomes a white tile under a pale icon in night mode.
- **The visual reference is TestFlight 1.13.1 (87), the last build the
  boss saw** (owner, 26 Sep 2026). No archive of it exists on this Mac; the
  only release iOS build before today's 2.0.0 ran at 00:38–00:42 on 26 Sep,
  so `4e49298` (00:25) is taken as its commit — `build/capture/` holds the
  golden capture used to compare (375×667, real fonts, per screen in its
  own process: one process hung after the settings tab). Three visible
  changes were made on top of that reference at the owner's request, and
  none of them is a restore — the rail row and the 48h card had been the
  same since 14 Sep: a taken dose puts its **✓ on the rail node** (mockup
  24) with name and time side by side instead of the time pushed to the
  far edge; every dose row has a rail node (gold dot while it still needs
  him); and «خلال ٤٨ ساعة» reads **name first**, then «بكرة ٩:٢٧ م».
  «القريب مني» is **always visible** again, and the list's bottom padding
  leaves room for pill + «ضيف» + dock so the last card scrolls fully clear.
- **Layout after the 26 Sep 2026 revert (owner): the pre-`760563b` look,
  with three invisible fixes.** The top bar is opaque in `F.pageGround` with
  **no bottom line and no shadow** (`scrolledUnderElevation: 0`). The dock
  labels get a 4px side inset and a pinned 1.3 line height, so «الملف الطبي»
  and «الإعدادات» never touch at 375 — same look, slightly smaller only when
  they would. Every tab gets «ضيف»'s overhang added to `padding.bottom`
  (`ShellBottomExtra`), so the last row («امسح حسابي») clears the +.
  «يومك» subtracts it, because its pill clearance is larger, and its pixels
  are unchanged. «القريب مني» floats again (always visible — see above;
  the «only at the end» rule lasted one commit, `8fa3d47`). Its shape is 44
  and its hit area 56. `layout_iphone_test` pins all of this.
- **«ضيف» is a circle — with its word under it.** Olive fill, gold ring,
  gold «+», exactly as asked; the label sits beneath the circle because
  «no icon-only buttons» was written for a 72-year-old and the owner chose
  to keep it. «القريب مني» is a small gold pill with an olive ring,
  floating **bottom-end** (the far side of the line — bottom-left in RTL)
  on the home screen only.
- **«طوارئ» is smaller in look, not in target**: padding, icon and text
  shrank; the height stays 56 because the tap-target minimum is a rule and
  this is the button pressed in a panic.
- **The water card is blue** (`F.waterGround` / `F.waterInk` /
  `F.waterDrop`), with a drop in its far corner that **flashes
  continuously** — brightening, growing and glowing on a 1.1s controller
  that repeats in reverse (still under «تقليل الحركة»). **Blue is reserved
  for water** and appears nowhere else.
- **A screen that always animates cannot be `pumpAndSettle`d, and that is
  the API's fault, not the animation's.** `pumpAndSettle` returns when no
  frame is scheduled; the flashing drop schedules one forever, so it hangs
  until its timeout on *every* screen the water card is on. The drop was
  first driven off the counter's own one-second tick to dodge this — which
  meant it only moved after the day's first cup, i.e. not at all on the
  screen anyone looks at. The fix is the right one: `settle()` in
  `scan_test_support` and its twins in `today_screen_test` / `shell_test` /
  `root_test` are now **bounded pumps** (60 × 25ms = 1.5s, more than any
  transition we have), and no test on a patient screen calls
  `pumpAndSettle` any more. Reach for a bounded pump first when a new
  screen animates; do not remove the animation to please the test.
- **The coral FAB stays green** (`#F58A8E` read off the PNG). It sits
  between our gold and our red, and a colour that close to «دي لسه
  عايزاك» must not be spent on «ضيف».

**كتلة «الآن» واحدة، بعدّادها** (جولة «كام دوا مأجّل؟»). كل جرعة مستنية
أو مأجّلة كانت كارت لوحدها، مكدّسين: تلات أدوية مأجّلة معناها الراجل مش
عارف هما كام ولا مين فيهم من غير ما ينزل ويعدّ.
- **الترويسة بتقول العدد**: «الآن — ٣ أدوية» (و«الآن — دوايين»، و«الآن»
  لوحدها لدوا واحد أو لكارت سكر من غير جرعات). `nowCountLabel` في
  `dose_actions`.
- **«أجّلتها — ٢» مجموعة متسمّية**، كل دوا فيها سطر: اسمه، وجرعته،
  و**الموبايل هيفكّره إمتى** («هيفكّرك ١٠:٣٠ ص») — السؤال الوحيد اللي
  بيسأله عن دوا أجّله، وماكانش ليه إجابة على الشاشة (الجملة القديمة كانت
  «هنفكّرك تاني بعد ربع ساعة»، وهي مدة مش ميعاد).
- **«تأكيد الكل» للكتلة، وزرار تأكيد لكل سطر.** زرار السطر بيبان **لما
  يبقى فيه اختيار فعلاً**: مع دوا واحد الزرار الأساسي هو تأكيده، وزرار
  تاني بنفس المعنى بيزوّد ارتفاع ويلخبط. وتأكيد السطر بيمشي على **جرعته
  هو** (`[line.dose]`) مش على مجموعة دقيقته — دواءين على نفس المرساة
  مجموعة واحدة، وتأكيد واحد فيهم كان هيسجّل التاني إنه اتاخد. اختبار
  باسمه، ومُتحقَّق بالطفرة (الطفرة عدّت أول مرة لأن كل جرعة في اللقطة
  كانت في دقيقة لوحدها — الحارس ماكانش اتحقّق شرطه، فاتزوّدت لقطة
  بدواءين على نفس المرساة).
- **أكتر من تلات سطور بتتطوى**: تلاتة و«+ دوا كمان» / «+ دواين كمان» /
  «+ ٣ أدوية كمان»، والدوسة بتفرد. بالكلام مش برقم — «+٢» جنب كتلة ذهبية
  بتتقري زينة، والدوا المطوي بيعدّي (نفس درس كارت المواعيد).
- **«·» اتحوّلت لـ« — » في العنوانين.** المواصفة كتبتهم «الآن · ٣ أدوية»
  و«أجّلتها · ٢»، والقاعدة المكتوبة بتمنع النقطة الوسطية في أي جملة
  بيقراها المستخدم (الصفر العربي «٠» هو نقطة، واختبار بيقرا كل نص في
  `lib/`). **القاعدة بتكسب، وبنقول.**
- **وقت التأجيل المعروض هو المجدول، بتعريف واحد.** `snoozeTimeFrom` في
  `reminder_plan.dart`؛ `snooze_time_mirror_test` بيشغّل
  `ReminderScheduler.snooze` الحقيقية ويقارن وقت الإشعار اللي طلع باللي
  الشاشة بتعرضه. **التأجيل نفسه ما اتلمسش** — الملف ده قراية للي حصل.
  وحد الشاشة زي ما هو: تأجيل من شاشة القفل ما بيوصلش `_snoozed` (في
  الذاكرة)، فبيتعرض كجرعة مستنية عادي.
- **`NowCard` اتشالت.** اللي فضل منها `CardTypeIcon` وبقت في ملفها
  (`card_type_icon.dart`) — كارت السكر بيستعملها برضه.
- **و`_SectionTitle` بقى نصّه `Flexible`.** العنوان بقى بيشيل عدّاد،
  وعلى SE بخط ×١٫٣ الصف كان بيفيض **٢١ بكسل** — الاختبار هو اللي لقاها،
  مش العين.
- **والقياس على SE، بالأرقام**: الكتلة بتلات سطور بتاخد **٨٤٩ بكسل**
  بخط ×١٫٠ و**١٦١٣** بـ×١٫٣ (النص بيلفّ لأن زرار السطر بياخد عرض). يعني
  على شاشة ٦٦٧ **الصفحة بتتزحلق** — وده مش كسر للقاعدة: القاعدة اللي
  المالك كتبها هي «الزرار عمره ما يتغطّى بالدوك ولا بالزرارات العايمة»،
  والاختبار بيثبتها بالشكل ده: بيزحلق لحد ما الزرار يبقى فوق **أول كروم
  عايم من فوق** (بيتقاس من الكروم نفسه، مش برقم مكتوب)، وبيتأكد إنه كامل
  ومش متغطّي — في الوضعين ×١٫٠ و×١٫٣.
  **لو المطلوب إن التلاتة يبانوا من غير زحلقة على SE، ده سطرين على
  `maxNowLines`** (تنزيله لاتنين على الشاشات القصيرة) — وهو قرار عرض،
  مكتوب هنا مش متعمول.
- **اللي ما اتلمسش**: التأجيل ومدته وجدولته، سلّم التصعيد، إشعارات
  الجرعات، ونمط كبار السن (`ElderHomeScreen` ليها كارتها وقاعدتها: «تم»
  واحدة وبس). اختبار الخطة الذهبية أخضر.

**«ضيف دوا» is one scrolling form, and nothing walks you through editors**
(24 Sep 2026 — the tester's «خطوات كتير ومقيّدة»). `AddMedicationScreen`
top to bottom: name (autofocused when empty) → «الدوا ده لإيه؟ (لو حابب)»
(`MedicationPurpose`, `domain/medication/`, single-select chips, tap again
to clear; stored in `medications.purpose`, **v23**, nullable — it will
drive a tips card on «يومك» later, not built) → «كام مرة» → «قبل / مع /
بعد الأكل / ساعة محددة» (**a 2×2 grid of equal-width chips** since the
device round of 24 Sep 2026 — four in one row clipped «ساعة محددة» on
SE; `wheels_se_test` pins full labels at ×1.0 and ×1.3) → **«مواعيد
الجرعات»: one row per dose, always visible, in plain words** —
«قبل الفطار بنص ساعة — ٧:٠٠ ص», «بعد العشا بربع ساعة — …», «مع الغدا — …»,
«الساعة ٩:٠٠ م», «الفطار — مش متحدد» or «اختار الساعة». The words come
from `spokenTimingWording` / `spokenOffset` / `spokenFixedWording` in
`domain/wording/rule_wording.dart` (15/30/45/60/120 by name, otherwise
«بـN دقيقة»); «الفطار − ٣٠ د» stays the *schedule's* wording (rule chips,
the son's list), not the form's. Tapping a row opens `DoseEditor` for that
dose only and returns → alert mode chips → **«هتبدأ الدوا من إمتى؟»**:
«النهارده» (default) / «يوم تاني», which opens the date picker
(today … +60 days) and then says «هيبدأ يوم ٣ سبتمبر ٢٠٢٦ — مفيش تذكير
قبلها.» → «احفظ», enabled once the name is non-empty and every row has a
time that is chosen or resolvable (an unset anchor row keeps it disabled).
**«تفاصيل أكتر» is gone from the add form** (owner, 24 Sep 2026): amount,
duration and «تعليمات» stay in the model and are edited on
`EditMedicationScreen` only (`MedicationRepository.updateDetails` writes
the instructions and the duration onto every schedule of the medication;
a blank manual amount is still «not given»). A scan line still arrives
with its amount, duration and instructions and they are saved as read —
the form simply does not show them.
**A future start needs no migration**: `dose_schedules.start_date` has
existed since v1 and `DoseSchedule.isActiveOn` already refuses days
before it, so the engine schedules nothing, `materializeDay` writes no
row, «يومك» shows nothing, and «جدول الأدوية» says «هيبدأ يوم …» until
then. `MedicationDraft.startDate` and `MedicationWrite.startDate` carry a
per-line start through «عدّل» on the review screen (null = the batch's
day). `test/data/start_date_test.dart` is the golden guard: two schedulers,
start today vs start in three days — nothing at all before the start, and
the dose notifications inside the overlap window are identical by id and
instant; the ladder and repeats move with the start because they take the
*nearest* reminders of each plan, which is the documented behaviour.
**«ساعة محددة» puts the clock right under the timing chips** (26 Sep 2026,
iPhone): an inline `FTimeWheel` card («ساعة ثابتة — مش هتتحرك مع روتين
يومك») writes the **first** dose, rests on 8:00 and writes nothing until
moved. While no other row was edited by hand, every turn re-spreads the
rest (`_spreadLive`); editing a row stops that. The rows and `DoseEditor`
are unchanged — the edit screen's per-dose editor already had its wheel
directly under its two mode chips.
**«ساعة محددة»: the first clock the person picks spreads the other rows
evenly across the waking day** (`_spreadFrom` — routine wake → sleep when
both are set, else 07:00 → 23:00 as an operational window) *in the rows,
where they see and can change them*; nothing is written before «احفظ».
Back from a row's editor keeps the form exactly as it was. **Blank manual
amount is «not given», not «unknown»**: `amountUnknown` is only kept when
the line came from a scan that could not read it (`initialAmountUnknown`),
so «اسأل الصيدلي عن جرعة …» never appears for a hand-typed medicine. The
same form serves «عدّل» on the prescription review (draft mode returns a
`MedicationDraft` with purpose and instructions too). Neither new column
is pushed: the medications payload names its columns, so no Supabase
migration. Tap counts from «اكتبها بإيدي», typing excluded: one pill after
breakfast and dinner was 6 taps (field, «مرتين», «بعد الأكل», «كمّل», next,
save) and is now **3** («مرتين», «بعد الأكل», «احفظ»); one pill at 9 PM
was 4 taps + a wheel and is still **4** (row, «ساعة محددة», «احفظ الجرعة»,
«احفظ») + the wheel, with the clock now a visible choice instead of a
link.
**What the prescription scan auto-fills** (audited 24 Sep 2026, and pinned
by `prescription_reading_test` / `multi_dose_read_test`): name, amount
(unclear → «مش معروفة», never invented), dose times — meal anchors with
before/after/at and a written offset, or a written clock → `FixedTiming`,
«١×٣» with no meal → our convention, flagged — hence times per day,
duration («لمدة ٧ أيام» → 7; **«اليوم فقط» / «مرة واحدة» → 1**, added to
the prompt this round), and **instructions** (`ReadLine.instructions`,
added this round to the model, the schema as a required nullable field
and the prompt: a handling note that is neither timing nor amount, null
with confidence 1 when none is written, never invented; an unsure one is
dropped rather than saved). Start date is today unless changed under
«عدّل». **Not read, by design**: purpose (the paper does not say it) and
alert mode (the device default). The human tap on «تمام» is still the only
write.

**The «ضيف دوا» sheet is defined once, opened from two places.**
`showAddSheet(context, routine:)` in `features/medication/add_sheet.dart`
holds the sheet's body — five entries, `addSheetLabels` — and both the
dock's «+ ضيف» and the «ضيف دوا» card at the top of «جدول الأدوية» call it,
so an entry added there appears in both without anyone remembering. The
card follows the screen's card language (same radius, padding, ink, no
new colour), a plus and the two words, nothing else; it sits above the
groups and stays when the list is empty, where the sentence is now just
«لسه مفيش أدوية.» — the card is the call to action, not a pointer at the
dock. `add_sheet_test` reads `lib/` and fails if a sheet titled «ضيف
دوا» is built anywhere else or if the callers are not exactly those two.

**Nothing is ever deleted: a medication is *removed*, a dose is
*stopped*** (schema v16 — `medications.removed_at`,
`dose_schedules.stopped_at`, both nullable). A hard delete is forbidden
here and the reason is mechanical, not stylistic: sync only upserts
(debt 1), so the row lives on in the cloud forever; and `dose_events`
cascades on the local delete, so the phone forgets the evidence while the
cloud still holds the same events as `pending`. At +60 the son is told his
father missed a dose his father removed, and the father's phone cannot
correct a row it deleted. `test/data/no_hard_delete_test.dart` reads
`lib/` and fails on a delete against either table (mutation-checked).
- **Stopping** sets `medications.stopped_at`, marks its **future**
  `pending` events `superseded` (the state `0010` added, which
  `due_escalations` never selects), and `rescheduleAll` then cancels their
  notifications. Past events are untouched — that is history, and it
  happened. It moves to the «موقوفة» group and **resumes**.
- **Removing** sets `removed_at`. It leaves every list, keeps its past
  events, and does not come back. It asks once, naming the medication, and
  says in words that there is no way back and that «وقّفه دلوقتي» is the
  reversible one. The confirm is ink, **not red** — red is emergency only,
  even for the irreversible thing.
- **Six reads had to learn this, and a missed one is a ghost dose on the
  son's phone:** the medication list (`_allQuery`), «يومك» and the
  calendar (`DoseEventRepository._watch`), the export, the scheduler
  (`_activeQuery` → `activeSchedules`), and the caregiver query. Each has
  its own named test in `test/data/soft_stop_test.dart`; the caregiver one
  is a source guard, because that query runs in the cloud.
- **Cloud: `0014_soft_stop.sql`** adds both columns and re-declares
  `private.due_escalations` with `m.removed_at is null` and
  `s.stopped_at is null`. The device already supersedes, so these are the
  second belt — an old phone, a row written by a background wake-up after
  the stop, or a push that has not landed yet. Its self-check walks four
  medications (live, removed, schedule-stopped, medication-stopped) and
  asserts only the live one is due, then rolls back.

**«تمام» على المراجعة دايماً مفتوحة (٢٦ سبتمبر ٢٠٢٦، تعليق المختبِر) — واللي
مش واضح بيتحفظ «مش معروف»، مش مخمّن.** ده بيعدّل القاعدة ٤ في نقطة واحدة:
اسم أو توقيت **مش واضح** ما بقاش يقفل الزرار. الجرعة «مش معروفة» زي ما كانت؛
الاسم بثقة قليلة بيتحفظ زي الورقة وعليه «اتأكد من الاسم» (`unsure-name-N`)؛
والمرساة اللي ما اتحددتش بتتسأل **بعد** «تمام» مرة واحدة (`askAnchorTime`،
وقفل الورقة = تخطّي) — الدوا محفوظ على مرساته والمحرّك ساكت عنها لحد ما تتحدد
(«؟»)، وباقي الجرعات بتتجدول عادي. اللي **ما ينفعش يتحفظ** — من غير اسم خالص
أو من غير ولا ميعاد — بيتساب برّه العدّ (الزرار بيعدّ اللي هيتحفظ) وبيتقال
بالكلام (`unsaveable-note`)؛ الزرار بيتقفل بس لما مفيش حاجة تتحفظ.
`review_without_routine_test` بيثبت السؤال مرة واحدة والثابتة بتتجدول قبلها.

**The review screen is a draft. «تمام، ظبّطهم» is the only write.**
Until this round «عدّل» opened `AddMedicationScreen`, which **saved
immediately**, while «تمام» saved the rest — one prescription written by
two different buttons, in two transactions, with the screen still open
in between. That split is what hid the dose loss.
Now `AddMedicationScreen` has a **draft mode** (`draft: true`) that pops a
`MedicationDraft` instead of writing; in save mode it pops the same type
*after* writing, so a caller has one return type and `null` always means
«رجع من غير حفظ». The review screen holds `_DraftLine`s — what the reader
said, plus whatever the human changed — and confirms them all through
`addMedicationsWithDoses`, **one transaction for the whole prescription**,
then schedules once. Nothing reaches the database before that tap; a test
asserts the schedules table and the notification sink are both empty after
an edit.
- **Each line can be removed** («شيله»), and the undo replaces the row in
  place — *not* a SnackBar. Two reasons, both real: a 6-second bar asks a
  man in his seventies to race a timer, and it sits directly on top of
  «تمام» while it is showing (the test caught that by tapping through it).
- The confirm button **carries the count** («تمام — ٣ أدوية») and is
  disabled at zero, with a line saying everything was removed. A button
  that says how much it is about to write is the cheapest possible guard
  against confirming a list you have not read.
- A line edited by hand reads «اتعدّل», not «اتضاف» — nothing was added
  yet, and the word should not claim otherwise.

**A medication with N doses is written in one place** — a bug, and the
shape that prevented it being caught. `MedicationRepository
.addMedicationWithDoses(timings: […])` inserts the medication and **all**
its schedules in a single transaction, and both writers go through it:
«ضيف دوا» and the prescription review's «تمام، ظبّطهم». `addMedication`
is now a one-timing wrapper over it.
Before this, each screen wrote for itself (`addMedication` then a loop of
`addDoseSchedule`), and `AddMedicationScreen` took a **single**
`initialTiming`. So the review screen's «عدّل» passed
`timings.value?.firstOrNull` and a four-dose Augmentin was saved as one:
the read was right, the edit path threw the rest away, and the patient
was reminded once. The screen now takes `initialTimings` (a list) and
pops the timings it actually saved, so the review card shows what was
written rather than what the paper said. **A count that can silently drop
to one is the failure mode here** — the regression test is named for it,
and `multi_dose_read_test` asserts the count again on the *read* side
(database, «جدول الأدوية», and the export's «٤× في اليوم»), because this
class of loss should be visible from both ends.
**How many doses a medication has is decided in exactly one place per
screen — and they are different screens on purpose.**

- **Adding («ضيف دوا»): «كام مرة في اليوم؟» and nothing else.**
  `AddMedicationScreen` briefly also showed the day's doses as a `DoseRow`
  list with «شيل» and «أضف جرعة» under it. That made **three** controls for
  one number — the chips, the list, and the editor walk after «كمّل» — and
  the list was the wrong one of the three: nothing there is saved yet, so
  removing a row is arithmetic on a preset, not an edit to a medicine.
  The chips now run ١ / ٢ / ٣ / ٤ plus «أكتر», which opens a number field
  (clamped 1–12; more doses than that is a typo, not a regimen).
  «مع الأكل» still seeds the offsets. Tapping the chip that is **already
  selected** does nothing — a second tap on «٤ مرات» for a line that came
  from paper would otherwise throw the paper's anchors away and rebuild
  them from our convention.
- **The convention past three:** ١× الفطار، ٢× + العشا، ٣× + الغدا،
  ٤× + قبل النوم، ٥× + الصحيان. Past five it cycles the same five anchors,
  because there is no sixth anchor and inventing one is rule 6. Two doses
  landing on one anchor are reviewed in the walk like any other, and if
  the person leaves them identical the engine groups them into one
  reminder — its documented behaviour, not a loss.
- **A scan reading keeps its own count.** Four timings from the paper
  arrive with «٤ مرات» selected and four editors in the walk, and the
  paper's anchors are what gets saved unless the person changes the
  number. The count used to be hidden entirely on the paper path, so a
  four-dose line could not be made a two-dose line at all.
- **Changing a saved medication is `EditMedicationScreen`'s job**, which is
  where `DoseRow` already lived and where a person goes to change a
  medicine they have. «أضف جرعة» writes a new schedule through
  `addDoseSchedule` (the path a scan uses); «شيل» calls `stopDoseSchedule`
  after a one-tap confirm naming the rule — a mistap here silently stops a
  dose ringing, and he finds out by missing it. The floor is one dose and
  it is enforced on real rows: the last `DoseRow` gets no «شيل» at all
  (null, not disabled), and `_removeTiming` refuses.
- **«شيل» on a saved dose is a soft stop, and a hard delete stays
  forbidden.** `dose_schedules` is a `SyncIdentity` table, sync upserts
  only for it (debt 1), and `dose_events` cascades on a local delete — so a
  real delete makes the phone forget while the cloud keeps the schedule
  and its `pending` events, which `due_escalations` still selects. At 3 PM
  the son is told his father missed a 2 PM dose that no longer exists, and
  the father's phone can no longer correct a row it deleted.
  `stopDoseSchedule` writes `stopped_at`, marks future events `superseded`,
  and `0014` already filters `s.stopped_at is null` server-side.

**D3.3 — elder mode + notifications (built)**
- Schema v9 `device_preferences`: one local row (`id = 1`, not synced) —
  `elder_mode`, `rung_first_on`, `rung_second_on`; no row = defaults.
  Written red first (the SchemaVerifier failed with «does not contain
  device_preferences»), frozen SQL above the `from < 6` block, and the v2
  file test now checks the table is empty. In drift, not
  shared_preferences, because the lock-screen isolate reschedules too.
- **The rung switches filter, they do not change the ladder.**
  `ReminderScheduler.preferences` is read at scheduling time only; rungs
  from `planEscalations` whose `escalationRungOf(id)` is off are dropped
  before `reconcile`, so an already-pending one is cancelled as stale.
  `planEscalations`, `ladderFor` and the domain are untouched.
  `buildServices` (app **and** background isolate) passes it — a test
  guards that line. Mutation-checked: dropping the filter fails four tests.
- «التنبيهات» (mockup 26): «تفويت جرعة», «في الموعد» and «+٦٠ د — إشعار
  لابنك» are 🔒 «دائمًا» with no switch at all; only +١٥ and +٣٠ switch,
  and each change reschedules at once. Banner in colloquial
  («الإعدادات دي على الموبايل ده بس»).
- **The son's rung reads +٦٠ everywhere now**, from `serverGraceWindow`
  — the reminder screen said «+٤٥» (the device's grace), which promised
  an alert before the server sends one.
- «نمط كبار السن» (mockup 18): a switch in settings (gold when on). When on,
  `AppShell` shows two tabs («الرئيسية», «الإعدادات») and no «ضيف»;
  `ElderHomeScreen` shows the greeting, **one** dose card — the first of
  `nowGroups`, the same selection as the home — with «تم ✅» (green, 80)
  and «بعد شوية ⏰» (real snooze, 64), **and the rest of the day under it,
  read-only**. The card is the only place with buttons; the rows below
  carry the time, the names and the state at elder sizes and nothing else,
  because a second «تم» would be a second place to confirm and that is
  what this mode exists to prevent. Showing only the card was the bug: if
  the next dose was hours away the whole screen read «مفيش أدوية
  النهارده», which to a 72-year-old says *his medicines were deleted*. A
  taken dose stays in that list marked «اتاخد» for the same reason the
  rail never drops one — vanishing reads as "I must have forgotten it".
  Overdue says **«لسه ما اتأكدتش»**, not «فات»: he forgot, he did not
  fail, and that wording is already the rail's. Sizes come from `F.elder*` and are
  **above** the normal floor (text 24+). Confirm and snooze are the shared
  `confirmGroup` / `snoozeGroup` in `features/today/dose_actions.dart`,
  used by the home too. The settings tab keeps normal sizes.

**D3.4 — emergency (built)**
- Schema v10 `emergency_profile`: SyncIdentity columns and a touch trigger
  from day one (PHASE_D3 rule 2), one row per patient: `blood_type`,
  `allergies`, `chronic_conditions`, `contacts_json` (`[{name, phone,
  relation}]`). Written red first; frozen SQL above the `from < 6` block.
  **Pushed since D5.1, without `contacts_json`** — names and phone numbers
  stay on the father's phone; the cloud table has no column for them and
  `health_file_sync_guard_test` fails if the sync code mentions it.
  Current medications are read from `medications`, never copied.
- **No field is ever filled or guessed.** null renders «لسه ما اتملاش», and
  nothing else — no «لا يوجد», no default blood type. Blank input saves
  as null; «مفيش حساسية» has to be typed by a person. A blood type outside
  the eight is refused, not stored. The only writer is
  `EmergencyEditScreen` (8 chips + «مش عارف» = null, free text, contacts).
- **An empty section offers the action, not a hyphen.** «جهات الاتصال»
  with nothing in it shows «ضيف جهة اتصال», which opens the edit screen
  scrolled to that section with one row ready. The path existed before
  (Settings → معلومات الطوارئ → عدّل → +) and nobody walked it: the info
  screen looks like a finished card, so «عدّل» reads as *correct
  something wrong*, not *add what is missing*. Found on the way: a blank
  contact row used to save as a contact with an empty name and a «اتصال»
  button dialling nothing — blank rows are now dropped on save, the same
  rule as every other field here.
- «معلومات الطوارئ» (19) on `F.redDeep`, «بطاقة الطوارئ» (32) as a full
  in-app screen with the gradient and a live clock (timer cancelled in
  dispose). Every contact has an «اتصال» button; the ambulance button
  pulses (short pulse on a timer, off under reduced motion) and **always
  asks «تتصل بالإسعاف ١٢٣؟» first** — mutation-checked: dialling directly
  fails the test. Entry: ink «طوارئ» in the top bar → card (all tabs,
  elder mode); settings «معلومات الطوارئ» → screen 19.
- `url_launcher` for `tel:` (`dialNumber` is swappable for tests); `tel` in
  `LSApplicationQueriesSchemes`. Contact calls go straight to the OS: iOS
  asks "Call …?" itself, Android opens the dialer without calling. Not yet
  tried on hardware — the simulator cannot place a call.
- **«من جهات الاتصال» picks one contact — it does not read the address
  book** (round 23). Beside «+ ضيف جهة اتصال», it opens the *system*
  picker and fills name + the number the person chose; «صلة القرابة»
  stays empty, because the phone does not know it and guessing it is a
  guess about people.
  **The rule is structural, not discipline.** `flutter_native_contact_picker`
  was chosen because it has **no API that enumerates contacts at all** —
  `CNContactPickerViewController` on iOS (out of our process),
  `ACTION_PICK` on Android — so "we read exactly the one the picker
  returned" has no other path to fail down, and **neither platform asks
  for a contacts permission**. The plugin import lives in one file
  (`lib/data/contacts/native_contact_picker.dart`) behind `ContactPicker`,
  like the `supabase_*` / `firebase_*` rule.
  `test/app/contacts_read_once_test.dart` holds four doors: one importer,
  one caller (the button's handler), no enumeration API anywhere in
  `lib/`, and no `READ_CONTACTS` / `NSContactsUsageDescription` in either
  platform file. Mutation-checked both ways.
  **The version is pinned exactly (`0.0.12`, no caret)** — the only
  dependency in the project that stands next to other people's names and
  numbers. Everything above is a property of *this build* of the plugin;
  a minor bump could start asking for a permission nobody decided to ask
  for. Upgrade by hand, reading the diff, with a device pass.
  Refusal shows one line and **removes the button** — that is what "never
  ask twice in a row" means here: there is no second ask to make. Plain
  cancellation is silent; closing the picker is not a refusal.
  **Never run on hardware**: `/device` step 9 covers both the iOS
  no-prompt claim and what Android really does with no picker available —
  the `ContactPickerDenied` mapping is read from the plugin's Kotlin, not
  observed, and it may instead come back as a plain cancel.

**«السجل» اتسمّى «الملف الطبي» للمستخدم** (٢٦ سبتمبر ٢٠٢٦، من الآيفون):
التبويب عند المريض والابن والممرض وعنوان الصفحة. اسم الكود (`HealthFileScreen`)
ما اتغيّرش. و`help_record` اتشال من السكريبت والكتالوج والتسجيلات — زراره
الوحيد (جنب العنوان) اتشال في `a6ba67e`. وتحت بالإنجليزي
«السجل» = نفس الشاشة. 

**«السجل» — one door, three plain sections** (owner-approved, 24 Sep 2026;
tester feedback #8 «الملف الصحي معقّد»). The dock tab «الملف» is now «السجل»
(the son's «الملف الصحي» tab is «السجل» too), and `HealthFileScreen` (same
file, same class) is one scrolling screen instead of seven equal buttons:
- **«مواعيدك الجاية»** — every dated follow-up stage
  (`upcomingAppointments`) as a row that opens its `CheckupScreen`, plus
  legacy `booking` records with a future date, each with **«فكّرني بيه»**
  (starts a visit follow-up on that day, `followSourceId` = the booking, so
  the booking row is then hidden here and stays a paper in «أوراقك»).
  Empty: «مفيش مواعيد جاية — … دوس «ميعاد جديد» ونفكّرك.» The one primary
  button is **«ميعاد جديد»** (`NewAppointmentBody` in an `FSheet`): «دكتور
  ولا معمل؟», an optional name, `DayPicker` (tomorrow by default), «احفظ
  الميعاد». Under the hood it is the existing follow-up start —
  `checkups.start` then `setStageDate(VisitStage.booked)`, or for a lab
  `advance` to «حجز المعمل» then its date — so **a booking can no longer be
  saved without its reminder**: the «حجز» kind is gone from «اكتب ورقة
  بإيدك» (the renamed manual entry), the enum value stays for old rows. The
  three old ways (from a paper in the file / a new photo / by hand) survive
  as «عندي روشتة — ابدأ منها» / «عندي تقرير — ابدأ منه» inside the sheet
  (keys `start-follow-visit` / `start-follow-lab`, then the unchanged
  `askStartWay`). No scheduling change: `appointment_guard_test` and the
  scheduler tests are untouched and green.
- **«أوراقك»** — a small search field with «فلتر» and «التقويم» beside it,
  then **one timeline of every kind, newest first, with a heading per day**
  (`RecordRowCard`, so photo / «⋯ خيارات» / rename / delete are the same
  rows). «فلتر» opens a sheet with one entry per kind and its count (the old
  `kind-entry-<kind>` keys, opening `RecordsOfKindScreen`) and «كل الأوراق
  بالفترة» (`HistoryScreen`). Empty: «لسه مفيش أوراق — صوّر روشتة أو تحليل
  من «ضيف»…». Adding stays behind the «ضيف» sheet only.
- **«للدكتور»** — one entry card to `DoctorPageScreen` (title «للدكتور»),
  which now **hides empty sections** and on a fresh phone shows one line,
  «لما تصوّر روشتة أو تحليل من «ضيف» هيظهر هنا», above «أسئلة العيلة» and
  the new **«اطبع أو ابعت الملف»** button (`ExportScreen` moved inside; it is
  no longer a peer on the hub).
Tap counts after the change: (a) remind me of Tuesday's visit — «السجل»,
«ميعاد جديد», «يوم تاني», the day, «تمام», «احفظ الميعاد» = **6 taps, 1
screen + a sheet** (was 9 taps / 5 screens, or a 6-tap «حجز» that reminded
nothing); (b) keep a lab and show it — 6 to keep (unchanged) + «السجل»,
«للدكتور» = **2 to show**; (c) everything from the last visit — «السجل» and
scroll: **1 tap**, the visit and its prescription under one day heading.
Emergency stays in the top bar and Settings; every old screen keeps its file
and its tests (paths updated where the hub changed).

**D3.5 — records (built)**
- Schema v11 `records` (SyncIdentity columns + trigger; pushed since D5.1,
  without the local attachment path): kind (imaging | visit |
  lab | prescription | booking), title, happened_at, doctor, **place** (added
  beyond PHASE_D3's list: the imaging centre, lab and clinic fields of
  mockup 28 had no column), notes, attachment_path, deleted_at. Written red
  first; frozen SQL above the `from < 6` block.
- **المسح بيمسح. The 30-day grace is gone, everywhere.** It used to be a
  soft delete: the row stayed struck through with «هيتمسح نهائي بعد ٣٠
  يوم — تقدر ترجّعه لحد كده» and «↺ رجّعه». That was written for a person
  who deletes by mistake, and it was wrong for the person who actually
  deletes — the one whose scan read a prescription he never wanted. He
  taps «امسحه» and it sits in his medical file for a month.
  Now: **one confirmation naming the record, and it is gone from every
  view in the same frame.** No «رجّعه», no strike-through, no trash screen
  (the text never promised one, and still doesn't).
- **The grace was not moved somewhere safer — it was removed.** The one
  place worth arguing for was a `lab` record whose attached photo is the
  only copy of a report (the camera path does not write to the gallery).
  But a grace nobody can see and nobody can act on protects no one: the
  thing that actually protects him is being told **before** the tap, so
  the confirmation names the loss — «هيتشال من الملف خالص، ومعاه الصورة
  المرفقة. مفيش رجوع.» when there is an attachment, and the shorter
  sentence when there is not.
- **What is deleted is the content; what remains is a tombstone.**
  `RecordsRepository.delete` clears doctor, place, notes, attachment path,
  checkup stage and fasting instant, writes `tombstoneTitle`, deletes the
  attachment file and the row's `lab_results` lines, and sets `deletedAt`.
  The row itself stays **because sync only upserts**: a hard local delete
  would leave the cloud copy in place with nothing to say it was deleted,
  and the son would keep reading a prescription his father removed.
- **The cloud row goes on the next push, not on the 30-day cron.**
  `_pushRecords` splits dirty rows into live and tombstoned; a tombstone is
  **upserted first and deleted second**, and only then marked synced. That
  order is the whole safety of it: if the delete fails mid-push, the cloud
  row is at least marked deleted (the caregiver query filters
  `deleted_at is null`) and the row stays dirty so the delete retries. The
  reverse order would leave the record visible to the son on any failure.
- **Nothing in `private.purge_deleted_records` had to change, and no
  migration is needed.** `records_delete` (0012) already lets the owner
  delete his own rows, and `lab_results.record_uuid` already cascades. The
  cron keeps running as a **backstop** for the one case sync cannot reach:
  a phone that deleted a record and never came online again — its
  tombstone upload is all the cloud has, and the cron is what eventually
  clears it. `record_retention_sql_test` was a mirror of a Dart constant
  that no longer exists; it now asserts that backstop is still wired.
- **كل سجل بيفضل شايل ورقته، والدوسة عليه بتفتحها (round 22).** A
  confirmed scan attaches its photo to the record it creates —
  **prescription and lab alike**; the prescription half was missing until
  this round, so a confirmed روشتة kept its medicines and lost its paper.
  What is kept is **what the picker gave us** (2560), never the 1600px
  copy `shrinkForAi` builds: the shrunk one is for the model to read, the
  kept one is for a human eye, and a test asserts the stored bytes are the
  picker's. A failed image write never blocks the record — the medicines
  are the promise, the photo is not.
  Tapping a record with an attachment opens `AttachmentViewerScreen`
  (`InteractiveViewer`, 1–5×, a close control carrying the word «اقفل» —
  no icon-only button). A record **without** one is untouched: no empty
  frame, no placeholder, no dead tap. `openAttachment` is also silent when
  the file is gone (deleted from outside, a restore without the folder) —
  a record without its photo is still a record. Both record lists do this,
  «الملف الصحي» and «الحالات السابقة»: two lists of the same rows must not
  behave differently.
  **The images stay on this phone.** Nothing here uploads one and the
  caregiver query is untouched, so «دائرة الرعاية»'s promise («مش هيشوفوا
  الصور») still holds. `health_file_sync_guard_test` now scans **every**
  `.dart` under `lib/data/sync/` and `lib/data/care/` — not the two files
  it used to name — so a path reaching the son's query fails it too.
  Deleting a record still deletes its file, and the confirmation still
  names the photo when there is one; both are under test, mutation-checked.
- `launchHousekeeping` still exists and is now empty, on purpose — the
  launch-time hook stays wired and tested for the next thing that needs it.
- **«الملف الصحي» shows and follows; it does not add.** «صوّر تقرير تحليل»
  used to sit on it as a second door to something the «ضيف» sheet already
  owns — and two doors to one action make a person wonder whether they are
  two different actions (the same reasoning that kept «الملف الصحي» out of
  Settings). Adding lives in the «ضيف» sheet, which is defined once and
  opened from the dock and the medication list.
- «إدخال يدوي» (28): five forms, same primitives, own labels per kind;
  date chips («النهارده»/«امبارح», «بكرة» for a booking) + a date picker.
  «الملف الصحي» (13): **entries, not one long list** (round 28) — one per
  record kind that has anything, with its count, each opening its own
  `RecordsOfKindScreen`. Search and «+ ضيف» stay where they were, and
  typing **replaces the entries with results across everything**: someone
  searching already knows what they want, and splitting by kind then is
  work for them. Search covers title, doctor, place, notes and the written
  date in Arabic or Western digits; «⋯ خيارات» (a word, not a bare icon) →
  «امسحه» → confirm.
  **The row had to move with the list, and nearly didn't.** That flat list
  carried two behaviours nothing else did — «⋯ خيارات» → امسحه, and
  tap-to-open-photo. Putting records behind entries would have deleted both
  in silence unless the opened list carried them, so the row is now
  `RecordRowCard` and both the search results and the kind list use it.
  Anything that splits a list in this app has to ask what the rows *did*,
  not just what they showed. «الحالات السابقة» (29): timeline newest first,
  kind and period filters (period uses calendar arithmetic). Every empty
  state says «لسه مفيش حاجة هنا» and how to add. Entry: settings «الملف
  الصحي», and a third option in the «ضيف» sheet.
- **The review screen fills the file from real use.** «تمام، ظبّطهم» writes
  one `prescription` record (date, medicine names; the doctor only if the
  reading is confident — otherwise null). It runs after the medicines and
  `rescheduleAll`, wrapped and logged: a failed record never undoes a
  confirmation. «صوّر تاني» writes nothing.
- **And when that write fails, the person is told — in one sentence.** The
  catch stays a catch (the medicines must still ring), but it is no longer
  only a `debugPrint`: the screen stays open with «الأدوية اتحفظت
  — بس الروشتة ما اتسجّلتش في الملف الصحي» and the real error is logged.
  Silently swallowing it left a man closing a screen believing his
  prescription was filed. Proven with a `RecordsRepository` on a **closed**
  database — the only way to make the write fail for real.

**The prescription's header: who wrote it, where, and when (round 16)**
- The reading carries `doctor`, `clinic` and `issuedAt` (`ReadField`s like
  every other field). **Absent is not uncertain**: a field the paper does
  not have comes back `value: null, confidence: 1`, so it renders «مش
  مكتوب على الورقة» in plain words and never takes the gold mark. The
  prompt says so in as many words, and forbids filling `issuedAt` from
  today's date — `_date` also refuses a year outside 2000–2100.
- The three sit above the medication list, each editable («عدّل»), each
  gold-edged with its note when the model is unsure.
- **`happenedAt` is the paper's date when it was read, otherwise today —
  and the screen says which, before «تمام» is tapped.** A gold
  `date-fallback` note («هتتسجّل بتاريخ النهاردة») is the whole point: a
  wrong date in a medical file is worse than a missing one, and the
  correction has to be possible while the person is still looking at it.
- **An uncertain header the human did not touch is saved as null, not as
  the guess** (`_confirmedHeader`). «د. هشـ؟» in a medical record is worse
  than an empty column; the confirm button is about the medicines, and
  tapping it is not a claim that the header was read. An edited field is
  his, and goes in as typed. Both directions are under test.
- Found by writing those tests: the header sheet disposed its
  `TextEditingController` the moment `FSheet.show` returned, while the
  dismiss animation still had frames to build — «A TextEditingController
  was used after being disposed» on every edit, on a real phone too. The
  controller now belongs to the State and dies with the screen.

**صوّر العلبة أو الشريط (built)** — «ضيف دوا» بقى تلات اختيارات،
**الصورة الأولانية**: «صوّر العلبة أو الشريط» / «صوّر روشتة» /
«أكتبها بإيدي».

- **العلبة بتقول الدوا إيه — مش إمتى، ولا قد إيه.** ده مش فلتر بعد
  القراية: `packageSchema` **مالوش خانة توقيت ولا جرعة أصلاً** (خمس حقول
  بس: `brand`, `activeIngredient`, `strength`, `form`, `packSize`)، و
  `responseSchema` بتاعة Gemini بتمنع أي حقل زيادة. والـsystem instruction
  بيقولها للموديل بالنص: «The packaging cannot know what THIS patient was
  told to take — only their doctor knows that». اختبار بيبعت رد فيه
  `dose` و`frequency` و`timings` و`durationDays` ويتأكد إن ولا واحدة
  وصلت أي حقل بيتعرض.
- **الطريق: صورة ← نفس فورم الإدخال اليدوي، متعبّي.** `ScanPackageScreen`
  بتنده القراية وبتفتح `AddMedicationScreen` نفسها بـ`packageReading`،
  فاللي بعد الصورة هو **نفس** الشاشة اللي بيكتب فيها بإيده — مش شاشة
  مراجعة تانية. خانة «اسم الدوا والتركيز» بتتملا («Concor 5 mg»)،
  و**خانة الجرعة والمواعيد بتفضل فاضية**، ولوحة فوق الفورم بتقول اللي
  اتقرا («المادة الفعّالة»، «الشكل»، «في العلبة») وبتقول السطر اللي
  الميزة كلها حواليه: «العلبة ما بتقولش الجرعة ولا المواعيد — دي من
  الدكتور، وإنت اللي بتكتبها تحت». القاعدة ٤ زي ما هي: مفيش صف بيتكتب
  ولا إشعار بيتجدول غير بدوسة «احفظ الجرعة».
- **الثقة الواطية = فراغ، مش تخمين.** حقل تحت `confidenceThreshold`
  بيرجع null. **واسم مش واضح معناه مفيش فورم خالص** — الشاشة بترجع
  «مقدرناش نقرا ده بوضوح — صوّر تاني أو اكتبه بإيدك» (`unreadablePackage`،
  جملة واحدة الشاشة والفورم بيقروا منها). حقل تاني مش واضح بيسيب الفورم
  مفتوح والحقل فاضي **ومتسمّى** تحت. نص اسم بثقة عالية هو أوحش ناتج
  ممكن: بيبقى دوا في قايمة راجل عنده ٧٢ سنة.
- **والشريط له فقرته في البرومبت**: الاسم على ورق قصدير بيلمع ومقطوع بين
  الحبوب، فالبرومبت بيطلب الضهر، وبيقول «return null rather than
  completing it» و«Partial text is a reason for low confidence, not for
  inference». اختبار بيثبّت الجمل دي — مش اللي الموديل بيرجّعه، الجملة
  نفسها.
- **«الدوا ده عندك خلاص؟» — وده محتاج عمود.**
  `domain/medication/duplicate_check.dart` (دارت نقية): بيطابق بالاسم
  **من غير تركيزه** (فـ«Concor 5mg» و«Concor 10 mg» نفس الدوا)، وبعدين
  بالمادة الفعّالة (فـPanadol وParamol بيتمسكوا). الجملة بتتقال والزرار
  بيفضل شغّال — **بنقول، مش بنمنع**: ممكن الدكتور كتب تركيزين فعلاً،
  والقرار قراره (نفس روح القاعدة ٤).
  **ومادة مش متسجّلة مش «مادة مختلفة»**: بنعدّي عليها بدل ما ندّعي إننا
  قارنّا — وده حد الفحص المكتوب، فيه اختبار باسمه.
- **schema v20: `medications.active_ingredient`** (nullable، **محلي** —
  مالوش عمود في السحابة والابن ما بيقراهوش، زي `attachment_path`).
  اتكتب أحمر الأول زي القاعدة: الفاحص وقع بـ«unexpected entries:
  active_ingredient»، وبعدين الخطوة اتحطّت **فوق** بلوك التطبيع بحماية
  وجود. من غير العمود ده فحص المادة بيبقى حارس شرطه عمره ما بيتحقّق —
  بالظبط النمط اللي «Testing conventions» بيحذّر منه. الأدوية القديمة
  كلها `null`، ومفيش مادة اتخترعت لواحد منهم (اختبار v19→v20 واختبار
  ملف v2).
- **نفس نقل Gemini بالحرف** (`GeminiPrescriptionReader.generate`): نفس
  الموديل، نفس `shrinkForAi`، نفس المهلة، نفس الرجوع للبديل على
  ٥٠٣/٤٢٩/تقاعد، نفس `x-goog-api-key`. **سطح شبكة جديد مش موجود** —
  برومبت و`responseSchema` مختلفين وبس. ورسالة العطل بتقول «العلبة» مش
  «التقرير».
- **الصورة ما بتتخزّنش، وده قرار مكتوب مش نسيان.** مسار العلبة بيعمل
  **دوا** مش **سجل**، و`medications` مالهاش عمود مرفقات — فحفظها كان
  هيحتاج عمود تاني. اللي المواصفة طلبته («تفضل على الجهاز زي الروشتات»)
  محفوظ بالمعنى اللي بيهم: الصورة عمرها ما بتترفع، وبتروح لـGemini بنفس
  الطريق بالظبط. لو المطلوب تتحفظ فعلاً، ده عمود على `medications` وجولة
  لوحده.
- الاختبارات: `package_reader_test` (١١ — التسريب، الـschema، الثقة،
  الشريط، النقل)، `duplicate_check_test` (١٢ نقية)، `scan_package_test`
  (١١ شاشة). **ست طفرات**: الثقة الواطية تعدّي، خانة جرعة في الـschema،
  المادة ما تتخزّنش، التطبيع ما يشيلش التركيز، «صوّر تاني» يتشال، وتحذير
  التكرار يتشال — كلها بتوقّع.
- **البرومبت لسه ما اتجربش على صورة حقيقية** — مفيش ولا صورة علبة في
  `test/assets/` ومفيش مفتاح على الماكينة دي.
  `test/ai/package_prompt_live_test.dart` مكتوب ومتخطّي لوحده، وبيشتغل
  بأمر واحد أول ما الصور تبقى موجودة:
  `GEMINI_API_KEY=… PACKAGE_PHOTOS=test/assets/packages flutter test
  test/ai/package_prompt_live_test.dart`. بيتأكد إن ولا حقل فيه كلام
  جرعات وإن علبة واضحة بتتقرا. **والفولدر في `.gitignore`** — صورة
  شريط متصرّف ممكن يكون عليها ستيكر باسم مريض، والقاعدة أسهل ما تتبع
  لما تبقى «ولا صورة تتكوميت».

**المخزون و«قرب يخلص» (25 Sep 2026, built, not device-tested).**
The older app recomputed stock as «remaining doses × amount» and overwrote
what the person typed; its refill alert never fired for many users. Here:
- **Optional, and only a human writes the number.** `medication_stock`
  (drift **v26**, its own `SyncIdentity` table, one row per medication —
  *not* a column on `medications`: a dose confirmation would bump the
  medication's `updated_at_ms` every time, which breaks 0024's
  «local edit wins» and re-pushes the whole row). No row = no stock, no
  line, no alert. Written on «عندك كام قرص دلوقتي؟» (an `FNumberWheel`
  that writes nothing until moved) on `EditMedicationScreen`
  (`StockSection`) and as an optional chip on «ضيف دوا» (save mode only).
  Unit from the amount field (`stockUnitOf`), else «وحدة».
- **Decrement only on `taken`, by the dose amount** (`doseAmountOf`: digits,
  نص/ربع, «قرصين»; default 1), restore on any taken → non-taken transition
  (`undoTaken`, or taken → skipped), never below 0; missed and skipped never
  touch it. It lives in `DoseEventRepository._setState` → `StockRepository
  .onDoseStateChanged`, so patient, «يومك», reminder screen and nurse proxy
  (`confirmByProxy`) all go through it. **The lock-screen `confirmDose`
  does not**: it queues, and the handler calls `events.flushStock()` as a
  courtesy *after* the cancels and `rescheduleAll` — rule 5's order.
  There is no undo button anywhere in the app yet; `undoTaken` exists for
  when there is.
- **«قرب يخلص» = days left ≤ warn days** (default 5, per medication, a
  wheel 1–30). Days = floor(stock ÷ (daily doses × amount)) from the
  medication's own daily schedules, never guessed; a non-daily schedule
  gives no number. «يومك» shows `RefillLines` below the rail: one gold-edged
  card per low medication («Concor فاضله ٤ أيام»), «اشتريت علبة جديدة»
  (wheel resting on 30 → adds) and «اطلبه من الصيدلية».
- **The alert is shown on a wake, not scheduled** — `RefillAlerts.sync`
  from `refreshRefills()` after launch, resume and every in-app
  confirmation, only 9:00–21:00, the first time a medication crosses and
  then every 3 days while still low (`notified_at`, local, never pushed);
  a restock clears it. Scheduling it would take an iOS slot from the dose
  window. The cost: a patient who never opens the app and never confirms
  in it gets no refill alert — the line waits on «يومك».
- **«اطلبه من الصيدلية» opens WhatsApp and stops there.** «صيدليتي» (name
  + number, `device_preferences`, local) is asked the first time; the
  message «محتاج X — ١ علبة» is on screen before «افتح واتساب», and
  `wa.me` only prefills — the person presses send.
- **Family and nurse read it** (0028 embed on the medications query, tiered
  fallback so an un-migrated project still loads). A nurse with
  `can_edit_meds` sends «اشتريت علبة جديدة» as a `restock` pending change;
  the patient's phone adds it without a conflict check — it is additive.
- **Dose reminders, ladder and escalation untouched** — golden plan and
  scheduler tests green with no edit.

**«إنت ماشي إزاي» وصورة الدوا (25 Sep 2026).**
- **Adherence** (`domain/adherence/`, pure): day = complete / missed /
  neutral / upcoming by the row's routine day; a dose missed **today**
  greys today's dot but does not reset the number while today is open —
  it resets once that routine day has closed. Card under the next-dose
  card on «يومك», in elder mode (36px dots, no late-take), in the nurse
  app and read-only on the son's «متابعة» (routine_day read from
  `dose_events`, no migration). «أخدتها متأخر» goes through
  `confirmGroup` / the nurse proxy path — no new write.
- **Medication photo** (drift **v27**, `medications.photo_path`, local,
  relative `med-photos/<uuid>.jpg`, not pushed): `prepareMedPhoto`
  (`core/images/`) bakes orientation, resizes to ≤800 and **clears all
  EXIF** before `MedPhotos` saves it; replacing, «شيلها» and removing the
  medicine delete the file. Shown by `MedPhotoThumb` beside the name on
  «الآن», the reminder screen, «جدول الأدوية», the edit screen, and large
  (112) in elder mode; no photo, a missing file or bad bytes fall back to
  the existing icon — never a broken image. «استخدم صورة العلبة» after a
  box scan; **not** offered on a prescription line (a photo of paper does
  not help recognise a pill). Notifications carry no photo.
  **Circle sync (0029, 25 Sep 2026):** `MedPhotoSync` (patient phone only,
  from `pullFromCircle` and right after a save/remove, never awaited by the
  UI) upserts `{patient}/med-photos/{med}.jpg` and deletes it when the photo
  or the medicine goes; failures back off 30 s → 6 h per medicine
  (`media.failures` in shared_preferences) and a failure older than 24 h,
  or a rejected nurse photo, becomes health code `mediaSync` — broken, so it
  rides the heartbeat to the admin dashboard, and never shown to the
  patient. The son and nurse read through `CircleMedPhotoCache`: one folder
  listing per patient (kept a minute), a download only when `updated_at`
  changed, the old copy when offline, the icon on any failure. A nurse
  with «يعدّل الأدوية» uploads a shrunk, EXIF-free photo to
  `pending/<uuid>.jpg` and sends a `photo` change; the patient's phone
  accepts it only if the path is under **its own** `pending/` and the bytes
  decode, re-runs `prepareMedPhoto`, saves, uploads it as the official copy
  and deletes the pending one — otherwise `missing` + `mediaSync`.
  `0030_patient_papers_limits.sql` (file only) caps the bucket at 10 MiB
  and `image/jpeg`, the one type both uploaders send.

**«أدوية لسه ماتشترتش» (25 Sep 2026).** Each line on the prescription
review asks «اشتريته؟» — «أيوه» selected by default, so nothing changes for
anyone who ignores it. «لسه» writes `medications.not_bought_at` (drift
**v28**, local) **after** `rescheduleAll`, and nothing in scheduling reads
it: the reminders start exactly when «هتبدأ الدوا من إمتى؟» said
(`not_bought_test` confirms with «لسه», marks bought, reschedules, and
asserts the notification set is identical). `NotBoughtSection` sits in
«السجل» above «أوراقك» only while the list has something; «يومك» carries a
quiet `NotBoughtLine` that opens it. «اطلبها من الصيدلية» is
`orderListFromPharmacy` — the stock WhatsApp flow with one line per
medicine, the user presses send; «اشتريته» clears the flag and, if stock is
tracked, asks the box quantity through the restock sheet. **Circle (0031):**
`not_bought_at` rides the medications push (in `_optionalColumns`, so a
project before 0031 still takes the row), the son sees a read-only card on
his «السجل» and the nurse a list with «اشتريته» only with «يعدّل الأدوية» —
a `bought` pending change the patient's phone applies by clearing the flag,
**never** touching stock (no guessed quantity). `not_bought_not_scheduling_test`
fails if scheduling, the ladder, the notification plan or any
`due_escalations` body mentions the field.

**Schedule patterns, round 1 (25 Sep 2026; audit in
`docs/schedule_patterns_audit.md`).** «ضيف دوا» asks «بياخده إزاي؟»: «كل يوم»
(the old form), «كل كام ساعة» (2/3/4/6/8/12 only — `everyHoursTimes` in
`domain/scheduling/every_hours.dart` expands to 24/N **fixed daily
schedules**, with a preview «هتاخده الساعة: …» before saving; no engine
type, no schema change), and «مرة واحدة» (`DoseRepeat.once`, reachable at
last). The edit screen has «خليه كل كام ساعة»: new fixed schedules are
added first, then the old ones soft-stopped. A prescription line the reader
returns as one day («اليوم فقط») is shown as «مرة واحدة بس» and saved `once`
(`addMedicationsWithDoses(onceAt:)`) — same behaviour as `durationDays: 1`.
Stock days-left uses one `averageDosesPerDay` for the patient and the
circle (every-8-h = 3, once and stopped = 0).

**Schedule patterns, round 2 (25 Sep 2026).** «أيام معينة» (weekday chips,
Saturday first), «كل كام يوم» (2–30) and «فترة وراحة» (e.g. 21/7) — decided
in **one** pure function, `dayPatternActive` in
`domain/scheduling/day_pattern.dart`, anchored on the schedule's start date
by UTC date difference (DST-proof), and asked from `DoseSchedule.isActiveOn`
only. Off-days therefore produce no reminder, rung, repeat or dose row; the
minute still comes from the anchor or fixed clock, so Ramadan is unchanged.
Stored as four nullable columns on `dose_schedules` (drift **v29**, all null
= every day). The form shows «الأيام الجاية: السبت ٢٧، …»; the edit screen's
«غيّر الأيام» adds new schedules from today then soft-stops the old ones.
Stock uses `patternShare` (n/7, 1/n, on/(on+off)) in both
`StockRepository` and the son's parse; the son and nurse read «السبت والتلات
— الفطار − ٣٠ د» from `dayPatternWording` (raw columns, no scheduling
import). **Sync:** ordinary schedules keep their exact payload; patterned
ones push separately with `weekdays / every_days / cycle_on / cycle_off`,
and until `0032_schedule_patterns.sql` runs a rejection keeps them local and
dirty, retried on every push, with health code `patternSync` for the
admin — and `fixed_timings` / `dose_events` now wait for their schedule to
be synced (a no-op in the normal parent-first flow) so a foreign key can
never block the queue. The prescription reader has no weekday or interval
field, so «يوم ويوم» on paper is not mapped yet.

**D3.6 — glucose + labs (built)**
- Schema v12 (written red first): `readings` — **blood glucose only**
  (`value_mg_dl`, `measured_at`, `context` صايم | بعد الأكل); no pressure,
  pulse or weight exist in this product. `lab_results` — one row per
  confirmed test (record_id → `records` lab row, test name as printed,
  value, unit). Both with SyncIdentity columns + triggers; pushed since D5.1.
- **The dangerous screen follows two rules that do not bend.**
  (a) Number, range, difference — stop. No advice, no diagnosis, no
  «يُفضّل», no «راجع دكتورك», no «ممكن يكون». `GeminiLabReader.systemInstruction`
  says so explicitly (pinned by a test); the schema carries only test,
  value, unit, lab and date, so no model free text ever renders.
  `adviceWords` in `features/health/usual_words.dart` is checked against
  the rendered text of 14, 8 and the home card **and** against every
  string literal in `lib/features/health/` — mutation-checked: putting
  «مرتفع» in the comparison fails three tests.
  (b) «المعتاد» means **his** usual (`domain/health/usual_range.dart`,
  pure): lowest–highest of his last 10 values — glucose needs 5 in the
  same context, a lab test 2 earlier values in the same unit. Below that
  the screen says «لسه ما عندناش قياسات كفاية نعرف المعتاد ليك» and marks
  nothing. A different unit says «مش هنقارن». Never a reference range.
- «قياس السكر» (14): typed, 20–600 refused as a typo («برّه اللي أجهزة
  القياس بتقراه»), context must be chosen, latest reading + his usual +
  a plain green line. «تصوير تقرير تحليل» (7): the prescription transport
  (`GeminiPrescriptionReader.generate`) with another prompt, and the
  shared `ScanStage` — no line marked before the reply, reveal walks what
  came back (tested with a mid-flight completer). «قراءة التقرير» (8):
  unsure lines gold «مش متأكد من دي — راجعها» and block «تمام، احفظه»
  until edited or removed; «صوّر تاني» carries equal weight.
- Confirming saves a `lab` record + `lab_results` + the photo through
  `AttachmentStore` (relative path in `attachment_path`). **Deleting the
  record deletes the file, then and there** — `RecordsRepository.delete`,
  after the row's transaction commits, because a row without its file is a
  smaller problem than an orphan file holding a patient's data. This line
  used to say "the 30-day purge deletes the file after the row"; that was
  left behind when «المسح بيمسح» removed the local grace, and the 30-day
  cron (`private.purge_deleted_records`) is a **cloud** backstop that never
  touches this phone.
- Home: the glucose card is gold and sits in «الآن» **only** when the
  latest reading is outside his own usual; otherwise a quiet card above
  water. «افتح» is secondary. Entry: «ضيف» sheet («قيس السكر», «صوّر
  تقرير تحليل») and «الملف الصحي».

**المتابعة بتتعرض بميعاد مرحلتها — مش بتاريخ ورقتها** (الجولة دي).
- **العطل، من جهاز حقيقي:** زيارة محجوزة **بكرة** كانت بتتعرض
  «١٣ سبتمبر ٢٠٢٣» عند الأب وعند الابن. ده تاريخ **الورقة اللي المتابعة
  اتبدت منها**، مش تاريخ أي حاجة جاية. كارت «مواعيدك الجاية» لوحده كان
  بيقول «بكرة»، لأنه الوحيد اللي بيقرا ميعاد المرحلة؛ كل شاشة تانية كانت
  بتطبع `happenedAt`.
- **السبب كان في الكتابة كمان، مش في العرض بس:** `HealthFileScreen`
  كانت بتبعت `happenedAt: source.happenedAt` لـ`checkups.start`، فصف
  المتابعة بياخد تاريخ الروشتة. اتشال: المتابعة حاجة **لسه بتحصل**،
  وتاريخ بدايتها هو النهارده. الورقة مش ضايعة — `followSourceId` هو
  الرابط.
- **القاعدة دلوقتي: متابعة مفتوحة عمرها ما تعرض `happenedAt`.** الميعاد
  ميعاد المرحلة الحالية، ومفيش ميعاد بيتقال بالحرف
  («لسه ما اتحددش ميعاد») — مش بترجع لتاريخ تاني.
- **`lib/domain/health/follow_display.dart` — دارت نقية، ومصدر واحد
  للناحيتين**: `countdownWord` (اتشالت نسختها التانية من
  `appointment_card`)، `followDateLine`، `followDateFull`،
  `followDisplayTitle`، `followRowName`، `followIsOpen`،
  `followStageDate` (و`CheckupService.stageDateOf` و`careStageDate`
  بيعدّوا عليها). نسختين من نفس الجملة معناها شاشتين يقدروا يختلفوا في
  صمت — نفس القاعدة اللي خلّت `rule_wording` مشتركة.
- **الاسم باللي بنتابعه، مش بالورقة**: «تقرير تحليل — ٦ نتايج» بقت
  «متابعة تحليل»، و«تقرير تحليل — CBC» بقت «متابعة CBC»، و«من غير اسم
  دكتور» بقت «متابعة زيارة». التحويل بيحصل **وقت العرض كمان**، فالصفوف
  اللي اتكتبت قبل كده بتتعرض صح من غير هجرة.
- **«زيارات» و«تحاليل» بقوا قسمين: «منتظر» ← «تمت».** القايمة كانت
  مرتّبة بتاريخ الورقة، فزيارة محجوزة بكرة كانت بتنزل تحت تقرير من ٢٠٢٣
  — الحاجة الوحيدة اللي محتاجة فعل بتختفي وسط الأرشيف. «منتظر» بالأقرب
  ميعاد، واللي من غير ميعاد آخرها (مش «بعيدة»، هي **مش متحدّدة**)؛ «تمت»
  بالأحدث. قسم فاضي ما بيظهرش، وشاشة بقسم واحد ما بتحطش عنوان فوق كل
  حاجة.
- **التقويم بيحط المتابعة على يوم ميعادها.** ومتابعة من غير ميعاد
  مالهاش يوم على التقويم أصلاً — بدل ما تقع على يوم الورقة.
- **«عدّل الاسم والدكتور» في «⋯ خيارات»** (`RecordsRepository.rename`)،
  للمتابعات بس. الاسم بيتولد من الورقة، والورقة ساعات مافيهاش اسم دكتور
  — فالراجل كان بيفضل قاعد قدّام متابعة مالهاش اسم يعرفها بيه، والمسح مش
  البديل (ده بيرمي المراحل والمواعيد). المتحكّمات عايشة في `State` مش في
  الدالة: ورقة بتتقفل لسه ليها كادرات بتتبني (عطل جولة ١٦).
- **عند الابن**: «مواعيده الجاية» قسم فوق (ذهبي، بنفس العدّ) تحت سطر
  الحالة — **والتنبيه المفتوح فاضل فوقه**، لأنه جرعة بتفوت دلوقتي وده
  قرار مكتوب من جولة ٢٨. و«زيارات»/«تحاليل» بقت اللي **مالوش** ميعاد
  جاي، فمفيش تكرار. **والمتابعة المفتوحة اتشالت من «الجديد»**: هي حاجة
  شغّالة مش حاجة وصلت، وكل تقديم مرحلة كان بيحرّك `updated_at` فتطلع
  أول القايمة كأنها جديدة، بتاريخ ورقتها القديم جنبها.
- **الابن مش بيشوف «من فين»**: `records.follow_source_id` محلي بالكامل
  وعمره ما يترفع (`health_file_sync_guard_test`)، فسطر الأصل على شاشته
  مش ممكن — وده مقصود، مش نقص.
- **عنوان تقرير التحاليل اتطلّع في `labReportTitle`** عشان يتختبر لوحده،
  وبقى بأرقام عربية لأي عدد.
- الاختبارات: `follow_display_test` (٢١ حالة نقية)،
  `follow_date_display_test` (تاريخ الورقة ٢٠٢٣ والميعاد بكرة، ومدوّر
  عليه في قايمة النوع والملف و«يومك» والتقويم)، وإضافات في
  `caregiver_redesign_test` و`lab_title_digits_test`. **سبع طفرات**:
  رجوع الصف لـ`happenedAt`، رجوع التقويم له، شيل سطر الميعاد، شيل تقسيم
  «منتظر»/«تمت»، رجوع المتابعة لـ«الجديد»، التكرار بين «مواعيده الجاية»
  و«زيارات»، وشيل «عدّل الاسم» — كلها بتوقّع.

**والملف الصحي عند الابن كان لسه بيعرض تاريخ الورقة** — نفس العطل، في
الملف اللي الجولة اللي فاتت نستيه.

من جهاز حقيقي، حساب الابن: زيارة محجوزة **بكرة** بتتعرض بتاريخ الروشتة.
`0e7991c` صلّحت `caregiver_screen.dart` («متابعة») وسابت
`caregiver_health_screen.dart:408`.

- **وده بيقول حاجة عن الاختبارات مش عن الكود**: مكانش فيه ولا لقطة فيها
  متابعة **مفتوحة** على تبويب الملف الصحي، فالسطر الغلط كان أخضر في كل
  تشغيلة. تقرير «اتصلّح» اللي فات كان صادق عن الملفات اللي شافها، ومفيش
  حاجة كانت هتوقّع على اللي ما شافهاش.
- **الحارس بقى سلوكي، مش قراية مصدر.**
  `caregiver_follow_date_test` بيمشي على **كل** سطح عند الابن —
  التبويبات الأربعة، والقوايم اللي بتتفتح من «الملف الصحي» — بلقطة فيها
  متابعتين مفتوحتين بتاريخ ورقة مميّز (١٣ سبتمبر ٢٠٢٣)، وبيقع لو ظهر في
  أي نص معروض. **ملف جديد يتنسي بيقع كمان** — ده اللي قراية المصدر
  مكانتش هتعمله. مُتحقَّق: رجوع السطر الأصلي بالحرف بيوقّع الحارس لوحده.
- **والتقسيمة بقت دالة واحدة للناحيتين**: `followSections` في
  `domain/health/follow_display.dart` (دارت نقية، بمُسنِدات) — شاشة الأب
  (`records_of_kind_screen`) وقايمة الابن (`CareListScreen`) بيقروا
  منها، ومعاها `waitingSectionLabel` / `doneSectionLabel`. نسختين كانوا
  هيبقوا قايمتين يترتبوا مختلف على نفس الداتا — وهي نفس غلطة التواريخ
  بالظبط، بعد ما اتصلّحت في مكان واحد بس.
- **وعلى كارت الابن**: المتابعة المفتوحة بتاخد حقل «الميعاد»
  (`followDateFull`، نفس دالة «متابعة» وشاشة الأب) وحقل «المرحلة»،
  والاسم بيعدّي على `followDisplayTitle`. **اللي خلص بيفضل بتاريخه**
  تحت اسم نوعه («تاريخ التقرير» / «تاريخ الورقة») — ده أرشيف، والتاريخ
  هو معناه.

**جرد `happenedAt` في `lib/features/care/` و`lib/data/care/`** — كل
استعمال، وليه فضل أو اتغيّر:

| المكان | بيعمل إيه | القرار |
|---|---|---|
| `caregiver_health_screen.dart:477` | تاريخ السجل في الكارت | **اتغيّر** — المفتوحة بقت «الميعاد» من ميعاد المرحلة؛ اللي خلص بيفضل بتاريخه |
| `caregiver_health_screen.dart:248` | مفتاح ترتيب «تمت» (الأحدث الأول) | **فضل** — ترتيب أرشيف، مش تاريخ معروض |
| `caregiver_screen.dart:277` | تاريخ صف في «الجديد» | **فضل** — `newestArrivals` بتفلتر المتابعات المفتوحة خالص (جولة الإشعارات)، فالسطر ده عمره ما يشوف متابعة |
| `caregiver_remote.dart:329` | بيبني صف «الجديد» | **فضل** — جوّه نفس الفلتر |
| `caregiver_remote.dart:331,333` | تاريخ قياس سكر / سؤال | **فضل** — مش سجلات ومالهاش مراحل |
| `caregiver_remote.dart:189,208,300,311` | تعريف الحقل في الموديل | **فضل** — العمود نفسه لازم يفضل؛ اللي اتغيّر مين بيعرضه |
| `supabase_caregiver_remote.dart:84` | قراية العمود من الصف | **فضل** — نقل من السحابة |

**ومفيش سطح تالت**: `lib/features/care/` فيه `arabicDate` في مكانين بس
(السجل، وقياس السكر بتاريخ قياسه)، والاتنين متغطّيين فوق.

**D3.7 — calendar + lab follow-up (built)**
- **It is called «تابع تحليل» / «متابعة التحليل», never «دورة».** «دورة
  فحص» described an administrative process; a man walking out of a clinic
  with a paper is not thinking "I am starting a cycle", he wants someone to
  walk it with him — so the button's one-line subtitle is «نمشي معاك من
  طلب الدكتور لحد ما النتيجة توصله». The **code** keeps its names on
  purpose (`CheckupStage`, `records.checkup_stage`, `CheckupService`):
  that is the code's language, and renaming it would be a migration with
  nothing behind it. `test/app/no_cycle_word_test.dart` reads every string
  literal under `lib/` — the same shape as `no_middle_dot_test`, comments
  excluded — and fails on «دورة»/«دورات». Mutation-checked.
- Schema v13 (written red first): `records.checkup_stage` (1..7, null = not
  a follow-up — every earlier lab record) and `records.fasting_reminder_at`
  (the scheduled instant, null = none; the ID itself is derived, never
  stored). Columns added with an existence check above the `from < 6` block.
- «متابعة التحليل» (11): seven stages from `domain/health/checkup.dart`; done ✓
  green, current numbered in gold (the state you are on), later faded. The
  user advances by hand. The subtitle stays, in colloquial: «التحليل مش ميعاد
  واحد — كل خطوة ليها وقتها، وهنا بتعرف وقفت فين». Started from «الملف
  الصحي» («تابع تحليل»); stopping = the D3.5 delete.
- **Each stage asks for its own date, and nothing is invented** (schema
  v17: `lab_booking_at`, `result_ready_at`, `doctor_visit_at`, plus
  `checkup_stage_since`). The rule that we never assume how long a stage
  takes is unchanged — it is now *served* rather than worked around: the
  person tells us, per stage, and only then is there a reminder.
  «حجز المعمل» asks «حجزت إمتى؟», «انتظار النتيجة» asks «النتيجة هتجهز
  إمتى؟», «النتيجة وصلت» asks «معاد الدكتور؟». Each is optional and
  editable, and **skipping is normal and says so in one short muted line**
  («لو لسه ما تحدّدش، عدّي — من غير ميعاد مفيش تذكير وبس.»), never a
  warning and never gold.
- **The person gives a day; the clock time comes from his own wake anchor**,
  not from an invented 9 AM — "the day starts at wake" is the app's own
  notion of when a person is up. With no saved routine it falls back to
  9:00, an operational choice like `defaultOffsetBefore`, not medical.
- **The day picker is one widget** (`DayPicker`: «بكرة» / «بعد بكرة» / a
  chip that opens the calendar). The fasting sheet and the stage sheet both
  use it — a second picker would be a second place for the same behaviour,
  free to disagree with the first.
- **Cancellation mirrors the fasting reminder exactly.** Changing a date
  reschedules onto the *same derived id*, so it replaces rather than adds.
  Going back a stage cancels and clears that stage's date (the plan
  changed — he will be asked again). Stopping the follow-up cancels
  everything. Advancing cancels a reminder only once it is meaningless,
  via `stageReminderStillUseful`: the lab-appointment reminder survives
  «التحضير» — you pass through that stage *before* you go — and dies after
  «سحب العينة».
- **A stage with no date does not go silent.** After
  `checkupStalledAfter` (7 days) at a date-asking stage with no date,
  «يومك» shows one line in the existing muted `_FollowUpPanel` —
  «متابعة صورة الدم واقفة عند حجز المعمل» — that opens the screen at the
  control which fixes it. **Seven days is a display threshold, not a claim
  about how long a lab takes**: we have never been told that number and do
  not invent it (rule 6). The sentence is a fact about the screen — this
  has not moved in a week — not about the body. `checkup_stage_since`
  exists because `updatedAtMs` moves on any edit and `happenedAt` is the
  draw time; neither can answer "how long at this stage".
- **Open follow-ups live on «يومك»** under their own small heading
  «متابعة التحاليل», each row the test name over its current stage,
  tapping through to the screen. Nothing renders when there are none — a
  follow-up nobody sees is a follow-up nobody does, and an empty section
  saying "none" is the opposite problem.
- **«خلصت» is the whole button** (round 27). It read «خلصت — على «سحب
  العينة»» — two ideas in one control, and the second one repeated: the
  timeline beside it already shows where you land, and advancing *is* what
  finishing means. **«رجوع لـ«حجز المعمل»» keeps naming its destination**:
  going back is the surprising direction, and the name is what makes the
  tap deliberate. Both follow-up kinds, one widget.
- **متابعة زيارة جنب متابعة التحليل، وتلات طرق تبدأ بيهم (round 24).**
  `FollowKind` (`lab` | `visit`, schema v19 `records.follow_kind`, cloud
  `0017`) picks which stage list `records.checkup_stage` is read against —
  the number 2 is «حجز المعمل» in a lab and «الزيارة تمت» in a visit.
  **null means `lab`, and that is not a guess**: before this round no other
  kind existed, so every old row with a stage was a lab follow-up.
  `FollowStage` is the one interface both `CheckupStage` and `VisitStage`
  implement, so the service and the screen branch once, not per line.
- **A visit has three stages — «الزيارة اتحجزت» ← «الزيارة تمت» ←
  «المتابعة» — and no more.** Copying the lab's seven would have invented a
  preparation and a waiting the man does not live. «الزيارة اتحجزت» is the
  only dated stage: same `DayPicker`, same `checkupIdFor(record, slot)`
  (slot 0 — a row is one kind, so it cannot collide with «حجز المعمل»),
  same `checkupPendingSlack` cap, same cancel on back / on advance / on
  stop. Its instant reuses `doctor_visit_at` because the meaning is the
  same one appointment.
- **After «الزيارة تمت» it asks once whether the doctor ordered a test**,
  and yes starts a «تابع تحليل» carrying the same doctor. «Once» needs no
  column: the question lives in the *advance action*, not in the screen, so
  reopening never re-asks. A visit that produced nothing stops at
  «المتابعة» like any last stage — nothing is deleted.
- **Three ways in, in this order: from the file, from a photo, by hand.**
  A lab follow-up starts from a lab report, a visit from a prescription —
  carrying its name/doctor/clinic and **the paper's date**, not today's.
  The scan path returns the record it wrote through a new `onSaved(id)` on
  `ScanLabScreen` / `ScanPrescriptionScreen`, so the confirmed report
  starts the follow-up in the same step.
  **The source record is never converted into the follow-up**: it holds
  results that already happened, and a row starting at «طلب الطبيب» with
  results on it contradicts itself. A new row points back through
  `follow_source_id`, which is also how «this paper is already followed»
  has an answer — a second follow-up on one paper would leave both of them
  partial. `follow_source_id` is **local only** (an internal int id, like
  `attachment_path`); `health_file_sync_guard_test` fails if the name
  reaches any cloud payload, comments included.
- **One «يومك» section for both**, «المتابعات», each row reading
  «{النوع} — {المرحلة}», and one stalled line naming the kind so
  «متابعة زيارة د. حسام واقفة عند الزيارة اتحجزت» reads correctly.
- **Band `50_000_000` is claimed** (`checkupIdBase` / `checkupIdFor(recordId,
  stageSlot)` / `isCheckupId`), one id per (record, stage) — `base +
  recordId * 3 + slot`, throwing past the band, and deliberately **not** in
  `isRescheduledId`. The iOS budget paid for it: `maxPendingReminders` drops
  46 → 44 so `checkupPendingSlack` (2) fits, and `maxPendingEscalations`
  stays 14. The dose horizon shortens by about two slots; the ladder was not
  touched.
- **Cloud: `supabase/migrations/0015_checkup_dates.sql`** adds the four
  columns to `public.records` (the device pushes them with the row) and
  changes **no policy and no `due_escalations`** — they are new columns on
  an existing table, and have nothing to do with escalation. Its self-check
  writes a full follow-up, asserts a plain record is still valid with them
  null, exercises the delete, and rolls back. **Confirmed applied
  20 Sep 2026** (see the migrations table above).
- **ترتيب «يومك» بقرار المالك**: «مواعيدك الجاية» ← «الآن» ←
  «جدول النهاردة» ← «المتابعات» ← السكر ← المية. ده **بيلغي** السطر
  اللي كان بيقول «كارت الجرعة بيفضل أول حاجة» في مواصفة المواعيد، وبيلغي
  تأكيد ترتيب قديم في `today_screen_test` («المية فوق جدول النهاردة»).
- **ومفيش تكرار بين الكتلتين**: متابعة ليها ميعاد جاي بتتعرض في
  «مواعيدك الجاية» **وبس**؛ «المتابعات» على «يومك» بقت للمتابعات اللي
  مستنية حركة ومالهاش ميعاد، وبتختفي خالص لما مايفضلش حاجة
  (`needsActionFollowUps`). القوايم الكاملة في «زيارات»/«تحاليل» زي ما هي.
- **والكتلة بتتقلّص لما فيه جرعة مستنية تأكيد — والقياس هو اللي فرض ده.**
  **(الأرقام دي اتغيّرت في جولة «إشعار واحد لكل لحظة» — شوفها فوق:
  سطرين مضغوطين دلوقتي، والزرار بيخلص عند ٥٩٦.)**
  على آيفون SE (٣٧٥×٦٦٧): الترويسة لوحدها **٢٦٠ بكسل**، وكارت الجرعة
  ~٢٣٠. كارت مواعيد بعنوان وصفّين وسطر شرح بياخد **١٥٥** → «تأكيد
  الجرعة» كان بينزل عند ٧٥٢، يعني **برّه الشاشة**. النسخة المضغوطة
  (سطر واحد، من غير عنوان ومن غير سطر شرح) بتاخد ٥٦ → الزرار بيخلص عند
  **٥٩٦** و«ضيف» العايم بيبدأ عند **٥٩٧٫٤**.
  **فرق بكسل ونص.** التنازل مقصود: العنوان زينة، والزرار ده اللي راجل
  عنده ٧٢ سنة بيدوس عليه عشان يأكّد دواه. واختبار على المقاس ده بيقفل
  على الرقمين — أي بكسل بيتزوّد فوق (ترويسة أطول، كتلة أكبر، تكبير خط)
  بيرجّع الزرار تحت الزرار العايم.
  **واللي المالك يقدر يقرره لو عايز هامش أوسع**: يقصّر ترويسة «يومك»
  (٢٦٠ بكسل على SE)، أو يرجّع المواعيد تحت كارت الجرعة.
- **والكتلة ذهبية** (`F.gold`) زي كارت «الآن» — «التذكير والحالة النشطة
  بس». مش كهرماني: الكهرماني لدرجات السلّم ٣ و٤ وبس.
- **ورقم لاتيني كان متخزّن في عنوان عربي.** `'تقرير تحليل — $count
  نتايج'` كان بيحقن رقم لاتيني، والعنوان بيتخزّن كده ويتعرض في كل مكان
  بيقراه. **مفيش إصلاح سابق للموضوع ده** — دوّرت في التاريخ كله ومفيش.
  المصدر اتصلّح (`arabicNumber`)، والصفوف اللي اتكتبت قبله بتتظبط في
  `launchHousekeeping` بنمط **مقفول** على الشكل ده بالظبط. عنوان كتبه
  إنسان ما بيتلمسش: الأرقام اللي جواه بتاعته، وفيه أسماء تحاليل فيها
  أرقام لاتينية (`HbA1c`) تحويلها بيبوّظها — واختبار بيقفل على ده.
- **مواعيد الزيارات والتحاليل — إشعارين وكارت، وسكّة بعيدة عن الدوا.**
  الميعاد كان إشعار واحد في يومه على الصحيان. بقى: **إشعار هادي امبارحه**
  (من غير صوت ولا هزاز) **على العشا** — المرساة المسائية اللي الراجل نفسه
  قالها في «ظبّط يومك»، ساعتها هو قاعد في البيت وخلاص يومه؛ **وإشعار في
  يومه بيرن على الصحيان**، مرة واحدة من غير تكرار؛ **وكارت ثابت على
  «يومك»** من ساعة الحجز لحد ما اليوم يعدّي، بيعدّ تنازلي («بعد ٣ أيام» /
  «بكرة» / «النهارده») وعمره ما يرن. الكارت **تحت «الآن»** عن قصد:
  الجرعة بتفضل أول حاجة على الشاشة.
- **والقيد الأول كان «ما تلمسش تذكير الدوا» — والضمانة فصل، مش نية.**
  `appointment_scheduler.dart` ما بيعرفش حاجة عن الجرعات ولا السلّم ولا
  التأجيل، وبيتنده **بعد** ما `rescheduleAll` ترجع في `try/catch` بتاعه
  (`AppServices.refreshAppointments`). **و`reminder_scheduler.dart` و
  `domain/escalation/` فرقهم عن قبل الجولة دي صفر سطر**، و
  `reminder_plan.dart` إضافة صافية. `test/data/appointment_guard_test.dart`
  (١١ حالة) بيثبت ده وقت الاختبار: **اختبار الخطة الذهبية** بيحسب خطة
  الجرعات كاملة لـ٨ أدوية × ٣ جرعات **من غير مواعيد وبخمس مواعيد** ويقارن
  المجموعتين حرفياً؛ وكمان إن `rescheduleAll` ما فيهاش كلمة «appointment»،
  وإن نداء المواعيد **بعد** نداء الجرعات في `main.dart` و`root.dart`، وإن
  الأسقف بأرقامها، وإن النطاقات متفصّلة **عند أقصى قيمة**، وإن مفيش
  `cancelAll`، وإن سكّة المواعيد ما بتستعملش المنبّه الدقيق.
- **القناة لوحدها**: `fakkarni_appointment` — مواعيد الدكتور تتسكّت من غير
  ما تذكير الدوا يتسكّت. وهدوء إشعار امبارحه جاي من `silent: true` على
  الإشعار نفسه (`NotificationCompat.Builder.setSilent`) مش من قناة تانية،
  فالقناة واحدة زي ما المواصفة طلبت.
- **والمنصّتين بيختلفوا عن قصد.** **iOS** بيمسك ٦٤ إشعار معلّق **وبيرمي
  الزيادة في صمت** — وممكن تبقى جرعة على حدّ النافذة؛ فالمواعيد بتاخد
  **نفس الخانتين** بتوع `checkupPendingSlack` (ولا خانة اتاخدت من
  الجرعات) كـ**نافذة متدحرجة** على أقرب إشعارين، **والإلغاء قبل الجدولة**
  عشان ما يبقاش فيه لحظة العدد فيها ٣ (اختبار بيقيس الأقصى **اللحظي**).
  **أندرويد** مفيهوش السقف ده فكل الإشعارات بتتجدول **من ساعة الحجز**:
  النافذة المتدحرجة بتعتمد على فتح التطبيق، وده أقل حاجة مضمونة هناك
  بسبب قتلة البطارية. **والمنبّه غير دقيق** في الحالتين — الدقيق مورد
  مقنّن ومحجوز للجرعات.
- **والحجز عمره ما يترفض.** الرفض القديم («فيه ميعادين متظبطين — شيل واحد
  الأول») اتشال: الميعاد البعيد بيستنى دوره، **والكارت هو شبكة الأمان**.
- **واللي بيحصل لو الأب ما فتحش التطبيق ولا أكّد جرعة كام يوم (iOS):
  النافذة ما بتتدحرجش.** الخانتين بيفضلوا على أقرب إشعارين وقت آخر فتحة؛
  لما يرنّوا، اللي بعدهم ما بيدخلش لحد ما حاجة تصحّي التطبيق — يعني
  **ميعاد تالت أو رابع ممكن يعدّي من غير إشعار**. نفس شكل الدين ٠ج وبنفس
  السبب. **ومفيش فحص سلامة بيقوله لسه، والمفروض يبقى فيه**: نظير
  `horizonFromPendingDoseIds` هنا هو «فيه ميعاد جاي مالوش إشعار معلّق».
  متسجّل مش متعمول.
- **وعلى موبايل الابن: إشعارات محلية من السحبة، مش دفع.**
  `CaregiverSnapshotHolder` بينده `syncCaregiverAppointments` بعد كل
  سحبة — نفس تقسيمة هادي/بيرن، نفس القناة، أرقام من نطاق الابن، وبتتعاد
  بلا أثر. **والحد**: ميعاد اتحجز بعد آخر سحبة عمره ما يوصل موبايل الابن
  غير لما **يفتح التطبيق تاني**؛ الحل الحقيقي دفع من السيرفر (FCM شغّال
  لابن على أندرويد، وiOS مستني APNs — الدين ٣). **والساعة على موبايله رقم
  ثابت** (٨ مساءً / ٨ صباحاً) مش مرساة الأب: الابن **ما بيحلّش مراسي**
  (`no_scheduling_imports_test`)، ومحرّك تاني على جهازه معناه جدولين
  ممكن يختلفوا في صمت.
- **وإشعارات المواعيد على أندرويد متختبرة بالوحدات، مش على جهاز.** اختبار
  المحاكي في CI بيغطّي سكّة زرار الجرعة وبس؛ مدّه للمواعيد بيحتاج ينتظر
  يوم كامل أو يزوّر ساعة الجهاز، فما اتعملش.
- **«اضبط تذكير الصيام» schedules a real notification — only from that
  tap (rule 4)**, at draw time minus the hours **the user picks** (no
  default, rule 6), through `NotificationService.scheduleCheckup`: its own
  Android channel `fakkarni_checkup`, **no «أخدته»/«فكّرني بعدين» buttons,
  no dose category, no payload** — those buttons record doses. It is
  cancelled by going back a stage, advancing past «سحب العينة», stopping
  the follow-up, or deleting the record from «الملف الصحي» (all through
  `CheckupService`); a deleted record does not come back.
  A third concurrent reminder is refused with words.
- «التقويم» (12): month/week (week starts Saturday), filters دوا (incl.
  prescription records) · زيارة · تحليل · أشعة · حجز · سكر. Days with
  entries get neutral green dots; a gold edge only for an unconfirmed past
  dose. Tapping a day shows its entries below. Reads
  `DoseEventRepository.watchBetween`, records and readings — no new table.
  Entry: «التقويم» on «الملف الصحي». Day cells are 64 tall but ≈53 wide on
  a 402pt phone — seven columns do not fit 56 each; the whole cell is the
  target.

**إشعار واحد لكل لحظة، ومعاه إصلاح ترقية** (٢٢ سبتمبر ٢٠٢٦، من آيفون
حقيقي — **أربع إشعارات عن نفس الصبح**):

```
«النهارده ميعادك في المعمل» / «تقرير تحليل — 6 نتايج»      ← الجديد
«النهارده عندك زيارة»       / «من غير اسم دكتور»            ← الجديد
«متابعة تقرير تحليل — 6 نتايج» / «النهارده ميعادك في المعمل.» ← القديم
«متابعة من غير اسم دكتور»      / «النهارده معاد زيارتك.»      ← القديم
```

تلات أعطال في الأربعة دول:
- **بقايا النسخة القديمة — دي ترقية بايظة، مش وسخ.** قبل جولة المواعيد
  كان ميعاد المرحلة بيتجدول برقم من نطاق `checkupIdFor`. النسخة الجديدة
  بتلغي الرقم ده جوّه `setStageDate` — يعني **بس لما الميعاد يتظبط
  تاني**. أي صف اتحطّ ميعاده قبل الترقية بيفضل ماسك إشعاره القديم
  **للأبد**، فبيرن جنب الجديد. ده بيحصل لكل مستخدم حقيقي بيحدّث ومعاه
  متابعة بميعاد. الإصلاح في **التوفيق**: `AppointmentScheduler.refresh`
  بيمشي على `pendingIds()` وبيلغي **كل** رقم في نطاق `isCheckupId` كل
  تشغيلة — إلغاء وبس، بالرقم، من نطاق **مفيش حاجة بتجدول فيه خالص**
  (تذكير الصيام نطاقه `fastingIdBase`). بلا أثر، رخيص، ومش محتاج يعرف
  الصفوف أصلاً — فبيمسك كمان إشعار لصف اتمسح.
- **الإشعار بقى لليوم، مش للميعاد** (طلب المالك). كل مواعيد اليوم
  الواحد بيطلعوا في إشعار واحد: «النهارده عندك: زيارة الدكتور، وميعاد
  المعمل»، و«بكرة عندك: …» للهادي. ميعاد واحد بيفضل بكلامه القديم
  («النهارده ميعادك في المعمل»)، ومن تلاتة وفوق بنسمّي الأولين ونقول
  «وحاجة كمان» — عنوان بيعدّ كل حاجة بيتقصّ في شريط الإشعارات.
  **والمتن بيسمّي اللي العنوان سمّاه بس**: عنوان بيقول «وحاجة كمان» ومتن
  بيعدّ التلاتة بيتناقضوا قدّام عين بتقرا بسرعة.
- **والمتن كان بيعرض عنوان الورقة الخام** («تقرير تحليل — 6 نتايج»، برقم
  لاتيني). إصلاح العناوين (`0e7991c`) غطّى الشاشات وما غطّاش الإشعارات.
  دلوقتي الإشعار بيعدّي على نفس `followDisplayTitle` — الأب والابن.

**والرقم اتغيّر معاه: `appointmentIdFor(day, notice)`.** المفتاح بقى
اليوم، فالرقم لازم يبقى مفتاحه اليوم كمان — `base + epochDay * 2 +
notice`، و`epochDayOf` بتتحسب **بالـUTC** لأن الفرق بين تاريخين محليين
بيغلط يوم كامل حوالين تغيير الساعة في مصر (يوم بـ٢٣ ساعة بيتقسم على ٢٤
ويطلع صفر). النطاق سايع `appointmentDaySpan` يوم — أكتر من ثمن آلاف سنة
— فمفيش لفّ ممكن، والدالة بترمي برّه الحد وعلى أي يوم قبل ١٩٧٠.
**ونطاق الابن اتغيّر لنفس الشكل**: كان مشتق من **مكان** الميعاد في
القايمة، وده كان بيخلّي نفس الرقم يشير لميعاد مختلف لما القايمة تتغيّر.

**واللي التجميع عمله في نافذة iOS: الخانتين بقوا يغطّوا يوم كامل.**
`checkupPendingSlack` لسه **٢** و`maxPendingReminders` لسه **٤٤** — ولا
خانة اتاخدت من الجرعات ولا من السلّم. اللي اتغيّر إن الخانتين كانوا
بيشيلوا **ميعاد واحد** (هادي + بيرن)، وبقوا يشيلوا **كل مواعيد أقرب
يوم**. يعني أب عنده تلات مواعيد في صبح واحد كان محتاج ست خانات وبقى
محتاج اتنين.

**والتوفيق بقى صاحب النطاق لوحده.** `clearStageDate` كانت بتلغي رقم
الميعاد بنفسها؛ دلوقتي الرقم مشتق من اليوم، فالإلغاء ده كان هيطفّي إشعار
ميعاد **تاني** واقع في نفس اليوم. فهي بتكتب `null` وبس، و`refresh` هو
اللي بيحسب ويلغي — و`advance` و`back` و«امسحه» بقوا بيندهوا
`refreshAppointments` زي `setStageDate`.

**وكارت «يومك» بيعرض سطرين حتى وهو مضغوط**، واللي زيادة بقى بكلامه
(«+ ميعاد تاني» / «+ ميعادين تانيين» / «+ ٣ مواعيد تانية») — «+١» جنب
كارت ذهبي بتتقري كأنها زينة، والتحليل كان بيستخبى وراها.
**والقياس على SE هو اللي حدّد شكل الصف**: الصف المضغوط مابقاش له حد
أدنى، فبياخد ارتفاع سطره العربي (~٢٩ على ١٧ بكسل)، ومفيش فاصل بين
الصفّين ولا فجوة تحت الكتلة. النتيجة: **زرار «تأكيد الجرعة» بيخلص عند
٥٩٦ و«ضيف» العايم بيبدأ عند ٥٩٧٫٤** — نفس فرق البكسل ونص بالظبط، بسطرين
بدل سطر. **وقاعدة «هدف اللمس ٥٦» محفوظة**: الكتلة المضغوطة ٦٢ بكسل وكل
حتة فيها بتفتح متابعة — الهدف هو الكارت، مش السطر.

**وحارس الأرقام اللاتينية مقصور على اللي إحنا بنولّده.** عناوين
الإشعارات كلها بتاعتنا، فولا رقم لاتيني فيها؛ والمتن بيعدّي على
`followDisplayTitle`. **لكن عنوان كتبه إنسان بيعدّي زي ما هو** («CBC
2026») — نفس قرار `lab_title_digits_test`، وفيه اختبار باسمه عشان
مايتقراش كثغرة.

الاختبارات: `appointment_grouping_test` (١٦ حالة — البقايا، التجميع،
الأسماء، والأرقام) وإضافات في `caregiver_appointment_notices_test` و
`today_appointments_test`. **ست طفرات**: شيل كنس النطاق القديم، كسر
التجميع باليوم، رجوع المتن لعنوان الورقة الخام (عند الأب وعند الابن)،
رجوع الكارت المضغوط لسطر واحد، ورجوع «+١» مكان الكلام — كلها بتوقّع.

**D3.8 — doctor page + export (built)**
- Schema v14 `visit_questions` (body, created_at, asked; SyncIdentity +
  trigger; pushed since D5.1). Written red first.
- **«الزيارات والروشتات» — grouped by the doctor's name.** The record has
  carried `doctor`, `place` and the paper's `happenedAt` since the review
  screen learned to read them, and this screen ignored all three: a visit
  summary with no doctor on it is not a summary. Visits and prescriptions
  (newest first, capped at 8 — this opens while a doctor is standing there)
  group under the name **as written**, matched case-insensitively after
  trimming so «د. هشام» and «د. هشام » are one person. It never guesses
  that «هشام» and «د. هشام» are the same man; that is a guess about people,
  and getting it wrong files a visit under a doctor who never saw it. A
  paper with no doctor gets its own group at the end, «من غير اسم دكتور
  على الورقة» — said in words, never invented, never mixed into someone
  else's. Each line under the head is «العنوان — العيادة — تاريخ الورقة».
- «ملخص زيارة الطبيب» (16): current medications with their rules, glucose
  for the last 30 days per context (count · lowest · highest · average),
  the latest value of each lab test with «كان X في {date}», the nearest
  booking, and family questions («اتسأل ✓»). **Numbers and facts only** —
  the D3.6 banned-words test now also reads this screen and every string
  literal in `features/doctor/` and `features/export/`, plus «يبدو»،
  «نستنتج»، «غالباً».
- «استخراج الملف» (30): period + one 👁/🙈 chip per section. **Hiding is
  enforced at generation:** `collectExport` never queries a hidden section,
  so it is not in the PDF at all. `test/features/export/export_pdf_test.dart`
  builds an uncompressed PDF, decodes its ToUnicode maps, and asserts a
  hidden section's Latin tokens are absent — after a positive control that
  finds every token with all sections visible (mutation-checked: ignoring
  the hidden flag fails three tests). Emergency is hidden by default;
  contact phone numbers never enter the file.
- «معاينة الملف» (31): the actual PDF bytes rasterized (`printing`), and
  those same bytes are what gets saved and shared (test asserts identity).
  «احفظ وشارك» saves to `Documents/exports/` (visible in Files via
  `UIFileSharingEnabled`), states that location, then opens the share
  sheet; if the sheet does not open the location stays on screen. «طباعة»
  opens the system print dialog.
- **Arabic in the PDF was verified by looking at a generated file, and it
  was broken first.** `pdf` shapes letters correctly but measures a word by
  its ink, not its advance, so words ending in a long-tailed letter ran into
  the next («سكرصايم»), and mixed Arabic/Latin lines came out reordered.
  `arabicLine` in `export_pdf.dart` fixes both: one `Text` per Arabic word
  padded with ink-less NBSPs (the box then follows the advance), Latin runs
  grouped into one LTR `Text`, all in an RTL `Wrap`; diacritics are stripped
  in the PDF only (a shadda landed off its letter). Re-check with a real
  render (`qlmanage -t`) after touching it — the code saying `rtl` proves
  nothing.
- Entry: «صفحة الطبيب» and «استخراج الملف» on «الملف الصحي». New
  dependencies: `pdf`, `printing` (no `share_plus`).

**D3.9 — nearby (built) — the 33rd screen**
- **Since the MapKit round: iOS asks Apple Maps, Android stays on
  Overpass — and the screen cannot tell which.** `PlacesSource` is one
  method, `nearby(lat, lon, radiusMeters) → List<Place>`, with two
  implementations: `OverpassPlaces` (unchanged behaviour) and
  `AppleMapKitPlaces`, a `MethodChannel('fakkarni/places')` to
  `ios/Runner/PlacesChannel.swift`, which runs two `MKLocalSearch`
  natural-language queries («صيدلية», «دكتور») inside the radius, filters
  by distance (MapKit returns *around* a region, not inside it), de-dupes,
  and returns name / lat / lon / phone / the MapKit identifier (iOS 18+;
  coordinates before that). **No key, no MapKit JS, no network code in
  Dart** — the OS talks to Apple under the same rules as the Maps app.
  `openingHours` is always null from MapKit — it does not expose hours,
  and the screen already stays silent without a tag. The choice happens in
  **exactly one place**, `placesSourceForPlatform` (`Platform.isIOS`), and
  `places_source_switch_test` reads `lib/` and fails if either source is
  constructed anywhere else or the screen names a source.
  `NearbyPlaces` is the façade the screen holds: the 24-hour cache, the
  3-decimal rounding and the offline fallback moved there from
  `OverpassPlaces` so both sources get them; the cache now stores
  `Place.toJson` (our shape, not the source's) under a key that carries the
  source id, so a device that changes source never reads the other's rows.
  `OverpassPlaces.search` survives as a delegation so the Overpass tests
  stayed byte-for-byte untouched. The Swift side **cannot be exercised by
  `flutter test`** — the contract test runs the same assertions against a
  fake source and against `AppleMapKitPlaces` on a mocked channel; the real
  `MKLocalSearch` is verified on the iPhone or not at all.
  **Four kinds since the hospitals-and-labs round: pharmacy, doctor,
  hospital, lab** — `PlaceKind` grew, `Place` did not. Overpass is still
  **one** query (a union of six tag selectors), and `amenity=clinic` now
  counts as a doctor because that is what OSM in Egypt actually uses far
  more than `healthcare=doctor`. MapKit finds hospitals through
  `MKLocalPointsOfInterestRequest` with the exact `.hospital` category —
  a category, not a word that gets interpreted — and labs through the
  natural-language query «معمل تحاليل»; pharmacies and doctors stay word
  searches until the phone comparison says otherwise. The screen has five
  chips in this order: «الكل / صيدليات / دكاترة / مستشفيات / معامل
  تحاليل» (the second reads «دكاترة», not «أطباء» — colloquial rule; the
  chip already existed with that word), each kind with its own icon from
  the Material set already in use (`local_pharmacy`, `medical_services`,
  `local_hospital`, `science`) and no new colour. The empty state is one
  sentence per kind on the existing pattern, naming the source through
  `sourceName` — «الكل» too. The cache key carries
  the full set of kind names, so rows written before a kind existed are
  never reused. `overpass_query_test` pins the six tags; the contract test
  runs all four kinds on both sources; the screen test taps each chip and
  sees only that kind and only its icon.
  **The privacy line names where the location actually goes**, and the
  screen still never names a source: every `PlacesSource` carries a
  `displayName` («Apple» / «OpenStreetMap»), `NearbyPlaces.sourceName`
  hands it up, and the screen prints «مكانك بيتبعت لـ … عشان يدوّر —
  التقريبي، مش مكانك بالظبط.» — Apple on iOS, OpenStreetMap on Android
  (`nearby_screen_test` pumps both). **No sentence on that screen names
  a source literally any more** — the header line and every empty state
  go through `sourceName` too; the one literal is «© مساهمو
  OpenStreetMap», the tile credit, which stays on both platforms because
  the tiles are OSM on both. A test pumps every filter under an
  Apple-named source and asserts no text but the credit contains
  "OpenStreetMap", then under Overpass and asserts none contains "Apple"
  (mutation-checked: a literal put back in the header fails it).
- PHASE_D3 said this needed billed Google Places. It does not: verified
  with a live Overpass query around central Cairo (no key, no account)
  and a live OSM tile; both usage policies read and quoted in the
  corrected PHASE_D3 line and in debt 4b.
- `lib/data/places/places.dart`: one Overpass query per search (pharmacy +
  `amenity=doctors` + `healthcare=doctor` in 2 km), the location rounded
  to 3 decimals (~110 m) **before** it leaves the phone — and the screen
  says it leaves («بنبعت مكانك التقريبي لـOpenStreetMap»); app User-Agent;
  24-hour cache keyed by the rounded point (shared_preferences). Offline
  with a cache shows those results with their date; without one, a plain
  message. Re-search only from «دوّر من مكاني تاني», never on map drag.
- `domain/places/opening_hours.dart` (pure) answers «فاتحة/قافلة» **only
  when it understands the whole tag** (24/7, day ranges incl. wrap, several
  spans, overnight, off); anything else → no verdict, the tag is shown
  verbatim. A wrong «فاتحة» walks a 72-year-old to a closed door.
- `NearbyScreen`: OSM tiles via `flutter_map` (built-in cache honours
  Cache-Control/Expires; `userAgentPackageName` set), our own «© مساهمو
  OpenStreetMap» label on the map (flutter_map's widget doubled the © and
  reordered the Arabic), `KeyboardOptions.disabled()` (the map's autofocus
  scrolled the privacy line off screen). Cards: name (or «صيدلية من غير
  اسم على الخريطة»), distance, open state only as above, «اتصل» only with
  a phone tag, «الطريق» → Apple Maps / `geo:`. Both are secondary buttons —
  a primary per card would break the two-primaries rule.
- Location permission is requested when the screen opens and nowhere else
  (`geolocator`; `NSLocationWhenInUseUsageDescription`, Android coarse/fine);
  denied, denied-forever («افتح الإعدادات») and service-off each get words.
- Entry: the «القريب مني» pill on the home screen (the «الأدوية» button
  was removed in the add-card round — nearby is not a medication-list
  concern), and «قريب منك» in
  settings. New dependencies: `flutter_map`, `latlong2`, `geolocator`.

**Ramadan mode (built, screen restyled in D2.7)**
- `domain/scheduling/ramadan.dart` (pure): `RamadanTimes` (Cairo defaults
  18:00 / 03:30) and `ramadanRoutine(original, times)` — breakfast → Iftar,
  lunch → Iftar too (a «قبل الغدا» dose merges instead of vanishing),
  dinner → Suhoor, sleep = Suhoor + 60, wake unchanged.
- Schema v7 `routine_backups` (device-only, not synced): its row existing
  IS the toggle. `RoutineRepository.enterRamadan` writes the backup BEFORE
  the routine and updates `day_routines` in place (same uuid);
  `leaveRamadan` restores it verbatim. Re-entering while on recomputes
  from the stored original, never from the live routine. ON→OFF twice
  equals the start (tested).
- `features/routine/ramadan_screen.dart` (mockup 25): «يومك في رمضان»,
  state card (gold when on), Suhoor / Iftar editable with sleep derived,
  and the preview as the heart — «N أدوية هتتحرك» with before → after per
  medication from the real engine, fixed doses listed as unmoved. **One
  button that IS the act** («فعّل وضع رمضان» / «اقفل وضع رمضان»); no
  switch, no autosave. A test opens the screen, edits Iftar, closes it,
  and asserts routine, backup and every scheduled notification are
  identical. Entry: the settings card, gold-edged with «شغّال» when on.
- Guard: «عدّل يومك» is locked while Ramadan is on (gold line) so an edit
  cannot be silently discarded by a later OFF.

**Round 4.2c — escalation alerts on the caregiver screen (built, NOT
device-verified)**
- `CaregiverAlert` + `CaregiverSnapshot.alerts`; `SupabaseCaregiverRemote`
  reads `escalations` (48h, mine, `sent|no_token|failed`, newest first)
  with the dose and medication embedded; `_AlertCard` above the week
  strip — gold while open, ivory + «أكّدها بعدين ✓» once taken, open
  always above resolved. Wording per status as described in Phase 4.
- 13 tests: six screen cases with a fake remote (one alert, resolved,
  skipped, `no_token`, `failed`, none → nothing), ordering open-above-
  resolved, and the pure `alertFromRow` parse.
- Unverified: the nested-embed `.eq` filter on the live project, and what
  a real `sent` row looks like there — every live row is still `no_token`
  until «Next» 4 lands, so the demo shows the in-app wording.

**Round 4.2b part 2 — the Dart side: registering the son's token (built,
NOT device-verified)**
- `lib/data/push/`: three interfaces, `PushTokenService` holding every
  decision in plain Dart, `FirebaseTokenSource` (the only Firebase import;
  Android only — iOS waits on APNs, debt 3) and `SupabasePushTokenRemote`
  (calls `claim_device_token`).
- `NotificationService` now creates the `fakkarni_caregiver` channel, its
  own channel so the son can mute his father's ordinary dose reminders
  without muting the alert that matters.
- Wired in `main.dart` (null when Supabase or Firebase is absent — the app
  is unchanged without either), cleared before sign-out, registered
  eagerly after linking.
- 12 tests with fakes, none touching Firebase, plus the channel-name mirror
  test.
- `firebase_core` ^4.14.0 + `firebase_messaging` ^16.6.0; google-services
  Gradle plugin 4.5.0; **no firebase-bom** (the Flutter plugins carry their
  own versions).
- **Gradle wiring verified 2026-09-15:** `flutter build apk --debug` with
  the google-services plugin applied builds and runs on the Pixel_8
  emulator (API 34) — the Android SDK now exists on this machine. Still
  unverified: a real device token, i.e. `handled 1 / sent` replacing
  `no_token`.

**Rounds 4.2b parts 2–3 — the cloud half is live**
- `0006`–`0009` all applied to the real project, `ALL ESCALATION TESTS
  PASSED` after each. `0008` schedules `fakkarni-escalate` every five
  minutes; `0009` makes an interrupted claim retry after 5 minutes and
  turns the claim into one atomic statement.
- The Edge Function is deployed with the atomic claim
  (`claim_escalation_for_service`); the old INSERT-then-409 version would
  have made `0009` a no-op.
- The only thing standing between a missed dose and the son's phone is a
  registered device token.

**Round 4.2b part 2 — the alert path, verified on the live project**
- `0006_push.sql`: `device_tokens` (token is the PK; writes go through
  `claim_device_token`) + `escalations` (`unique (dose_event_uuid,
  caregiver_id, rung)` is the whole no-duplicate mechanism),
  `private.server_grace_window()` and `private.due_escalations` — the one
  definition of the selection. `0007_escalate_rpc.sql`: a `public` wrapper
  for it, `service_role` only, because `private` is not exposed to
  PostgREST.
- `tests/escalation_test.sql` proved the selection **before** any sending
  code existed: chosen once, second run empty, confirmed/missed (until 0011)/stopped/
  unlinked/pending-link never chosen, +50 no and +60 exactly yes, the
  unique catching a racing second claim, and a second brother still
  alerted after the first.
- `functions/escalate/index.ts`: no imports (plain fetch + Web Crypto),
  three modes (`dry_run`, one event by hand ignoring the clock, bounded
  scan), bearer must equal the service role key, claim-then-send, transient
  FCM failures release the claim and permanent ones delete the dead token.
- `test/data/sync/server_grace_sql_test.dart` holds the 60 in SQL against
  `serverGraceWindow` in Dart, and fails if either moves alone.
- Verified live: `ALL ESCALATION TESTS PASSED`, and a hand invocation
  returned `handled 1 / no_token` — Google accepted the service account,
  the care relationship resolved, the row was claimed. Only token
  registration is missing.
- Also fixed on the way: `0001`–`0003` could never be re-run (the README
  claimed otherwise), and the `serverGraceWindow` invariant was written as
  `>` and tested with a minute subtracted to make `>` pass on an `=`.

**Round 4.2b part 1 — the cloud knows the dose before its time (built)**
- `rescheduleAll` materialises yesterday, today **and tomorrow**;
  idempotent, so re-opening adds nothing.
- `serverGraceWindow` (60) + `syncSlack` (15) beside `graceWindow` (45),
  with the invariant under test.
- Caregiver footer goes gold past `staleAfter` (24h) with «اطمن عليه».
- Foundation test in `test/data/sync/`: one morning open, no further
  touch → every dose of today and tomorrow reaches the cloud as `pending`
  before its time.
- Fixed a latent test bug found on the way: the no-saved-routine case
  pointed its event repository at the wrong database, invisible until
  materialisation reached a day with real doses.

**Round 4.2a — the isolate's writes reach the cloud (built, not yet
device-verified)**
- `SyncService.pushOnce({timeout})` — one bounded attempt over the same
  `push()` body, so there is still exactly one definition of how a row
  goes to the cloud; `backgroundTimeout` is injectable for tests.
- `initSupabaseForIsolate()` beside `initSupabaseAuth()`; the background
  entry point in `bootstrap.dart` builds a `SyncService` without
  `start()` (no listeners, no timers) and calls `shutdown()` in `finally`.
- `NotificationActionHandler.sync` pushes as its last statement. Tests
  assert the last cancel happens before the first upsert, that an
  unlinked device makes zero calls, and that a failing or hanging cloud
  leaves the local write, the cancels and the dirty rows intact.
- Device check pending: `/device` steps 7 and 8.

**Round 3.2a — stable row identity (built)**
- `uuid` on all six tables, v4 backfilled per row, schema v5. Verified by
  SchemaVerifier (v4→v5) and the hand-written v2-file test (v2→v5).

**Round 3.5 — the son's read-only view (built)**
- `CaregiverRemote` + Supabase impl (linked patient via own
  care_relationships, meds, 7 days of dose_events, max server updated_at);
  `CaregiverScreen` (mockup 04; the 7-day strip from 12 was built here and
  **removed in round 30**): today's list with states verbatim, gold «لسه ما اتأكدتش»,
  «آخر تحديث من موبايل والدك». Entry: «متابعة {الاسم}» on the link screen
  + «افتح المتابعة» after redeem.

**Round 3.4 — one-way sync, father's device → cloud (built)**
- drift v6: `updated_at_ms`/`synced_at_ms` on every SyncIdentity table,
  SQLite triggers in beforeOpen, SchemaVerifier-proven migration (rows
  survive, everything starts dirty so the first push uploads history).
- `lib/data/sync/`: SyncService (dirty queries with uuid-joins, batched
  upsert-on-uuid, silent failure policy) + SupabaseSyncRemote (injects
  owner_id on patients). Cloud 0004: server-side updated_at (moddatetime).

**Round 3.3 — invite code + care circle (built)**
- SQL: `invite_codes` + `create_invite`/`redeem_invite` (the one gate);
  rls_test.sql extended and still the authority. Dart: `CareCircleService`
  (interface + Supabase impl in lib/data/care/), father's huge 3-3 western
  code screen, son's 6-digit redeem screen, patient-row upsert — the only
  sync write. Device check: father shows code, son (simulator) redeems,
  one accepted care_relationships row, code marked used.

**Phase 3.1 — identity plumbing (built)**
- `AuthService` + `AnonymousAuthService` (live) + `GoogleAuthService`
  (dormant sibling); `SignInScreen` behind «اربط ابني»; guard tests prove
  auth is not a gate. Real-device check: tap «اربط ابني» with
  SUPABASE_URL/SUPABASE_ANON_KEY set → user appears in Supabase Auth.

**Demo prep (chore, no features)**
- Step-trace `debugPrint`s removed from `bootstrap.dart` and
  `notification_actions.dart`. Kept: the isolate-entry and `_onTap` lines
  (see the second-engine note above) and every log inside a `catch` —
  `Handle: ⚠`, `Auth:`, `Care:` — they are the only record of a real
  failure on a path no test reaches.
- `test/app/phone_width_smoke_test.dart`: ~25 screens at 390 wide, text
  ×1.0 and ×1.3, empty and seeded, with the real fonts loaded (the test
  font's 1em glyphs give false overflows). It found and fixed: the
  emergency card's top row, the tab labels, the medication group head.
- `GoldNote` (ink text, gold start edge) replaces gold *text* on ivory
  (≈1.9:1) in redeem / edit routine / edit medication; settings values are
  ink, not gold.
- **Known, not fixed (decisions):** the water
  counter's «٠» reads as a bullet; the empty home shows water above
  «جدول النهاردة» and the «ضيف» FAB covers the empty-state line; the
  notification permission has no in-app lead-in; the caregiver screen
  still uses gold text.

**Front-door visuals (مطابقة المخططات ١ و٢ و٣)**
- **Splash is 3.85s of motion + a 1.2s rest + a 0.45s fade = 5.5s total**
  (1.9s → 3.35s → 5.5s): ring, tail, then the gold dot **flies in from
  off-screen right on an arc**, hops as it lands, flashes once (the dot
  lightens toward white and its halo expands), «فكرني» rises — **and then
  nothing moves for 1.2 seconds** before the layer fades. `FaMarkPainter`
  gained `dotSlide` and `dotFlash`; reduced-motion still jumps to the
  final state (`_exitAtMs`, the one place the fade's start is written).
- **The rest is the point, and it is why the total grew.** At 3.35s the
  motion ran 2.75s with only 0.25s of stillness after it, and on a real
  cold launch the app is ready before the eye settles: the mark assembles,
  the word arrives and the whole layer leaves in one blink, so a first-time
  user never actually sees the brand. Every beat was scaled by the same
  ×1.4 so the story and its proportions are unchanged — only the hold is
  new. Do not "trim" this back by shortening the rest; the rest is the
  feature, and the animation must never look cut off mid-flight.
  `test/app/splash_test.dart` samples `FaMarkPainter`'s moving fields at
  two instants a second apart inside the rest and fails if any of them
  differ — mutation-checked: starting the fade at 3.85s goes red. It lives
  in its own file because `_splashShown` is per-process, so a completed
  splash in one test would skip every later one.
- **Entry screen follows mockup 02**: white ground, the ink mark with its
  gold dot, three cards, and a «يلا نبدأ» primary. **This replaces D4's
  "each card is the action"** — the owner asked for the mockup's two-step
  select-then-start; the card now only selects (green tint, green edge,
  check), and the button carries the move.
- **Sign-in follows mockup 03** as far as the truth allows: white ground,
  centred mark, title, subtitle, the «حساب تجريبي» chip where the mockup
  puts its role chip, a white Google row and a dark Apple row, an «أو»
  divider, then the one working control. **Not built, and not because of
  time**: real Google/Apple sign-in (debts 2 and 3 — the rows stay locked
  with their own reasons), the email field (Email OTP was removed from the
  product), and the mockup's «بياناتك الطبية مشفّرة» line — nothing is
  encrypted beyond the platform default, so the entry screen says what is
  actually true: the data stays on this phone until he links someone.
- The white ground is on these two screens only; the rest of the app keeps
  `F.ivory`. Flipping the whole app to the mockups' white is a brand-token
  change and a separate decision.

**D5.2 — the son sees the whole health file (built)**
- `CaregiverSnapshot` carries `records` (with lab lines embedded under their
  report), `readings`, `emergency` and `questions`. Row → model mapping is
  pure (`recordFromRow`, `readingFromRow`, `emergencyFromRow`,
  `questionFromRow` beside `medicationFromRow`); `recordFromRow` returns null
  for a soft-deleted row as a second line behind the `deleted_at is null`
  filter. Every query is bounded until a delta fetch exists: records 50
  (newest arrival first), readings 30 days / 200, questions 50, emergency 1.
- **One snapshot, one fetch per refresh.** `CaregiverSnapshotHolder` owns
  the fetch, the not-linked callback and the 10-second poll; both data tabs
  read it. "Visible" now means either data tab — the poll stops on
  «الإعدادات» and in the background, and entering a data tab (even from the
  other one) refreshes at once. `CaregiverScreen` still builds its own
  holder when opened on its own from the link screens.
- **«الجديد»** (`newestArrivals`, cap 10) mixes records, readings and
  questions. It sat directly under the alert cards until round 26; it now
  sits **below «النهارده» and «أدويته»** — a missed dose still outranks a
  new lab, but so does today's dose list, which is what the son opened the
  screen to read.
  Ordered by cloud `updated_at`, each row showing the event's own date: a 2019 lab entered today is new
  to the son. Dose events are left out (their `updated_at` moves on every
  confirmation) and so are medications.
- **«الملف الصحي» is entries too** (round 28b, same split as the father's):
  the red emergency card stays at the top — it is a card read at a glance,
  not a list — and under it one entry per thing that has content, with its
  count, each opening its own `CareListScreen`. **An empty entry does not
  appear**: its absence *is* «مفيش حاجة هنا», and the screen no longer
  stacks three empty panels saying so; with nothing at all it shows one
  sentence. The opened list **listens to the same holder**, so the
  ten-second poll updates it while it is open — a list holding a snapshot
  taken at open time would go stale with nothing to say so.
  The shell guard that walks every tappable widget now allows the entry
  labels and ignores a text that is only Arabic-Indic digits: the count is
  part of the entry's name, not an action of its own.
- **«الملف الصحي» content**: the red emergency card (blood type, allergies,
  chronic conditions; «لسه ما اتملاش» for empty; no contacts, no call buttons),
  glucose readings as number + context + date only (D3.6 — the advice-word
  scan now reads `lib/features/care/` too), records grouped by kind with
  lab lines under their report, and the family's questions («اتسأل ✓»).
  Kind and context words come from the patient's own wording files, not a
  copy. No image and no empty box for attachments (D5.3).
- **What is coming, not only what happened.** A father who set his
  medicines up tonight has an empty today and a full tomorrow. When today
  has no dose events, «متابعة» says «مفيش جرعات النهارده — أول جرعة
  بكرة الساعة ٧:٠٠ الصبح» (`spokenTime`: الصبح / الضهر / بالليل) and lists
  tomorrow's doses marked «بكرة», read-only — the rows are already in the
  snapshot because the father's device materialises tomorrow. With nothing
  tomorrow either, the old «مفيش جرعات متسجّلة النهارده لسه.» stays. A week
  strip with seven empty days is one sentence instead of seven dashes:
  «لسه بدري. أول جرعة هتبان هنا أول ما تتسجّل».
- `caregiver_shell_test` walks every tappable widget on all four tabs and
  still allows only the tab labels and «تسجيل الخروج».
- **The father is told.** A line under «دائرة الرعاية» (`caregiverCanSee`)
  lists exactly what a linked son sees and what he does not (emergency
  numbers, images, any change). It is conditional («لو ربطت…») because the
  father's phone cannot know for sure that a son is linked. When the cloud
  gains a new kind of data, this line changes in the same round.

**D5.1 — the health file reaches the cloud (built; 0012 must run first)**
- `supabase/migrations/0012_health_file.sql`: `records`, `readings`,
  `lab_results`, `visit_questions`, `emergency_profile` — uuid PKs,
  `patient_uuid` (or `record_uuid` for lab lines) with cascade, server
  `updated_at` via moddatetime, RLS on, `anon`/`public` stripped. One
  SELECT policy per table through `private.can_access_patient` (lab lines
  via the new `private.patient_of_record`); INSERT/UPDATE/DELETE for the
  owner only. `records` policies read their own `patient_uuid` — the 0005
  rule. The son has no write path. It ends with a self-check that runs as
  the son (reads, cannot update), as a stranger (reads nothing), and
  exercises the purge — all rolled back.
- **Decided out loud, and pinned by `health_file_sync_guard_test`:** the
  cloud holds **no phone number** (`contacts_json` is not pushed and has no
  column) and **no local file path** (`attachment_path`; images are D5.3).
  The two old no-sync guards were removed — this round is the decision they
  were waiting for.
- **The 30-day promise holds in the cloud too.** A local purge never
  reaches the cloud (sync has no deletes), so the soft-deleted row would
  have lived there forever and «هيتمسح نهائي بعد ٣٠ يوم» would be false for
  a linked patient. `private.purge_deleted_records()` runs daily
  (`fakkarni-purge-records`, pg_cron) against `private.record_retention()`,
  a mirror of `RecordsRepository.retentionDays` held by
  `record_retention_sql_test`.
- `SyncService` pushes records → readings → lab_results → visit_questions →
  emergency_profile after the existing tables, each shaped like
  `_pushMedications`. Wire names that differ from local: the question's
  local `created_at` goes as `written_at` (the cloud `created_at` is the
  server's). A failed table leaves its rows and every later table's rows
  dirty; earlier tables were marked only after their upsert succeeded.
- **Before a build with this code reaches a linked phone, run 0012** —
  otherwise every push after dose_events fails (no table), silently, on
  every trigger; the dose rows before it are unaffected.

**D4 — entry screen + caregiver account (built)**
- **The root decides from data, never from a role column** (`AppRoot`):
  a local patient (routine saved or sex asked) → the patient app, exactly
  as before; no patient but a locally restored session → `CaregiverShell`;
  neither → `EntryScreen`. Once either a patient or a care link exists,
  the entry screen never appears again. `watchHasPatient` + the auth state
  stream drive it; nothing is written to decide it.
- **Entry screen: two doors** (mockup 02's cards; select, then «يلا نبدأ»).
  «التليفون ده ليا» → `SignInScreen` → «نتعرّف عليك» → «ظبّط يومك» →
  «يومك». «ابني أو والدي بعتلي كود» → the same screen in caregiver mode.
- **The third card is gone** («بظبّط لحد تاني»). All it ever did was flip
  the setup wording to the third person («نتعرّف على والدك أو والدتك»,
  «بيصحى», «يومها») — a choice nothing was stored from and nothing else
  depended on. `forSomeoneElse` and `Say.aboutSomeoneElse` went with it,
  so every patient now hears the second person. The cost is named: a son
  setting the phone up for his father sees «اسمك إيه؟» and types his
  father's name. It is in git if it should come back.
- **Sign-in is shown on the patient path, and it is skippable.** The
  screen is the real one — the working «حساب تجريبي», the locked
  Google/Apple rows with their own reasons — and its exit says what it
  does here: «كمّل من غير حساب» continues to the questions rather than
  going back. **The local-first guarantee is unchanged**: he reaches
  «يومك» with no account and no network, and `root_test`'s guard still
  proves no session and no sign-in call at launch, because this screen
  appears after a tap. `AppRoot._patientPath` keeps him on the patient
  path if he does sign in mid-setup — otherwise a session with no patient
  yet would read as "son" and send him to the caregiver screen. A «رجوع»
  returns to the entry screen until a patient exists.
- **«ابني أو والدي بعتلي كود»** → `SignInScreen(onCaregiverLinked:)`, which
  explains that this is the only place an account is asked for and offers
  no «اعرض كود الربط» → `RedeemCodeScreen` → «افتح المتابعة» pops `true`
  to the root → `CaregiverShell`. No patient question, no routine, no
  patient met. `signInToLink()` is still called from exactly one line.
  After linking the notification permission is requested once (without it
  the escalation push cannot show on Android 13+) — outside the redeem
  `try`, so a failed permission request never turns a successful link
  into «مقدرناش نكمّل».
- **The son is not a patient.** `CaregiverShell`: **four tabs** (round 29)
  — «متابعة», «الأدوية», «الملف الصحي», «الإعدادات»; no «يومك», «ضيف», dose
  editor, Ramadan, or «طوارئ» shortcut (the father's emergency data lives
  on the father's phone).
  «متابعة» is about **state** — alerts, the week, today's doses, «الجديد».
  **«الأدوية» is its own dock tab, not a section on it**: that list is
  *reference* («what is he on»), and at the foot of the state screen the
  two crowded each other — whoever came to check on his father scrolled
  past it, and whoever came for the medicines scrolled past everything
  else. It carries the same label and `medication_outlined` icon as the
  father's own dock tab; the rules are read from `dose_schedules` /
  `fixed_timings` in the cloud and worded by `domain/wording/rule_wording`
  (the same text the patient sees; the son's side still never resolves an
  anchor). **The section was moved, not copied** — one door per room, the
  same rule that keeps «الملف الصحي» out of Settings, and a test asserts
  the list does not appear on «متابعة».
  **It is a data tab**: `dataTabs` is `{0, 1, 2}`, so entering it fetches
  at once and the ten-second poll keeps running while it is visible. Left
  out of that set it would show a frozen list with nothing saying so, which
  is why `caregiver_poll_test` covers it like the other two.
  «الإعدادات» is the account (sign-out clears the push token first) and
  «اللغة: عربي». `caregiver_shell_test` walks every tappable widget on all
  four tabs and allows only the tab labels and «تسجيل الخروج» —
  mutation-checked with a planted button.
- **Not linked vs offline:** `snapshot()` returning null means "no linked
  patient" → back to the entry screen (a son whose code failed and who
  closed the app); a thrown `CareCircleException` is offline → the existing
  offline sentence stays on the son's home.
- **Unverified live:** the medicines embed
  (`dose_schedules(…, fixed_timings(minute_of_day))`) has never run against
  the real project; RLS should allow it through `can_access_patient`.
  Devices linked as a son **before** D4 went through onboarding, so they
  hold a routine and stay "patient" — reinstall them.

**App icon + Android launch screen (chore)**
- `flutter_launcher_icons` config lives in `pubspec.yaml`, fed by
  `assets/branding/icon-1024.png` (opaque, iOS + legacy Android) and
  `icon-foreground.png` (transparent, mark already at 45.5% for the
  adaptive safe zone — hence `adaptive_icon_foreground_inset: 0`; the
  default 16% would shrink it to ~31%). Re-run with
  `dart run flutter_launcher_icons`, **then `git checkout
  ios/Runner.xcodeproj/project.pbxproj`**: 0.14.4 rewrites
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` to
  `AppIcon` (a boolean setting); the icon name is already set on the target.
  `test/app/branding_test.dart` fails if either path stops existing.
- Android launch screen is flat `#0A4638` with no mark, like iOS since D1:
  `drawable*/launch_background.xml` for ≤ API 30, and `values-v31` /
  `values-night-v31` (`windowSplashScreenBackground` + a transparent
  `windowSplashScreenAnimatedIcon`) because Android 12+ draws its own
  splash and never reads that drawable. Home-screen name «فكرني» on both
  (`android:label`, `CFBundleDisplayName`).

**C2 — reverted 18 Sep 2026 (the key is back in the app)**
- C2 shipped and was verified end to end (`ca41dd3`, `32dc5c1`, `503979a`;
  `0013 OK`, curl checks, a real iPhone scan, and the fallback exercised
  against a real Google load spike). The owner then reverted it the same
  day. **The reason was latency, not correctness:** reads went through our
  function and the round trip made an already slow read slower.
- Reverted with `git revert` so the history keeps both directions.
  **Deliberately kept in the tree, unused:**
  `supabase/functions/ai-read/index.ts`, `supabase/migrations/0013_ai_reads.sql`
  (already applied to the live project — do not re-run it as if it were new),
  its README entry, and `test/ai/ai_read_function_test.dart`. Re-applying C2
  is reverting the revert.
- **Kept from the C2 rounds because they are client-side and had nothing to
  do with where the key lives** — losing them would have made today worse
  than before C2:
  - the request timeout (`attemptTimeout` 35 s per call, two calls at most,
    under `readTimeout` 75 s — a test pins that arithmetic). Before C2 there
    was **no timeout at all**;
  - the fallback to the fallback model on `503`/`429`/**timeout**, not just
    on a retired `404` — `_fallbackReason` now lives in the client;
  - «الخدمة زحمة دلوقتي — استنى شوية وجرّب تاني.» instead of «صوّر تاني»
    when the failure is overload or a timeout. Telling a patient to
    re-photograph a page that read fine is wrong advice;
  - `thinkingConfig.thinkingBudget = 0` (from `--dart-define=GEMINI_THINKING_BUDGET`,
    `off` to send nothing). **This one was not on the owner's keep-list** —
    it lived in the `.ts` file, so a literal revert would have dropped it and
    handed back the 15–20 s reads he had just asked to have fixed. It is a
    request field, client-expressible, and nothing to do with the key, so it
    was ported under the same rule as the other three. Say so if that call
    is wrong; it is one field to delete.
- **Lost with the revert, because they were the server:** the per-user and
  global daily caps, `ai_reads` attribution, and the rule that an AI read
  needs a session. Any read is now unmetered and unattributed, and
  `AiReadGate` is gone — the scan screens are back to «قراية الصور مش
  متظبطة في النسخة دي» when the key is missing. A loop or a bad build can
  empty the quota with nothing to stop it.

**Next**
0. AI reads take 15–20 s end to end (see C2) — find out where the time
   goes before the next demo
1. Photograph a real handwritten prescription; tune
   `maxWidth`/`imageQuality` and the prompt from what actually fails
2. Re-run the `/device` checklist for the action buttons specifically: tap
   «أخدته» on the lock screen with the app terminated, then check
   `pending()` grew (Android background isolate + iOS category actions were
   not part of the first device pass)
2. Stop / edit a medication from «يومك» (`stopMedication` exists in the
   repository, no screen calls it)
3. Re-run the `/device` checklist on iOS now that the background engine
   registers plugins — the lock-screen path (and therefore 4.2a's push
   from the isolate) has never actually executed on hardware
4. Build the APK on a machine with the Android SDK, install it, sign in,
   and confirm a `device_tokens` row appears — then invoke `escalate` by
   hand and confirm `sent` instead of `no_token`. Everything upstream of
   the token is proven on the live project; this is the only unverified
   link in the chain — and the first time the caregiver screen's
   `sent` line («السيرفر بلّغك …») renders from a real row
5. Open the caregiver screen against the live project with at least one
   `escalations` row present and confirm the card appears — that is the
   first run of the nested-embed filter in `SupabaseCaregiverRemote`
6. Round 4.3: the son's alert screen (mockup 27); Critical Alerts request

---

## Never do

- Add a dependency to `lib/domain/`
- Persist a resolved clock time for an anchor dose, make `FixedTiming` the
  default, or put a dose-time column on `dose_schedules` (`active_from` is
  the rule's start instant, not a dose time — the one allowed exception)
- Wipe or recreate the database to change the schema — write a migration and
  a case in `migration_test.dart`
- Schedule a notification straight from an unconfirmed AI result
- Call `cancelAll()` — it reaches across every band, including Phase 4's
  escalation. Cancel by ID, filtered to your own band
- Allocate or persist a notification ID; derive it from the slot instead
- Use `fullScreenIntent` or the `USE_EXACT_ALARM` permission — Google Play
  restricts both to alarm/calling apps and will reject the review.
  Use `SCHEDULE_EXACT_ALARM` requested at runtime instead.
- Read a lock-screen result from a **debug** build on iOS — from iOS 14 the
  background isolate cannot run at all once `flutter run` detaches, so the
  answer is about the build mode. Use a profile build
- Call `debugPrint` on the wake-up path — it ships in release. Use `diag`
- Write formal MSA in the UI
- Invent a medication duration, dosage or timing — this applies to the
  Gemini prompt as much as to the code
- Put a Supabase service-role key in `admin/` — the dashboard is an ordinary
  authenticated client and the wall is `private.is_admin()` in SQL. The guard
  fails on the name even inside a comment
- Hardcode an API key, put one in a tracked file, or call Gemini with an
  empty key
- Ship a notification sound over 30 seconds, or put the dose chime or the
  insistent flag on a non-dose notification — `dose_alert_test` fails both
