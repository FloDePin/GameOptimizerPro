# Security policy

GameOptimizerPro runs with administrator rights, so security reports are taken seriously.

## Reporting a vulnerability

Please **don't open a public issue**. Use [**Report a vulnerability**](https://github.com/FloDePin/GameOptimizerPro/security/advisories/new) — GitHub's private reporting, only the maintainer can see it. Include what you found, how to reproduce it and which version (SHA256 of `GameOptimizerPro.ps1`) you used.

## Supported versions

Only the latest release is supported. Its SHA256 is published in [CHECKSUMS.txt](CHECKSUMS.txt).

## Verifying a download

`install.ps1` compares the downloaded script with the hash in `CHECKSUMS.txt` and warns before running anything that doesn't match. To check a file by hand:

```powershell
Get-FileHash .\GameOptimizerPro.ps1 -Algorithm SHA256
```
