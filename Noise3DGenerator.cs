using UnityEditor;
using UnityEngine;


// This class mainly serves the purpose of generating 3D textures to be used for perlin noise sampling in shaders
// Basically just generates some random vectors using rgba values to store gradients
// Importantly, the noise itself is NOT perlin nor should it be read like noise, as no interpolation is done at this step
public class Noise3DGenerator : MonoBehaviour
{
    // Seeing as time complexity is of little concern, this function just uses rejection sampling
    private Vector3 GenerateRandomGradient(float _maxSteepness) {
        Quaternion rotationFromNeutral = Quaternion.Euler(Random.Range(0, 360), Random.Range(0, 360), Random.Range(0, 360));
        
        Vector3 newGradientDirection = rotationFromNeutral * Vector3.forward; // Randomly rotating to get an even distribution of pseudo-random directions the gradient can take
        
        return newGradientDirection * _maxSteepness;
    }

    public void GenerateNewNoiseTexture(int _size, float _maxSteepness, string name="Instance0.asset") {
        TextureFormat format = TextureFormat.RGB24; // Only needs to store a 3D gradient vector

        Texture3D noiseGradients = new Texture3D(_size, _size, _size, format, false);
        noiseGradients.wrapMode = TextureWrapMode.Repeat; // Should repeat for sampling across a large plane

        Color[] gradientVectors = new Color[_size * _size * _size];

        for (int i = 0; i < gradientVectors.Length; i++) { // Doesn't really matter the order in which map is generated
            Vector3 randomGradient = GenerateRandomGradient(_maxSteepness);
            
            gradientVectors[i] = new Color(randomGradient.x, randomGradient.y, randomGradient.z);
        }

        noiseGradients.SetPixels(gradientVectors);
        noiseGradients.Apply();

        AssetDatabase.CreateAsset(noiseGradients, $"Assets/NoiseMaps/{name}.asset");        
    }
}
