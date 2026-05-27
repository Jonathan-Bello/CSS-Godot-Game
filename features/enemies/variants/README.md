# Enemy Variants

These scenes instance the base enemy scenes and override exported variant fields.

- `variant_css_properties`: CSS properties that make hits critical for this variant.
- `variant_visual_tint`: visual color multiplier.
- `variant_visual_scale`: visual-only size change.
- `variant_outline_enabled`: duplicates each polygon as a slightly larger outline.
- `variant_z_index`: render ordering, useful for background enemies.
- `variant_contact_enabled`: disables player damage when false.
- `variant_world_collision_enabled`: disables physical collision when false.
- `variant_health_multiplier` and `variant_contact_damage_multiplier`: quick tuning without new scripts.

Use the base scenes for normal enemies:

- `res://features/enemies/css_flying_enemy.tscn`
- `res://features/enemies/css_ground_charger_enemy.tscn`

Use the variant scenes as examples or duplicate them for new colors/behaviors.
