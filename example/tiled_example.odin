package tiled_example
import "core:fmt"
import rl "vendor:raylib"
import "core:mem"
import tiled "../tiled"
import filepath "core:path/filepath"

// Tiled maps are in JSON format(.tmj), have "Tile Layer Format" CSV, and "Compression Level" -1.
// If tilesets are embedded in your map, parse_tilemap() may be used, otherwise, parse_tilemap_and_tilesets() is provided.

tiled_map_files := []string {
	"levels/jb-32.tmj",
	"levels/level25.tmj",
	"levels/MagicLand.tmj",
	"levels/gameart2d-desert.tmj"
}

// this function loads a tiled map and makes a slice of textures that correspond to the tilesets.
// other potential textures such as tiled image layers are not accounted for. 
load_map :: proc(path: string, alloc: mem.Allocator) -> (tiled_map: tiled.Map, tileset_textures: []rl.Texture) {
	tiled_map = tiled.parse_tilemap_and_tilesets(path, alloc)

	tileset_textures = make_slice([]rl.Texture, len(tiled_map.tilesets), alloc)
	dir := filepath.dir(path, alloc)

	for &tex, i in tileset_textures {
		ts := tiled_map.tilesets[i]
		if ts.image == "" do continue
		tileset_texture_path := filepath.join({dir, ts.image}, alloc)
		tex = rl.LoadTexture(fmt.ctprint(tileset_texture_path))
		if !rl.IsTextureValid(tex) {
			panic(fmt.tprintf("Can't load texture from path '%v'", tileset_texture_path))
		}
	}
	return
}

unload_map :: proc(alloc: mem.Allocator, textures: []rl.Texture2D) {
	for tex in textures {
		rl.UnloadTexture(tex)
	}

	free_all(alloc)
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	level_allocator := context.temp_allocator
		// Probably want to set this to something like a vmem.Arena
		// This arena is flushed when a different map is loaded.
		// This can be used for all other allocations that exist for the duration that one level is loaded.

	rl.ChangeDirectory(rl.GetApplicationDirectory())
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(640, 480, "Tiles, it's what's for dinner")

	map_idx := 0

	tiled_map, tileset_textures := load_map(tiled_map_files[map_idx], level_allocator)
	defer unload_map(level_allocator, tileset_textures)

	camera := rl.Camera2D { zoom = 1 }

	for !rl.WindowShouldClose() {

		camera_speed := 200 * rl.GetFrameTime()
		if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) {
			camera_speed *= 3
		}
		if rl.IsKeyDown(.UP) {
			camera.target.y -= camera_speed
		}
		if rl.IsKeyDown(.DOWN) {
			camera.target.y += camera_speed
		}
		if rl.IsKeyDown(.LEFT) {
			camera.target.x -= camera_speed
		}
		if rl.IsKeyDown(.RIGHT) {
			camera.target.x += camera_speed
		}
		if rl.IsKeyPressed(.EQUAL) {
			camera.zoom += 0.5
		}
		if rl.IsKeyPressed(.MINUS) {
			camera.zoom = max(camera.zoom - 0.5, 0.5)
		}
		if rl.IsKeyPressed(.SPACE) {
			map_idx = (map_idx + 1) %% len(tiled_map_files)

			unload_map(level_allocator, tileset_textures)
			tiled_map, tileset_textures = load_map(tiled_map_files[map_idx], level_allocator)

			camera.target = 0
		}

		rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.BeginMode2D(camera)

			for layer in tiled_map.layers {
				if layer.type != .tilelayer do continue //implement image layers and other static renderables here
				for gid, i in layer.data {
					if gid == 0 do continue

					gid, flags := tiled.strip_flags(gid)
						// if not using flipped tiles, this function may be skipped.
						// alternatively, a seperate slice of flags may be created on map load

					tileset, tileset_idx := tiled.get_tileset_from_gid(tiled_map.tilesets, gid) 
						// if only using one tileset and texture, this function may be skipped and set once per load

					tile_id := gid - tileset.first_gid
					world_x := f32((i32(i) % tiled_map.width) * tileset.tile_width)
					world_y := f32((i32(i) / tiled_map.width) * tileset.tile_height)
					tileset_x := f32((tile_id % tileset.columns) * (tileset.tile_width + tileset.spacing))
					tileset_y := f32((tile_id / tileset.columns) * (tileset.tile_height + tileset.spacing))
					source: rl.Rectangle = {tileset_x, tileset_y, f32(tileset.tile_width), f32(tileset.tile_height)}

					if .flip_horizontal in flags do source.width *= -1
					if .flip_vertical   in flags do source.height *= -1
						// tile rotations use a combination of .flip_diagonal and .flip_horizontal and/or .flip_vertical
						// if needed, implement here and use DrawTexturePro instead of DrawTextureRec

					rl.DrawTextureRec(tileset_textures[tileset_idx], source, {world_x, world_y}, rl.WHITE)
				}
			}

			rl.EndMode2D()

			text: cstring : "pan: arrows, zoom: -/+, change map: space"
			rl.DrawText(text, 4, 2, 20, rl.BLACK)
			rl.DrawText(text, 6, 4, 20, rl.WHITE)

		rl.EndDrawing()
	}
}