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
<style scoped>
section {
    font-size: 30px;
}
</style>
![bg right:50% w:400](qr-code.png)
Gergely Brautigam 

https://github.com/Skarlso
https://gergelybrautigam.com 
https://github.com/external-secrets

QR code link to repository ->

---

# Agenda

- Why rotation is important
- External Secrets intro
- Rotation
- Demo
- ESO Reloader Demo
- Caveats
    - Downtime
    - Race conditions
- Closing words

---

# Why is it important to rotate secrets?

- the longer the token the longer the expouser and the chain of custody
- uber 2022 where a mobile device was compromised
- dependabot exploit of 2023
- cloudflare outage 2023. they rotated, however, due to human error some of the tokens
got exposed and they got inflitrated
- there are many many more...

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

# Different Generator Types
<style scoped>
section {
    font-size: 30px;
}
</style>

- Azure Container Registry
- AWS Elastic Container Registry
- AWS STS Session Token
- Google Container Registry
- Quay
- Vault Dynamic Secret
- Password
- Webhook ( _any_ type )
- Github
- UUID

---

# What we are trying to achieve

![width:700px center](demo-arch.png)

---

# Demo

---

# Drawbacks

- No second secret rotation process ( where you switch over to a second secret instead of updating
the current one )
- Race condition can occur when rotation happens at the wrong time ( retry )

---

# Conclusion

Thank you for listening!
Gergely.
@Skarlso
