vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord)
{
    float alpha = 1.0 - clamp(screenCoord.x / love_ScreenSize.x * 2.0, 0.0, 1.0);
    return vec4(0.0, 0.0, 0.0, alpha * 0.8);
}
