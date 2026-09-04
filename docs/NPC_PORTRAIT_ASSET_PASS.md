# NPC Portrait Asset Pass — Visual Cohesion Correction

## Status

The first portrait-generation attempt was stopped on 2026-09-04 after review
against the attached Yalonda benchmark. The generated portraits used a
photorealistic studio-photo treatment and therefore failed the 907Hustle
visual-cohesion standard. They must not be promoted to production or used as
style references.

Affected generated portraits:

- Mina Vale
- Dre Smooth
- Biniam Tesfaye
- Selam Tesfaye
- Reggie
- Lani
- Marcus
- Sonny
- Denise (generation was in progress when the pass was stopped)

The affected files were never committed or wired into the Godot project. Any
future agent should treat the generated previews from this attempt as rejected
work and regenerate the affected characters rather than copying them into
`assets/img/`.

## Authoritative visual benchmark

The attached Yalonda portrait is the source of truth for the NPC portrait
language. It is a small, square portrait-card treatment rather than a
photographic headshot:

- heavily stylized digital painting with visible ink/brush contouring;
- grounded semi-realistic facial likeness, not photorealism and not cartoon or
  anime; recognizable anatomy with deliberate painterly simplification;
- very dark charcoal/black background and clothing, with deep crushed
  shadows;
- restrained warm brown, ochre, and muted skin tones against near-black;
- thin, controlled red edge/rim accent on the camera-right silhouette and
  background;
- low-key, high-contrast lighting with the face emerging from shadow;
- natural skin and hair texture expressed through painted strokes, not glossy
  beauty retouching;
- composed, observant expression and practical working-class wardrobe;
- head-and-shoulders framing, centered portrait card, generous dark margin,
  square crop suitable for small UI thumbnails;
- quiet, serious, lived-in Anchorage mood; no glamour, spectacle, or generic
  stock-photo smile.

For every new portrait, compare the result directly with Yalonda and ask:
“Would these read as assets from the same game if shown beside each other?”
If not, reject and regenerate before doing technical export or checklist work.

## Corrected workflow requirements

1. Read the character's ClickUp bio and the relevant repository story/dialogue
   canon before every generation.
2. If no character profile exists, write a concise profile in the project's
   character-reference documentation first. Ground inferred details in role,
   dialogue, relationships, location, and gameplay function; do not invent
   facts that contradict canon.
3. Use Yalonda's stylized portrait-card treatment as the shared prompt spine.
   Preserve each character's established identity, age, background, wardrobe,
   occupation, and emotional posture while keeping rendering, palette,
   contrast, texture, and framing cohesive.
4. Validate at full size and approximately 96px, 64px, and 48px before marking
   a checklist item complete.
5. Keep all rejected previews out of production. Do not mark ClickUp complete
   until the corrected asset is committed and validated.

## Rejection reason

The stopped batch was technically clean in several respects (square framing,
readable faces, dark background, and no visible watermark), but those checks do
not override the visual mismatch. The rendering level, facial treatment,
contrast rolloff, and overall asset language were photographic and materially
different from Yalonda's painterly portrait-card benchmark. Visual cohesion is
therefore the blocking issue for all affected characters.
