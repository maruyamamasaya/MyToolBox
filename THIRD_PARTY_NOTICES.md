# Third-party notices

## Stats (reference for AppleSMC protocol and M1 sensor mapping)

- Author: Serhiy Mytrovtsiy
- Copyright (c) 2019 Serhiy Mytrovtsiy
- License: MIT — [full text](Resources/Stats-LICENSE.txt)
- Source: [exelban/stats](https://github.com/exelban/stats)
- Referenced revision: `c9e7ebe3390a84e3075946ffe39dda709c4747b1`
- Reference files: `SMC/smc.swift`, `Modules/Sensors/values.swift`

MyToolBox's `SMCReader.swift` reimplements the read-only byte protocol; `Sensors.swift` uses the referenced M1 key classification. The MIT notice is retained with the repository and inside MyToolBox.app. No fan-control, unlock, helper, or write functionality is incorporated. Stats is not a runtime dependency.

## Japanese national holidays

Source: Cabinet Office, Government of Japan, [national holidays](https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html). The published CSV was retrieved on 2026-10-15 and converted to Resources/JapaneseHolidays.json (1955–2027). Attribution and transformation are documented in [local tools](docs/LOCAL_TOOLS.md). No network access is required at runtime.

## Browser tools (behavioral reference)

[maruyamamasaya/tool](https://github.com/maruyamamasaya/tool), revision c011a4aa3518af8c72686ed3cf6950363b3612d7. No repository license was identified. Its fifteen tools were inspected for behavior; source code and assets were not copied or bundled. Native Swift implementations are independent.
