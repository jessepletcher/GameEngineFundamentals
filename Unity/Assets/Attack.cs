using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ClickLogger : MonoBehaviour
{
    void Update()
    {
        if (Input.GetMouseButtonDown(0)) // 0 = left click
        {
            Debug.Log("Attack!!");
        }
    }
}