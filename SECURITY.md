# Security reporting and release policy

Report suspected vulnerabilities privately to alessandro.paperi@lansitec.com. Include app version, operating system, reproduction steps and impact. Do not post passwords, LoRa keys, customer identifiers or location traces in public issues.

Builds and diagnostics do not establish absence of vulnerabilities. The repository's security-review branches generate candidates with read-only build permissions; they do not automatically publish releases. Release approval requires reviewed test/build results, component/license inventory, verified artifact hashes/signatures and explicit tracking of residual risks. Do not describe an unsigned Windows installer as a verified publisher binary.

Android official signing material is held outside source control and CI. The official app identity differs from the prior guidedtest application. A company-controlled recoverable key backup must be arranged before broad distribution. Never commit private keys or credentials. CI must remain unable to sign official APKs.

Every platform change is recorded in PLATFORM_CHANGELOG.md. Maintain shared feature parity while preserving reviewed platform adapters. Recheck dependencies and threat assumptions before each release. There is no promised fixed support lifetime or vulnerability response SLA until Lansitec defines one.

