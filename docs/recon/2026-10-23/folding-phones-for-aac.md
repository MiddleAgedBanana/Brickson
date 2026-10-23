# Folding phones for an AAC app: a short note

> **Research snapshot, 2026-10-23**, the day iPhone Duo went on sale.
> Written in a cloud session for the Wave 3 plan (docs/ROADMAP.md) at the
> owner's request, as a low-priority question. It is research, not
> instructions: where it disagrees with `AGENTS.md`, `docs/DECISIONS.md`
> or `docs/ROADMAP.md`, those win. Nobody has used Brickson on a folding
> phone, and the owner has not held one.

**The question.** How well suited is a folding phone, such as Apple's
iPhone Duo, for an AAC app used by people living with ALS, from touch
to switches to eye tracking? The guess to test was: mostly a bigger
iPhone, for caregivers and for people early in the disease; the iPad
stays the main device.

## Answer

The guess mostly holds. On today's evidence, iPhone Duo is a large,
light, pocketable iPhone: well suited to someone who still uses touch
or a switch, and to a caregiver, but not a replacement for an iPad (or
a dedicated eye-gaze device) once a person relies on their eyes. Four
reasons, in order of weight:

1. **Eye Tracking and Head Tracking work only when it is fully open.**
   Apple: "On iPhone Duo, Eye Tracking works only when the device is
   fully open; it isn't available when iPhone Duo is partially folded."
   The same is said of Head Tracking. So the poses in which it stands
   by itself on a table or bedside cannot be used with the eyes or the
   head. While either is on, "the part of the inner display where the
   FaceTime camera sits is dark, so a control in that area can be hard
   to see" ([Eye Tracking guide][eye]; [Head Tracking guide][head]: each
   says it of its own feature).
2. **The open screen is small for gaze.** Worked out from Apple's pixel
   counts and densities ([specifications][specs]; not Apple's own
   figures): the inner display is about 11 × 16 cm, about a third of a
   13-inch iPad's screen, half an 11-inch iPad's and a little less than
   an iPad mini's. At the 45 cm Apple recommends for Eye Tracking it
   spans about 14 × 20 degrees, against about 33 × 25 for a 13-inch iPad.
   The reference app's gaze floors (docs/DECISIONS.md, "Layouts from the
   space available") would fit few tiles, and the research the roadmap
   rests on found 4 degrees the comfortable gaze target
   (`docs/recon/2026-10-15/als-aac-research.md`).
3. **External eye trackers: in Apple's guides, for iPad only.** The user
   guides document an external eye tracker for iPad only ("You can also
   use a Made for iPad (MFi) eye-tracking device to control iPad", [iPad
   guide][ipad-eye]). The iPhone guide, which covers iPhone Duo, has no
   such section, and lists pointer devices "such as trackpads, game
   controllers, and mouse devices" ([AssistiveTouch][at]). Apple's
   features page says "iPad also supports third-party eye trackers", but
   also names an "eye-tracking device" among AssistiveTouch's pointers
   for iOS and iPadOS ([Apple's accessibility features][features]), so
   whether one works with iPhone Duo is unconfirmed, not ruled out.
4. **Mounting and durability are unknown.** Phone holders used in AAC
   grip devices up to about 9.5 cm wide ([Rehadapt][rehadapt]); the open
   Duo is 11.8 × 16.5 cm, and no mount maker lists a holder for it yet.
   Apple gives no fold-life figure, and warns to keep grit away from the
   hinge and not to put a screen protector on the inner display
   ([handling][handling]).

**What it does well.** It weighs 254 g, less than an iPad mini; the
closed phone fits ordinary phone mounts; it stands by itself, partly
folded, for touch or switch use at a table or bedside; and it has every
Apple access feature Brickson relies on, including Switch Control,
Voice Control, Personal Voice and Assistive Access ([specifications][specs];
[poses][poses]).

## What AAC practice says

- **No one has said anything about folding phones.** Searches of
  AssistiveWare, Tobii Dynavox, Smartbox, PRC-Saltillo, ASHA, the ALS
  Association, the MND Association, research indexes and forums found no
  study, clinical guidance or vendor statement on folding phones for AAC.
  Everything above is reasoning from specifications and general practice.
- **Phones are companions and backups.** The MND Association lists a
  phone text-to-speech app as "useful as a backup option to a
  communication aid" ([MND Association][mnda-apps]); mount makers show a
  phone on its own small mount beside the main device
  ([Mount'n Mover][mountnmover]); AssistiveWare offers its text app on
  iPhone "for easy on-the-go use" ([Proloquo4Text][p4t]).
- **Families run the system.** In a survey of 68 people with ALS, 96% of
  those who kept the AAC system going were family members
  ([Beukelman et al. 2011][beukelman]), which supports a caregiver's
  phone as a real role.
- **Eye gaze late in the disease.** Eye tracking is often the least
  tiring method late in ALS, and for some it is the only one left
  ([Beukelman et al. 2011][beukelman]); dedicated gaze devices use 13 to
  16 inch screens at about 65 cm ([TD Pilot manual][tdpilot]).
- **Touch is not the limit.** Studies of people with tetraplegia on
  touchscreens found errors level off at targets of about 12 mm
  ([Guerreiro, Nicolau et al.][touch]), so the open Duo holds plenty of
  touch targets; it is gaze that runs out of room.

## What it means for Brickson

Nothing changes in R0 item 13: Brickson must run well on iPhone Duo
(it has Eye Tracking, so it is a supported device under docs/DECISIONS.md,
"Minimum iOS, iPhone and iPad"), and the owner's two fold choices stand.
Two small points for the layout engine (Wave 3 items 3 and 6): a gaze or
head profile meets only the fully open inner display, never a partly
folded or closed phone (Apple: each "works only when the device is fully
open"; no device check yet, see *Gaps*); and the dark camera area under
Eye Tracking or Head Tracking needs checking on a real iPhone Duo, since
Apple documents no way to run either in a simulator. Family Setup could
later say, for iPhone Duo, that Eye Tracking and Head Tracking need it
fully open on a stand.

## Gaps

- No published accuracy for Apple's Eye Tracking on any device; the
  nearest independent figure (about 3.2 to 3.6 degrees) is for ARKit gaze
  on an iPad Pro ([Taore et al. 2024][taore]), not the accessibility
  feature and not a phone.
- Apple's guides name no outer-display case: they rule out the closed
  phone only through "works only when the device is fully open", and
  nobody has checked it on a device.
- No hinge-life figure, teardown or independent durability test yet, and
  no evidence on heat or battery with the camera running all day.
- No ALS-specific evidence on phone against tablet screen size for AAC.

[eye]: https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios
[head]: https://support.apple.com/guide/iphone/iph9c3dc17cf/ios
[ipad-eye]: https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/ipados
[at]: https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios
[specs]: https://www.apple.com/iphone-duo/specs/
[features]: https://www.apple.com/accessibility/features/
[handling]: https://support.apple.com/guide/iphone/important-handling-information-iphbbe12ba1/ios
[poses]: https://support.apple.com/guide/iphone/pose-iphone-duo-iphv3p93k1bm/ios
[rehadapt]: https://rehadapt.com/product/l3d-ga-universal-phone-50-95mm/
[mnda-apps]: https://www.mndassociation.org/support-and-information/information-resources/free-or-low-cost-apps
[mountnmover]: https://www.mountnmover.com/support/wheelchair-mounting-overview
[p4t]: https://www.assistiveware.com/products/proloquo4text
[beukelman]: https://pmc.ncbi.nlm.nih.gov/articles/PMC3096454/
[tdpilot]: https://download.mytobiidynavox.com/TD%20Pilot/Documents/Users%20Manuals/TobiiDynavox_TDPilot_UsersManual_en-US_13000441.pdf
[touch]: https://web.tecnico.ulisboa.pt/hugo.nicolau/project/touchmotor.html
[taore]: https://pmc.ncbi.nlm.nih.gov/articles/PMC11223623/
