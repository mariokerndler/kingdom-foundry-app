# Kingdom Foundry

Kingdom Foundry is a Flutter app for generating 10-pile kingdoms for Dominion-style play. You can choose the expansions you own, apply setup constraints, ban specific cards, import shared kingdoms, and review strategy hints for the final board.

## Implemented Features

- Named collection profiles with separate setup selections, edition and update-pack filters, and individual promo ownership.
- Rule filters for attacks, cursers, durations, potion-cost cards, debt-cost cards, and travellers.
- Requirement rules for `+Buy`, trashing, village, draw, attack/reaction pairing, attack caps, max cost, and minimum expansion variety.
- Landscape support for Events, Projects, Landmarks, Ways, Allies, Traits, and Prophecies.
- Split-pile handling so linked piles are selected together but count as one kingdom slot.
- Setup notes for special cases such as Liaison/Ally, Omen/Prophecy, Loot, Travellers, and other expansion-specific extras.
- Automatic Black Market decks target 15 unused permitted piles, with one physical card from each. Their dependencies resolve alongside other setup choices and persist in the library, backups, full codes and browser URLs. Small collections use fewer cards and show a reminder.
- Explicit Platinum/Colony and Shelter choices in Table setup, with live checklist previews and persistence through rerolls, the library, backups and full setup codes. Compact codes and ordinary share links still contain card selections only.
- Heuristic archetype analysis for generated or imported kingdoms.
- A searchable catalogue with localized card text, filters, and split-pile bans.
- Compact or detailed boards, expansion sorting, pile locks, and reroll undo.
- A first-game menu with publisher-recommended kingdoms and a Beginner Friendly roll, plus an optional preference for less repetition between boards.
- Text lists with landscapes, compact share codes, web share links, and full setup codes with saved rules and player count.
- Local history for the last 10 boards and a saved kingdom library with names, notes, search, and JSON backup and restore.
- Persistent preferences and optional card translation packs.
- Flutter targets for Web, Android, iOS, and Windows.

## Card Coverage

The [catalogue](assets/data/cards.json) includes selectable piles, landscapes, and auxiliary cards. A split pile counts once under Kingdom piles.

The bundled German translation pack covers all 829 records with German names and paraphrased rules, including retired first-edition cards and auxiliary piles. Interface language remains separate from card language.

First-edition profiles include the cards shared with the catalogued second edition. Retired cards that are absent from the catalogue are unavailable. Update-pack profiles can select just the replacement cards, or combine them with the shared cards from a first-edition box.

<!-- catalogue:start -->
829 records across 17 expansion and edition groups.

| Expansion | Kingdom piles | First-edition-only piles | Landscapes | Auxiliary records | Total records |
| --- | ---: | ---: | ---: | ---: | ---: |
| Adventures | 30 | 0 | 20 | 8 | 58 |
| Alchemy | 12 | 0 | 0 | 0 | 12 |
| Allies | 31 | 0 | 23 | 0 | 72 |
| Base (2nd Ed.) | 26 | 6 | 0 | 0 | 32 |
| Cornucopia & Guilds (2nd Ed.) | 26 | 8 | 0 | 11 | 45 |
| Dark Ages | 35 | 0 | 0 | 22 | 57 |
| Empires | 24 | 0 | 34 | 8 | 71 |
| Hinterlands (2nd Ed.) | 26 | 9 | 0 | 0 | 35 |
| Intrigue (2nd Ed.) | 26 | 6 | 0 | 0 | 32 |
| Menagerie | 30 | 0 | 40 | 1 | 71 |
| Nocturne | 33 | 0 | 0 | 44 | 77 |
| Plunder | 40 | 0 | 30 | 15 | 85 |
| Promos | 11 | 0 | 1 | 0 | 13 |
| Prosperity (2nd Ed.) | 25 | 9 | 0 | 0 | 34 |
| Renaissance | 25 | 0 | 20 | 5 | 50 |
| Rising Sun | 25 | 0 | 25 | 0 | 50 |
| Seaside (2nd Ed.) | 27 | 8 | 0 | 0 | 35 |
<!-- catalogue:end -->

Run `dart run tool/catalogue_summary.dart` after editing the catalogue to regenerate this table.

## Quality Checks

The [verification workflow](.github/workflows/verify.yml) runs the analyzer, tests, catalogue summary check, and release web build on pushes and pull requests. Tests cover combined generation rules against the actual catalogue, import validation, old share codes, and storage recovery.

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
dart run tool/catalogue_summary.dart --check
flutter build web --release
dart run tool/prepare_web_release.dart
```

## Deploying to Hostinger

The verification workflow publishes the prepared `build/web/` contents using SFTP after all checks pass. Deployment runs only for pushes to `main` or manual runs on `main`, and remains disabled until configured. Pull requests never deploy. Uploads run one at a time.

Enable SSH access in Hostinger and use the host, username and port shown there. Hostinger normally uses port **65002** for SFTP. See the [Hostinger SFTP guide](https://www.hostinger.com/support/5972689-how-to-connect-to-your-hosting-using-sftp-in-hostinger/).

Run the key setup commands in Bash (Git Bash on Windows), from a private folder outside this repository. Create a dedicated deployment SSH key using `ssh-keygen -t ed25519 -C "github-hostinger-deploy" -f hostinger_deploy`. Leave its passphrase empty for unattended deployment. Add only `hostinger_deploy.pub` to Hostinger's SSH keys. See [Hostinger's SSH key instructions](https://www.hostinger.com/support/5634532-how-to-generate-ssh-keys-and-add-them-to-hostinger-dashboard/).

Save the server's public host key with `ssh-keyscan -p 65002 -t ed25519 YOUR_SFTP_HOST > hostinger_known_hosts`. Run `ssh-keygen -lf hostinger_known_hosts` and compare the SHA256 fingerprint with the ED25519 fingerprint in Hostinger's SSH Access page. Only use this file after the fingerprints match. The workflow requires this trusted key and refuses unknown or changed servers.

If Windows reports `choose_kex: unsupported KEX method sntrup761x25519-sha512@openssh.com`, use Git Bash's `/usr/bin/ssh-keyscan` explicitly in that command. Some Windows OpenSSH versions advertise this exchange method without implementing it in `ssh-keyscan`. In PowerShell, use `& 'C:\Program Files\Git\usr\bin\ssh-keyscan.exe' -p 65002 -t ed25519 YOUR_SFTP_HOST | Set-Content -Encoding ascii hostinger_known_hosts`, then verify the fingerprint as above. This changes only the local key collection tool; server verification stays enabled.

In the GitHub repository, open **Settings → Secrets and variables → Actions** and add these repository secrets:

| Secret | Value |
| --- | --- |
| `HOSTINGER_SFTP_HOST` | SFTP host or IPv4 address from SSH Access, without a protocol prefix |
| `HOSTINGER_SFTP_USERNAME` | SSH/SFTP username from SSH Access |
| `HOSTINGER_SSH_PRIVATE_KEY` | Complete contents of the private `hostinger_deploy` file, including its header and footer |
| `HOSTINGER_SSH_KNOWN_HOSTS` | Complete contents of the verified `hostinger_known_hosts` file, not just its fingerprint |

Then add these repository variables:

| Variable | Value |
| --- | --- |
| `HOSTINGER_SERVER_DIR` | Existing SFTP path to the website, ending in `/`, e.g. `domains/example.com/public_html/` relative to the login directory; use `./` only if the account opens directly inside `public_html` |
| `HOSTINGER_SFTP_PORT` | Optional; defaults to `65002` |
| `HOSTINGER_DEPLOY_ENABLED` | `true` to enable publishing |

Confirm the destination using an SFTP client before enabling deployment. Paths support letters, digits, `_`, `-`, `.`, and `/`. This configuration serves the app at the domain root. For a URL subfolder, change the Flutter build command to use the matching `--base-href /subfolder/` and set the SFTP destination to that folder. The workflow uses SSH key authentication; it does not need the old FTP secrets or the `HOSTINGER_FTP_PROTOCOL` variable.

Once this workflow is pushed and configured, use **Actions → Verify Kingdom Foundry → Run workflow** on `main` for the first deployment. Later pushes to `main` publish automatically. Set `HOSTINGER_DEPLOY_ENABLED` to `false` to stop publishing while keeping checks enabled. Local deployment checks run with `python3 -m unittest discover -s tool -p 'test_*.py'` (Python and Bash required).

Back up the current website first: matching files in the destination will be replaced. The upload copies all visible release files and directories, retaining old assets and unrelated files on the server. It does not delete remote files. Updates are not atomic, so visitors may briefly encounter a partially uploaded release; rerun the workflow if an upload fails. Live Hostinger connectivity and the hosted workflow require verification after configuration.

## Getting Started

The web release preparation step packages the app and catalogue for offline reopening after an online visit. Deploy all of `build/web` together. A newly cached release takes over after all tabs running the previous release close. On a kingdom board, **Kingdom actions → Print table setup** opens a print-friendly view with the Supply, landscapes, and resolved setup choices.

Local headless Chrome and Edge verification on 17 November 2026 covered online startup, offline reload and generation, cache updates after closing an old tab, and the results menu's print view. Root and subdirectory deployments passed with their corresponding base URLs. A blocked bootstrap script displayed Retry and recovered once loading was restored. The A4 print layout was visually checked. Production hosting, other browser engines and physical printing still need verification.

The latest release checks also covered full shared setups with Druid's Boons, Obelisk's Ruins choice and player-specific Landmark tokens. Those choices survived offline reload. Reopening a library entry with stale generated instructions refreshed its checklist and retained its setup choices and personal note.

The 20 November 2026 audit passed 262 tests and release checks in Chrome, Edge, Firefox and Playwright WebKit, including accessible names, keyboard lock controls, offline refresh and Inherited starting-deck print instructions. Local startup/reroll measurements and evidence for all 27 improvement items are recorded in [the implementation audit](IMPROVEMENTS.md). External screen-reader speech, physical devices, native builds, production hosting and the hosted CI run remain unverified.

In **Table setup**, choose whether to use Platinum/Colony and Shelters, preview the resulting quantities and starting decks, then Apply. Existing history and saved-library entries retain these choices without changing their names or notes. Boards with resolved setup choices use full browser URLs so refresh can preserve them; use **Copy full setup** when exporting these decisions explicitly.

### Prerequisites

- Tested with Flutter 3.41.6, which bundles Dart 3.11.4.

### Run locally

```bash
flutter pub get
flutter run
```

To run in Chrome:

```bash
flutter run -d chrome
```

## Project Structure

```text
lib/
├── controllers/   # Kingdom generation, heuristics, typed failures
├── models/        # Card, rules, setup result, enums
├── providers/     # Riverpod state and async loading
├── screens/       # Main configuration and results screens
├── services/      # Card loading, persistence, history
├── utils/         # Theme and archetype helpers
└── widgets/       # Reusable UI for cards, tabs, sheets, and sections
assets/data/
└── cards.json     # Card database
test/
└── ...            # Engine, parser, and widget tests
```

## Notes

- Public app name: `Kingdom Foundry`
- Flutter package name: `kingdom_foundry`
- Main card model: `KingdomCard`

This is an unofficial companion project and is not affiliated with or endorsed by the publisher of Dominion.
