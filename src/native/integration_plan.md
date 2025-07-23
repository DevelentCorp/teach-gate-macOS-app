# TeachGateVPN Native Module Integration Plan

## Windows Implementation (`TeachGateVpn`)

### 1. File Structure

- **TeachGateVpn.sln**: Visual Studio Solution
- **TeachGateVpn/**: C# Project Directory
  - **TeachGateVpn.csproj**: C# Project File
  - **TeachGateVpnService.cs**: Main VPN Service
  - **Properties/**
    - **AssemblyInfo.cs**: Assembly Information
- **TeachGateVpn-Unit-Tests/** (Optional): Unit Test Project

### 2. Class Definition (`TeachGateVpnService.cs`)

```csharp
namespace TeachGateVpn
{
    public class TeachGateVpnService
    {
        // Service state and properties
        private string ServerAddress { get; set; }
        private string Password { get; set; }
        private bool IsConnected { get; set; }

        // Service methods
        public void Start(string config, int port) { ... }
        public void Stop() { ... }
        public void Disconnect() { ... }
        public bool IsRunning() { ... }
    }
}
```

### 3. React Native Bridging (`TeachGateModule.cs`)

- A C# implementation of the `TeachGateModule` that will be projected into React Native.

```csharp
using ReactNative.Bridge;
using ReactNative.Modules.Core;

namespace TeachGateVpn
{
    public class TeachGateModule : ReactContextBaseJavaModule
    {
        public TeachGateModule(ReactApplicationContext reactContext) : base(reactContext) { }

        public override string Name => "TeachGateVpn";

        [ReactMethod]
        public void Start(string serverAddress, string password) { ... }

        [ReactMethod]
        public void Stop() { ... }

        [ReactMethod]
        public void GetStatus(IPromise promise) { ... }
    }
}
```

### 4. `TeachGatePackage.cs`

- The `TeachGatePackage` will register the `TeachGateModule` with React Native.

```csharp
using ReactNative.Bridge;
using ReactNative.Modules.Core;
using System.Collections.Generic;

namespace TeachGateVpn
{
    public class TeachGatePackage : IReactPackage
    {
        public IReadOnlyList<INativeModule> CreateNativeModules(ReactApplicationContext reactContext)
        {
            return new List<INativeModule>
            {
                new TeachGateModule(reactContext)
            };
        }

        public IReadOnlyList<Type> CreateViewManagers(ReactApplicationContext reactContext)
        {
            return new List<Type>();
        }
    }
}
```

## macOS Implementation (`TeachGateVpn`)

- The macOS implementation will be done in Swift and will follow a similar structure.
- A `TeachGateVpn.swift` file will contain the main logic, and it will be bridged to React Native using a `TeachGateVpn.m` file.
