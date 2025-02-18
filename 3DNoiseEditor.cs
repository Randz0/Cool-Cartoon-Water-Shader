using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(Noise3DGenerator))]
public class NoiseEditor : Editor // 3D editor, won't let me name it with numbers so sry in advance for the pmo syntax
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        Noise3DGenerator tiedTo = (Noise3DGenerator)target;

        if (GUILayout.Button("Do Something")) {
            tiedTo.GenerateNewNoiseTexture(10, 1, "first");
        }
    }
}
