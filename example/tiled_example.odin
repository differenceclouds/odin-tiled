package tiled_example
import "core:fmt"
import rl "vendor:raylib"
import "core:mem"
import tiled "../"


//Tiled maps are in JSON format(.tmj), have "Tile Layer Format" CSV, and "Compression Level" -1.
//Tilesets are embedded in the .tmj, otherwise tiled.parse_tileset() must be used.

tiled_map_files := []string {
	"levels/jb-32.tmj",
	"levels/level25.tmj",
	"levels/MagicLand.tmj",
	"levels/gameart2d-desert.tmj"
}

//Note: This function doesn't account for multiple tilemaps / tilemap textures, and is just arranged this way for the convenience of this demo.
load_map :: proc(path: string, alloc: mem.Allocator) -> (tiled_map: tiled.Map, tileset: tiled.Tileset, texture: rl.Texture) {
	free_all(alloc)
	tiled_map = tiled.parse_tilemap(path, alloc)
	tileset = tiled_map.tilesets[0]

	tileset_texture_path := fmt.ctprintf("levels/%v",tileset.image)
	texture = rl.LoadTexture(tileset_texture_path)
	if !rl.IsTextureValid(texture) {
		panic(fmt.tprintf("Can't load texture from path '%v'", tileset_texture_path))
	}
	return
}

main :: proc() {
	level_allocator := context.temp_allocator
	defer free_all(level_allocator)
		//Probably want to set this to something like a vmem.Arena
		//This arena is flushed when a different map is loaded.
		//This can be used for all other allocations that exist for the duration that one level is loaded.

	rl.ChangeDirectory(rl.GetApplicationDirectory())
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(640, 480, "Tiles, it's what's for dinner")

	map_idx := 0

	tiled_map, tileset, tileset_texture := load_map(tiled_map_files[map_idx], level_allocator)

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
			tiled_map, tileset, tileset_texture = load_map(tiled_map_files[map_idx], level_allocator)
			camera.target = 0
		}

		rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.BeginMode2D(camera)

			for layer in tiled_map.layers {
				if layer.type != "tilelayer" do continue //implement image layers and other static renderables here
				for gid, i in layer.data {
					world_x := f32((i32(i) % tiled_map.width) * tileset.tile_width)
					world_y := f32((i32(i) / tiled_map.width) * tileset.tile_height)
					tileset_idx := gid - tileset.first_gid
					tileset_x := f32((tileset_idx % tileset.columns) * (tileset.tile_width + tileset.spacing))
					tileset_y := f32((tileset_idx / tileset.columns) * (tileset.tile_height + tileset.spacing))
					source: rl.Rectangle = {tileset_x, tileset_y, f32(tileset.tile_width), f32(tileset.tile_height)}

					rl.DrawTextureRec(tileset_texture, source, {world_x, world_y}, rl.WHITE)
				}
			}

			rl.EndMode2D()

			text: cstring : "pan: arrows, zoom: -/+, change map: space"
			rl.DrawText(text, 4, 2, 20, rl.BLACK)
			rl.DrawText(text, 6, 4, 20, rl.WHITE)

		rl.EndDrawing()
	}
}