<!--
{
  "availability" : [
    "iOS: 27.1.0 -",
    "iPadOS: 27.1.0 -",
    "macCatalyst: 27.1.0 -",
    "tvOS: 27.1.0 -",
    "visionOS: 27.1.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "UIKit",
  "identifier" : "/documentation/UIKit/UITraitCollection/verticalBarEdge",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Property",
  "symbol" : {
    "kind" : "Instance Property",
    "modules" : [
      "UIKit"
    ],
    "preciseIdentifier" : "c:objc(cs)UITraitCollection(py)verticalBarEdge"
  },
  "title" : "verticalBarEdge"
}
-->

# verticalBarEdge

The edge where the system places the vertical bar.

```
var verticalBarEdge: UIVerticalBarEdge { get }
```

## Discussion

This property reflects the system’s preferred edge regardless of whether a
vertical bar is currently visible. Returns `UIVerticalBarEdgeUnspecified` on
devices and in contexts where the system never places a vertical bar — for
example hardware without a vertical bar, or a size class or orientation in
which no vertical bar is used.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)