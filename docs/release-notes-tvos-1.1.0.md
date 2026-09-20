# Cabinet for tvOS 1.1.0

The first release from this fork, and the first tvOS release since
1.0.1. Apple TV only; the iPhone and Mac builds still come from the
upstream releases linked in the README.

**A real loading screen for large games.** A game over a hundred
megabytes that is not already on the Apple TV now gets the whole
screen while it downloads: the cover in the centre, a real bar, and
"340 MB of 1.2 GB" under it instead of a percentage in the Play
button's label. Press Back to stop the download and return to the
launch screen. Cartridges keep the quick inline behaviour, since that
wait is under a second on a home network.

**Dark, always.** Cabinet TV draws one ambient backdrop, the cover of
whatever you played last, blurred and darkened, and that canvas is
dark by construction. Setting tvOS to Light used to put dark chrome
on it and make the text hard to read. The app now stays dark whatever
the system appearance says, the same position the Mac build and
Apple's own TV app already take.

**Firmware comes down once.** A platform's BIOS used to be downloaded
again for every game on that platform. It now lands on one shelf per
platform on the Apple TV and is fetched once, which across an arcade
library saves a few hundred megabytes of repeat downloads.

**Signed for this fork.** The build carries its own bundle identifiers
and app group, so it installs and its Top Shelf works without the
upstream team's certificates.

## What you need

A RomM server with your games on it, and an Apple TV running tvOS 18
or later. The IPA is unsigned; install it with Xcode from a Mac, or
through a signing service, as described in the README's "Get it"
section.
