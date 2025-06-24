In non-interactive CI/CD scenarios where certificates are used to authenticate with Azure Service Fabric, consider the following best practices:

### **Use Admin Certificates Instead of Cluster Certificates**
Cluster certificates are used for node-to-node and cluster-level authentication and are highly privileged.
For CI/CD pipelines, prefer using a dedicated Admin client certificate:

* Grants administrative access only at the client level.
* Limits the blast radius in case of exposure.
* Easier to rotate or revoke without impacting cluster internals.

### **Best practices to protect your service fabric certificates:**

- Provision a dedicated Service Fabric Admin certificate specifically for the CI/CD pipeline instead of cluster certificate. This certificate should not be reused across other services or users.
- Restrict access to this certificate strictly to the pipeline environment. It should never be distributed beyond what is necessary.
- Secure the pipeline itself, as it is part of the cluster’s supply chain and a high-value target for attackers.
- Implement telemetry and monitoring to detect potential exposure—such as unauthorized access to the CI/CD machine or unexpected distribution of the certificate.
- Establish a revocation and rotation plan to quickly respond if the certificate is compromised.
