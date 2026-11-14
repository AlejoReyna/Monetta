<div align="center">

# Monetta

<p><em>Video preview pending.</em></p>

<!-- Add the demo video here when it is ready. -->

_An iOS and Android storefront for Monetta, with a live Shopify catalog, personalized recommendations, and native checkout._

</div>

Develop from source with Flutter 3.44.8 and a device or simulator:

```bash
git clone https://github.com/AlejoReyna/Monetta.git
cd Monetta
make setup
make gen
cp config/dart_defines.staging.json.example config/dart_defines.staging.json
# Fill in the public staging values using config/README.md.
make run-staging
```

<sub>[Configuration](./config/README.md) · [Architecture](./docs/ARCHITECTURE.md) · [Technical reference](./DEVELOPMENT.md)</sub>
