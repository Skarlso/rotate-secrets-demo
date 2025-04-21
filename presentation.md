---
marp: true
theme: gaia
class: lead, invert
style: |
    section{
      justify-content: flex-start;
    }
---

# Automatic Secret rotation with ESO
![bg right:50% w:400](en.png)
Gergely Brautigam 

https://github.com/Skarlso
https://gergelybrautigam.com 
https://github.com/external-secrets

---

# Agenda

- External Secrets intro
- Rotation
- ESO Reloader
- Demo
- Caveats
    - Downtime
    - Race conditions
- Closing words

---

# What is External Secrets Operator

<style>
img[alt~="center"] {
  display: block;
  margin: 0 auto;
}
</style>

![width:300px center](secrets.png)

<!-- ![bg](secrets.png) -->

---

# Architecture

![width:850px center](diagrams-high-level-simple.png)

---

# Providers

- AWS
- GCP
- Vault
- Kubernetes
...

---

# SecretStore architecture

![width:550px center](secret-store.png)

---

# SecretStore

![width:500px center](secretstore.png)

---

# ExternalSecret

![width:500px center](externalsecret.png)

---

# What are generators

![width:500px center](generators_architecture.png)

---

# Vault Dynamic Secret Generator

![width:500px center](vault-generator.png)

---

# Demo

---

# Conclusion

Thank you for listening!
Gergely.
@Skarlso
