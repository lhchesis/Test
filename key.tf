resource "aws_key_pair" "sshkey" {
  key_name   = "user02-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCnP9+JqucAu0meragFTu49pMXTEsJSO3+fH9UPJNqHwG4UUz1DUB0vvvPq783pukwHvgH1zvmjtvlz5FqxB87QsTr/dEjSMdlzFADWexcq7HirYJXmZBFofwhpkvCEBA5eUyqwWt/CH86rroarnVIvK58j8/3FxuHH+tW9fyEhzPuMbJMm7+y+h5ttfbp/kG/acZBMpMkN2eZmWOs5Q5BK2dQEtQFPmHLdsFBhfglp32GqRa4iiMCQd7KAP21EDrm0MSw8kTHX8xHTR5Igazi+6TRFECo6qnjD4wUlSeDAhdvGr495DwIFMXwoEkL2Wk+1zPlt8qZ4JksKyaRm8YN ec2-user@ip-172-31-39-43"
}
