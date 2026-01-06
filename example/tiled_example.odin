package tiled_example
import "core:fmt"
import rl "vendor:raylib"
import tiled "../../tiled"

main :: proc() {
	level_allocator := context.temp_allocator
		//Probably want to set this to something like a vmem.Arena
		//This arena would be flushed when a different level is loaded.
		//This can be used for all other allocations that exist for the duration that one level is loaded.

	rl.ChangeDirectory(rl.GetApplicationDirectory())
	rl.InitWindow(640, 480, "Tiles, it's what's for dinner")

	jb_32_tilemap := tiled.parse_tilemap("levels/jb-32.tmj", level_allocator)
		//This tilemap is in JSON format(.tmj), has "Tile Layer Format" CSV, and "Compression Level" -1.
		//the tileset is embedded in the .tmj, otherwise tiled.parse_tileset must be used in addition.

	tiled_map := jb_32_tilemap
	tileset := tiled_map.tilesets[0]

	tileset_texture_path := fmt.ctprintf("levels/%v",tileset.image)
	tileset_texture := rl.LoadTexture(tileset_texture_path)
	if !rl.IsTextureValid(tileset_texture) {
		panic(fmt.tprintf("Can't load texture from path '%v'", tileset_texture_path))
	}

	camera := rl.Camera2D { zoom = 1 }

	for !rl.WindowShouldClose() {
		elapsed := rl.GetFrameTime()

		camera_speed := 200 * elapsed
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

		rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.BeginMode2D(camera)

			for layer in tiled_map.layers {
				if layer.type != "tilelayer" do continue
				for gid, i in layer.data {
					world_x := f32((i32(i) % tiled_map.width) * tileset.tile_width)
					world_y := f32((i32(i) / tiled_map.width) * tileset.tile_height)
					tileset_idx := gid - tileset.first_gid
					tileset_x := f32((tileset_idx % tileset.columns) * tileset.tile_width)
					tileset_y := f32((tileset_idx / tileset.columns) * tileset.tile_height)
					source: rl.Rectangle = {tileset_x, tileset_y, f32(tileset.tile_width), f32(tileset.tile_height)}

					rl.DrawTextureRec(tileset_texture, source, {world_x, world_y}, rl.WHITE)
				}
			}

			rl.EndMode2D()
		rl.EndDrawing()
	}
}