---
name: play-release
description: Take a game built from this Godot 4.7 template from "works on my phone" to Google Play: new-game setup (package name, version code, release keystore), signed AAB export, Play Console tracks (internal, the 12-tester 14-day closed test, production), store listing assets, Data safety, ads and audience declarations, and a pre-release checklist. Use this whenever the user wants to publish, upload, release, sign, make an AAB, set up a keystore, prepare a store page or screenshots, start a closed test, or asks what Google Play requires, even if they only say "ship it".
---

# Releasing to Google Play (as of October 2026)

Facts below were checked in October 2026; Google changes rules often, so re-check the Play Console
Help pages named here before each first release of a game. Not legal or tax advice.

## 1. New game from the template (once per game)
1. `gh repo create <game> --template MehulKumars/godot-mobile-template --private --clone`
2. In `export_presets.cfg` and `project.godot`: set `package/unique_name` (for example
   `com.<studio>.<game>`; never ship `com.changeme.template`), `package/name`, `config/name`.
   The package name can never change after the first upload.
3. Create the release keystore (command from Godot's docs; use only letters and numbers in the
   password, special characters may cause errors):
   ```
   keytool -v -genkey -keystore <game>.keystore -alias <game> -keyalg RSA -validity 10000
   ```
   Store the file and both passwords in 1Password. Keep it out of the repo (`*.keystore` is ignored).
   With Play App Signing (standard for AAB uploads) Google holds the app signing key and this file
   is your **upload key**: if it is lost or leaked you can request an upload-key reset in Play
   Console, but that takes time and blocks updates meanwhile, so back it up.
4. In the Godot editor: Project > Export > "Android Release AAB" > Keystore: Release (path),
   Release User (alias), Release Password. Godot stores these in `.godot/export_credentials.cfg`,
   which is not committed. For CI use the environment variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
   `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

## 2. Build
- Increase `version/code` in `export_presets.cfg` for every upload (Play rejects repeats); bump
  `version/name` for players.
- Release AAB:
  `godot --headless --path . --install-android-build-template --export-release "Android Release AAB" build/game-release.aab`
- Technical gates the template already meets: AAB format, target API 36 (Godot 4.7.2 default,
  required since 31 Aug 2026), 16 KB memory pages (Godot 4.5+; updates without it are blocked from
  1 Feb 2027), 64-bit arm64 included. If the game sells anything: Play Billing Library 8+ (Godot
  billing plugin 3.3.0 or later).

## 3. Pre-release checklist (report each line as done / missing)
- [ ] `tools/check.ps1` passes.
- [ ] Interstitials go through `AdPolicy` and appear only when a results screen opens; none in the
      first session; rewarded ads are opt-in and labelled.
- [ ] Ad unit IDs: test IDs during development, real IDs only in the release build.
- [ ] Real ad, purchase and analytics services are wired in `services.gd`. The mocks show nothing in
      release builds (no ads, no rewards); a release still on mocks earns nothing.
- [ ] Release build has no dev console (LimboConsole `disable_in_release_build=true`; DevTools frees
      itself) and excludes `tests/` and `addons/gut/` (release preset exclude filter).
- [ ] Your own launcher icons in `assets/template_icon/` (the template ships a placeholder play
      mark; both presets already point at these files): main 192 x 192, adaptive foreground and
      background 432 x 432, monochrome 432 x 432, splash 512 x 512, with important artwork inside the
      centred 66 dp circle (264 px) so launchers do not clip it.
- [ ] The splash shows your game name (and studio logo if any); `ATTRIBUTION.md` names your team
      (the template says "Your Studio") and keeps the Godot, Maaack, font and icon entries; the
      credits screen adds the licence texts itself; `ASSETS_LICENSES.md` complete; no AI-generated assets; no CC-BY-NC or GPL assets.
- [ ] Release AAB installed and played on one Mali and one Adreno phone (via the internal testing
      track): no crash, no freeze, 48 dp touch targets, readable text, Back button opens pause.
- [ ] Android 12+ shows `splash_screen/icon` before the game starts: it must be your icon (the
      template once shipped Maaack's logo there by accident).
- [ ] Licence files still ship (`include_filter`: `LICENSE.txt`, `core/ui/fonts/OFL_*.txt`, the icon
      licence) and the credits screen shows them, after any change to the export filters.
- [ ] Analytics logs the first-time funnel (`tutorial_step_1`, `first_win`, `level_3_start`) and seeds.
- [ ] Keep/kill lines for this game are written down.

## 4. Play Console steps
1. **Account**: personal developer account, US$25 one-time, ID and credit card in your legal name.
   Your legal name, country and developer email are public; Google shows your full address "if you
   decide to monetize on Google Play" (whether ads-only counts is unconfirmed: check before launch).
   Use a dedicated developer email.
2. **Create the app**, then **Internal testing**: upload the first AAB by hand (later uploads can
   be automated).
3. **Store forms**: privacy policy URL (GitHub Pages works), ads declaration ("contains ads"), Data
   safety form (required even if you collect nothing yourself; include what AdMob and analytics
   SDKs collect), content rating questionnaire, target audience **13+** with adult-looking art so
   the Families policy does not apply, category, contact email.
4. **Closed test**: personal accounts created after 13 Nov 2023 need **at least 12 testers opted
   in for 14 consecutive days** before applying for production (internal-testing testers do not
   count; it must be the closed track); review usually takes up to about 7
   days. Whether every later app repeats this is not stated by Google, so plan about 3 weeks per
   new game and start the next game's test while the current one is in review. Keep a standing
   group of 15-20 testers.
5. **Production**: apply, then roll out.

## 5. Store listing assets
- 512 x 512 icon, 1024 x 500 feature graphic, at least 3 portrait screenshots (at least 1080 x 1920).
  Keep screenshots within a 2:1 aspect ratio: a raw 1080 x 2400 phone capture is too tall, so crop
  or pad it to 9:16.
- A preview video is "highly recommended for games": real footage only (record with scrcpy
  `--record` or Godot `--write-movie`), showing the twist in the first 3 seconds. Unrepresentative
  ads and store art have been banned by the UK ASA (Playrix).
- Store listing experiments test icons and screenshots for free; localise the listing (DE, JP, FR,
  KR, BR) before translating the game.

## 6. After launch
- Judge a game only after 500+ installs from strangers; under ~300 organic installs in two weeks
  means fix the store page first.
- Check Android vitals weekly: crash rate under 1.09%, ANR rate under 0.47%, under 8% on any phone model.
- Payouts: AdMob pays once earnings pass US$100. In-app purchases need BillDesk KYC for India-based
  merchants. Ask a chartered accountant about income tax and GST before the first filing.
