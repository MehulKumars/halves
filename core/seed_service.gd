class_name SeedService
extends RefCounted
## Stable seeds for procedural content.
##
## Seeds come from SHA-256 of the parts, not String.hash(), so a seed for
## ("halves", chapter, level) never changes. Godot's RandomNumberGenerator algorithm is
## an implementation detail that may change between engine versions, so still generate
## levels offline and bake them to data files with a gen_version; only disposable content
## (endless runs, shuffles) should be generated at runtime.


static func make_seed(parts: Array, gen_version: int) -> int:
	var strings := PackedStringArray()
	for part: Variant in parts:
		strings.append(str(part))
	strings.append("v%d" % gen_version)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("|".join(strings).to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	return digest.decode_s64(0)


static func make_rng(parts: Array, gen_version: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = make_seed(parts, gen_version)
	return rng
