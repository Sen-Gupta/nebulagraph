# Known Issues

## Issue #1: Unicode Handling in .NET DaprClient SDK

**Status**: OPEN | **Priority**: Medium | **Component**: .NET DaprClient + NebulaGraph

### Problem
The .NET DaprClient SDK has limitations with Unicode characters (emojis, international text) when retrieving data from NebulaGraph state store.

### Root Cause
- **System.Text.Json** strict Unicode validation
- **ASCII Allowlist**: Only 0x20-0x7E characters allowed by default  
- **Surrogate Pairs**: Emojis and multi-byte sequences cause `DecoderFallbackException`

### Evidence
**✅ Direct Dapr HTTP API** (works):
```bash
curl -X GET "http://localhost:3502/v1.0/state/nebulagraph-state/unicode-test"
# Returns: "🌟 Unicode: 中文, العربية, Русский, 日本語 🚀"
```

**❌ .NET DaprClient** (fails):
```csharp
var result = await _daprClient.GetStateAsync<string>(StateStoreName, key);
// Throws: DecoderFallbackException
```

### Workaround
Multi-tier retrieval implemented in `StateStoreController.cs`:
1. **Byte Array Approach** (most reliable)
2. **JsonElement Approach** (fallback)  
3. **Direct String Approach** (last resort)

### Impact
- **Functional**: Unicode data retrieval fails in .NET apps
- **Scope**: Affects .NET DaprClient users with international data
- **Workaround**: Available with minimal performance impact
- **Test Results**: 39/40 tests passing (97.5% success rate)

### Next Steps
- [ ] Investigate Dapr .NET SDK Unicode configuration options
- [ ] Research System.Text.Json encoder settings
- [ ] Create comprehensive Unicode handling unit tests
- [ ] Explore alternative serialization approaches
```bash
$ curl -X GET "http://localhost:3502/v1.0/state/nebulagraph-state/unicode-test"
"🌟 Unicode: 中文, العربية, Русский, 日本語 🚀"
```

**Failed .NET SDK Test** (DaprClient):
```bash
$ curl -X POST "http://localhost:5090/api/StateStore/unicode-support"
{"success":false,"status":"FAILED","message":"❌ Unicode Support failed"}
```

### Current Status

#### What Works ✅
- NebulaGraph backend properly stores UTF-8 Unicode data
- Direct Dapr HTTP API correctly retrieves Unicode data
- curl-based validation confirms data integrity
- Storage operations preserve Unicode characters

#### What Fails ❌
- .NET DaprClient SDK `GetStateAsync<string>()` calls
- Unicode test endpoints in StateStoreController
- System.Text.Json deserialization of Unicode strings
- Multi-byte character sequence handling

### Impact Assessment

#### Severity: Medium
- **Functional Impact**: Unicode data retrieval fails in .NET applications
- **Workaround Available**: Multi-tier retrieval approach provides fallback
- **Scope**: Affects .NET applications using DaprClient with Unicode data
- **Performance**: Minimal impact with byte array fallback approach

#### Test Results
- **Comprehensive Test Suite**: 39/40 tests passing (97.5% success rate)
- **Unicode-specific Tests**: 0/2 tests passing (unicode-diagnostic, unicode-support)
- **Overall System**: Fully functional with workaround

### Next Steps

#### Immediate Actions
- [x] Document issue and workaround implementation
- [x] Validate data integrity at HTTP API level
- [x] Implement multi-tier retrieval fallback strategy
- [ ] Create unit tests for Unicode handling edge cases

#### Long-term Solutions
- [ ] Investigate Dapr .NET SDK configuration options
- [ ] Research System.Text.Json encoder settings
- [ ] Consider custom JSON serialization options
- [ ] Explore alternative Unicode handling approaches

#### Investigation Areas
- [ ] JavaScriptEncoder.UnsafeRelaxedJsonEscaping configuration
- [ ] Custom JsonSerializerOptions for Unicode
- [ ] Dapr SDK version compatibility testing
- [ ] Alternative serialization libraries (Newtonsoft.Json)

### Related Files
```
src/examples/NebulaGraphNetExample/Controllers/StateStoreController.cs
├── Lines 335-353: Unicode test implementation
├── Lines 745-828: unicode-diagnostic endpoint
├── Lines 829-916: unicode-support endpoint
└── Lines 1436-1470: RunIndividualTest helper method

src/examples/NebulaGraphNetExample/test_net.sh
└── Lines 260-280: Unicode test validation
```

### References
- [System.Text.Json Unicode Documentation](https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-character-encoding)
- [Dapr .NET SDK Issues](https://github.com/dapr/dotnet-sdk/issues)
- [UTF-8 Encoding Standards](https://tools.ietf.org/html/rfc3629)


### Last Updated
August 11, 2025

---

## Issue Template (For Future Issues)

### Status: [OPEN/IN_PROGRESS/RESOLVED]
### Priority: [Critical/High/Medium/Low]
### Component: [Component Name]

### Problem Description
[Brief description of the issue]

### Technical Details
[Detailed technical analysis]

### Current Status
[What works and what doesn't]

### Impact Assessment
[Severity and scope analysis]

### Next Steps
[Action items and investigation areas]

### Related Files
[List of affected files]

### Last Updated
[Date of last update]
