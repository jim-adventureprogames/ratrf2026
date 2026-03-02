shader_type canvas_item;

uniform vec4 colorHasLootMin : source_color;
uniform vec4 colorHasLootMax : source_color;

uniform vec4 colorMouseOverMin : source_color;
uniform vec4 colorMouseOverMax : source_color;

uniform vec4 colorObservantMin : source_color;
uniform vec4 colorObservantMax : source_color;

uniform vec4 colorHostileMin : source_color;
uniform vec4 colorHostileMax : source_color;

/*
see sprite_component.gd to keep up to date.
enum ESpriteBorderStyle 
{
	none = 0,
	has_loot = 1,
	observant = 2,
	hostile = 3,
	mouse_over = 999
}
*/

instance uniform int border_state;

void vertex() {
	// Called for every vertex the material is visible on.
}

vec4 getSinWave(vec4 minC, vec4 maxC, float period) {
	float delta = sin((TIME / period) * TAU) * 0.5f + 0.5f;
	return mix( minC, maxC, delta);
}

vec4 getBorderColor() {
	if( border_state == 1 )
		return getSinWave( colorHasLootMin, colorHasLootMax, 3.0f);
	if( border_state == 2 )
		return getSinWave( colorObservantMin, colorObservantMax, 2.0f);
	if( border_state == 3 )
		return getSinWave( colorHostileMin, colorHostileMax, 1.0f);
	if( border_state == 999)
		return getSinWave( colorMouseOverMin, colorMouseOverMax, 2.0f);
		
	return vec4(0,0,0,0);
}

void fragment() {
	
	vec4 src = texture(TEXTURE, UV);
	vec2 pxSize = TEXTURE_PIXEL_SIZE;
	
	
	float a0 = 1.0f - src.a;
	float a1 = texture(TEXTURE, UV + pxSize * vec2(1,0)).a;
	float a2 = texture(TEXTURE, UV + pxSize * vec2(-1,0)).a;
	float a3 = texture(TEXTURE, UV + pxSize * vec2(0,1)).a;
	float a4 = texture(TEXTURE, UV + pxSize * vec2(0,-1)).a;
	
	float border = clamp(a0 * (a1 + a2 + a3 + a4), 0.0, 1.0);
	// Called for every pixel the material is visible on.
	COLOR = getBorderColor() * border + src * (1.0f-border);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
