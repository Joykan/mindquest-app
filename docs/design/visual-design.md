# Visual design

The wireframes (step 1) set the layout of each screen in greyscale. This page
sets the look: colours, type and the main components. The app's theme
(`lib/core/theme/`) uses exactly these values.

## Where it comes from

The look builds on the earlier MindQuest prototype, which users already
associated with calm greens, the brain logo and a Kenyan touch. These were
kept. The prototype's problems were fixed:

| Prototype | Now |
|---|---|
| Dark green and white screens mixed, plus a purple header | One light theme, with a dark theme as a setting |
| XP shown on screens (+20, +30, +200) didn't match the real rules | Screens show the values the database awards (mood +10, chat +2, article +5, weekly quest +25) |
| Light text on muted tiles, hard to read | All text meets WCAG AA contrast (4.5:1, or 3:1 for large text) |
| The phone's own font, so it looked different on every phone | Nunito bundled in the app |
| Empty icon boxes, invisible helpline heading | Fixed in the new screens |

## Colours

| Token | Light | Dark | Used for |
|---|---|---|---|
| primary | `#2F7A5D` | `#6FCFB0` | Main buttons, active tab, user chat bubble |
| on-primary | `#FFFFFF` | `#10201A` | Text on primary |
| brand-forest | `#1C2B25` | `#0C1411` | Welcome background, headers |
| accent-mint | `#6FCFB0` | `#6FCFB0` | Progress bars, highlights |
| reward-amber | `#F5B544` | `#F5B544` | XP, streaks, today's mission |
| on-reward | `#3A2A00` | `#3A2A00` | Text on amber |
| crisis | `#D93F44` | `#FF7A7E` | Crisis support and Call buttons only |
| crisis-surface | `#FDECEC` | `#3A1F21` | Crisis card background |
| background | `#F6F8F7` | `#121B17` | Screen background |
| surface | `#FFFFFF` | `#1C2B25` | Cards, sheets, input box |
| surface-soft | `#E8F1ED` | `#24362F` | Bot chat bubble, info pills |
| text | `#16231E` | `#EAF2EE` | Main text |
| text-muted | `#5B6B64` | `#9DB1A8` | Secondary text |
| border | `#DCE5E1` | `#2E4139` | Card and input borders |

Primary was darkened from the prototype's `#4A9172` so white text on it reaches
5.2:1 contrast (the prototype's green gave 3.9:1, below the 4.5:1 guideline).
Red is kept for crisis support only, so it always means "urgent help".

## Logo and app icon

The brain on a green gradient tile (primary to mint), the same as the old
prototype's logo. It is used as the phone's app icon, the web icon and inside
the app (Welcome, Home, Chat). The brain is a bundled image
(`assets/images/brain.png`) rather than an emoji, so it looks the same on every
phone. Brain graphic: [Twemoji](https://github.com/jdecked/twemoji), licensed
CC-BY 4.0. Full-size icon: `docs/design/app-icon.png`.

## Type

Font: **Nunito** (rounded, friendly, easy to read; free under the SIL Open
Font License, files in `assets/fonts/`).

| Style | Weight | Size / line height | Used for |
|---|---|---|---|
| Display | ExtraBold 800 | 28 / 34 | Welcome title |
| Title | Bold 700 | 22 / 28 | Screen titles |
| Heading | Bold 700 | 17 / 22 | Card titles, helpline names |
| Body | Regular 400 | 15 / 21 | Chat messages, paragraphs |
| Body strong | SemiBold 600 | 15 / 21 | Emphasis |
| Small | Regular 400 | 13 / 18 | Details, timestamps |
| Label | Bold 700 | 15 / 20 | Buttons |
| Caption | SemiBold 600 | 12 / 16 | Pills, tab labels |

## Shapes and spacing

- Buttons: 52 px tall, 16 px corner radius.
- Cards: white surface, 1 px border, 16 px radius, no shadow.
- Chat bubbles: 18 px radius with a 4 px corner on the sender's side.
- Text input: pill shaped (24 px radius).
- Bottom sheets: 24 px top corners.
- Screen padding 16 px; space between cards 12 px.

## Light and dark mode

The app follows the phone's setting by default. Users can choose Light, Dark or
"Same as phone" (for now from the chat screen's menu, later in Profile). The
choice is saved on the phone.

## Figma (high-fidelity screens)

The hi-fi screens are designed by hand in the same Figma file as the
wireframes, in a section called "Hi-fi" to the right of them, so each screen
can be compared with its wireframe.

1. Foundations: the 8 text styles above (Nunito) and the colours above. The
   Starter plan allows one mode per variable collection, so either use two
   collections (light and dark) or colour styles named `Light/primary`,
   `Dark/primary` and so on.
2. Components: primary and secondary button, card, chip, bot and user chat
   bubbles, bottom navigation bar.
3. Screens: duplicate each wireframe into the Hi-fi section and restyle it.
   For screens already built in the app (Welcome, Sign in, Onboarding, Chat,
   Crisis support), phone screenshots are the reference so design and app
   match. New screens follow the wireframe layout.
4. Export each finished frame as PNG so it can be compared with the app.
