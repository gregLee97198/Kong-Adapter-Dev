# SIT 3.9.3 — 2026-10-20

Source commit: db6b0bc. See 部署命令.md for node-by-node deployment.

This Git directory contains documentation, validation, dependency inventory and sanitized complete YAML examples only. Offline delivery is at C:/CMTF-II/delivery/20261020/kong-3.9.3.zip on the build machine; ZIP and image archives are not in Git.

adapter.example.yaml has no API key. Fill config_token locally and rename to adapter.yaml before using a configuration from Git. kong.example.yaml is the complete site-baseline Kong configuration. The locally delivered ZIP already contains the supplied key; do not upload it to Git.

SHA256SUMS describes the original private offline bundle, not the sanitized examples. Do not compare adapter.example.yaml against the private adapter.yaml checksum. Build/smoke checks passed; SIT deployment and Portal prerequisites remain user validation tasks. 13000 migration is user-managed.
