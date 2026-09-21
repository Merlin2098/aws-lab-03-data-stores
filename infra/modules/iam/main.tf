# Intentionally empty for now.
#
# The student uses their own AWS credentials (stored locally in
# .env.credentials, gitignored) to run scripts/*.py and AWS CLI commands
# against the lab resources — no dedicated IAM user/role is provisioned by
# Terraform for this first version (see docs/superpowers/specs/
# 2026-09-20-lab-storage-infra-design.md, section 6).
#
# This module exists as the designated home for any IAM role/policy that
# does not have a natural home inside another module (per the IAM
# cross-module placement rule in AGENTS.md). Add resources here only when
# such a need arises.
