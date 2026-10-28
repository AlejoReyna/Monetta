<!--
{
  "availability" : [
    "iOS: 27.1.0 -",
    "iPadOS: 27.1.0 -",
    "macCatalyst: -",
    "tvOS: 27.1.0 -",
    "visionOS: 27.1.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "UIKit",
  "identifier" : "/documentation/UIKit/UIView/reservedRegions(kind:options:)",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "UIKit"
    ],
    "preciseIdentifier" : "s:So6UIViewC5UIKitE15reservedRegions4kind7optionsSayAbCE14ReservedRegionVGAH4KindV_AH12QueryOptionsVtF"
  },
  "title" : "reservedRegions(kind:options:)"
}
-->

# reservedRegions(kind:options:)

Returns the reserved regions of a kind that overlap the view.

```
@MainActor @preconcurrency func reservedRegions(kind: UIView.ReservedRegion.Kind, options: UIView.ReservedRegion.QueryOptions = []) -> [UIView.ReservedRegion]
```

## Parameters

`kind`

The kind of reserved region to return, such as [`occlusion`](/documentation/UIKit/UIView/ReservedRegion/Kind-swift.struct/occlusion) or [`division`](/documentation/UIKit/UIView/ReservedRegion/Kind-swift.struct/division).

`options`

Options that change which regions the method returns. By default, the method returns only active regions. Pass [`includeInactive`](/documentation/UIKit/UIView/ReservedRegion/QueryOptions/includeInactive) to also return regions that aren’t currently active.

## Return Value

The reserved regions that overlap the view, with frames in the view’s coordinate space.

## Discussion

Use this method to arrange your view’s content around areas that the device hardware reserves, such as a camera or the fold of a hinge. UIKit tracks the regions you read in [`updateConstraints()`](/documentation/UIKit/UIView/updateConstraints()) and runs it again when the regions change.

For more information, see [`UIView.ReservedRegion`](/documentation/UIKit/UIView/ReservedRegion).

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)