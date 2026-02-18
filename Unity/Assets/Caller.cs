using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class Caller : MonoBehaviour
{
    public Receiver receiver;
    // Start is called before the first frame update
    void Start()
    {
        print("Calling");
        receiver.OnCalled();

    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
