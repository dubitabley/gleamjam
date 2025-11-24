// custom javascript ffi based on the tiramisu code
// but for things that it doesn't provide
import * as THREE from "three";

/**
 * Load texture from data - see https://threejs.org/docs/#DataTexture
 * @param {TypedArray} data
 * @param {number} width
 * @param {number} height
 * @param {number} format
 * @returns {THREE.Texture}
 */
export function loadTextureFromData(data, width, height, format) {
    const texture = new THREE.DataTexture(data, width, height, format);
    texture.needsUpdate = true;
    return texture;
}

export const RGBFormat = () => THREE.RGBFormat;
export const RGBAFormat = () => THREE.RGBAFormat;

/**
 * Dispose of texture when it's not longer used
 * https://threejs.org/docs/#Texture.dispose
 * @param {Texture} texture
 */
export function disposeTexture(texture) {
    texture.dispose();
}
